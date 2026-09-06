/// Centralized error handler that converts raw exceptions / server messages
/// into short, friendly strings that participants and hosts can understand.
class AppError {
  AppError._();

  /// Returns a user-friendly message for any caught [error] object.
  ///
  /// Example:
  ///   catch (e) { _showSnackBar(AppError.from(e)); }
  static String from(Object error, {String? context}) {
    final raw = error.toString().toLowerCase();
    return _map(raw, context: context);
  }

  /// Converts a raw server/bloc message string into a friendly message.
  static String fromMessage(String? message, {String? context}) {
    if (message == null || message.isEmpty) {
      return _fallback(context);
    }
    return _map(message.toLowerCase(), context: context);
  }

  static String _map(String raw, {String? context}) {
    // ── Network / connectivity ──────────────────────────────────────────────
    if (raw.contains('socket') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable') ||
        raw.contains('failed host lookup') ||
        raw.contains('errno = 111') ||
        raw.contains('errno = 7')) {
      return 'Unable to reach the server. Please check your connection and try again.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'The request timed out. Please check your connection and try again.';
    }
    if (raw.contains('no internet') || raw.contains('network')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data.';
    }

    // ── Session / room errors ───────────────────────────────────────────────
    if (raw.contains('session not found') ||
        (raw.contains('not found') && context == 'session')) {
      return 'Session not found. Please double-check the code and try again.';
    }
    if (raw.contains('session has ended') ||
        raw.contains('already ended') ||
        raw.contains('expired')) {
      return 'This session has already ended. Ask your host for a new code.';
    }
    if (raw.contains('session is not active') || raw.contains('not active')) {
      return 'This session isn\'t active yet. Please wait for the host to start it.';
    }
    if (raw.contains('access code') || raw.contains('invalid code')) {
      return 'Invalid session code. Please check the code and try again.';
    }

    // ── Auth / permission errors ────────────────────────────────────────────
    if (raw.contains('unauthorized') ||
        raw.contains('401') ||
        raw.contains('not authorized') ||
        raw.contains('unauthenticated')) {
      return 'You\'re not authorized to do this. Please sign in and try again.';
    }
    if (raw.contains('forbidden') || raw.contains('403')) {
      return 'You don\'t have permission to do this.';
    }

    // ── Not found ───────────────────────────────────────────────────────────
    if (raw.contains('404') || raw.contains('not found')) {
      return 'The requested item could not be found.';
    }

    // ── Server errors ───────────────────────────────────────────────────────
    if (raw.contains('500') ||
        raw.contains('internal server error') ||
        raw.contains('server error')) {
      return 'Something went wrong on the server. Please try again in a moment.';
    }
    if (raw.contains('503') || raw.contains('service unavailable')) {
      return 'The server is temporarily unavailable. Please try again shortly.';
    }

    // ── Poll / vote errors ──────────────────────────────────────────────────
    if (raw.contains('voting is locked') || raw.contains('poll is locked')) {
      return 'Voting is closed for this poll.';
    }
    if (raw.contains('already voted')) {
      return 'You\'ve already submitted a response to this poll.';
    }

    // ── Q&A errors ──────────────────────────────────────────────────────────
    if (raw.contains('question') && raw.contains('not found')) {
      return 'This question no longer exists.';
    }
    if (raw.contains('profan')) {
      return 'Your message contains inappropriate content. Please revise and try again.';
    }

    // ── Validation ──────────────────────────────────────────────────────────
    if (raw.contains('required') || raw.contains('missing')) {
      return 'Please fill in all required fields.';
    }
    if (raw.contains('too long') || raw.contains('max length')) {
      return 'Your input is too long. Please shorten it and try again.';
    }

    // ── Context-specific fallbacks ──────────────────────────────────────────
    return _fallback(context);
  }

  static String _fallback(String? context) {
    switch (context) {
      case 'join':
        return 'Unable to join the session. Please try again.';
      case 'create':
        return 'Unable to create the session. Please try again.';
      case 'load':
        return 'Unable to load your data. Pull down to refresh.';
      case 'submit':
        return 'Unable to submit your response. Please try again.';
      case 'poll':
        return 'Unable to update the poll. Please try again.';
      case 'quiz':
        return 'Unable to start the quiz. Please try again.';
      case 'analytics':
        return 'Unable to load analytics. Please try again.';
      case 'export':
        return 'Export failed. Please try again.';
      case 'scan':
        return 'Couldn\'t scan the QR code. Try again or enter the code manually.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ── Common success messages ───────────────────────────────────────────────
  static const String sessionCreated = 'Session created successfully!';
  static const String sessionDeleted = 'Session deleted.';
  static const String sessionUpdated = 'Changes saved.';
  static const String pollCreated = 'Poll created and ready to go!';
  static const String quizCreated = 'Quiz question created!';
  static const String pollEnded = 'Poll ended.';
  static const String pollLocked = 'Poll locked — no more responses accepted.';
  static const String responseSubmitted = 'Response submitted!';
  static const String responseUpdated = 'Response updated!';
  static const String questionSubmitted = 'Your question was sent!';
  static const String answerSent = 'Answer sent to participants.';
  static const String markedAnswered = 'Question marked as answered.';
  static const String settingsSaved = 'Settings saved successfully.';
  static const String exportSuccess = 'Export ready!';
  static const String copied = 'Copied to clipboard!';
}
