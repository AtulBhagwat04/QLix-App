import express from 'express';
import Joi from 'joi';
import { 
  createPoll, 
  getSessionPolls, 
  getPollDetails, 
  updatePoll, 
  deletePoll,
  getPollResults
} from '../controllers/pollController.js';
import { protectHost } from '../middlewares/auth.js';
import { validateBody } from '../middlewares/validation.js';

const router = express.Router();

const optionSchema = Joi.object({
  optionText: Joi.string().required(),
  isCorrect: Joi.boolean().optional(),
});

const createPollSchema = Joi.object({
  sessionId: Joi.string().guid({ version: 'uuidv4' }).required(),
  title: Joi.string().required(),
  type: Joi.string().valid('multiple_choice', 'word_cloud', 'rating', 'open_text', 'ranking', 'survey').required(),
  settings: Joi.object().allow(null).optional(),
  options: Joi.array().items(optionSchema).allow(null).optional(),
});

const updatePollSchema = Joi.object({
  title: Joi.string().optional(),
  status: Joi.string().valid('draft', 'active', 'locked', 'ended').optional(),
  settings: Joi.object().allow(null).optional(),
  options: Joi.array().items(optionSchema).allow(null).optional(),
});

// Host-protected creation and modification
router.post('/', protectHost, validateBody(createPollSchema), createPoll);
router.patch('/:id', protectHost, validateBody(updatePollSchema), updatePoll);
router.delete('/:id', protectHost, deletePoll);

// Open lookup and calculation endpoints
router.get('/session/:sessionId', getSessionPolls);
router.get('/:id', getPollDetails);
router.get('/:id/results', getPollResults);

export default router;
