import jwt from 'jsonwebtoken';

import { env } from '../config/env.js';

export function authenticate(req, res, next) {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ message: 'Thiếu token (Authorization: Bearer ...)' });
  }
  try {
    const payload = jwt.verify(token, env.jwt.secret);
    req.user = {
      id: Number(payload.sub),
      username: payload.username,
      role: payload.role,
    };
    return next();
  } catch {
    return res.status(401).json({ message: 'Token không hợp lệ hoặc đã hết hạn' });
  }
}

export function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ message: 'Cần quyền admin' });
  }
  return next();
}
