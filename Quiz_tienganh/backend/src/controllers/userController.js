import bcrypt from 'bcryptjs';

import { pool } from '../config/database.js';
import { createUser, findUserByUsername } from '../services/authService.js';

function rankTitle(level) {
  const n = Number(level);
  if (n >= 55) {
    return 'Bậc thầy ngôn ngữ';
  }
  if (n >= 40) {
    return 'Chuyên gia từ vựng';
  }
  if (n >= 25) {
    return 'Học giả tích cực';
  }
  if (n >= 10) {
    return 'Người học nâng cao';
  }
  return 'Người học';
}

export async function list(_req, res) {
  try {
    const [rows] = await pool.execute(
      `SELECT id, username, level, xp, role, created_at FROM users ORDER BY id ASC`,
    );
    return res.json(rows);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** Admin tạo tài khoản (học viên hoặc admin phụ) */
export async function adminCreate(req, res) {
  try {
    const { username, password, role } = req.body ?? {};
    if (!username || !password) {
      return res.status(400).json({ message: 'Cần username và password' });
    }
    if (String(username).length < 3 || String(password).length < 6) {
      return res
        .status(400)
        .json({ message: 'Username >= 3 ký tự, password >= 6 ký tự' });
    }
    const r = role === 'admin' ? 'admin' : 'learner';
    const exists = await findUserByUsername(String(username).trim());
    if (exists) {
      return res.status(409).json({ message: 'Username đã tồn tại' });
    }
    const id = await createUser({
      username: String(username).trim(),
      password: String(password),
      role: r,
    });
    return res.status(201).json({ id });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** Hồ sơ chi tiết cho modal admin */
export async function adminProfile(req, res) {
  try {
    const id = Number(req.params.id);
    const [rows] = await pool.execute(
      `SELECT u.id, u.username, u.level, u.xp, u.role, u.created_at,
        (SELECT COUNT(*) FROM user_vocabulary uv WHERE uv.user_id = u.id) AS vocab_count,
        (SELECT ROUND(AVG(qr.score), 1) FROM quiz_results qr WHERE qr.user_id = u.id) AS quiz_avg,
        (SELECT COUNT(*) FROM quiz_results qr WHERE qr.user_id = u.id) AS quiz_attempts,
        (SELECT MAX(created_at) FROM quiz_results WHERE user_id = u.id) AS last_quiz,
        (SELECT MAX(last_review) FROM user_vocabulary WHERE user_id = u.id) AS last_vocab
       FROM users u WHERE u.id = :id LIMIT 1`,
      { id },
    );
    if (!rows.length) {
      return res.status(404).json({ message: 'Không tìm thấy user' });
    }
    const u = rows[0];
    const a = u.last_quiz ? new Date(u.last_quiz).getTime() : 0;
    const b = u.last_vocab ? new Date(u.last_vocab).getTime() : 0;
    const last = a >= b ? u.last_quiz : u.last_vocab;
    const segment = 5000;
    const mod = Number(u.xp) % segment;
    const levelProgress = mod / segment;
    const xpUntilNext = segment - mod;

    return res.json({
      id: u.id,
      username: u.username,
      level: u.level,
      xp: u.xp,
      role: u.role,
      created_at: u.created_at,
      vocab_count: Number(u.vocab_count),
      quiz_avg: u.quiz_avg != null ? Number(u.quiz_avg) : 0,
      quiz_attempts: Number(u.quiz_attempts),
      last_activity: last,
      rank_title: rankTitle(u.level),
      level_progress: levelProgress,
      xp_until_next: xpUntilNext,
      display_handle: `@${u.username}`,
      email: `${u.username}@atelier.quiz`,
      preferred_language: 'Tiếng Việt (mặc định)',
      student_id: `USR-${String(u.id).padStart(5, '0')}`,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** Admin đặt lại mật khẩu */
export async function resetPassword(req, res) {
  try {
    const id = Number(req.params.id);
    const { password } = req.body ?? {};
    if (!password || String(password).length < 6) {
      return res.status(400).json({ message: 'Mật khẩu >= 6 ký tự' });
    }
    const hash = await bcrypt.hash(String(password), 10);
    const [result] = await pool.execute(
      `UPDATE users SET password = :hash WHERE id = :id`,
      { id, hash },
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Không tìm thấy user' });
    }
    return res.json({ ok: true });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function getById(req, res) {
  try {
    const id = Number(req.params.id);
    if (req.user.role !== 'admin' && req.user.id !== id) {
      return res.status(403).json({ message: 'Không được xem user khác' });
    }
    const [rows] = await pool.execute(
      `SELECT id, username, level, xp, role, created_at FROM users WHERE id = :id LIMIT 1`,
      { id },
    );
    if (!rows.length) {
      return res.status(404).json({ message: 'Không tìm thấy user' });
    }
    return res.json(rows[0]);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** Admin chỉnh level/xp; learner có thể cập nhật chính mình (giới hạn sau). */
export async function update(req, res) {
  try {
    const id = Number(req.params.id);
    const { level, xp } = req.body ?? {};
    if (req.user.role !== 'admin' && req.user.id !== id) {
      return res.status(403).json({ message: 'Không được sửa user khác' });
    }
    if (req.user.role !== 'admin' && (level !== undefined || xp !== undefined)) {
      return res.status(403).json({ message: 'Chỉ admin được đổi level/xp' });
    }
    const [existing] = await pool.execute(
      `SELECT id, level, xp FROM users WHERE id = :id LIMIT 1`,
      { id },
    );
    if (!existing.length) {
      return res.status(404).json({ message: 'Không tìm thấy user' });
    }
    const row = existing[0];
    const nextLevel = level !== undefined ? Number(level) : row.level;
    const nextXp = xp !== undefined ? Number(xp) : row.xp;
    await pool.execute(
      `UPDATE users SET level = :level, xp = :xp WHERE id = :id`,
      { id, level: nextLevel, xp: nextXp },
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
    if (id === req.user.id) {
      return res.status(400).json({ message: 'Không xóa chính mình' });
    }
    const [result] = await pool.execute(`DELETE FROM users WHERE id = :id`, {
      id,
    });
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Không tìm thấy user' });
    }
    return res.status(204).send();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
