import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

import { pool } from '../config/database.js';
import { env } from '../config/env.js';

export async function findUserByUsername(username) {
  const [rows] = await pool.execute(
    'SELECT id, username, password, level, xp, role, created_at FROM users WHERE username = :u LIMIT 1',
    { u: username },
  );
  return rows[0] ?? null;
}

export async function findUserById(id) {
  const [rows] = await pool.execute(
    'SELECT id, username, level, xp, role, created_at FROM users WHERE id = :id LIMIT 1',
    { id },
  );
  return rows[0] ?? null;
}

export async function createUser({ username, password, role = 'learner' }) {
  const hash = await bcrypt.hash(password, 10);
  const [result] = await pool.execute(
    `INSERT INTO users (username, password, level, xp, role)
     VALUES (:username, :password, 1, 0, :role)`,
    { username, password: hash, role },
  );
  return result.insertId;
}

export function verifyPassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

export function signToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      username: user.username,
      role: user.role,
    },
    env.jwt.secret,
    { expiresIn: env.jwt.expiresIn },
  );
}
