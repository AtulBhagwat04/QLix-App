import db from '../config/db.js';
import redis from '../config/redis.js';
import { calculatePollResults } from '../controllers/pollController.js';
import { filterProfanity } from '../utils/profanity.js';

function mapQuestionToCamelCase(row) {
  return {
    id: row.id,
    sessionId: row.session_id,
    participantId: row.participant_id,
    text: row.text,
    isAnonymous: row.is_anonymous,
    status: row.status,
    upvotesCount: row.upvotes_count,
    isPinned: row.is_pinned,
    answerText: row.answer_text || null,
    authorName: row.authorName || (row.is_anonymous ? 'Anonymous' : 'Guest'),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

// Map tracking active running quiz countdown intervals by sessionId to prevent overlapping timers on restarts
const activeQuizTimers = new Map();

export default function registerSocketHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // State tracks for connection
    let currentRoom = null;
    let currentParticipantId = null;
    let currentRole = null; // 'host' | 'participant' | 'presenter'

    // 1. Join Session Room
    socket.on('join_session', async ({ accessCode, participantId, role }) => {
      try {
        // Find session
        const sessionRes = await db.query(
          'SELECT id, title, state FROM sessions WHERE access_code = $1 OR id = $1',
          [accessCode]
        );

        if (sessionRes.rows.length === 0) {
          socket.emit('error', { message: 'Session not found' });
          return;
        }

        const session = sessionRes.rows[0];
        const roomName = `session:${session.id}`;
        
        socket.join(roomName);
        currentRoom = roomName;
        currentParticipantId = participantId;
        currentRole = role || 'participant';

        console.log(`Socket ${socket.id} joined room ${roomName} as ${currentRole}`);

        let participant = null;
        if (participantId) {
          const partRes = await db.query(
            'SELECT id, name, is_anonymous, joined_at FROM participants WHERE id = $1',
            [participantId]
          );
          if (partRes.rows.length > 0) {
            const p = partRes.rows[0];
            participant = {
              id: p.id,
              name: p.is_anonymous ? 'Anonymous' : p.name,
              isAnonymous: p.is_anonymous,
              joinedAt: p.joined_at,
            };
          }
        }

        const partCountRes = await db.query(
          'SELECT COUNT(*) as count FROM participants WHERE session_id = $1',
          [session.id]
        );
        const totalParticipants = parseInt(partCountRes.rows[0].count, 10);

        // Broadcast participant join to hosts and presenter
        io.to(roomName).emit('participant_joined_ack', {
          participantId,
          role: currentRole,
          participant,
          totalParticipants,
          timestamp: Date.now(),
        });
      } catch (err) {
        console.error('Socket join_session error:', err);
        socket.emit('error', { message: 'Failed to join session room' });
      }
    });

    // 2. Host Activates Poll
    socket.on('activate_poll', async ({ sessionId, pollId }) => {
      try {
        const sessionRes = await db.query(
          'SELECT id FROM sessions WHERE id = $1 OR access_code = $1',
          [sessionId]
        );
        const targetSessionId = sessionRes.rows[0]?.id || sessionId;
        const roomName = `session:${targetSessionId}`;

        if (pollId) {
          // Activate target poll in sessions and polls table
          await db.query(
            'UPDATE sessions SET active_poll_id = $1 WHERE id = $2',
            [pollId, sessionId]
          );
          
          await db.query(
            "UPDATE polls SET status = 'active' WHERE id = $1",
            [pollId]
          );

          // Retrieve active poll details
          const pollRes = await db.query('SELECT * FROM polls WHERE id = $1', [pollId]);
          if (pollRes.rows.length === 0) return;
          const poll = pollRes.rows[0];

          const optionsRes = await db.query(
            'SELECT * FROM poll_options WHERE poll_id = $1 ORDER BY order_index ASC',
            [pollId]
          );
          poll.options = optionsRes.rows.map(opt => ({
            id: opt.id,
            pollId: opt.poll_id,
            optionText: opt.option_text,
            option_text: opt.option_text,
            isCorrect: opt.is_correct,
            orderIndex: opt.order_index
          }));

          const results = await calculatePollResults(poll);
          poll.results = results;

          // Broadcast active poll info to room
          io.to(roomName).emit('poll_activated', { poll });
        } else {
          // End any currently active polls in this session
          await db.query(
            "UPDATE polls SET status = 'ended' WHERE session_id = $1 AND status = 'active'",
            [sessionId]
          );

          // Deactivate
          await db.query(
            'UPDATE sessions SET active_poll_id = NULL WHERE id = $1',
            [sessionId]
          );
          io.to(roomName).emit('poll_deactivated');
        }
      } catch (err) {
        console.error('Socket activate_poll error:', err);
      }
    });

    // 3. Submit Reaction
    socket.on('submit_reaction', ({ emoji }) => {
      if (currentRoom) {
        // Broadcast emoji animation to room
        io.to(currentRoom).emit('reaction_broadcast', { emoji, id: Math.random().toString() });
      }
    });

    // 4. Submit Vote (Real-time and atomic updates)
    socket.on('submit_vote', async ({ pollId, participantId, optionIds, textResponse, ratingValue, rankingIds }) => {
      try {
        if (!currentRoom) return;

        // Fetch poll details
        const pollRes = await db.query('SELECT * FROM polls WHERE id = $1', [pollId]);
        if (pollRes.rows.length === 0) return;
        const poll = pollRes.rows[0];

        if (poll.status !== 'active') {
          socket.emit('error', { message: 'Voting is locked or closed' });
          return;
        }

        const client = await db.pool.connect();
        try {
          await client.query('BEGIN');

          // Check if already voted
          const checkVote = await client.query(
            'SELECT id FROM votes WHERE poll_id = $1 AND participant_id = $2',
            [pollId, participantId]
          );

          if (checkVote.rows.length > 0) {
            // Re-voting is allowed depending on settings. For simplicity, we delete previous votes first
            await client.query(
              'DELETE FROM votes WHERE poll_id = $1 AND participant_id = $2',
              [pollId, participantId]
            );
          }

          // Insert new vote(s)
          if (poll.type === 'multiple_choice') {
            for (const optId of optionIds) {
              await client.query(
                'INSERT INTO votes (poll_id, option_id, participant_id) VALUES ($1, $2, $3)',
                [pollId, optId, participantId]
              );
            }
          } else if (poll.type === 'word_cloud') {
            const cleanWord = filterProfanity(textResponse.trim().toLowerCase());
            if (cleanWord) {
              await client.query(
                'INSERT INTO votes (poll_id, participant_id, text_response) VALUES ($1, $2, $3)',
                [pollId, participantId, cleanWord]
              );
              // HINCRBY in Redis
              await redis.hincrby(`poll:wordcloud:${pollId}`, cleanWord, 1);
            }
          } else if (poll.type === 'rating') {
            await client.query(
              'INSERT INTO votes (poll_id, participant_id, rating_value) VALUES ($1, $2, $3)',
              [pollId, participantId, ratingValue]
            );
          } else if (poll.type === 'open_text') {
            const filteredText = filterProfanity(textResponse.trim());
            await client.query(
              'INSERT INTO votes (poll_id, participant_id, text_response) VALUES ($1, $2, $3)',
              [pollId, participantId, filteredText]
            );
          } else if (poll.type === 'ranking') {
            // rankingIds is ordered list of option IDs
            for (let index = 0; index < rankingIds.length; index++) {
              const optId = rankingIds[index];
              await client.query(
                'INSERT INTO votes (poll_id, option_id, participant_id, rank_value) VALUES ($1, $2, $3, $4)',
                [pollId, optId, participantId, index]
              );
            }
          }

          await client.query('COMMIT');
        } catch (err) {
          await client.query('ROLLBACK');
          throw err;
        } finally {
          client.release();
        }

        // Recalculate results
        const aggregates = await calculatePollResults(poll);

        // Total votes count for the session
        const voteCountRes = await db.query(
          `SELECT COUNT(v.id) as count
           FROM votes v
           JOIN polls p ON v.poll_id = p.id
           WHERE p.session_id = $1`,
          [poll.session_id]
        );
        const totalVotes = parseInt(voteCountRes.rows[0]?.count || 0, 10);

        // Fetch participant name for recent activity
        let participantName = 'Anonymous';
        if (participantId) {
          const partRes = await db.query('SELECT name, is_anonymous FROM participants WHERE id = $1', [participantId]);
          if (partRes.rows.length > 0 && !partRes.rows[0].is_anonymous) {
            participantName = partRes.rows[0].name || 'Anonymous';
          }
        }

        // Fetch option text if multiple choice or ranking
        let optionText = null;
        if (optionIds && optionIds.length > 0) {
          const optRes = await db.query('SELECT option_text FROM poll_options WHERE id = $1', [optionIds[0]]);
          optionText = optRes.rows[0]?.option_text || null;
        }

        const recentResponseItem = {
          id: Math.random().toString(),
          createdAt: new Date().toISOString(),
          participantName,
          pollTitle: poll.title,
          pollType: poll.type,
          optionText: optionText,
          ratingValue: ratingValue ?? null,
          textResponse: textResponse ?? null,
          rankValue: rankingIds && rankingIds.length > 0 ? 0 : null
        };

        // Broadcast updated results to room
        io.to(currentRoom).emit('votes_updated', {
          pollId,
          sessionId: poll.session_id,
          results: aggregates,
          totalVotes,
          recentResponse: recentResponseItem,
        });

      } catch (err) {
        console.error('Socket submit_vote error:', err);
      }
    });

    // 5. Submit Question (Q&A)
    socket.on('submit_question', async ({ sessionId, participantId, text, isAnonymous }) => {
      try {
        const roomName = `session:${sessionId}`;

        // Get moderation settings
        const sessionRes = await db.query('SELECT settings FROM sessions WHERE id = $1', [sessionId]);
        if (sessionRes.rows.length === 0) return;
        const settings = sessionRes.rows[0].settings || {};
        const moderationEnabled = settings.qaModeration ?? false;

        const status = moderationEnabled ? 'pending' : 'approved';
        const filteredText = filterProfanity(text.trim());

        const result = await db.query(
          `INSERT INTO questions (session_id, participant_id, text, is_anonymous, status)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [sessionId, participantId, filteredText, isAnonymous ?? true, status]
        );

        const dbQuestion = result.rows[0];
        let authorName = 'Anonymous';
        if (!dbQuestion.is_anonymous) {
          const partRes = await db.query('SELECT name FROM participants WHERE id = $1', [participantId]);
          authorName = partRes.rows[0]?.name || 'Guest';
        }
        
        const question = mapQuestionToCamelCase({
          ...dbQuestion,
          authorName
        });

        // Broadcast: If moderation is on, send ONLY to hosts. If moderation is off, send to ALL.
        if (moderationEnabled) {
          // In room, hosts/presenters have joined sub-rooms or we broadcast and clients filter,
          // but cleaner to send to all host sockets directly or emit with validation.
          // For simplicity, we emit a 'question_created' event to the entire room, 
          // and participant clients filter out 'pending' status.
          io.to(roomName).emit('question_created', { question });
        } else {
          io.to(roomName).emit('question_created', { question });
        }
      } catch (err) {
        console.error('Socket submit_question error:', err);
      }
    });

    // 6. Upvote Question
    socket.on('upvote_question', async ({ sessionId, questionId, participantId }) => {
      try {
        const roomName = `session:${sessionId}`;
        
        // Transaction to toggle upvote
        const client = await db.pool.connect();
        try {
          await client.query('BEGIN');
          
          const checkUpvote = await client.query(
            'SELECT 1 FROM question_upvotes WHERE question_id = $1 AND participant_id = $2',
            [questionId, participantId]
          );

          if (checkUpvote.rows.length > 0) {
            await client.query(
              'DELETE FROM question_upvotes WHERE question_id = $1 AND participant_id = $2',
              [questionId, participantId]
            );
            await client.query(
              'UPDATE questions SET upvotes_count = GREATEST(0, upvotes_count - 1) WHERE id = $1',
              [questionId]
            );
          } else {
            await client.query(
              'INSERT INTO question_upvotes (question_id, participant_id) VALUES ($1, $2)',
              [questionId, participantId]
            );
            await client.query(
              'UPDATE questions SET upvotes_count = upvotes_count + 1 WHERE id = $1',
              [questionId]
            );
          }

          await client.query('COMMIT');
        } catch (err) {
          await client.query('ROLLBACK');
          throw err;
        } finally {
          client.release();
        }

        const updatedQ = await db.query('SELECT upvotes_count FROM questions WHERE id = $1', [questionId]);
        const upvotesCount = updatedQ.rows[0].upvotes_count;

        io.to(roomName).emit('question_upvoted', {
          questionId,
          upvotesCount,
        });
      } catch (err) {
        console.error('Socket upvote_question error:', err);
      }
    });

    // 7. Change Question Status (Moderation, answering, pinning)
    socket.on('update_question_status', async ({ sessionId, questionId, status, isPinned, answerText }) => {
      try {
        const roomName = `session:${sessionId}`;
        
        const queryParts = [];
        const params = [];
        let index = 1;

        if (status) {
          queryParts.push(`status = $${index}`);
          params.push(status);
          index++;
        }
        if (isPinned !== undefined) {
          queryParts.push(`is_pinned = $${index}`);
          params.push(isPinned);
          index++;
        }
        // Store host's written answer text (if provided)
        if (answerText !== undefined && answerText !== null) {
          queryParts.push(`answer_text = $${index}`);
          params.push(answerText.trim() || null);
          index++;
        }

        if (queryParts.length === 0) return;

        params.push(questionId);
        const updateQuery = `
          UPDATE questions 
          SET ${queryParts.join(', ')}, updated_at = CURRENT_TIMESTAMP 
          WHERE id = $${index} 
          RETURNING *
        `;

        const result = await db.query(updateQuery, params);
        if (result.rows.length > 0) {
          const dbQuestion = result.rows[0];
          const partRes = await db.query('SELECT name FROM participants WHERE id = $1', [dbQuestion.participant_id]);
          const authorName = dbQuestion.is_anonymous ? 'Anonymous' : (partRes.rows[0]?.name || 'Guest');
          
          const question = mapQuestionToCamelCase({
            ...dbQuestion,
            authorName
          });

          io.to(roomName).emit('question_status_changed', { question });
        }
      } catch (err) {
        console.error('Socket update_question_status error:', err);
      }
    });

    // 8. Quiz Controls (timers & ticks)
    socket.on('start_quiz_timer', async ({ sessionId, pollId, durationSeconds }) => {
      try {
        const roomName = `session:${sessionId}`;
        let remaining = parseInt(durationSeconds, 10) || 15;

        // Clear any previous running timer for this session to prevent conflicting countdowns on restart
        if (activeQuizTimers.has(sessionId)) {
          clearInterval(activeQuizTimers.get(sessionId));
          activeQuizTimers.delete(sessionId);
        }

        // Set poll status to active so responses are accepted (preserves existing votes without clearing)
        await db.query("UPDATE polls SET status = 'active' WHERE id = $1", [pollId]);
        await db.query("UPDATE sessions SET active_quiz_question_id = $1 WHERE id = $2", [pollId, sessionId]);

        // Save active state in Redis with the new timestamp and duration
        const now = Date.now();
        await redis.hset(`quiz:active:${sessionId}`, {
          pollId,
          activatedAt: now,
          timeLimit: remaining,
        });

        io.to(roomName).emit('quiz_timer_start', { pollId, durationSeconds: remaining });

        const intervalId = setInterval(async () => {
          remaining--;
          if (remaining <= 0) {
            clearInterval(intervalId);
            if (activeQuizTimers.get(sessionId) === intervalId) {
              activeQuizTimers.delete(sessionId);
            }
            io.to(roomName).emit('quiz_timer_end', { pollId });
            // Lock poll and reveal results
            await db.query("UPDATE polls SET status = 'locked' WHERE id = $1", [pollId]);
            const pollRes = await db.query("SELECT * FROM polls WHERE id = $1", [pollId]);
            if (pollRes.rows.length > 0) {
              const results = await calculatePollResults(pollRes.rows[0]);
              io.to(roomName).emit('votes_updated', { pollId, results });
            }
          } else {
            io.to(roomName).emit('quiz_timer_tick', { pollId, remaining });
          }
        }, 1000);

        activeQuizTimers.set(sessionId, intervalId);

      } catch (err) {
        console.error('Socket start_quiz_timer error:', err);
      }
    });

    socket.on('stop_quiz_timer', async ({ sessionId, pollId }) => {
      try {
        const roomName = `session:${sessionId}`;
        if (activeQuizTimers.has(sessionId)) {
          clearInterval(activeQuizTimers.get(sessionId));
          activeQuizTimers.delete(sessionId);
        }
        io.to(roomName).emit('quiz_timer_end', { pollId });
        await db.query("UPDATE polls SET status = 'locked' WHERE id = $1", [pollId]);
        const pollRes = await db.query("SELECT * FROM polls WHERE id = $1", [pollId]);
        if (pollRes.rows.length > 0) {
          const results = await calculatePollResults(pollRes.rows[0]);
          io.to(roomName).emit('votes_updated', { pollId, results });
        }
      } catch (err) {
        console.error('Socket stop_quiz_timer error:', err);
      }
    });

    // 9. Host broadcast announcements
    socket.on('send_announcement', async ({ sessionId, title, message }) => {
      try {
        const roomName = `session:${sessionId}`;

        const result = await db.query(
          'INSERT INTO announcements (session_id, title, message) VALUES ($1, $2, $3) RETURNING *',
          [sessionId, title, message]
        );

        io.to(roomName).emit('announcement_received', { announcement: result.rows[0] });
      } catch (err) {
        console.error('Socket send_announcement error:', err);
      }
    });

    // 10. Host update session state (draft / active / ended)
    socket.on('update_session_state', async ({ sessionId, state }) => {
      try {
        const sessionRes = await db.query(
          'UPDATE sessions SET state = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 OR access_code = $2 RETURNING *',
          [state, sessionId]
        );
        if (sessionRes.rows.length === 0) return;
        const updatedSession = sessionRes.rows[0];
        const targetSessionId = updatedSession.id;
        const roomName = `session:${targetSessionId}`;

        io.to(roomName).emit('session_state_changed', {
          sessionId: targetSessionId,
          state: updatedSession.state,
          session: updatedSession,
        });
      } catch (err) {
        console.error('Socket update_session_state error:', err);
      }
    });

    // Disconnect Handler
    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });
  });
}
