import cors from 'cors';
import express from 'express';

import { pool } from './config/database.js';
import { env } from './config/env.js';
import { ensureSchema } from './db/ensureSchema.js';
import { router as apiRouter } from './routes/index.js';

const app = express();

app.use(
  cors({
    origin: true,
    credentials: true,
  }),
);
app.use(express.json());
app.use('/api', apiRouter);

/** Kiểm tra API + kết nối MySQL */
app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1 AS ok');
    return res.json({
      ok: true,
      env: env.nodeEnv,
      database: 'connected',
      dbName: env.db.database,
    });
  } catch (err) {
    return res.status(503).json({
      ok: false,
      env: env.nodeEnv,
      database: 'error',
      message: err?.message ?? 'Không kết nối được MySQL',
      hint: 'Kiểm tra MySQL đã chạy và đã import database/schema.sql',
    });
  }
});

app.use((_req, res) => {
  res.status(404).json({ message: 'Không tìm thấy endpoint' });
});

app.use((err, _req, res, _next) => {
  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ message: 'Lỗi máy chủ' });
});

async function start() {
  await ensureSchema();
  app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`API: http://localhost:${env.port}`);
    // eslint-disable-next-line no-console
    console.log(`Health: http://localhost:${env.port}/health`);
    // eslint-disable-next-line no-console
    console.log(
      `MySQL DB: ${env.db.database} @ ${env.db.host}:${env.db.port} (${env.db.user})`,
    );
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
