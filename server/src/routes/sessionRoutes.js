import express from 'express';
import Joi from 'joi';
import { 
  createSession, 
  getSessions, 
  getSessionDetails, 
  joinSessionByCode, 
  updateSession, 
  deleteSession,
  verifySessionCode
} from '../controllers/sessionController.js';
import { protectHost } from '../middlewares/auth.js';
import { validateBody } from '../middlewares/validation.js';

const router = express.Router();

const createSessionSchema = Joi.object({
  title: Joi.string().required(),
  description: Joi.string().allow('', null),
  settings: Joi.object().allow(null).optional(),
});

const joinSessionSchema = Joi.object({
  accessCode: Joi.string().length(6).required(),
  name: Joi.string().max(100).allow('', null),
  deviceId: Joi.string().required(),
  isAnonymous: Joi.boolean().optional(),
});

const updateSessionSchema = Joi.object({
  title: Joi.string().optional(),
  description: Joi.string().allow('', null).optional(),
  state: Joi.string().valid('draft', 'active', 'ended').optional(),
  isPresenterModeActive: Joi.boolean().optional(),
  settings: Joi.object().allow(null).optional(),
  activePollId: Joi.string().guid({ version: 'uuidv4' }).allow(null).optional(),
  activeQuizQuestionId: Joi.string().guid({ version: 'uuidv4' }).allow(null).optional(),
});

// Host-protected routes
router.post('/', protectHost, validateBody(createSessionSchema), createSession);
router.get('/', protectHost, getSessions);
router.patch('/:id', protectHost, validateBody(updateSessionSchema), updateSession);
router.delete('/:id', protectHost, deleteSession);

// Public / Participant routes
router.post('/join', validateBody(joinSessionSchema), joinSessionByCode);
router.get('/verify/:accessCode', verifySessionCode);
router.get('/:id', getSessionDetails);

export default router;
