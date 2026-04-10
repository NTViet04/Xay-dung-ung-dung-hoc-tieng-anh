import { pool } from '../config/database.js';

const DIFFICULTIES = ['B1', 'B2', 'C1'];

function masterySelectSql() {
  return `(
    SELECT
      CASE
        WHEN COUNT(*) = 0 THEN 'Med'
        WHEN SUM(status = 'mastered') >= 0.75 * COUNT(*) THEN 'Expert'
        WHEN SUM(status = 'mastered') >= 0.5 * COUNT(*) THEN 'High'
        WHEN SUM(status = 'mastered') >= 0.25 * COUNT(*) THEN 'Med'
        ELSE 'Low'
      END
    FROM user_vocabulary uv
    WHERE uv.vocab_id = v.id
  ) AS mastery_label`;
}

export async function list(req, res) {
  try {
    const topicId = req.query.topic_id ? Number(req.query.topic_id) : null;
    const rawDiff = req.query.difficulty
      ? String(req.query.difficulty).toUpperCase()
      : null;
    const difficulty =
      rawDiff && DIFFICULTIES.includes(rawDiff) ? rawDiff : null;
    const q = req.query.q ? String(req.query.q).trim() : '';

    let sql = `SELECT v.id, v.word, v.meaning, v.pronunciation, v.example, v.topic_id,
      v.difficulty, v.created_at, t.name AS topic_name,
      ${masterySelectSql()}
      FROM vocabularies v
      INNER JOIN topics t ON t.id = v.topic_id`;
    const params = {};
    const where = [];
    if (topicId && !Number.isNaN(topicId)) {
      where.push('v.topic_id = :topicId');
      params.topicId = topicId;
    }
    if (difficulty) {
      where.push('v.difficulty = :difficulty');
      params.difficulty = difficulty;
    }
    if (q.length > 0) {
      where.push(
        '(v.word LIKE :q OR v.meaning LIKE :q OR v.pronunciation LIKE :q)',
      );
      params.q = `%${q}%`;
    }
    if (where.length) {
      sql += ` WHERE ${where.join(' AND ')}`;
    }
    sql += ' ORDER BY v.id ASC';
    const [rows] = await pool.execute(sql, params);
    return res.json(rows);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function getById(req, res) {
  try {
    const id = Number(req.params.id);
    const sql = `SELECT v.id, v.word, v.meaning, v.pronunciation, v.example, v.topic_id,
      v.difficulty, v.created_at, t.name AS topic_name,
      ${masterySelectSql()}
      FROM vocabularies v
      INNER JOIN topics t ON t.id = v.topic_id
      WHERE v.id = :id LIMIT 1`;
    const [rows] = await pool.execute(sql, { id });
    if (!rows.length) {
      return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    }
    return res.json(rows[0]);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function create(req, res) {
  try {
    const {
      word,
      meaning,
      pronunciation,
      example,
      topic_id: topicId,
      difficulty: rawDiff,
    } = req.body ?? {};
    if (!word || !meaning || !topicId) {
      return res.status(400).json({ message: 'Cần word, meaning, topic_id' });
    }
    const difficulty =
      rawDiff && DIFFICULTIES.includes(String(rawDiff).toUpperCase())
        ? String(rawDiff).toUpperCase()
        : 'B2';
    const [result] = await pool.execute(
      `INSERT INTO vocabularies (word, meaning, pronunciation, example, topic_id, difficulty)
       VALUES (:word, :meaning, :pronunciation, :example, :topic_id, :difficulty)`,
      {
        word: String(word).trim(),
        meaning: String(meaning).trim(),
        pronunciation: pronunciation ?? null,
        example: example ?? null,
        topic_id: Number(topicId),
        difficulty,
      },
    );
    return res.status(201).json({ id: result.insertId });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function update(req, res) {
  try {
    const id = Number(req.params.id);
    const [existing] = await pool.execute(
      `SELECT * FROM vocabularies WHERE id = :id LIMIT 1`,
      { id },
    );
    if (!existing.length) {
      return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    }
    const row = existing[0];
    const {
      word,
      meaning,
      pronunciation,
      example,
      topic_id: topicId,
      difficulty: rawDiff,
    } = req.body ?? {};
    let difficulty = row.difficulty;
    if (rawDiff !== undefined) {
      const u = String(rawDiff).toUpperCase();
      difficulty = DIFFICULTIES.includes(u) ? u : row.difficulty;
    }
    await pool.execute(
      `UPDATE vocabularies SET word = :word, meaning = :meaning, pronunciation = :pronunciation,
       example = :example, topic_id = :topic_id, difficulty = :difficulty WHERE id = :id`,
      {
        id,
        word: word !== undefined ? String(word).trim() : row.word,
        meaning: meaning !== undefined ? String(meaning).trim() : row.meaning,
        pronunciation:
          pronunciation !== undefined ? pronunciation : row.pronunciation,
        example: example !== undefined ? example : row.example,
        topic_id:
          topicId !== undefined ? Number(topicId) : row.topic_id,
        difficulty,
      },
    );
    return res.json({ ok: true });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function remove(req, res) {
  try {
    const id = Number(req.params.id);
    const [result] = await pool.execute(
      `DELETE FROM vocabularies WHERE id = :id`,
      { id },
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    }
    return res.status(204).send();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
