import db from '../config/db.js';
import redis from '../config/redis.js';
import { AppError } from '../middlewares/errorHandler.js';

export const createPoll = async (req, res, next) => {
  const { sessionId, title, type, settings, options } = req.body;

  try {
    // Start transactional process
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      // Get count of polls to determine next order_index
      const countRes = await client.query(
        'SELECT COUNT(*) FROM polls WHERE session_id = $1',
        [sessionId]
      );
      const orderIndex = parseInt(countRes.rows[0].count, 10);

      const pollRes = await client.query(
        `INSERT INTO polls (session_id, title, type, settings, order_index)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [sessionId, title, type, JSON.stringify(settings || {}), orderIndex]
      );

      const poll = pollRes.rows[0];
      const createdOptions = [];

      if (options && Array.isArray(options) && options.length > 0) {
        for (let i = 0; i < options.length; i++) {
          const opt = options[i];
          const optRes = await client.query(
            `INSERT INTO poll_options (poll_id, option_text, is_correct, order_index)
             VALUES ($1, $2, $3, $4)
             RETURNING *`,
            [poll.id, opt.optionText, opt.isCorrect ?? false, i]
          );
          createdOptions.push(optRes.rows[0]);
        }
      }

      await client.query('COMMIT');
      poll.options = createdOptions;

      res.status(201).json({
        status: 'success',
        data: poll,
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

export const getSessionPolls = async (req, res, next) => {
  const { sessionId } = req.params;

  try {
    const pollsRes = await db.query(
      'SELECT * FROM polls WHERE session_id = $1 ORDER BY order_index ASC',
      [sessionId]
    );

    const polls = pollsRes.rows;

    for (let i = 0; i < polls.length; i++) {
      const optRes = await db.query(
        'SELECT * FROM poll_options WHERE poll_id = $1 ORDER BY order_index ASC',
        [polls[i].id]
      );
      polls[i].options = optRes.rows;
    }

    res.status(200).json({
      status: 'success',
      results: polls.length,
      data: polls,
    });
  } catch (error) {
    next(error);
  }
};

export const getPollDetails = async (req, res, next) => {
  const { id } = req.params;

  try {
    const pollRes = await db.query('SELECT * FROM polls WHERE id = $1', [id]);
    if (pollRes.rows.length === 0) {
      return next(new AppError('Poll not found', 404));
    }

    const poll = pollRes.rows[0];

    const optRes = await db.query(
      'SELECT * FROM poll_options WHERE poll_id = $1 ORDER BY order_index ASC',
      [id]
    );
    poll.options = optRes.rows;

    res.status(200).json({
      status: 'success',
      data: poll,
    });
  } catch (error) {
    next(error);
  }
};

export const updatePoll = async (req, res, next) => {
  const { id } = req.params;
  const { title, status, settings, options } = req.body;

  try {
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      const check = await client.query('SELECT * FROM polls WHERE id = $1', [id]);
      if (check.rows.length === 0) {
        throw new AppError('Poll not found', 404);
      }

      // Update poll details
      const pollRes = await client.query(
        `UPDATE polls
         SET title = COALESCE($1, title),
             status = COALESCE($2, status),
             settings = COALESCE($3, settings),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $4
         RETURNING *`,
        [title, status, settings ? JSON.stringify(settings) : null, id]
      );

      const poll = pollRes.rows[0];

      // If options are provided, recreate them (simple sync strategy for templates/builders)
      if (options && Array.isArray(options)) {
        await client.query('DELETE FROM poll_options WHERE poll_id = $1', [id]);
        const createdOptions = [];
        for (let i = 0; i < options.length; i++) {
          const opt = options[i];
          const optRes = await client.query(
            `INSERT INTO poll_options (poll_id, option_text, is_correct, order_index)
             VALUES ($1, $2, $3, $4)
             RETURNING *`,
            [id, opt.optionText, opt.isCorrect ?? false, i]
          );
          createdOptions.push(optRes.rows[0]);
        }
        poll.options = createdOptions;
      } else {
        const optRes = await client.query(
          'SELECT * FROM poll_options WHERE poll_id = $1 ORDER BY order_index ASC',
          [id]
        );
        poll.options = optRes.rows;
      }

      await client.query('COMMIT');

      // Clear any redis cache for results if we edited the poll status/options
      await redis.del(`poll:results:${id}`);

      res.status(200).json({
        status: 'success',
        data: poll,
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

export const deletePoll = async (req, res, next) => {
  const { id } = req.params;

  try {
    const result = await db.query('DELETE FROM polls WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return next(new AppError('Poll not found', 404));
    }

    await redis.del(`poll:results:${id}`);

    res.status(200).json({
      status: 'success',
      message: 'Poll deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

// Aggregates results of a poll in real-time
export const getPollResults = async (req, res, next) => {
  const { id } = req.params;

  try {
    const pollRes = await db.query('SELECT * FROM polls WHERE id = $1', [id]);
    if (pollRes.rows.length === 0) {
      return next(new AppError('Poll not found', 404));
    }
    const poll = pollRes.rows[0];

    const results = await calculatePollResults(poll);

    res.status(200).json({
      status: 'success',
      data: {
        pollId: id,
        type: poll.type,
        results,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Internal result calculation service
export const calculatePollResults = async (poll) => {
  const pollId = poll.id;
  const type = poll.type;

  switch (type) {
    case 'multiple_choice': {
      const votesRes = await db.query(
        `SELECT option_id, COUNT(*) as count 
         FROM votes 
         WHERE poll_id = $1 AND option_id IS NOT NULL
         GROUP BY option_id`,
        [pollId]
      );
      
      const optionsRes = await db.query(
        'SELECT id, option_text, is_correct FROM poll_options WHERE poll_id = $1 ORDER BY order_index ASC',
        [pollId]
      );

      const voteMap = {};
      votesRes.rows.forEach(r => {
        voteMap[r.option_id] = parseInt(r.count, 10);
      });

      const totalVotes = votesRes.rows.reduce((acc, r) => acc + parseInt(r.count, 10), 0);

      const data = optionsRes.rows.map(opt => ({
        id: opt.id,
        optionText: opt.option_text,
        isCorrect: opt.is_correct,
        votes: voteMap[opt.id] || 0,
        percentage: totalVotes > 0 ? Math.round(((voteMap[opt.id] || 0) / totalVotes) * 100) : 0,
      }));

      return {
        totalVotes,
        options: data,
      };
    }

    case 'word_cloud': {
      // Fetch from Redis for ultra-fast aggregation if cached, otherwise load from DB and seed Redis
      const redisKey = `poll:wordcloud:${pollId}`;
      const cached = await redis.hgetall(redisKey);

      let wordFreq = {};
      if (Object.keys(cached).length > 0) {
        Object.keys(cached).forEach(word => {
          wordFreq[word] = parseInt(cached[word], 10);
        });
      } else {
        const votesRes = await db.query(
          'SELECT text_response FROM votes WHERE poll_id = $1 AND text_response IS NOT NULL',
          [pollId]
        );
        
        votesRes.rows.forEach(r => {
          const cleanWord = r.text_response.trim().toLowerCase();
          if (cleanWord) {
            wordFreq[cleanWord] = (wordFreq[cleanWord] || 0) + 1;
          }
        });

        // Seed to Redis
        if (Object.keys(wordFreq).length > 0) {
          const multi = redis.multi();
          Object.keys(wordFreq).forEach(word => {
            multi.hset(redisKey, word, wordFreq[word]);
          });
          await multi.exec();
        }
      }

      const totalWords = Object.values(wordFreq).reduce((acc, count) => acc + count, 0);

      const words = Object.keys(wordFreq).map(word => ({
        text: word,
        value: wordFreq[word],
      })).sort((a, b) => b.value - a.value);

      return {
        totalVotes: totalWords,
        words,
      };
    }

    case 'rating': {
      const votesRes = await db.query(
        `SELECT rating_value, COUNT(*) as count 
         FROM votes 
         WHERE poll_id = $1 AND rating_value IS NOT NULL
         GROUP BY rating_value`,
        [pollId]
      );

      const distribution = {};
      let totalValue = 0;
      let totalVotes = 0;

      votesRes.rows.forEach(r => {
        const rating = parseInt(r.rating_value, 10);
        const count = parseInt(r.count, 10);
        distribution[rating] = count;
        totalValue += rating * count;
        totalVotes += count;
      });

      const average = totalVotes > 0 ? parseFloat((totalValue / totalVotes).toFixed(2)) : 0;

      return {
        totalVotes,
        average,
        distribution,
      };
    }

    case 'open_text': {
      const votesRes = await db.query(
        `SELECT v.id, v.text_response as text, p.name, p.is_anonymous, v.created_at
         FROM votes v
         JOIN participants p ON v.participant_id = p.id
         WHERE v.poll_id = $1 AND v.text_response IS NOT NULL
         ORDER BY v.created_at DESC`,
        [pollId]
      );

      return {
        totalVotes: votesRes.rows.length,
        responses: votesRes.rows.map(r => ({
          id: r.id,
          text: r.text,
          author: r.is_anonymous ? 'Anonymous' : r.name,
          createdAt: r.created_at,
        })),
      };
    }

    case 'ranking': {
      // Ranking is aggregated using Borda Count or simple positional weights:
      // If we have N options, 1st choice gets N points, 2nd gets N-1, etc.
      const votesRes = await db.query(
        `SELECT option_id, rank_value, COUNT(*) as count
         FROM votes
         WHERE poll_id = $1 AND option_id IS NOT NULL AND rank_value IS NOT NULL
         GROUP BY option_id, rank_value`,
        [pollId]
      );

      const optionsRes = await db.query(
        'SELECT id, option_text FROM poll_options WHERE poll_id = $1',
        [pollId]
      );

      const n = optionsRes.rows.length;
      const scoreMap = {};
      
      // Initialize map
      optionsRes.rows.forEach(opt => {
        scoreMap[opt.id] = { optionText: opt.option_text, score: 0, votesCount: 0 };
      });

      let totalVoters = 0;
      const voterCountRes = await db.query(
        'SELECT COUNT(DISTINCT participant_id) as count FROM votes WHERE poll_id = $1',
        [pollId]
      );
      totalVoters = parseInt(voterCountRes.rows[0].count, 10);

      votesRes.rows.forEach(r => {
        const optId = r.option_id;
        const rank = parseInt(r.rank_value, 10); // 0-indexed: 0 is first, 1 is second
        const count = parseInt(r.count, 10);

        if (scoreMap[optId]) {
          // Weight: N - rank
          const weight = n - rank;
          scoreMap[optId].score += weight * count;
          scoreMap[optId].votesCount += count; // how many times this option was selected anywhere in the ranking
        }
      });

      const optionsList = Object.keys(scoreMap).map(id => ({
        id,
        optionText: scoreMap[id].optionText,
        score: scoreMap[id].score,
        votes: scoreMap[id].votesCount,
      })).sort((a, b) => b.score - a.score);

      return {
        totalVotes: totalVoters,
        options: optionsList,
      };
    }

    case 'survey': {
      // A Survey maps to sub-polls (chained). In the settings we have the child poll IDs.
      // We calculate each child poll's results and return them as a list.
      const subPollsRes = await db.query(
        'SELECT * FROM polls WHERE session_id = $1 AND id != $2 ORDER BY order_index ASC',
        [poll.session_id, pollId]
      );

      // In custom settings we check if this survey has designated poll IDs
      let pollIds = poll.settings?.pollIds || [];
      if (pollIds.length === 0) {
        // Fallback: use all other polls in session
        pollIds = subPollsRes.rows.map(p => p.id);
      }

      const surveyResults = [];
      for (const pId of pollIds) {
        const itemRes = await db.query('SELECT * FROM polls WHERE id = $1', [pId]);
        if (itemRes.rows.length > 0) {
          const item = itemRes.rows[0];
          const itemResults = await calculatePollResults(item);
          surveyResults.push({
            pollId: item.id,
            title: item.title,
            type: item.type,
            results: itemResults,
          });
        }
      }

      return {
        totalVotes: surveyResults[0]?.results?.totalVotes || 0,
        subPolls: surveyResults,
      };
    }

    default:
      return {};
  }
};
