import express from 'express';
import Joi from 'joi';
import { 
  createQuestion, 
  getQuestions, 
  toggleUpvoteQuestion, 
  updateQuestionStatus 
} from '../controllers/qaController.js';
import { protectHost } from '../middlewares/auth.js';
import { validateBody } from '../middlewares/validation.js';

const router = express.Router();

const createQuestionSchema = Joi.object({
  sessionId: Joi.string().guid({ version: 'uuidv4' }).required(),
  participantId: Joi.string().guid({ version: 'uuidv4' }).required(),
  text: Joi.string().min(3).required(),
  isAnonymous: Joi.boolean().optional(),
});

const upvoteQuestionSchema = Joi.object({
  questionId: Joi.string().guid({ version: 'uuidv4' }).required(),
  participantId: Joi.string().guid({ version: 'uuidv4' }).required(),
});

const updateQuestionStatusSchema = Joi.object({
  status: Joi.string().valid('pending', 'approved', 'answered', 'dismissed').optional(),
  isPinned: Joi.boolean().optional(),
});

router.post('/', validateBody(createQuestionSchema), createQuestion);
router.get('/session/:sessionId', getQuestions);
router.post('/upvote', validateBody(upvoteQuestionSchema), toggleUpvoteQuestion);

// Host-protected moderation updates
router.patch('/:id', protectHost, validateBody(updateQuestionStatusSchema), updateQuestionStatus);

export default router;
