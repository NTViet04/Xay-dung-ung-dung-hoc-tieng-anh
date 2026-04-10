import { Router } from 'express';

import { authRoutes } from './authRoutes.js';
import { quizRoutes } from './quizRoutes.js';
import { progressRoutes } from './progressRoutes.js';
import { statsRoutes } from './statsRoutes.js';
import { topicRoutes } from './topicRoutes.js';
import { userRoutes } from './userRoutes.js';
import { userVocabularyRoutes } from './userVocabularyRoutes.js';
import { vocabularyRoutes } from './vocabularyRoutes.js';

export const router = Router();

router.use('/auth', authRoutes);
router.use('/topics', topicRoutes);
router.use('/vocabularies', vocabularyRoutes);
router.use('/users', userRoutes);
router.use('/user-vocabulary', userVocabularyRoutes);
router.use('/quiz', quizRoutes);
router.use('/progress', progressRoutes);
router.use('/stats', statsRoutes);
