import db from '../config/db.js';
import { AppError } from '../middlewares/errorHandler.js';

// Helper to generate a unique 6-digit access code
const generateAccessCode = async () => {
  let attempts = 0;
  while (attempts < 10) {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const check = await db.query('SELECT id FROM sessions WHERE access_code = $1', [code]);
    if (check.rows.length === 0) {
      return code;
    }
    attempts++;
  }
  throw new Error('Failed to generate a unique access code');
};

export const createSession = async (req, res, next) => {
  const { title, description, settings } = req.body;
  const hostId = req.user.id;

  try {
    const accessCode = await generateAccessCode();
    const result = await db.query(
      `INSERT INTO sessions (access_code, host_id, title, description, settings) 
       VALUES ($1, $2, $3, $4, $5) 
       RETURNING *`,
      [accessCode, hostId, title, description, JSON.stringify(settings || {})]
    );

    res.status(201).json({
      status: 'success',
      data: result.rows[0],
    });
  } catch (error) {
    next(error);
  }
};

export const getSessions = async (req, res, next) => {
  const hostId = req.user.id;

  try {
    const result = await db.query(
      `SELECT s.*, 
        (SELECT COUNT(*) FROM participants WHERE session_id = s.id) as participant_count,
        (SELECT COUNT(*) FROM polls WHERE session_id = s.id) as poll_count
       FROM sessions s 
       WHERE s.host_id = $1 
       ORDER BY s.created_at DESC`,
      [hostId]
    );

    res.status(200).json({
      status: 'success',
      results: result.rows.length,
      data: result.rows,
    });
  } catch (error) {
    next(error);
  }
};

export const getSessionDetails = async (req, res, next) => {
  const { id } = req.params;

  try {
    const result = await db.query('SELECT * FROM sessions WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return next(new AppError('Session not found', 404));
    }

    res.status(200).json({
      status: 'success',
      data: result.rows[0],
    });
  } catch (error) {
    next(error);
  }
};

export const joinSessionByCode = async (req, res, next) => {
  const { accessCode, name, deviceId, isAnonymous } = req.body;

  try {
    // Find session
    const sessionRes = await db.query(
      'SELECT * FROM sessions WHERE access_code = $1',
      [accessCode]
    );

    if (sessionRes.rows.length === 0) {
      return next(new AppError('Active session not found with this code', 404));
    }

    const session = sessionRes.rows[0];
    if (session.state === 'ended') {
      return next(new AppError('This session has already ended', 400));
    }

    // Check if participant already exists in this session
    let participant;
    const partRes = await db.query(
      'SELECT * FROM participants WHERE session_id = $1 AND device_id = $2',
      [session.id, deviceId]
    );

    if (partRes.rows.length > 0) {
      participant = partRes.rows[0];
      // Update name if changed
      if (name && participant.name !== name) {
        const updateRes = await db.query(
          'UPDATE participants SET name = $1, is_anonymous = $2 WHERE id = $3 RETURNING *',
          [name, isAnonymous ?? false, participant.id]
        );
        participant = updateRes.rows[0];
      }
    } else {
      // Create new participant
      const insertRes = await db.query(
        `INSERT INTO participants (session_id, device_id, name, is_anonymous) 
         VALUES ($1, $2, $3, $4) 
         RETURNING *`,
        [session.id, deviceId, name || 'Anonymous', isAnonymous ?? true]
      );
      participant = insertRes.rows[0];
    }

    res.status(200).json({
      status: 'success',
      data: {
        session,
        participant,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const updateSession = async (req, res, next) => {
  const { id } = req.params;
  const { title, description, state, isPresenterModeActive, settings, activePollId, activeQuizQuestionId } = req.body;

  try {
    const check = await db.query('SELECT * FROM sessions WHERE id = $1', [id]);
    if (check.rows.length === 0) {
      return next(new AppError('Session not found', 404));
    }

    const existingSession = check.rows[0];
    const newActivePollId = activePollId !== undefined ? activePollId : existingSession.active_poll_id;
    const newActiveQuizQuestionId = activeQuizQuestionId !== undefined ? activeQuizQuestionId : existingSession.active_quiz_question_id;

    const result = await db.query(
      `UPDATE sessions 
       SET title = COALESCE($1, title),
           description = COALESCE($2, description),
           state = COALESCE($3, state),
           is_presenter_mode_active = COALESCE($4, is_presenter_mode_active),
           settings = COALESCE($5, settings),
           active_poll_id = $6,
           active_quiz_question_id = $7,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $8 
       RETURNING *`,
      [
        title,
        description,
        state,
        isPresenterModeActive,
        settings ? JSON.stringify(settings) : null,
        newActivePollId,
        newActiveQuizQuestionId,
        id,
      ]
    );

    res.status(200).json({
      status: 'success',
      data: result.rows[0],
    });
  } catch (error) {
    next(error);
  }
};

export const deleteSession = async (req, res, next) => {
  const { id } = req.params;

  try {
    const result = await db.query('DELETE FROM sessions WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return next(new AppError('Session not found', 404));
    }

    res.status(200).json({
      status: 'success',
      message: 'Session successfully deleted',
    });
  } catch (error) {
    next(error);
  }
};

export const verifySessionCode = async (req, res, next) => {
  const { accessCode } = req.params;

  try {
    const result = await db.query(
      'SELECT * FROM sessions WHERE access_code = $1',
      [accessCode]
    );

    if (result.rows.length === 0) {
      return next(new AppError('Active session not found with this code', 404));
    }

    const session = result.rows[0];
    if (session.state === 'ended') {
      return next(new AppError('This session has already ended', 400));
    }

    res.status(200).json({
      status: 'success',
      data: session,
    });
  } catch (error) {
    next(error);
  }
};
