import { pool } from '../config/database.js';

/** % từ vựng theo trạng thái: học dở vẫn tăng tiến độ (không chỉ mastered). */
function vocabProgressPctFromRow(r) {
  const v = Number(r.vocab_progress_pct ?? 0);
  return Number.isFinite(v) ? Math.round(v) : 0;
}

function topicsMasteredCount(topicRows) {
  let n = 0;
  for (const r of topicRows) {
    const vt = Number(r.vocab_total ?? 0);
    const qb = Number(r.quiz_best_score ?? 0);
    const vp = vt > 0 ? vocabProgressPctFromRow(r) : 0;
    const mastery = vt > 0 ? Math.max(vp, qb) : qb;
    if (mastery >= 100) {
      n += 1;
    }
  }
  return n;
}

/** Chuỗi ngày liên tiếp có hoạt động (quiz hoặc ôn từ có last_review). */
function streakDaysFromDates(descDateStrs) {
  if (!descDateStrs.length) {
    return 0;
  }
  let streak = 1;
  for (let i = 1; i < descDateStrs.length; i += 1) {
    const newer = new Date(`${descDateStrs[i - 1]}T12:00:00`);
    const older = new Date(`${descDateStrs[i]}T12:00:00`);
    const diffDays = Math.round((newer - older) / 86400000);
    if (diffDays === 1) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}

/**
 * GET /progress/summary — số liệu tổng hợp cho màn hồ sơ (từ DB thật).
 */
export async function getMyProgressSummary(req, res) {
  try {
    const userId = req.user.id;

    const [wm] = await pool.execute(
      `SELECT COUNT(*) AS n
       FROM user_vocabulary uv
       INNER JOIN vocabularies v ON v.id = uv.vocab_id
       WHERE uv.user_id = ? AND uv.status = 'mastered'`,
      [userId],
    );
    const wordsMasteredTotal = Number(wm[0]?.n ?? 0);

    const [qc] = await pool.execute(
      `SELECT COUNT(*) AS n FROM quiz_results WHERE user_id = ?`,
      [userId],
    );
    const quizAttemptsTotal = Number(qc[0]?.n ?? 0);

    const [avgRow] = await pool.execute(
      `SELECT COALESCE(AVG(score), 0) AS a FROM quiz_results WHERE user_id = ?`,
      [userId],
    );
    const avgQuizScore = Math.round(Number(avgRow[0]?.a ?? 0));

    const [topicRows] = await pool.execute(
      `SELECT
         t.id AS topic_id,
         (SELECT COUNT(*) FROM vocabularies v WHERE v.topic_id = t.id) AS vocab_total,
         (
           SELECT COUNT(*)
           FROM user_vocabulary uv
           INNER JOIN vocabularies v ON v.id = uv.vocab_id
           WHERE uv.user_id = ? AND v.topic_id = t.id AND uv.status = 'mastered'
         ) AS vocab_mastered,
         (
           SELECT COALESCE(ROUND(
             100 * SUM(
               CASE
                 WHEN uv.status = 'mastered' THEN 1
                 WHEN uv.status = 'review' THEN 0.5
                 WHEN uv.status = 'learning' THEN 0.25
                 WHEN uv.status = 'new' THEN 0
                 ELSE 0
               END
             ) / NULLIF(COUNT(v.id), 0)
           ), 0)
           FROM vocabularies v
           LEFT JOIN user_vocabulary uv
             ON uv.vocab_id = v.id AND uv.user_id = ?
           WHERE v.topic_id = t.id
         ) AS vocab_progress_pct,
         (
           SELECT COALESCE(MAX(qr.score), 0)
           FROM quiz_results qr
           WHERE qr.user_id = ? AND qr.topic_id = t.id
         ) AS quiz_best_score
       FROM topics t
       ORDER BY t.id ASC`,
      [userId, userId, userId],
    );

    const topicsTotal = topicRows.length;
    const topicsMastered = topicsMasteredCount(topicRows);

    const [dateRows] = await pool.execute(
      `SELECT DISTINCT d FROM (
         SELECT DATE(created_at) AS d FROM quiz_results WHERE user_id = ?
         UNION
         SELECT DATE(last_review) AS d FROM user_vocabulary WHERE user_id = ? AND last_review IS NOT NULL
       ) x
       WHERE d IS NOT NULL
       ORDER BY d DESC`,
      [userId, userId],
    );

    const descDates = dateRows.map((r) => {
      const v = r.d;
      if (v instanceof Date) {
        return v.toISOString().slice(0, 10);
      }
      return String(v).slice(0, 10);
    });

    const streakDays = streakDaysFromDates(descDates);

    const studyMinutesEstimate = Math.round(
      quizAttemptsTotal * 3 + wordsMasteredTotal * 1.5,
    );

    return res.json({
      words_mastered_total: wordsMasteredTotal,
      quiz_attempts_total: quizAttemptsTotal,
      topics_mastered_count: topicsMastered,
      topics_total: topicsTotal,
      avg_quiz_score: avgQuizScore,
      streak_days: streakDays,
      study_minutes_estimate: studyMinutesEstimate,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/**
 * Tiến độ theo chủ đề (một nguồn dữ liệu cho app): từ vựng mastered + điểm quiz tốt nhất.
 */
export async function listMyTopicProgress(req, res) {
  try {
    const userId = req.user.id;
    const [rows] = await pool.execute(
      `SELECT
         t.id AS topic_id,
         t.name AS topic_name,
         (SELECT COUNT(*) FROM vocabularies v WHERE v.topic_id = t.id) AS vocab_total,
         (
           SELECT COUNT(*)
           FROM user_vocabulary uv
           INNER JOIN vocabularies v ON v.id = uv.vocab_id
           WHERE uv.user_id = ? AND v.topic_id = t.id AND uv.status = 'mastered'
         ) AS vocab_mastered,
         (
           SELECT COALESCE(ROUND(
             100 * SUM(
               CASE
                 WHEN uv.status = 'mastered' THEN 1
                 WHEN uv.status = 'review' THEN 0.5
                 WHEN uv.status = 'learning' THEN 0.25
                 WHEN uv.status = 'new' THEN 0
                 ELSE 0
               END
             ) / NULLIF(COUNT(v.id), 0)
           ), 0)
           FROM vocabularies v
           LEFT JOIN user_vocabulary uv
             ON uv.vocab_id = v.id AND uv.user_id = ?
           WHERE v.topic_id = t.id
         ) AS vocab_progress_pct,
         (
           SELECT COALESCE(MAX(qr.score), 0)
           FROM quiz_results qr
           WHERE qr.user_id = ? AND qr.topic_id = t.id
         ) AS quiz_best_score
       FROM topics t
       ORDER BY t.id ASC`,
      [userId, userId, userId],
    );
    // Chuẩn hóa số (mysql2 đôi khi trả BigInt — JSON.stringify lỗi hoặc client parse sai).
    const out = rows.map((r) => ({
      topic_id: Number(r.topic_id),
      topic_name: r.topic_name,
      vocab_total: Number(r.vocab_total ?? 0),
      vocab_mastered: Number(r.vocab_mastered ?? 0),
      vocab_progress_pct: Number(r.vocab_progress_pct ?? 0),
      quiz_best_score: Number(r.quiz_best_score ?? 0),
    }));
    return res.json(out);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
