import { pool } from '../config/database.js';

export async function list(_req, res) {
  try {
    const [rows] = await pool.execute(
      `SELECT t.id, t.name, t.description, t.created_at,
        (SELECT COUNT(*) FROM vocabularies v WHERE v.topic_id = t.id) AS word_count
       FROM topics t
       ORDER BY t.id ASC`,
    );
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
    const [rows] = await pool.execute(
      `SELECT t.id, t.name, t.description, t.created_at,
        (SELECT COUNT(*) FROM vocabularies v WHERE v.topic_id = t.id) AS word_count
       FROM topics t WHERE t.id = :id LIMIT 1`,
      { id },
    );
    if (!rows.length) {
      return res.status(404).json({ message: 'Không tìm thấy chủ đề' });
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
    const { name, description } = req.body ?? {};
    if (!name || String(name).trim() === '') {
      return res.status(400).json({ message: 'Cần name' });
    }
    const [result] = await pool.execute(
      `INSERT INTO topics (name, description) VALUES (:name, :description)`,
      { name: String(name).trim(), description: description ?? null },
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
    const { name, description } = req.body ?? {};
    const [existing] = await pool.execute(
      `SELECT id, name, description FROM topics WHERE id = :id LIMIT 1`,
      { id },
    );
    if (!existing.length) {
      return res.status(404).json({ message: 'Không tìm thấy chủ đề' });
    }
    const nextName =
      name !== undefined ? String(name).trim() : existing[0].name;
    const nextDesc =
      description !== undefined ? description : existing[0].description;
    await pool.execute(
      `UPDATE topics SET name = :name, description = :description WHERE id = :id`,
      { id, name: nextName, description: nextDesc },
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
    const [result] = await pool.execute(`DELETE FROM topics WHERE id = :id`, { id });
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Không tìm thấy chủ đề' });
    }
    return res.status(204).send();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
