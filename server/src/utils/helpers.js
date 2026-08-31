/**
 * Reusable utility helpers for database conversions and safe parsing.
 */

/**
 * Safely parse a SQL COUNT(*) / count column from any SQL dialect (PostgreSQL / SQLite).
 * @param {object} row - The database row containing a count.
 * @param {string} [defaultKey='count'] - Optional default key name.
 * @returns {number} The integer count, defaulting to 0.
 */
export const parseCount = (row, defaultKey = 'count') => {
  if (!row) return 0;
  const val = row[defaultKey] ?? row['COUNT(*)'] ?? row['count(*)'] ?? 0;
  return parseInt(val, 10) || 0;
};

/**
 * Safely parse JSON strings or return fallback / original object.
 * @param {any} val - The value to parse.
 * @param {any} [fallback=null] - Fallback if parsing fails.
 * @returns {any} Parsed value or fallback.
 */
export const safeJsonParse = (val, fallback = null) => {
  if (val === null || val === undefined) return fallback;
  if (typeof val === 'object') return val;
  if (typeof val === 'string') {
    try {
      return JSON.parse(val);
    } catch {
      return fallback !== null ? fallback : val;
    }
  }
  return fallback;
};

/**
 * Format a poll option database row into a standardized response object.
 * @param {object} opt - The database row.
 * @returns {object} Standardized option object.
 */
export const formatPollOption = (opt) => {
  if (!opt) return null;
  return {
    id: opt.id,
    pollId: opt.poll_id || opt.pollId,
    optionText: opt.option_text || opt.optionText,
    option_text: opt.option_text || opt.optionText,
    isCorrect: Boolean(opt.is_correct ?? opt.isCorrect),
    orderIndex: opt.order_index ?? opt.orderIndex ?? 0,
  };
};

/**
 * Format a Q&A question row into a standardized camelCase object.
 * @param {object} row - The database question row.
 * @returns {object} Standardized question object.
 */
export const formatQuestion = (row) => {
  if (!row) return null;
  return {
    id: row.id,
    sessionId: row.session_id || row.sessionId,
    participantId: row.participant_id || row.participantId,
    participantName: row.participant_name || row.participantName,
    questionText: row.question_text || row.questionText,
    upvotesCount: parseInt(row.upvotes_count ?? row.upvotesCount ?? 0, 10),
    status: row.status || 'pending',
    isPinned: Boolean(row.is_pinned ?? row.isPinned),
    createdAt: row.created_at || row.createdAt,
  };
};
