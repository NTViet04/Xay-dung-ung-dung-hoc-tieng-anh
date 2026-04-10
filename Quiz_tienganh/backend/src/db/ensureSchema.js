import { pool } from '../config/database.js';

/**
 * Đồng bộ schema khi máy chủ khởi động (DB cũ chưa chạy migration thủ công).
 * Thêm cột difficulty cho bảng vocabularies nếu chưa có.
 */
export async function ensureSchema() {
  await ensureVocabularyDifficulty();
  await ensureQuizQuestionsTable();
}

async function ensureVocabularyDifficulty() {
  try {
    await pool.execute(
      `ALTER TABLE vocabularies
       ADD COLUMN difficulty ENUM('B1', 'B2', 'C1') NOT NULL DEFAULT 'B2' AFTER topic_id`,
    );
    // eslint-disable-next-line no-console
    console.log('Schema: đã thêm cột vocabularies.difficulty');
  } catch (e) {
    if (e.errno === 1060 || e.code === 'ER_DUP_FIELDNAME') {
      // Duplicate column name
    } else {
      throw e;
    }
  }
  try {
    await pool.execute(
      `ALTER TABLE vocabularies ADD KEY idx_vocab_difficulty (difficulty)`,
    );
  } catch (e) {
    if (
      e.errno === 1061 ||
      e.code === 'ER_DUP_KEYNAME' ||
      (e.message && e.message.includes('Duplicate key name'))
    ) {
      return;
    }
    throw e;
  }
}

async function ensureQuizQuestionsTable() {
  try {
    await pool.execute(`
      CREATE TABLE IF NOT EXISTS quiz_questions (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        topic_id INT UNSIGNED NOT NULL,
        prompt TEXT NOT NULL,
        option_a VARCHAR(512) NOT NULL,
        option_b VARCHAR(512) NOT NULL,
        option_c VARCHAR(512) NOT NULL,
        option_d VARCHAR(512) NOT NULL,
        correct_index TINYINT UNSIGNED NOT NULL COMMENT '0=A ... 3=D',
        explanation TEXT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_qq_topic (topic_id),
        CONSTRAINT fk_qq_topic FOREIGN KEY (topic_id) REFERENCES topics (id)
          ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    // eslint-disable-next-line no-console
    console.log('Schema: bảng quiz_questions sẵn sàng');
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('ensureQuizQuestionsTable:', e);
    throw e;
  }
}
