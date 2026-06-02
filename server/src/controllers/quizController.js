import db from '../config/db.js';
import redis from '../config/redis.js';
import { AppError } from '../middlewares/errorHandler.js';

export const activateQuizQuestion = async (req, res, next) => {
  const { sessionId, pollId, timeLimit } = req.body;

  try {
    // Check if session exists
    const sessionCheck = await db.query('SELECT id FROM sessions WHERE id = $1', [sessionId]);
    if (sessionCheck.rows.length === 0) {
      return next(new AppError('Session not found', 404));
    }

    // Set active question in database
    await db.query(
      'UPDATE sessions SET active_quiz_question_id = $1 WHERE id = $2',
      [pollId, sessionId]
    );

    // Save activation timestamp and time limit in Redis
    const now = Date.now();
    await redis.hset(`quiz:active:${sessionId}`, {
      pollId,
      activatedAt: now,
      timeLimit: timeLimit || 15, // default 15s
    });

    res.status(200).json({
      status: 'success',
      data: {
        sessionId,
        pollId,
        activatedAt: now,
        timeLimit: timeLimit || 15,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const submitQuizAnswer = async (req, res, next) => {
  const { sessionId, participantId, pollId, optionId } = req.body;

  try {
    // 1. Check if the question is active and get activation time
    const quizState = await redis.hgetall(`quiz:active:${sessionId}`);
    if (!quizState || quizState.pollId !== pollId) {
      return next(new AppError('This quiz question is not active or has ended', 400));
    }

    const activatedAt = parseInt(quizState.activatedAt, 10);
    const timeLimit = parseInt(quizState.timeLimit, 10);
    const now = Date.now();

    const elapsedSeconds = (now - activatedAt) / 1000;
    if (elapsedSeconds > timeLimit + 1) { // 1-second grace period for latency
      return next(new AppError('Time limit exceeded for this question', 400));
    }

    // 2. Prevent double voting for this specific poll question
    const checkVote = await db.query(
      'SELECT id FROM votes WHERE poll_id = $1 AND participant_id = $2',
      [pollId, participantId]
    );
    if (checkVote.rows.length > 0) {
      return next(new AppError('You have already submitted an answer for this question', 400));
    }

    // 3. Verify if the chosen option is correct
    const optRes = await db.query(
      'SELECT is_correct FROM poll_options WHERE id = $1 AND poll_id = $2',
      [optionId, pollId]
    );

    if (optRes.rows.length === 0) {
      return next(new AppError('Option not found for this question', 404));
    }

    const isCorrect = optRes.rows[0].is_correct;
    let scoreEarned = 0;
    const basePoints = 1000;

    if (isCorrect) {
      // Points = Base Points * (Time Remaining / Time Limit)
      const timeRemaining = Math.max(0, timeLimit - elapsedSeconds);
      scoreEarned = Math.round(basePoints * (timeRemaining / timeLimit));
    }

    // 4. Save vote/answer to database
    await db.query(
      `INSERT INTO votes (poll_id, option_id, participant_id) 
       VALUES ($1, $2, $3)`,
      [pollId, optionId, participantId]
    );

    // 5. Update score in DB & Redis Leaderboard
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      // Update in PostgreSQL
      const scoreCheck = await client.query(
        'SELECT score FROM quiz_scores WHERE session_id = $1 AND participant_id = $2',
        [sessionId, participantId]
      );

      let newScore = scoreEarned;

      if (scoreCheck.rows.length > 0) {
        newScore = scoreCheck.rows[0].score + scoreEarned;
        await client.query(
          `UPDATE quiz_scores 
           SET score = $1, last_answered_at = CURRENT_TIMESTAMP 
           WHERE session_id = $2 AND participant_id = $3`,
          [newScore, sessionId, participantId]
        );
      } else {
        await client.query(
          `INSERT INTO quiz_scores (session_id, participant_id, score) 
           VALUES ($1, $2, $3)`,
          [sessionId, participantId, newScore]
        );
      }

      await client.query('COMMIT');

      // Update in Redis Leaderboard (Sorted Set)
      await redis.zadd(`quiz:leaderboard:${sessionId}`, newScore, participantId);

      res.status(200).json({
        status: 'success',
        data: {
          isCorrect,
          pointsEarned: scoreEarned,
          totalScore: newScore,
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

export const getLeaderboard = async (req, res, next) => {
  const { sessionId } = req.params;

  try {
    // Get top 15 participant IDs and their scores from Redis Sorted Set
    // Format returned: [id1, score1, id2, score2, ...]
    const rawLeaderboard = await redis.zrevrange(`quiz:leaderboard:${sessionId}`, 0, 14, 'WITHSCORES');

    const leaderboard = [];
    const participantIds = [];
    const scoresMap = {};

    for (let i = 0; i < rawLeaderboard.length; i += 2) {
      const id = rawLeaderboard[i];
      const score = parseInt(rawLeaderboard[i + 1], 10);
      participantIds.push(id);
      scoresMap[id] = score;
    }

    if (participantIds.length > 0) {
      // Lookup participant names in database
      const placeholders = participantIds.map((_, idx) => `$${idx + 1}`).join(', ');
      const partRes = await db.query(
        `SELECT id, name, is_anonymous FROM participants WHERE id IN (${placeholders})`,
        participantIds
      );

      const partMap = {};
      partRes.rows.forEach(p => {
        partMap[p.id] = p.is_anonymous ? 'Anonymous' : p.name;
      });

      // Construct ordered leaderboard
      participantIds.forEach((id, index) => {
        leaderboard.push({
          rank: index + 1,
          participantId: id,
          name: partMap[id] || 'Guest',
          score: scoresMap[id],
        });
      });
    }

    res.status(200).json({
      status: 'success',
      data: leaderboard,
    });
  } catch (error) {
    next(error);
  }
};

export const resetQuiz = async (req, res, next) => {
  const { sessionId } = req.params;

  try {
    await db.query('DELETE FROM quiz_scores WHERE session_id = $1', [sessionId]);
    await redis.del(`quiz:leaderboard:${sessionId}`);
    await redis.del(`quiz:active:${sessionId}`);

    // Reset active quiz questions in session
    await db.query('UPDATE sessions SET active_quiz_question_id = NULL WHERE id = $1', [sessionId]);

    res.status(200).json({
      status: 'success',
      message: 'Quiz leaderboard reset successfully',
    });
  } catch (error) {
    next(error);
  }
};
