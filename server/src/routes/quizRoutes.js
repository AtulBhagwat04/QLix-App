import express from 'express';
import Joi from 'joi';
import { 
  activateQuizQuestion, 
  submitQuizAnswer, 
  getLeaderboard, 
  resetQuiz 
} from '../controllers/quizController.js';
import { protectHost } from '../middlewares/auth.js';
import { validateBody } from '../middlewares/validation.js';

const router = express.Router();

const activateSchema = Joi.object({
  sessionId: Joi.string().guid({ version: 'uuidv4' }).required(),
  pollId: Joi.string().guid({ version: 'uuidv4' }).required(),
  timeLimit: Joi.number().min(5).max(120).optional(),
});

const submitAnswerSchema = Joi.object({
  sessionId: Joi.string().guid({ version: 'uuidv4' }).required(),
  participantId: Joi.string().guid({ version: 'uuidv4' }).required(),
  pollId: Joi.string().guid({ version: 'uuidv4' }).required(),
  optionId: Joi.string().guid({ version: 'uuidv4' }).required(),
});

// Host-protected controls
router.post('/activate', protectHost, validateBody(activateSchema), activateQuizQuestion);
router.post('/session/:sessionId/reset', protectHost, resetQuiz);

// Participant/Open endpoints
router.post('/submit', validateBody(submitAnswerSchema), submitQuizAnswer);
router.get('/session/:sessionId/leaderboard', getLeaderboard);

export default router;
