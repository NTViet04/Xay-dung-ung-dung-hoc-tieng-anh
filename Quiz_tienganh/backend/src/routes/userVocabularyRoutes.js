import { Router } from 'express';

import * as userVocabularyController from '../controllers/userVocabularyController.js';
import { authenticate } from '../middleware/authMiddleware.js';

export const userVocabularyRoutes = Router();

userVocabularyRoutes.get('/', authenticate, userVocabularyController.listMine);
userVocabularyRoutes.post('/', authenticate, userVocabularyController.upsert);
