import { pool } from '../config/database.js';

/**
 * Lấy ngẫu nhiên N từ trong topic để làm quiz (client tự trộn đáp án).
 */
export async function getQuestions(req, res) {
  try {
    const topicId = req.query.topic_id ? Number(req.query.topic_id) : null;
    const limit = Math.min(Math.max(Number(req.query.limit) || 10, 1), 50);
    if (!topicId || Number.isNaN(topicId)) {
      return res.status(400).json({ message: 'Cần topic_id' });
    }
    const [topics] = await pool.execute(
      `SELECT id, name FROM topics WHERE id = :topicId LIMIT 1`,
      { topicId },
    );
    if (!topics.length) {
      return res.status(404).json({ message: 'Không tìm thấy chủ đề' });
    }
    const topicName = topics[0].name;

    const [cntRows] = await pool.execute(
      `SELECT COUNT(*) AS cnt FROM quiz_questions WHERE topic_id = :topicId`,
      { topicId },
    );
    const bankCount = Number(cntRows[0]?.cnt) || 0;

    if (bankCount > 0) {
      const take = Math.min(limit, bankCount);
      const [bankRows] = await pool.query(
        `SELECT id, topic_id, prompt, option_a, option_b, option_c, option_d,
                correct_index, explanation
         FROM quiz_questions
         WHERE topic_id = ?
         ORDER BY RAND()
         LIMIT ?`,
        [topicId, take],
      );
      const questions = bankRows.map((row) => ({
        id: row.id,
        prompt: row.prompt,
        options: [row.option_a, row.option_b, row.option_c, row.option_d],
        correct_index: Number(row.correct_index),
        explanation: row.explanation,
      }));
      return res.json({
        mode: 'bank',
        topic_id: topicId,
        topic_name: topicName,
        questions,
        count: questions.length,
      });
    }

    const [rows] = await pool.query(
      `SELECT id, word, meaning, pronunciation, example, topic_id, difficulty
       FROM vocabularies
       WHERE topic_id = ?
       ORDER BY RAND()
       LIMIT ?`,
      [topicId, limit],
    );
    return res.json({
      mode: 'vocab',
      topic_id: topicId,
      topic_name: topicName,
      questions: rows,
      count: rows.length,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** Nộp bài: body { topic_id?, total_questions, correct_count } — score = %; cộng XP và cập nhật level */
export async function submitResult(req, res) {
  try {
    const userId = req.user.id;
    const {
      topic_id: topicId,
      total_questions: totalQuestions,
      correct_count: correctCount,
    } = req.body ?? {};
    const total = Number(totalQuestions) || 10;
    const correct = Number(correctCount);
    if (Number.isNaN(correct) || correct < 0 || correct > total) {
      return res.status(400).json({ message: 'correct_count không hợp lệ' });
    }
    let tid = null;
    if (topicId !== undefined && topicId !== null && topicId !== '') {
      tid = Number(topicId);
      if (Number.isNaN(tid)) {
        return res.status(400).json({ message: 'topic_id không hợp lệ' });
      }
      const [t] = await pool.execute(
        `SELECT id FROM topics WHERE id = :tid LIMIT 1`,
        { tid },
      );
      if (!t.length) {
        return res.status(404).json({ message: 'Không tìm thấy chủ đề' });
      }
    }
    const score = Math.round((correct * 100) / total);
    const xpGain = correct * 5;
    const [result] = await pool.execute(
      `INSERT INTO quiz_results (user_id, topic_id, score, total_questions, correct_count)
       VALUES (:userId, :topicId, :score, :total, :correct)`,
      {
        userId,
        topicId: tid,
        score,
        total,
        correct,
      },
    );
    /** XP + level: mỗi 500 XP tăng 1 level (tối đa 99) */
    await pool.execute(
      `UPDATE users SET
        xp = xp + :xpGain,
        level = LEAST(99, GREATEST(1, 1 + FLOOR((xp + :xpGain) / 500)))
       WHERE id = :userId`,
      { xpGain, userId },
    );
    const [userRow] = await pool.execute(
      `SELECT id, username, xp, level FROM users WHERE id = :userId LIMIT 1`,
      { userId },
    );
    const u = userRow[0];
    return res.status(201).json({
      id: result.insertId,
      score,
      total_questions: total,
      correct_count: correct,
      xp_gained: xpGain,
      user: { xp: u.xp, level: u.level },
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function listMyResults(req, res) {
  try {
    const userId = req.user.id;
    const [rows] = await pool.execute(
      `SELECT qr.id, qr.topic_id, qr.score, qr.total_questions, qr.correct_count, qr.created_at,
              t.name AS topic_name
       FROM quiz_results qr
       LEFT JOIN topics t ON t.id = qr.topic_id
       WHERE qr.user_id = :userId
       ORDER BY qr.created_at DESC`,
      { userId },
    );
    return res.json(rows);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
