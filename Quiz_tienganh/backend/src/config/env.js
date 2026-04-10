import dotenv from 'dotenv';

dotenv.config();

export const env = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD ?? '',
    database: process.env.DB_NAME || 'quiz_tienganh',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'dev-only-change-in-production-min-32-chars!!',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
};
