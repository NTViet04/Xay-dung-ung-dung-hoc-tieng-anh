import { Router } from 'express';

import * as statsController from '../controllers/statsController.js';
import { authenticate, requireAdmin } from '../middleware/authMiddleware.js';

export const statsRoutes = Router();

statsRoutes.get(
  '/dashboard',
  authenticate,
  requireAdmin,
  statsController.dashboard,
);

statsRoutes.get(
  '/topic-management',
  authenticate,
  requireAdmin,
  statsController.topicManagementSummary,
);

statsRoutes.get(
  '/vocabulary-management',
  authenticate,
  requireAdmin,
  statsController.vocabularyManagementSummary,
);

statsRoutes.get(
  '/user-management',
  authenticate,
  requireAdmin,
  statsController.userManagementSummary,
);
