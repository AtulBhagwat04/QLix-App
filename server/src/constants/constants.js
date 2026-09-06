/**
 * Server-wide system constants, states, and event names.
 */

export const SESSION_STATES = {
  DRAFT: 'draft',
  ACTIVE: 'active',
  ENDED: 'ended',
};

export const POLL_TYPES = {
  MULTIPLE_CHOICE: 'multiple_choice',
  WORD_CLOUD: 'word_cloud',
  RATING: 'rating',
  OPEN_TEXT: 'open_text',
  RANKING: 'ranking',
  SURVEY: 'survey',
};

export const QA_STATUS = {
  PENDING: 'pending',
  APPROVED: 'approved',
  ANSWERED: 'answered',
  DISMISSED: 'dismissed',
};

export const PARTICIPANT_ROLES = {
  HOST: 'host',
  PARTICIPANT: 'participant',
  PRESENTER: 'presenter',
};

export const SOCKET_EVENTS = {
  // Connection / Room
  JOIN_SESSION: 'join_session',
  PARTICIPANT_JOINED_ACK: 'participant_joined_ack',
  PARTICIPANT_JOINED: 'participant_joined',
  USER_DISCONNECTED: 'user_disconnected',

  // Session
  SESSION_STATE_CHANGED: 'session_state_changed',
  ANNOUNCEMENT_BROADCAST: 'announcement_broadcast',

  // Polls
  POLL_ACTIVATED: 'poll_activated',
  VOTE_CAST: 'vote_cast',
  VOTES_UPDATED: 'votes_updated',

  // Q&A
  QUESTION_SUBMITTED: 'question_submitted',
  QUESTION_CREATED: 'question_created',
  QUESTION_UPVOTED: 'question_upvoted',
  QUESTION_STATUS_CHANGED: 'question_status_changed',

  // Quiz
  QUIZ_QUESTION_ACTIVATED: 'quiz_question_activated',
  QUIZ_ANSWER_SUBMITTED: 'quiz_answer_submitted',
  QUIZ_COUNTDOWN_TICK: 'quiz_countdown_tick',
  LEADERBOARD_UPDATED: 'leaderboard_updated',

  // Reactions & Errors
  LIVE_REACTION: 'live_reaction',
  ERROR: 'error',
};
