import { Router } from 'express';

import * as userController from '../controllers/userController.js';
import { authenticate, requireAdmin } from '../middleware/authMiddleware.js';

export const userRoutes = Router();

userRoutes.get('/', authenticate, requireAdmin, userController.list);
userRoutes.post('/', authenticate, requireAdmin, userController.adminCreate);

userRoutes.put(
  '/:id/password',
  authenticate,
  requireAdmin,
  userController.resetPassword,
);
userRoutes.get(
  '/:id/admin-profile',
  authenticate,
  requireAdmin,
  userController.adminProfile,
);

userRoutes.get('/:id', authenticate, userController.getById);
userRoutes.put('/:id', authenticate, userController.update);
userRoutes.delete('/:id', authenticate, requireAdmin, userController.remove);
