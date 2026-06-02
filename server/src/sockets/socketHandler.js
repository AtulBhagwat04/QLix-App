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
    authorName: row.authorName || (row.is_anonymous ? 'Anonymous' : 'Guest'),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

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
          'SELECT id, title, state FROM sessions WHERE access_code = $1',
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

        // Broadcast participant join to hosts and presenter
        io.to(roomName).emit('participant_joined_ack', {
          participantId,
          role: currentRole,
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
        const roomName = `session:${sessionId}`;

        if (pollId) {
          // End any currently active polls in this session
          await db.query(
            "UPDATE polls SET status = 'ended' WHERE session_id = $1 AND status = 'active'",
            [sessionId]
          );

          // Deactivate any currently active poll for this session
          await db.query(
            'UPDATE sessions SET active_poll_id = $1 WHERE id = $2',
            [pollId, sessionId]
          );
          
          await db.query(
            'UPDATE polls SET status = \'active\' WHERE id = $1',
            [pollId]
          );

          // Retrieve active poll details
          const pollRes = await db.query('SELECT * FROM polls WHERE id = $1', [pollId]);
          const poll = pollRes.rows[0];

          const optionsRes = await db.query(
            'SELECT * FROM poll_options WHERE poll_id = $1 ORDER BY order_index ASC',
            [pollId]
          );
          poll.options = optionsRes.rows;

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

        // Broadcast updated results to room
        io.to(currentRoom).emit('votes_updated', {
          pollId,
          results: aggregates,
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
    socket.on('update_question_status', async ({ sessionId, questionId, status, isPinned }) => {
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
        let remaining = durationSeconds || 15;

        // Save active state in Redis
        await redis.hset(`quiz:active:${sessionId}`, {
          pollId,
          activatedAt: Date.now(),
          timeLimit: remaining,
        });

        io.to(roomName).emit('quiz_timer_start', { pollId, durationSeconds: remaining });

        const intervalId = setInterval(async () => {
          remaining--;
          if (remaining <= 0) {
            clearInterval(intervalId);
            io.to(roomName).emit('quiz_timer_end', { pollId });
            // Unlock and reveal correct answer in poll results
            await db.query('UPDATE polls SET status = \'locked\' WHERE id = $1', [pollId]);
            const pollRes = await db.query('SELECT * FROM polls WHERE id = $1', [pollId]);
            const results = await calculatePollResults(pollRes.rows[0]);
            io.to(roomName).emit('votes_updated', { pollId, results });
          } else {
            io.to(roomName).emit('quiz_timer_tick', { pollId, remaining });
          }
        }, 1000);

      } catch (err) {
        console.error('Socket start_quiz_timer error:', err);
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

    // Disconnect Handler
    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });
  });
}
