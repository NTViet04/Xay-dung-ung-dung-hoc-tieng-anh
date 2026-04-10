import {
  createUser,
  findUserByUsername,
  findUserById,
  signToken,
  verifyPassword,
} from '../services/authService.js';

export async function register(req, res) {
  try {
    const { username, password } = req.body ?? {};
    if (!username || !password) {
      return res.status(400).json({ message: 'Cần username và password' });
    }
    if (String(username).length < 3 || String(password).length < 6) {
      return res
        .status(400)
        .json({ message: 'Username >= 3 ký tự, password >= 6 ký tự' });
    }
    const exists = await findUserByUsername(String(username).trim());
    if (exists) {
      return res.status(409).json({ message: 'Username đã tồn tại' });
    }
    const id = await createUser({
      username: String(username).trim(),
      password: String(password),
      role: 'learner',
    });
    const user = await findUserById(id);
    const token = signToken(user);
    return res.status(201).json({
      token,
      user: {
        id: user.id,
        username: user.username,
        level: user.level,
        xp: user.xp,
        role: user.role,
      },
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function login(req, res) {
  try {
    const { username, password } = req.body ?? {};
    if (!username || !password) {
      return res.status(400).json({ message: 'Cần username và password' });
    }
    const user = await findUserByUsername(String(username).trim());
    if (!user) {
      return res.status(401).json({ message: 'Sai tài khoản hoặc mật khẩu' });
    }
    const ok = await verifyPassword(String(password), user.password);
    if (!ok) {
      return res.status(401).json({ message: 'Sai tài khoản hoặc mật khẩu' });
    }
    const token = signToken(user);
    return res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        level: user.level,
        xp: user.xp,
        role: user.role,
      },
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}

export async function me(req, res) {
  try {
    const user = await findUserById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'Không tìm thấy user' });
    }
    return res.json({
      id: user.id,
      username: user.username,
      level: user.level,
      xp: user.xp,
      role: user.role,
      created_at: user.created_at,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ message: 'Lỗi máy chủ' });
  }
}
