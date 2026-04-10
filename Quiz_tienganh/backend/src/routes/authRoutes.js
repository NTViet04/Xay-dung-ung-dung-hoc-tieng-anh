import { Router } from 'express';

import * as authController from '../controllers/authController.js';
import { authenticate } from '../middleware/authMiddleware.js';

export const authRoutes = Router();

authRoutes.post('/login', authController.login);
authRoutes.post('/register', authController.register);
authRoutes.get('/me', authenticate, authController.me);
