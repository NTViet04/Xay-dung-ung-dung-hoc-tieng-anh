import { Router } from 'express';

import * as progressController from '../controllers/progressController.js';
import { authenticate } from '../middleware/authMiddleware.js';

export const progressRoutes = Router();

progressRoutes.get('/topics', authenticate, progressController.listMyTopicProgress);
progressRoutes.get('/summary', authenticate, progressController.getMyProgressSummary);
