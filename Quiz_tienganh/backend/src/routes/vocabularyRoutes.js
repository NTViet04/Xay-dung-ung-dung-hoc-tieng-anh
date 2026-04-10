import { Router } from 'express';

import * as vocabularyController from '../controllers/vocabularyController.js';
import { authenticate, requireAdmin } from '../middleware/authMiddleware.js';

export const vocabularyRoutes = Router();

vocabularyRoutes.get('/', vocabularyController.list);
vocabularyRoutes.get('/:id', vocabularyController.getById);
vocabularyRoutes.post('/', authenticate, requireAdmin, vocabularyController.create);
vocabularyRoutes.put('/:id', authenticate, requireAdmin, vocabularyController.update);
vocabularyRoutes.delete(
  '/:id',
  authenticate,
  requireAdmin,
  vocabularyController.remove,
);
