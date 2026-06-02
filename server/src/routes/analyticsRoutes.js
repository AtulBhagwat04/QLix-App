import express from 'express';
import { 
  getSessionAnalytics, 
  exportQuestionsCSV, 
  exportVotesCSV 
} from '../controllers/analyticsController.js';
import { protectHost } from '../middlewares/auth.js';

const router = express.Router();

// All analytics routes require host authorization
router.get('/session/:sessionId', protectHost, getSessionAnalytics);
router.get('/session/:sessionId/export/questions', protectHost, exportQuestionsCSV);
router.get('/session/:sessionId/export/votes', protectHost, exportVotesCSV);

export default router;
