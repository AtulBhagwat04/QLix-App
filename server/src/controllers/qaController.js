import db from '../config/db.js';
import { AppError } from '../middlewares/errorHandler.js';

export const createQuestion = async (req, res, next) => {
  const { sessionId, participantId, text, isAnonymous } = req.body;

  try {
    // Fetch session details to check moderation settings
    const sessionRes = await db.query('SELECT settings FROM sessions WHERE id = $1', [sessionId]);
    if (sessionRes.rows.length === 0) {
      return next(new AppError('Session not found', 404));
    }

    const settings = sessionRes.rows[0].settings || {};
    const moderationEnabled = settings.qaModeration ?? false; // default moderation disabled

    // Determine initial status
    const status = moderationEnabled ? 'pending' : 'approved';

    const result = await db.query(
      `INSERT INTO questions (session_id, participant_id, text, is_anonymous, status)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [sessionId, participantId, text, isAnonymous ?? true, status]
    );

    // Fetch participant name to attach to return object
    const question = result.rows[0];
    if (!question.is_anonymous) {
      const partRes = await db.query('SELECT name FROM participants WHERE id = $1', [participantId]);
      question.authorName = partRes.rows[0]?.name || 'Guest';
    } else {
      question.authorName = 'Anonymous';
    }

    res.status(201).json({
      status: 'success',
      data: question,
    });
  } catch (error) {
    next(error);
  }
};

export const getQuestions = async (req, res, next) => {
  const { sessionId } = req.params;
  const { status, sortBy, search, participantId } = req.query;

  try {
    let query = `
      SELECT q.*, p.name as author_name,
      EXISTS(SELECT 1 FROM question_upvotes qu WHERE qu.question_id = q.id AND qu.participant_id = $2::uuid) as has_upvoted
      FROM questions q
      JOIN participants p ON q.participant_id = p.id
      WHERE q.session_id = $1
    `;
    const params = [sessionId, participantId || '00000000-0000-0000-0000-000000000000'];

    let paramIndex = 3;

    if (status) {
      query += ` AND q.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    } else {
      // Default: exclude dismissed questions for regular clients unless requested
      query += ` AND q.status != 'dismissed'`;
    }

    if (search) {
      query += ` AND q.text ILIKE $${paramIndex}`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    // Sorting: default is pinned first, then upvotes count, then created_at
    const order = sortBy === 'recent' ? 'q.created_at DESC' : 'q.upvotes_count DESC, q.created_at DESC';
    query += ` ORDER BY q.is_pinned DESC, ${order}`;

    const result = await db.query(query, params);

    const data = result.rows.map(row => ({
      id: row.id,
      sessionId: row.session_id,
      participantId: row.participant_id,
      text: row.text,
      isAnonymous: row.is_anonymous,
      status: row.status,
      upvotesCount: row.upvotes_count,
      isPinned: row.is_pinned,
      hasUpvoted: row.has_upvoted,
      authorName: row.is_anonymous ? 'Anonymous' : row.author_name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    res.status(200).json({
      status: 'success',
      results: data.length,
      data,
    });
  } catch (error) {
    next(error);
  }
};

export const toggleUpvoteQuestion = async (req, res, next) => {
  const { questionId, participantId } = req.body;

  try {
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      // Check if question exists
      const checkQ = await client.query('SELECT id, upvotes_count FROM questions WHERE id = $1', [questionId]);
      if (checkQ.rows.length === 0) {
        throw new AppError('Question not found', 404);
      }

      // Check for existing upvote
      const checkUpvote = await client.query(
        'SELECT 1 FROM question_upvotes WHERE question_id = $1 AND participant_id = $2',
        [questionId, participantId]
      );

      let isUpvoted = false;
      if (checkUpvote.rows.length > 0) {
        // Remove upvote
        await client.query(
          'DELETE FROM question_upvotes WHERE question_id = $1 AND participant_id = $2',
          [questionId, participantId]
        );
        await client.query(
          'UPDATE questions SET upvotes_count = GREATEST(0, upvotes_count - 1) WHERE id = $1',
          [questionId]
        );
      } else {
        // Add upvote
        await client.query(
          'INSERT INTO question_upvotes (question_id, participant_id) VALUES ($1, $2)',
          [questionId, participantId]
        );
        await client.query(
          'UPDATE questions SET upvotes_count = upvotes_count + 1 WHERE id = $1',
          [questionId]
        );
        isUpvoted = true;
      }

      // Get updated count
      const updatedQ = await client.query('SELECT upvotes_count FROM questions WHERE id = $1', [questionId]);
      const upvotesCount = updatedQ.rows[0].upvotes_count;

      await client.query('COMMIT');

      res.status(200).json({
        status: 'success',
        data: {
          questionId,
          upvotesCount,
          hasUpvoted: isUpvoted,
        },
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
};

export const updateQuestionStatus = async (req, res, next) => {
  const { id } = req.params;
  const { status, isPinned } = req.body;

  try {
    const queryParts = [];
    const params = [];
    let paramIndex = 1;

    if (status) {
      queryParts.push(`status = $${paramIndex}`);
      params.push(status);
      paramIndex++;
    }

    if (isPinned !== undefined) {
      queryParts.push(`is_pinned = $${paramIndex}`);
      params.push(isPinned);
      paramIndex++;
    }

    if (queryParts.length === 0) {
      return next(new AppError('No parameters provided for update', 400));
    }

    params.push(id);
    const updateQuery = `
      UPDATE questions 
      SET ${queryParts.join(', ')}, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $${paramIndex} 
      RETURNING *
    `;

    const result = await db.query(updateQuery, params);
    if (result.rows.length === 0) {
      return next(new AppError('Question not found', 404));
    }

    const question = result.rows[0];

    // Get author name
    const partRes = await db.query('SELECT name FROM participants WHERE id = $1', [question.participant_id]);
    question.authorName = question.is_anonymous ? 'Anonymous' : (partRes.rows[0]?.name || 'Guest');

    res.status(200).json({
      status: 'success',
      data: question,
    });
  } catch (error) {
    next(error);
  }
};
