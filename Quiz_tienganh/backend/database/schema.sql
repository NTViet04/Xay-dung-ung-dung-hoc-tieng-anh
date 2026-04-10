-- Quiz Tiếng Anh — MySQL 8.x
-- Charset: utf8mb4
-- Mật khẩu mẫu cho mọi user: 123456 (bcrypt)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP DATABASE IF EXISTS quiz_tienganh;
CREATE DATABASE quiz_tienganh CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE quiz_tienganh;

-- ----------------------------
-- Bảng users
-- ----------------------------
CREATE TABLE users (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL,
  password VARCHAR(255) NOT NULL COMMENT 'bcrypt hash',
  level INT UNSIGNED NOT NULL DEFAULT 1,
  xp INT UNSIGNED NOT NULL DEFAULT 0,
  role ENUM('learner', 'admin') NOT NULL DEFAULT 'learner',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mật khẩu: 123456
INSERT INTO users (id, username, password, level, xp, role, created_at) VALUES
(1, 'admin', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 10, 5000, 'admin', '2025-01-05 08:00:00'),
(2, 'moderator', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 8, 3200, 'admin', '2025-01-06 09:15:00'),
(3, 'nguyenvana', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 5, 2100, 'learner', '2025-01-10 10:00:00'),
(4, 'tranthib', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 4, 1800, 'learner', '2025-01-11 11:20:00'),
(5, 'levanc', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 3, 1200, 'learner', '2025-01-12 14:30:00'),
(6, 'phamthid', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 6, 2450, 'learner', '2025-01-13 08:45:00'),
(7, 'hoangvane', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 2, 800, 'learner', '2025-01-14 16:00:00'),
(8, 'vuthif', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 7, 3000, 'learner', '2025-01-15 09:10:00'),
(9, 'dangvang', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 3, 950, 'learner', '2025-01-16 12:00:00'),
(10, 'buithih', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 4, 1600, 'learner', '2025-01-17 07:30:00'),
(11, 'dominhi', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 5, 2200, 'learner', '2025-01-18 18:20:00'),
(12, 'maivank', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 1, 400, 'learner', '2025-01-19 10:50:00'),
(13, 'lythil', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 6, 2800, 'learner', '2025-01-20 15:40:00'),
(14, 'chuvanm', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 2, 700, 'learner', '2025-01-21 13:15:00'),
(15, 'demo_user', '$2b$10$xjID16xFi.jkzBm5eruvWeft8MPSCGOK.XE8s1gTrn4f.3Z6xf1Sm', 4, 1500, 'learner', '2025-01-22 09:00:00');

-- ----------------------------
-- Bảng topics
-- ----------------------------
CREATE TABLE topics (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(128) NOT NULL,
  description TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO topics (id, name, description, created_at) VALUES
(1, 'Du lịch & Giao thông', 'Từ vựng về phương tiện, sân bay, khách sạn.', '2025-02-01 08:00:00'),
(2, 'Công việc & Văn phòng', 'Họp hành, email, dự án.', '2025-02-01 08:05:00'),
(3, 'Ẩm thực', 'Đồ ăn, nhà hàng, nấu nướng.', '2025-02-01 08:10:00'),
(4, 'Công nghệ', 'Máy tính, phần mềm, internet.', '2025-02-01 08:15:00'),
(5, 'Sức khỏe', 'Bác sĩ, thuốc, thể dục.', '2025-02-01 08:20:00'),
(6, 'Giáo dục', 'Trường học, bài tập, thi cử.', '2025-02-01 08:25:00'),
(7, 'Thiên nhiên', 'Cây cối, động vật, môi trường.', '2025-02-01 08:30:00'),
(8, 'Thể thao', 'Bóng đá, Olympic, tập luyện.', '2025-02-01 08:35:00'),
(9, 'Âm nhạc', 'Nhạc cụ, thể loại, buổi hòa nhạc.', '2025-02-01 08:40:00'),
(10, 'Nghệ thuật', 'Hội họa, bảo tàng, triển lãm.', '2025-02-01 08:45:00'),
(11, 'Khoa học', 'Vật lý, hóa học, thí nghiệm.', '2025-02-01 08:50:00'),
(12, 'Đời sống hàng ngày', 'Mua sắm, gia đình, thói quen.', '2025-02-01 08:55:00'),
(13, 'Cảm xúc', 'Vui, buồn, lo lắng, tự tin.', '2025-02-01 09:00:00'),
(14, 'Thời tiết', 'Mưa, nắng, bão, nhiệt độ.', '2025-02-01 09:05:00'),
(15, 'Nhà cửa', 'Phòng, đồ đạc, dọn dẹp.', '2025-02-01 09:10:00');

-- ----------------------------
-- Bảng vocabularies
-- ----------------------------
CREATE TABLE vocabularies (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  word VARCHAR(128) NOT NULL,
  meaning VARCHAR(512) NOT NULL,
  pronunciation VARCHAR(128) NULL,
  example TEXT NULL,
  topic_id INT UNSIGNED NOT NULL,
  difficulty ENUM('B1', 'B2', 'C1') NOT NULL DEFAULT 'B2',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_vocab_topic (topic_id),
  KEY idx_vocab_difficulty (difficulty),
  CONSTRAINT fk_vocab_topic FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO vocabularies (id, word, meaning, pronunciation, example, topic_id, difficulty, created_at) VALUES
(1, 'itinerary', 'lịch trình du lịch', '/aɪˈtɪnəreri/', 'We planned a detailed itinerary for Japan.', 1, 'B1', '2025-02-02 10:00:00'),
(2, 'boarding pass', 'thẻ lên máy bay', '/ˈbɔːrdɪŋ pæs/', 'Show your boarding pass at the gate.', 1, 'B2', '2025-02-02 10:01:00'),
(3, 'deadline', 'hạn chót', '/ˈdedlaɪn/', 'The deadline for the report is Friday.', 2, 'B2', '2025-02-02 10:02:00'),
(4, 'agenda', 'chương trình nghị sự', '/əˈdʒendə/', 'Please send the agenda before the meeting.', 2, 'B1', '2025-02-02 10:03:00'),
(5, 'appetizer', 'món khai vị', '/ˈæpɪtaɪzər/', 'We ordered soup as an appetizer.', 3, 'B1', '2025-02-02 10:04:00'),
(6, 'cuisine', 'ẩm thực', '/kwɪˈziːn/', 'Italian cuisine is famous worldwide.', 3, 'B2', '2025-02-02 10:05:00'),
(7, 'download', 'tải xuống', '/ˈdaʊnloʊd/', 'You can download the app for free.', 4, 'B1', '2025-02-02 10:06:00'),
(8, 'password', 'mật khẩu', '/ˈpæswɜːrd/', 'Choose a strong password.', 4, 'B1', '2025-02-02 10:07:00'),
(9, 'prescription', 'đơn thuốc', '/prɪˈskrɪpʃn/', 'The doctor wrote a prescription.', 5, 'B2', '2025-02-02 10:08:00'),
(10, 'symptom', 'triệu chứng', '/ˈsɪmptəm/', 'Fever is a common symptom.', 5, 'B2', '2025-02-02 10:09:00'),
(11, 'scholarship', 'học bổng', '/ˈskɑːlərʃɪp/', 'She won a scholarship to MIT.', 6, 'C1', '2025-02-02 10:10:00'),
(12, 'assignment', 'bài tập', '/əˈsaɪnmənt/', 'Submit your assignment by Monday.', 6, 'B2', '2025-02-02 10:11:00'),
(13, 'sustainable', 'bền vững', '/səˈsteɪnəbl/', 'We need sustainable energy.', 7, 'C1', '2025-02-02 10:12:00'),
(14, 'ecosystem', 'hệ sinh thái', '/ˈiːkoʊsɪstəm/', 'Pollution harms the ecosystem.', 7, 'B2', '2025-02-02 10:13:00'),
(15, 'tournament', 'giải đấu', '/ˈtʊrnəmənt/', 'The team reached the final tournament.', 8, 'B2', '2025-02-02 10:14:00'),
(16, 'melody', 'giai điệu', '/ˈmelədi/', 'The song has a catchy melody.', 9, 'B1', '2025-02-02 10:15:00'),
(17, 'exhibition', 'triển lãm', '/ˌeksɪˈbɪʃn/', 'The art exhibition opens tomorrow.', 10, 'B2', '2025-02-02 10:16:00'),
(18, 'hypothesis', 'giả thuyết', '/haɪˈpɑːθəsɪs/', 'Scientists tested the hypothesis.', 11, 'C1', '2025-02-02 10:17:00'),
(19, 'groceries', 'thực phẩm (đi chợ)', '/ˈɡroʊsəriz/', 'I need to buy groceries.', 12, 'B1', '2025-02-02 10:18:00'),
(20, 'anxious', 'lo lắng', '/ˈæŋkʃəs/', 'She felt anxious before the exam.', 13, 'B2', '2025-02-02 10:19:00'),
(21, 'humid', 'ẩm ướt', '/ˈhjuːmɪd/', 'The weather is hot and humid.', 14, 'B1', '2025-02-02 10:20:00'),
(22, 'furniture', 'đồ nội thất', '/ˈfɜːrnɪtʃər/', 'We bought new furniture.', 15, 'B1', '2025-02-02 10:21:00'),
(23, 'luggage', 'hành lý', '/ˈlʌɡɪdʒ/', 'Do not leave luggage unattended.', 1, 'B2', '2025-02-02 10:22:00'),
(24, 'negotiate', 'đàm phán', '/nɪˈɡoʊʃieɪt/', 'We need to negotiate the price.', 2, 'C1', '2025-02-02 10:23:00'),
(25, 'recipe', 'công thức nấu ăn', '/ˈresəpi/', 'Follow the recipe carefully.', 3, 'B1', '2025-02-02 10:24:00');

-- ----------------------------
-- Bảng user_vocabulary (tiến độ từng từ)
-- ----------------------------
CREATE TABLE user_vocabulary (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  vocab_id INT UNSIGNED NOT NULL,
  status ENUM('new', 'learning', 'review', 'mastered') NOT NULL DEFAULT 'new',
  last_review DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_vocab (user_id, vocab_id),
  KEY idx_uv_user (user_id),
  KEY idx_uv_vocab (vocab_id),
  CONSTRAINT fk_uv_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_uv_vocab FOREIGN KEY (vocab_id) REFERENCES vocabularies (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO user_vocabulary (id, user_id, vocab_id, status, last_review, created_at) VALUES
(1, 3, 1, 'mastered', '2025-03-01 09:00:00', '2025-02-10 10:00:00'),
(2, 3, 2, 'learning', '2025-03-02 10:00:00', '2025-02-10 10:05:00'),
(3, 4, 3, 'review', NULL, '2025-02-11 08:00:00'),
(4, 4, 4, 'new', NULL, '2025-02-11 08:05:00'),
(5, 5, 5, 'mastered', '2025-03-03 14:00:00', '2025-02-12 11:00:00'),
(6, 5, 6, 'learning', NULL, '2025-02-12 11:10:00'),
(7, 6, 7, 'mastered', '2025-03-04 16:00:00', '2025-02-13 09:00:00'),
(8, 6, 8, 'mastered', '2025-03-04 16:30:00', '2025-02-13 09:10:00'),
(9, 7, 9, 'new', NULL, '2025-02-14 12:00:00'),
(10, 7, 10, 'learning', '2025-03-05 08:00:00', '2025-02-14 12:10:00'),
(11, 8, 11, 'mastered', '2025-03-06 10:00:00', '2025-02-15 07:00:00'),
(12, 8, 12, 'review', NULL, '2025-02-15 07:15:00'),
(13, 9, 13, 'learning', NULL, '2025-02-16 13:00:00'),
(14, 9, 14, 'new', NULL, '2025-02-16 13:05:00'),
(15, 10, 15, 'mastered', '2025-03-07 11:00:00', '2025-02-17 15:00:00'),
(16, 11, 16, 'review', '2025-03-08 09:30:00', '2025-02-18 10:20:00'),
(17, 11, 17, 'learning', NULL, '2025-02-18 10:25:00'),
(18, 12, 18, 'new', NULL, '2025-02-19 08:50:00'),
(19, 13, 19, 'mastered', '2025-03-09 12:00:00', '2025-02-20 14:40:00'),
(20, 14, 20, 'learning', NULL, '2025-02-21 11:15:00');

-- ----------------------------
-- Bảng quiz_results
-- ----------------------------
CREATE TABLE quiz_results (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  topic_id INT UNSIGNED NULL,
  score INT NOT NULL COMMENT 'điểm % hoặc tổng điểm tùy app — ở đây: điểm đúng (0-100)',
  total_questions TINYINT UNSIGNED NOT NULL DEFAULT 10,
  correct_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_qr_user (user_id),
  KEY idx_qr_topic (topic_id),
  CONSTRAINT fk_qr_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_qr_topic FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO quiz_results (id, user_id, topic_id, score, total_questions, correct_count, created_at) VALUES
(1, 3, 1, 80, 10, 8, '2025-03-10 10:00:00'),
(2, 3, 2, 70, 10, 7, '2025-03-10 11:00:00'),
(3, 4, 3, 90, 10, 9, '2025-03-11 09:15:00'),
(4, 5, 4, 60, 10, 6, '2025-03-11 14:20:00'),
(5, 5, 1, 100, 10, 10, '2025-03-12 08:30:00'),
(6, 6, 5, 75, 10, 7, '2025-03-12 16:00:00'),
(7, 6, 6, 85, 10, 8, '2025-03-13 09:00:00'),
(8, 7, 7, 50, 10, 5, '2025-03-13 12:45:00'),
(9, 8, 8, 95, 10, 9, '2025-03-14 07:10:00'),
(10, 8, 9, 88, 10, 8, '2025-03-14 18:00:00'),
(11, 9, 10, 65, 10, 6, '2025-03-15 10:30:00'),
(12, 10, 11, 72, 10, 7, '2025-03-15 15:00:00'),
(13, 10, 12, 78, 10, 7, '2025-03-16 11:20:00'),
(14, 11, 13, 82, 10, 8, '2025-03-16 19:00:00'),
(15, 11, 14, 91, 10, 9, '2025-03-17 08:40:00'),
(16, 12, 15, 55, 10, 5, '2025-03-17 13:00:00'),
(17, 13, 1, 77, 10, 7, '2025-03-18 09:50:00'),
(18, 13, 3, 84, 10, 8, '2025-03-18 20:10:00'),
(19, 14, 2, 68, 10, 6, '2025-03-19 12:30:00'),
(20, 15, 4, 73, 10, 7, '2025-03-20 10:00:00');

-- ----------------------------
-- Ngân hàng câu hỏi trắc nghiệm (quiz theo chủ đề) — đồng bộ với ensureSchema
-- ----------------------------
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mỗi topic (1–15) ít nhất 3 câu — tổng 45 câu mẫu
INSERT INTO quiz_questions (id, topic_id, prompt, option_a, option_b, option_c, option_d, correct_index, explanation, sort_order, created_at) VALUES
-- Topic 1: Du lịch & Giao thông
(1, 1, 'What do you show at the airport gate?', 'Boarding pass', 'Passport only', 'Ticket only', 'ID card only', 0, 'Thẻ lên máy bay = boarding pass.', 0, '2025-03-21 10:00:00'),
(2, 1, '“Itinerary” means:', 'Travel schedule', 'Insurance', 'Invoice', 'Interview', 0, 'Lịch trình chuyến đi.', 1, '2025-03-21 10:01:00'),
(3, 1, '“Luggage” is:', 'Bags and suitcases', 'A flight number', 'A hotel key', 'A map', 0, 'Hành lý.', 2, '2025-03-21 10:02:00'),
-- Topic 2: Công việc & Văn phòng
(4, 2, 'A meeting “agenda” is:', 'List of topics to discuss', 'A type of email', 'Office furniture', 'Salary', 0, 'Chương trình nghị sự.', 0, '2025-03-21 10:03:00'),
(5, 2, '“Deadline” means:', 'The last time to finish something', 'A new employee', 'A lunch break', 'A printer error', 0, 'Hạn chót.', 1, '2025-03-21 10:04:00'),
(6, 2, 'To “negotiate” means to:', 'Discuss to reach agreement', 'Cancel a meeting', 'Send an invoice', 'Print a document', 0, 'Đàm phán.', 2, '2025-03-21 10:05:00'),
-- Topic 3: Ẩm thực
(7, 3, '“Cuisine” refers to:', 'Style of cooking', 'A kitchen tool', 'A waiter', 'A receipt', 0, 'Ẩm thực.', 0, '2025-03-21 10:06:00'),
(8, 3, 'An “appetizer” is:', 'A small dish before the main meal', 'The main course', 'A dessert', 'A drink only', 0, 'Món khai vị.', 1, '2025-03-21 10:07:00'),
(9, 3, 'A “recipe” is:', 'Instructions to cook a dish', 'A restaurant bill', 'A table reservation', 'A spice shop', 0, 'Công thức nấu ăn.', 2, '2025-03-21 10:08:00'),
-- Topic 4: Công nghệ
(10, 4, 'To “download” means to:', 'Copy data from the internet to your device', 'Delete a file', 'Turn off Wi-Fi', 'Charge a battery', 0, 'Tải xuống.', 0, '2025-03-21 10:09:00'),
(11, 4, 'A “password” is used to:', 'Protect access to an account', 'Print faster', 'Clean the screen', 'Save battery', 0, 'Mật khẩu.', 1, '2025-03-21 10:10:00'),
(12, 4, 'Software is:', 'Programs that run on a computer', 'Only the monitor', 'A type of cable', 'Office furniture', 0, 'Phần mềm.', 2, '2025-03-21 10:11:00'),
-- Topic 5: Sức khỏe
(13, 5, 'A “symptom” is:', 'A sign of illness', 'A type of medicine', 'A doctor title', 'A hospital room', 0, 'Triệu chứng.', 0, '2025-03-21 10:12:00'),
(14, 5, 'A “prescription” is:', 'A doctor’s written order for medicine', 'A blood test only', 'A gym membership', 'A diet soda', 0, 'Đơn thuốc.', 1, '2025-03-21 10:13:00'),
(15, 5, 'A “check-up” is:', 'A routine medical examination', 'A surgery', 'Only buying vitamins', 'A hospital meal', 0, 'Khám định kỳ.', 2, '2025-03-21 10:14:00'),
-- Topic 6: Giáo dục
(16, 6, 'A “scholarship” is:', 'Money to help pay for study', 'A school building', 'A lunch ticket', 'A bus route', 0, 'Học bổng.', 0, '2025-03-21 10:15:00'),
(17, 6, 'An “assignment” is:', 'Work a student must complete', 'Only a final exam', 'A school holiday', 'A teacher name', 0, 'Bài tập.', 1, '2025-03-21 10:16:00'),
(18, 6, 'A “lecture” is:', 'A spoken lesson to a class', 'Only a written test', 'A sports match', 'A library card', 0, 'Bài giảng.', 2, '2025-03-21 10:17:00'),
-- Topic 7: Thiên nhiên
(19, 7, '“Sustainable” means:', 'Able to continue without harm', 'Very expensive', 'Only for cities', 'Temporary only', 0, 'Bền vững.', 0, '2025-03-21 10:18:00'),
(20, 7, 'An “ecosystem” is:', 'Living things and their environment together', 'Only trees', 'Only weather', 'A zoo ticket', 0, 'Hệ sinh thái.', 1, '2025-03-21 10:19:00'),
(21, 7, '“Pollution” is:', 'Harmful substances in air, water, or soil', 'Clean rain', 'Fresh air only', 'A plant name', 0, 'Ô nhiễm.', 2, '2025-03-21 10:20:00'),
-- Topic 8: Thể thao
(22, 8, 'A “tournament” is:', 'A competition with many teams or players', 'Only one match', 'A coach only', 'A stadium seat', 0, 'Giải đấu.', 0, '2025-03-21 10:21:00'),
(23, 8, 'To “train” means to:', 'Practice to improve skills', 'Only watch TV', 'Sell tickets', 'Paint lines', 0, 'Tập luyện.', 1, '2025-03-21 10:22:00'),
(24, 8, 'A “referee” is:', 'A person who enforces rules in a game', 'Only a fan', 'A ball seller', 'A locker key', 0, 'Trọng tài.', 2, '2025-03-21 10:23:00'),
-- Topic 9: Âm nhạc
(25, 9, 'A “melody” is:', 'A sequence of musical notes', 'Only drums', 'A concert ticket', 'A microphone stand', 0, 'Giai điệu.', 0, '2025-03-21 10:24:00'),
(26, 9, 'A “concert” is:', 'A live music performance', 'Only a CD', 'A music app icon', 'A silent room', 0, 'Buổi hòa nhạc.', 1, '2025-03-21 10:25:00'),
(27, 9, '“Rhythm” is:', 'The pattern of beats in music', 'Only the lyrics', 'The stage name', 'A guitar case', 0, 'Nhịp điệu.', 2, '2025-03-21 10:26:00'),
-- Topic 10: Nghệ thuật
(28, 10, 'An “exhibition” is:', 'A public show of art or objects', 'Only a shop', 'A movie only', 'A bus stop', 0, 'Triển lãm.', 0, '2025-03-21 10:27:00'),
(29, 10, 'A “sculpture” is:', 'Art made by shaping materials', 'Only a painting', 'A photo frame', 'A ticket booth', 0, 'Điêu khắc.', 1, '2025-03-21 10:28:00'),
(30, 10, 'A “portrait” is:', 'A picture of a person', 'Only a landscape', 'A museum ticket', 'A color name', 0, 'Chân dung.', 2, '2025-03-21 10:29:00'),
-- Topic 11: Khoa học
(31, 11, 'A “hypothesis” is:', 'An idea to test by experiment', 'A final proof only', 'A lab coat', 'A calculator brand', 0, 'Giả thuyết.', 0, '2025-03-21 10:30:00'),
(32, 11, 'An “experiment” is:', 'A test to discover or prove something', 'Only reading a book', 'A classroom desk', 'A school bell', 0, 'Thí nghiệm.', 1, '2025-03-21 10:31:00'),
(33, 11, 'A “molecule” is:', 'A group of atoms bonded together', 'Only water', 'A star name', 'A type of plant', 0, 'Phân tử.', 2, '2025-03-21 10:32:00'),
-- Topic 12: Đời sống hàng ngày
(34, 12, '“Groceries” are:', 'Food and household items you buy', 'Only clothes', 'Only furniture', 'Bus tickets only', 0, 'Thực phẩm / đồ đi chợ.', 0, '2025-03-21 10:33:00'),
(35, 12, 'To “commute” means to:', 'Travel regularly between home and work', 'Only walk once', 'Cook dinner', 'Clean windows', 0, 'Đi làm hàng ngày.', 1, '2025-03-21 10:34:00'),
(36, 12, 'A “chore” is:', 'A routine household task', 'Only a party', 'A vacation', 'A shopping mall name', 0, 'Việc vặt trong nhà.', 2, '2025-03-21 10:35:00'),
-- Topic 13: Cảm xúc
(37, 13, '“Anxious” means:', 'Worried or nervous', 'Very happy only', 'Very cold', 'Very tall', 0, 'Lo lắng.', 0, '2025-03-21 10:36:00'),
(38, 13, '“Confident” means:', 'Sure of your abilities', 'Always sad', 'Always lost', 'Always late', 0, 'Tự tin.', 1, '2025-03-21 10:37:00'),
(39, 13, 'To “relax” means to:', 'Become calm and rest', 'Run faster', 'Shout louder', 'Work harder only', 0, 'Thư giãn.', 2, '2025-03-21 10:38:00'),
-- Topic 14: Thời tiết
(40, 14, '“Humid” means:', 'Air with a lot of water vapor', 'Very dry', 'Very windy only', 'Very dark', 0, 'Ẩm ướt.', 0, '2025-03-21 10:39:00'),
(41, 14, 'A “forecast” is:', 'A prediction of future weather', 'Only past weather records', 'A winter coat', 'A sun hat only', 0, 'Dự báo.', 1, '2025-03-21 10:40:00'),
(42, 14, '“Thunder” is:', 'The loud sound after lightning', 'Only snow', 'A cloud name', 'A wind speed unit', 0, 'Sấm.', 2, '2025-03-21 10:41:00'),
-- Topic 15: Nhà cửa
(43, 15, '“Furniture” refers to:', 'Items like chairs, tables, beds', 'Only walls', 'Only windows', 'Only doors', 0, 'Đồ nội thất.', 0, '2025-03-21 10:42:00'),
(44, 15, 'A “landlord” is:', 'A person who rents property to others', 'Only a tenant', 'A neighbor only', 'A plumber', 0, 'Chủ nhà cho thuê.', 1, '2025-03-21 10:43:00'),
(45, 15, 'To “decorate” means to:', 'Make a place look nicer', 'Only clean the floor', 'Only paint walls white', 'Sell the house', 0, 'Trang trí.', 2, '2025-03-21 10:44:00');

SET FOREIGN_KEY_CHECKS = 1;