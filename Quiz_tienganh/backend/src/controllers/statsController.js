import { pool } from '../config/database.js';

function weekStartMonday(d = new Date()) {
  const date = new Date(d);
  const day = date.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0);
  return date;
}

function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

function fmtMysql(dt) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())} ${pad(dt.getHours())}:${pad(dt.getMinutes())}:${pad(dt.getSeconds())}`;
}

/** Đếm quiz_results theo từng ngày trong tuần (Thứ 2–CN), index 0 = Thứ 2 */
async function activityByWeekdayRange(start, end) {
  const rows = await pool.execute(
    `SELECT WEEKDAY(qr.created_at) AS wd, COUNT(*) AS c
     FROM quiz_results qr
     WHERE qr.created_at >= ? AND qr.created_at < ?
     GROUP BY WEEKDAY(qr.created_at)`,
    [fmtMysql(start), fmtMysql(end)],
  );
  const arr = [0, 0, 0, 0, 0, 0, 0];
  const list = rows[0];
  for (const row of list) {
    const wd = Number(row.wd);
    if (wd >= 0 && wd <= 6) {
      arr[wd] = Number(row.c);
    }
  }
  return arr;
}

function performanceFromScore(score) {
  if (score == null) {
    return { type: 'mastered', label: 'ĐÃ THUỘC', color: 'green' };
  }
  const s = Number(score);
  if (s >= 90) {
    return { type: 'grade', label: `A+ (${s}%)`, color: 'green' };
  }
  if (s >= 75) {
    return { type: 'grade', label: `B (${s}%)`, color: 'blue' };
  }
  if (s >= 55) {
    return { type: 'progress', label: 'ĐANG LÀM', color: 'slate' };
  }
  return { type: 'progress', label: 'CẦN CỐ GẮNG', color: 'orange' };
}

/** Thống kê dashboard admin — dữ liệu thật từ DB */
export async function dashboard(req, res) {
  try {
    const ledgerPage = Math.max(0, parseInt(req.query.ledger_page ?? '0', 10) || 0);
    const ledgerLimit = Math.min(50, Math.max(1, parseInt(req.query.ledger_limit ?? '10', 10) || 10));
    const searchRaw = req.query.q != null ? String(req.query.q).trim() : '';
    const search = searchRaw.slice(0, 120);
    const offset = ledgerPage * ledgerLimit;

    const [[userCounts]] = await pool.execute(
      `SELECT
         COUNT(*) AS total_users,
         COALESCE(SUM(role = 'learner'), 0) AS learners,
         COALESCE(SUM(role = 'admin'), 0) AS admins
       FROM users`,
    );

    const [[learnersLast30]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM users
       WHERE role = 'learner'
         AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`,
    );
    const [[learnersPrev30]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM users
       WHERE role = 'learner'
         AND created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)
         AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)`,
    );
    const nNew = Number(learnersLast30.c);
    const nOld = Number(learnersPrev30.c);
    let userGrowthPercent = 0;
    if (nOld > 0) {
      userGrowthPercent = Math.round(((nNew - nOld) / nOld) * 1000) / 10;
    } else if (nNew > 0) {
      userGrowthPercent = 100;
    }

    const [[topicCount]] = await pool.execute(
      `SELECT COUNT(*) AS total_topics FROM topics`,
    );
    const [[topicsNew]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM topics
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`,
    );

    const [[vocabCount]] = await pool.execute(
      `SELECT COUNT(*) AS total_vocabularies FROM vocabularies`,
    );
    const [[vocabNew30]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM vocabularies
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`,
    );

    const [[quizCount]] = await pool.execute(
      `SELECT COUNT(*) AS total_quiz_results FROM quiz_results`,
    );

    const [[distinctQuizUsers7d]] = await pool.execute(
      `SELECT COUNT(DISTINCT user_id) AS c FROM quiz_results
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)`,
    );
    const activeLearnersWeek = Number(distinctQuizUsers7d.c);
    const learnersBadgeExtra = Math.max(0, activeLearnersWeek - 3);

    const monThis = weekStartMonday();
    const monLast = addDays(monThis, -7);
    const sunThisEnd = addDays(monThis, 7);
    const sunLastEnd = monThis;

    const activityThisWeek = await activityByWeekdayRange(monThis, sunThisEnd);
    const activityLastWeek = await activityByWeekdayRange(monLast, sunLastEnd);

    const [[masteryRow]] = await pool.execute(
      `SELECT
         (SELECT COUNT(*) FROM user_vocabulary
           WHERE status = 'mastered'
             AND last_review >= DATE_SUB(NOW(), INTERVAL 30 DAY)) AS m1,
         (SELECT COUNT(*) FROM user_vocabulary
           WHERE status = 'mastered'
             AND last_review < DATE_SUB(NOW(), INTERVAL 30 DAY)
             AND last_review >= DATE_SUB(NOW(), INTERVAL 60 DAY)) AS m0`,
    );
    const m1 = Number(masteryRow.m1);
    const m0 = Number(masteryRow.m0);
    let masteryPercent = 0;
    if (m0 > 0) {
      masteryPercent = Math.round(((m1 - m0) / m0) * 100);
    } else if (m1 > 0) {
      masteryPercent = 100;
    }
    masteryPercent = Math.min(999, Math.max(0, masteryPercent));

    const [topTopic] = await pool.execute(
      `SELECT t.name, AVG(qr.score) AS avg_s
       FROM quiz_results qr
       INNER JOIN topics t ON t.id = qr.topic_id
       WHERE qr.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
       GROUP BY t.id, t.name
       ORDER BY avg_s DESC
       LIMIT 1`,
    );
    const topTopicName = topTopic[0]?.name ?? '—';
    const topAvg =
      topTopic[0]?.avg_s != null ? Math.round(Number(topTopic[0].avg_s)) : null;

    let masteryMessage = '';
    if (topAvg != null && topTopicName !== '—') {
      masteryMessage = `Học viên đạt điểm trung bình ${topAvg}% ở chủ đề «${topTopicName}» trong 30 ngày qua. Số từ chuyển sang trạng thái thuộc tăng ${masteryPercent}% so với kỳ trước.`;
    } else {
      masteryMessage = `Số từ chuyển sang trạng thái thuộc trong 30 ngày qua tăng ${masteryPercent}% so với 30 ngày trước đó.`;
    }

    const [recentRows] = await pool.execute(
      `SELECT u.username
       FROM quiz_results qr
       INNER JOIN users u ON u.id = qr.user_id AND u.role = 'learner'
       WHERE qr.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
       ORDER BY qr.created_at DESC
       LIMIT 24`,
    );
    const seenUser = new Set();
    const recentUsernames = [];
    for (const r of recentRows) {
      const un = r.username;
      if (!seenUser.has(un)) {
        seenUser.add(un);
        recentUsernames.push(un);
        if (recentUsernames.length >= 3) {
          break;
        }
      }
    }

    const ledgerParams = [];
    let ledgerFilter = '';
    if (search.length > 0) {
      ledgerFilter =
        ' WHERE ledger.username LIKE ? OR ledger.action_vi LIKE ? ';
      const like = `%${search.replace(/[%_]/g, '')}%`;
      ledgerParams.push(like, like);
    }

    const ledgerUnion = `
      SELECT
        qr.created_at AS ts,
        u.id AS user_id,
        u.username,
        u.role,
        'quiz' AS kind,
        CONCAT('Hoàn thành quiz chủ đề «', IFNULL(t.name, 'Chung'), '»') AS action_vi,
        qr.score AS score_val
      FROM quiz_results qr
      INNER JOIN users u ON u.id = qr.user_id
      LEFT JOIN topics t ON t.id = qr.topic_id
      UNION ALL
      SELECT
        uv.last_review AS ts,
        u.id,
        u.username,
        u.role,
        'mastered' AS kind,
        CONCAT('Thuộc từ «', v.word, '» — ', IFNULL(t2.name, '')) AS action_vi,
        NULL AS score_val
      FROM user_vocabulary uv
      INNER JOIN users u ON u.id = uv.user_id
      INNER JOIN vocabularies v ON v.id = uv.vocab_id
      LEFT JOIN topics t2 ON t2.id = v.topic_id
      WHERE uv.status = 'mastered' AND uv.last_review IS NOT NULL
    `;

    let ledgerTotalAll;
    if (search.length > 0) {
      const like = `%${search.replace(/[%_]/g, '')}%`;
      const [ctr] = await pool.execute(
        `SELECT COUNT(*) AS c FROM (${ledgerUnion}) AS ledger
         WHERE ledger.username LIKE ? OR ledger.action_vi LIKE ?`,
        [like, like],
      );
      ledgerTotalAll = Number(ctr[0]?.c ?? 0);
    } else {
      const [ctr] = await pool.execute(
        `SELECT COUNT(*) AS c FROM (${ledgerUnion}) AS ledger`,
      );
      ledgerTotalAll = Number(ctr[0]?.c ?? 0);
    }

    const [[activitiesTodayRow]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM (
         SELECT created_at FROM quiz_results WHERE DATE(created_at) = CURDATE()
         UNION ALL
         SELECT last_review FROM user_vocabulary
          WHERE status = 'mastered' AND last_review IS NOT NULL
            AND DATE(last_review) = CURDATE()
       ) z`,
    );
    const activitiesToday = Number(activitiesTodayRow.c);

    /** LIMIT/OFFSET dùng số nguyên an toàn — prepared stmt với UNION gây ER_WRONG_ARGUMENTS (1210) trên một số bản MySQL. */
    const safeLimit = Math.min(50, Math.max(1, Number(ledgerLimit) || 10));
    const safeOffset = Math.max(0, Number(offset) || 0);
    const ledgerSql = `
      SELECT * FROM (${ledgerUnion}) AS ledger
      ${ledgerFilter}
      ORDER BY ledger.ts DESC
      LIMIT ${safeLimit} OFFSET ${safeOffset}
    `;

    const [ledgerRows] =
      ledgerParams.length > 0
        ? await pool.query(ledgerSql, ledgerParams)
        : await pool.query(ledgerSql);

    const ledger = ledgerRows.map((row) => {
      const perf = performanceFromScore(row.score_val);
      const dot =
        row.kind === 'mastered'
          ? 'green'
          : Number(row.score_val) >= 75
            ? 'green'
            : Number(row.score_val) >= 55
              ? 'blue'
              : 'orange';
      return {
        user_id: row.user_id,
        username: row.username,
        role: row.role,
        kind: row.kind,
        action: row.action_vi,
        timestamp: row.ts,
        performance_type: perf.type,
        performance_label: perf.label,
        performance_color: perf.color,
        dot_color: dot,
      };
    });

    return res.json({
      users: {
        total: userCounts.total_users,
        learners: userCounts.learners,
        admins: userCounts.admins,
      },
      user_growth_percent: userGrowthPercent,
      topics: topicCount.total_topics,
      topics_new_30d: Number(topicsNew.c),
      vocabularies: vocabCount.total_vocabularies,
      vocab_new_30d: Number(vocabNew30.c),
      quiz_results: quizCount.total_quiz_results,
      active_learners_week: activeLearnersWeek,
      learners_badge_extra: learnersBadgeExtra,
      recent_learner_usernames: recentUsernames,
      activity_this_week: activityThisWeek,
      activity_last_week: activityLastWeek,
      mastery: {
        percent: masteryPercent,
        topic_name: topTopicName,
        avg_score_30d: topAvg,
        message: masteryMessage,
      },
      ledger,
      ledger_total_all: ledgerTotalAll,
      activities_today: activitiesToday,
      ledger_page: ledgerPage,
      ledger_limit: ledgerLimit,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** KPI trang quản lý người dùng (admin) */
export async function userManagementSummary(_req, res) {
  try {
    const [[learners]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM users WHERE role = 'learner'`,
    );
    const [[active]] = await pool.execute(
      `SELECT COUNT(DISTINCT user_id) AS c FROM quiz_results
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)`,
    );
    const [[xpSum]] = await pool.execute(
      `SELECT COALESCE(SUM(xp), 0) AS s FROM users`,
    );
    const [[pending]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM quiz_results
       WHERE score < 55 AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`,
    );
    const [[avgLvl]] = await pool.execute(
      `SELECT ROUND(AVG(level), 1) AS a FROM users WHERE role = 'learner'`,
    );
    return res.json({
      total_learners: Number(learners.c),
      active_this_week: Number(active.c),
      total_xp_sum: Number(xpSum.s),
      pending_reports: Number(pending.c),
      avg_level_learners: avgLvl.a != null ? Number(avgLvl.a) : 0,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** KPI trang kho từ vựng (admin) */
export async function vocabularyManagementSummary(_req, res) {
  try {
    const [[tc]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM vocabularies`,
    );
    const [[today]] = await pool.execute(
      `SELECT COUNT(*) AS c FROM vocabularies
       WHERE DATE(created_at) = CURDATE()`,
    );
    const [[mc]] = await pool.execute(
      `SELECT ROUND(100 * SUM(status = 'mastered') / NULLIF(COUNT(*), 0)) AS p
       FROM user_vocabulary`,
    );
    return res.json({
      total_library: Number(tc.c),
      added_today: Number(today.c),
      mastery_percent: mc.p != null ? Number(mc.p) : 0,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

/** KPI trang quản lý chủ đề (admin) */
export async function topicManagementSummary(_req, res) {
  try {
    const [[tc]] = await pool.execute(`SELECT COUNT(*) AS c FROM topics`);
    const [[wc]] = await pool.execute(`SELECT COUNT(*) AS c FROM vocabularies`);
    const [[mc]] = await pool.execute(
      `SELECT ROUND(100 * SUM(status = 'mastered') / NULLIF(COUNT(*), 0)) AS p
       FROM user_vocabulary`,
    );
    return res.json({
      total_topics: Number(tc.c),
      total_vocabularies: Number(wc.c),
      mastery_percent: mc.p != null ? Number(mc.p) : 0,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
