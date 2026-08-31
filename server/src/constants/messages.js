/**
 * Centralized server text messages (errors, success messages, validation responses).
 */

export const ERROR_MESSAGES = {
  // Auth
  INVALID_CREDENTIALS: 'Email or password is invalid.',
  EMAIL_ALREADY_EXISTS: 'An account with this email address already exists.',
  UNAUTHORIZED: 'You are not logged in. Please log in to get access.',
  INVALID_TOKEN: 'Invalid authentication token. Please log in again.',
  TOKEN_EXPIRED: 'Your token has expired. Please log in again.',
  FORBIDDEN: 'You do not have permission to perform this action.',

  // Sessions
  SESSION_NOT_FOUND: 'Session not found.',
  SESSION_EXPIRED: 'This session has ended or is inactive.',
  INVALID_ACCESS_CODE: 'Invalid session access code.',
  SESSION_ALREADY_EXISTS: 'A session with this code already exists.',
  FAILED_CREATE_SESSION: 'Failed to create session.',
  FAILED_UPDATE_SESSION: 'Failed to update session.',
  FAILED_DELETE_SESSION: 'Failed to delete session.',

  // Polls
  POLL_NOT_FOUND: 'Poll not found.',
  INVALID_POLL_TYPE: 'Invalid poll type specified.',
  VOTE_ALREADY_SUBMITTED: 'You have already voted on this poll.',
  POLL_INACTIVE: 'This poll is not currently accepting responses.',
  FAILED_CREATE_POLL: 'Failed to create poll.',

  // Q&A
  QUESTION_NOT_FOUND: 'Question not found.',
  PROFANITY_DETECTED: 'Your question contains inappropriate language.',
  FAILED_CREATE_QUESTION: 'Failed to submit question.',

  // Quiz
  QUIZ_TIME_EXPIRED: 'Time has expired for this question.',
  QUIZ_ALREADY_ANSWERED: 'You have already answered this quiz question.',
  FAILED_SUBMIT_QUIZ: 'Failed to submit quiz answer.',

  // General
  INTERNAL_SERVER_ERROR: 'Something went wrong on the server.',
  ROUTE_NOT_FOUND: 'The requested route does not exist.',
};

export const SUCCESS_MESSAGES = {
  // Auth
  LOGIN_SUCCESS: 'Successfully logged in.',
  SIGNUP_SUCCESS: 'Account created successfully.',
  LOGOUT_SUCCESS: 'Successfully logged out.',

  // Sessions
  SESSION_CREATED: 'Session created successfully.',
  SESSION_UPDATED: 'Session updated successfully.',
  SESSION_DELETED: 'Session deleted successfully.',
  SESSION_JOINED: 'Joined session successfully.',

  // Polls
  POLL_CREATED: 'Poll created successfully.',
  POLL_UPDATED: 'Poll updated successfully.',
  POLL_DELETED: 'Poll deleted successfully.',
  VOTE_RECORDED: 'Vote recorded successfully.',

  // Q&A
  QUESTION_SUBMITTED: 'Question submitted successfully.',
  QUESTION_STATUS_UPDATED: 'Question status updated successfully.',
  UPVOTE_TOGGLED: 'Upvote toggled successfully.',

  // Quiz
  QUIZ_ACTIVATED: 'Quiz question activated.',
  QUIZ_SUBMITTED: 'Quiz answer submitted successfully.',
  QUIZ_RESET: 'Quiz reset successfully.',
};
