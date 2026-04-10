-- Chạy một lần trên DB đã tồn tại (trước khi có cột difficulty trong schema.sql mới).
USE quiz_tienganh;

ALTER TABLE vocabularies
  ADD COLUMN difficulty ENUM('B1', 'B2', 'C1') NOT NULL DEFAULT 'B2' AFTER topic_id,
  ADD KEY idx_vocab_difficulty (difficulty);
