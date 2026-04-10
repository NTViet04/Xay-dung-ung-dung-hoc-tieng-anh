import { Router } from 'express';

import * as quizBankController from '../controllers/quizBankController.js';
import * as quizController from '../controllers/quizController.js';
import { authenticate, requireAdmin } from '../middleware/authMiddleware.js';

export const quizRoutes = Router();

quizRoutes.get('/questions', authenticate, quizController.getQuestions);
quizRoutes.post('/results', authenticate, quizController.submitResult);
quizRoutes.get('/results', authenticate, quizController.listMyResults);

quizRoutes.get(
  '/bank-questions',
  authenticate,
  requireAdmin,
  quizBankController.listByTopic,
);
quizRoutes.post(
  '/bank-questions',
  authenticate,
  requireAdmin,
  quizBankController.create,
);
quizRoutes.put(
  '/bank-questions/:id',
  authenticate,
  requireAdmin,
  quizBankController.update,
);
quizRoutes.delete(
  '/bank-questions/:id',
  authenticate,
  requireAdmin,
  quizBankController.destroy,
);
