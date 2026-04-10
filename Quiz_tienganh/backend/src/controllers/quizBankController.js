import { pool } from '../config/database.js';

function parseIndex(v) {
  const n = Number(v);
  if (Number.isNaN(n) || n < 0 || n > 3) {
    return null;
  }
  return n;
}

function normalizeQuestionRow(r) {
  return {
    id: Number(r.id),
    topic_id: Number(r.topic_id),
    topic_name: r.topic_name != null ? String(r.topic_name) : null,
    prompt: r.prompt,
    option_a: r.option_a,
    option_b: r.option_b,
    option_c: r.option_c,
    option_d: r.option_d,
    correct_index: Number(r.correct_index),
    explanation: r.explanation,
    sort_order: Number(r.sort_order ?? 0),
    created_at: r.created_at,
  };
}

/** GET /quiz/bank-questions — toàn bộ (admin) hoặc ?topic_id= — lọc một chủ đề */
export async function listByTopic(req, res) {
  try {
    const raw = req.query.topic_id;
    const topicId = raw !== undefined && raw !== null && String(raw).trim() !== ''
      ? Number(raw)
      : null;
    if (topicId != null && !Number.isNaN(topicId)) {
      const [rows] = await pool.execute(
        `SELECT qq.id, qq.topic_id, t.name AS topic_name, qq.prompt,
                qq.option_a, qq.option_b, qq.option_c, qq.option_d,
                qq.correct_index, qq.explanation, qq.sort_order, qq.created_at
         FROM quiz_questions qq
         INNER JOIN topics t ON t.id = qq.topic_id
         WHERE qq.topic_id = :topicId
         ORDER BY qq.sort_order ASC, qq.id ASC`,
        { topicId },
      );
      return res.json(rows.map(normalizeQuestionRow));
    }
    const [rows] = await pool.execute(
      `SELECT qq.id, qq.topic_id, t.name AS topic_name, qq.prompt,
              qq.option_a, qq.option_b, qq.option_c, qq.option_d,
              qq.correct_index, qq.explanation, qq.sort_order, qq.created_at
       FROM quiz_questions qq
       INNER JOIN topics t ON t.id = qq.topic_id
       ORDER BY qq.topic_id ASC, qq.sort_order ASC, qq.id ASC`,
    );
    return res.json(rows.map(normalizeQuestionRow));
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** POST /quiz/bank-questions */
export async function create(req, res) {
  try {
    const {
      topic_id: topicId,
      prompt,
      option_a: optionA,
      option_b: optionB,
      option_c: optionC,
      option_d: optionD,
      correct_index: correctRaw,
      explanation,
      sort_order: sortOrder,
    } = req.body ?? {};
    const tid = Number(topicId);
    if (!tid || Number.isNaN(tid)) {
      return res.status(400).json({ message: 'topic_id không hợp lệ' });
    }
    if (!prompt || String(prompt).trim().length === 0) {
      return res.status(400).json({ message: 'Nội dung câu hỏi (prompt) là bắt buộc' });
    }
    const a = optionA != null ? String(optionA).trim() : '';
    const b = optionB != null ? String(optionB).trim() : '';
    const c = optionC != null ? String(optionC).trim() : '';
    const d = optionD != null ? String(optionD).trim() : '';
    if (!a || !b || !c || !d) {
      return res.status(400).json({ message: 'Đủ 4 đáp án A–D' });
    }
    const correctIndex = parseIndex(correctRaw);
    if (correctIndex === null) {
      return res.status(400).json({ message: 'correct_index phải là 0–3 (A–D)' });
    }
    const [t] = await pool.execute(`SELECT id FROM topics WHERE id = :tid LIMIT 1`, {
      tid,
    });
    if (!t.length) {
      return res.status(404).json({ message: 'Không tìm thấy chủ đề' });
    }
    const sort = Number(sortOrder);
    const order = Number.isNaN(sort) ? 0 : sort;
    const expl = explanation != null && String(explanation).trim().length > 0
      ? String(explanation).trim()
      : null;

    const [result] = await pool.execute(
      `INSERT INTO quiz_questions
        (topic_id, prompt, option_a, option_b, option_c, option_d, correct_index, explanation, sort_order)
       VALUES (:tid, :prompt, :a, :b, :c, :d, :ci, :expl, :ord)`,
      {
        tid,
        prompt: String(prompt).trim(),
        a,
        b,
        c,
        d,
        ci: correctIndex,
        expl,
        ord: order,
      },
    );
    return res.status(201).json({ id: result.insertId });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** PUT /quiz/bank-questions/:id */
export async function update(req, res) {
  try {
    const id = Number(req.params.id);
    if (!id || Number.isNaN(id)) {
      return res.status(400).json({ message: 'id không hợp lệ' });
    }
    const {
      prompt,
      option_a: optionA,
      option_b: optionB,
      option_c: optionC,
      option_d: optionD,
      correct_index: correctRaw,
      explanation,
      sort_order: sortOrder,
    } = req.body ?? {};

    const [existing] = await pool.execute(
      `SELECT id FROM quiz_questions WHERE id = :id LIMIT 1`,
      { id },
    );
    if (!existing.length) {
      return res.status(404).json({ message: 'Không tìm thấy câu hỏi' });
    }

    const correctIndex = parseIndex(correctRaw);
    if (correctRaw !== undefined && correctIndex === null) {
      return res.status(400).json({ message: 'correct_index phải là 0–3' });
    }

    const fields = [];
    const params = { id };

    if (prompt !== undefined) {
      fields.push('prompt = :prompt');
      params.prompt = String(prompt).trim();
    }
    if (optionA !== undefined) {
      fields.push('option_a = :oa');
      params.oa = String(optionA).trim();
    }
    if (optionB !== undefined) {
      fields.push('option_b = :ob');
      params.ob = String(optionB).trim();
    }
    if (optionC !== undefined) {
      fields.push('option_c = :oc');
      params.oc = String(optionC).trim();
    }
    if (optionD !== undefined) {
      fields.push('option_d = :od');
      params.od = String(optionD).trim();
    }
    if (correctIndex !== null && correctRaw !== undefined) {
      fields.push('correct_index = :ci');
      params.ci = correctIndex;
    }
    if (explanation !== undefined) {
      fields.push('explanation = :expl');
      const ex = String(explanation).trim();
      params.expl = ex.length ? ex : null;
    }
    if (sortOrder !== undefined) {
      const s = Number(sortOrder);
      fields.push('sort_order = :ord');
      params.ord = Number.isNaN(s) ? 0 : s;
    }

    if (fields.length === 0) {
      return res.status(400).json({ message: 'Không có trường cập nhật' });
    }

    await pool.execute(
      `UPDATE quiz_questions SET ${fields.join(', ')} WHERE id = :id`,
      params,
    );
    return res.json({ ok: true });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** DELETE /quiz/bank-questions/:id */
export async function destroy(req, res) {
  try {
    const id = Number(req.params.id);
    if (!id || Number.isNaN(id)) {
      return res.status(400).json({ message: 'id không hợp lệ' });
    }
    const [r] = await pool.execute(`DELETE FROM quiz_questions WHERE id = :id`, { id });
    if (r.affectedRows === 0) {
      return res.status(404).json({ message: 'Không tìm thấy câu hỏi' });
    }
    return res.status(204).send();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
