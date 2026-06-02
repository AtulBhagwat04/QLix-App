import db from '../config/db.js';
import { AppError } from '../middlewares/errorHandler.js';

export const getSessionAnalytics = async (req, res, next) => {
  const { sessionId } = req.params;

  try {
    // 1. Total Participant Count
    const partCountRes = await db.query(
      'SELECT COUNT(*) FROM participants WHERE session_id = $1',
      [sessionId]
    );
    const totalParticipants = parseInt(partCountRes.rows[0].count, 10);

    // 2. Total Votes Count
    const voteCountRes = await db.query(
      `SELECT COUNT(v.id) 
       FROM votes v
       JOIN polls p ON v.poll_id = p.id
       WHERE p.session_id = $1`,
      [sessionId]
    );
    const totalVotes = parseInt(voteCountRes.rows[0].count, 10);

    // 3. Total Q&A Questions Count
    const qaCountRes = await db.query(
      'SELECT COUNT(*) FROM questions WHERE session_id = $1',
      [sessionId]
    );
    const totalQuestions = parseInt(qaCountRes.rows[0].count, 10);

    // 4. Poll by Poll Stats
    const pollsStatsRes = await db.query(
      `SELECT p.id, p.title, p.type, p.status, COUNT(v.id) as votes_count
       FROM polls p
       LEFT JOIN votes v ON p.id = v.poll_id
       WHERE p.session_id = $1
       GROUP BY p.id, p.title, p.type, p.status
       ORDER BY p.order_index ASC`,
      [sessionId]
    );

    const pollStats = pollsStatsRes.rows.map(row => ({
      id: row.id,
      title: row.title,
      type: row.type,
      status: row.status,
      votesCount: parseInt(row.votes_count, 10),
    }));

    // 5. Daily/Timeline activity (joined participants hourly or daily)
    const timelineRes = await db.query(
      `SELECT DATE_TRUNC('hour', joined_at) as hour, COUNT(*) as count
       FROM participants
       WHERE session_id = $1
       GROUP BY hour
       ORDER BY hour ASC`,
      [sessionId]
    );

    const activityTimeline = timelineRes.rows.map(row => ({
      time: row.hour,
      count: parseInt(row.count, 10),
    }));

    res.status(200).json({
      status: 'success',
      data: {
        sessionId,
        metrics: {
          totalParticipants,
          totalVotes,
          totalQuestions,
          averageEngagement: totalParticipants > 0 ? parseFloat(((totalVotes + totalQuestions) / totalParticipants).toFixed(2)) : 0,
        },
        pollStats,
        activityTimeline,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Generates CSV format of all questions asked in a session
export const exportQuestionsCSV = async (req, res, next) => {
  const { sessionId } = req.params;

  try {
    const result = await db.query(
      `SELECT q.id, q.text, q.status, q.upvotes_count, q.is_pinned, q.is_anonymous, p.name as author, q.created_at
       FROM questions q
       JOIN participants p ON q.participant_id = p.id
       WHERE q.session_id = $1
       ORDER BY q.created_at ASC`,
      [sessionId]
    );

    let csvContent = 'Question ID,Question Text,Status,Upvotes,Is Pinned,Is Anonymous,Author,Created At\n';
    result.rows.forEach(row => {
      const escapedText = `"${row.text.replace(/"/g, '""')}"`;
      const author = row.is_anonymous ? 'Anonymous' : `"${row.author.replace(/"/g, '""')}"`;
      csvContent += `${row.id},${escapedText},${row.status},${row.upvotes_count},${row.is_pinned},${row.is_anonymous},${author},${row.created_at.toISOString()}\n`;
    });

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="session-${sessionId}-questions.csv"`);
    res.status(200).send(csvContent);
  } catch (error) {
    next(error);
  }
};

// Generates CSV of votes cast
export const exportVotesCSV = async (req, res, next) => {
  const { sessionId } = req.params;

  try {
    const result = await db.query(
      `SELECT v.id, p.title as poll_title, p.type as poll_type, opt.option_text, v.rating_value, v.text_response, v.rank_value, v.created_at
       FROM votes v
       JOIN polls p ON v.poll_id = p.id
       LEFT JOIN poll_options opt ON v.option_id = opt.id
       WHERE p.session_id = $1
       ORDER BY v.created_at ASC`,
      [sessionId]
    );

    let csvContent = 'Vote ID,Poll Title,Poll Type,Selected Option,Rating Value,Text Response,Rank Value,Created At\n';
    result.rows.forEach(row => {
      const pollTitle = `"${row.poll_title.replace(/"/g, '""')}"`;
      const optionText = row.option_text ? `"${row.option_text.replace(/"/g, '""')}"` : '';
      const textResponse = row.text_response ? `"${row.text_response.replace(/"/g, '""')}"` : '';
      csvContent += `${row.id},${pollTitle},${row.poll_type},${optionText},${row.rating_value ?? ''},${textResponse},${row.rank_value ?? ''},${row.created_at.toISOString()}\n`;
    });

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="session-${sessionId}-votes.csv"`);
    res.status(200).send(csvContent);
  } catch (error) {
    next(error);
  }
};
