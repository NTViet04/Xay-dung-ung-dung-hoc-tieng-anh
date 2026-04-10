import { pool } from '../config/database.js';

/** Tiến độ từ của user đang đăng nhập */
export async function listMine(req, res) {
  try {
    const userId = req.user.id;
    const [rows] = await pool.execute(
      `SELECT uv.id, uv.vocab_id, uv.status, uv.last_review, uv.created_at,
              v.word, v.meaning, v.topic_id
       FROM user_vocabulary uv
       JOIN vocabularies v ON v.id = uv.vocab_id
       WHERE uv.user_id = :userId
       ORDER BY uv.id ASC`,
      { userId },
    );
    return res.json(rows);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** Ghi nhận / cập nhật tiến độ một từ */
export async function upsert(req, res) {
  try {
    const userId = req.user.id;
    const { vocab_id: vocabId, status, last_review: lastReview } = req.body ?? {};
    if (!vocabId || !status) {
      return res.status(400).json({ message: 'Cần vocab_id và status' });
    }
    const allowed = ['new', 'learning', 'review', 'mastered'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ message: 'status không hợp lệ' });
    }
    const [v] = await pool.execute(
      `SELECT id FROM vocabularies WHERE id = :id LIMIT 1`,
      { id: Number(vocabId) },
    );
    if (!v.length) {
      return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    }
    const lr =
      lastReview !== undefined && lastReview !== null
        ? new Date(lastReview)
        : null;
    const vid = Number(vocabId);
    const [existing] = await pool.execute(
      `SELECT id FROM user_vocabulary WHERE user_id = :userId AND vocab_id = :vid LIMIT 1`,
      { userId, vid },
    );
    if (existing.length) {
      await pool.execute(
        `UPDATE user_vocabulary SET status = :status, last_review = :lastReview WHERE id = :id`,
        { status, lastReview: lr, id: existing[0].id },
      );
    } else {
      await pool.execute(
        `INSERT INTO user_vocabulary (user_id, vocab_id, status, last_review)
         VALUES (:userId, :vid, :status, :lastReview)`,
        { userId, vid, status, lastReview: lr },
      );
    }
    return res.status(201).json({ ok: true });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
