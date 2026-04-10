import { Router } from 'express';

import * as topicController from '../controllers/topicController.js';
import { authenticate, requireAdmin } from '../middleware/authMiddleware.js';

export const topicRoutes = Router();

topicRoutes.get('/', topicController.list);
topicRoutes.get('/:id', topicController.getById);
topicRoutes.post('/', authenticate, requireAdmin, topicController.create);
topicRoutes.put('/:id', authenticate, requireAdmin, topicController.update);
topicRoutes.delete('/:id', authenticate, requireAdmin, topicController.remove);
