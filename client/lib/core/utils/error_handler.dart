import 'package:dio/dio.dart';
import '../constants/app_strings.dart';

/// Centralized error handler that converts raw exceptions, DioExceptions, and
/// server messages into clean, friendly strings that users can understand.
class AppError {
  AppError._();

  /// Returns a user-friendly message for any caught [error] object.
  ///
  /// Example:
  ///   catch (e) { _showSnackBar(AppError.from(e, context: 'login')); }
  static String from(Object? error, {String? context}) {
    if (error == null) {
      return _fallback(context);
    }

    // 1. Specialized handling for DioException (Network/HTTP errors)
    if (error is DioException) {
      return _fromDioException(error, context: context);
    }

    // 2. Extract and sanitize string error
    final raw = error.toString();
    return fromMessage(raw, context: context);
  }

  /// Converts a raw server/bloc message string into a friendly message.
  static String fromMessage(String? message, {String? context}) {
    if (message == null || message.trim().isEmpty) {
      return _fallback(context);
    }

    final sanitized = _cleanRawException(message);
    return _map(sanitized, context: context);
  }

  static String _fromDioException(DioException dioError, {String? context}) {
    // Check for network timeout or connectivity failures
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppStrings.errorTimeout;
      case DioExceptionType.connectionError:
        return AppStrings.errorNetwork;
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      default:
        break;
    }

    // Inspect server response body for custom backend messages
    String? serverMessage;
    final responseData = dioError.response?.data;
    if (responseData is Map) {
      serverMessage = responseData['message']?.toString() ??
          responseData['error']?.toString();
    } else if (responseData is String &&
        responseData.isNotEmpty &&
        !responseData.contains('<html') &&
        !responseData.contains('<!DOCTYPE')) {
      serverMessage = responseData;
    }

    final statusCode = dioError.response?.statusCode;
    final path = dioError.requestOptions.path.toLowerCase();

    // If server provided a specific message, check if it's clean and meaningful
    if (serverMessage != null && serverMessage.trim().isNotEmpty) {
      final cleanMsg = _cleanRawException(serverMessage);
      final mapped = _map(cleanMsg, context: context, statusCode: statusCode);
      return mapped;
    }

    // Status-code specific fallback
    if (statusCode != null) {
      if (statusCode == 401) {
        if (context == 'login' || path.contains('/auth/login')) {
          return AppStrings.errorInvalidCredentials;
        }
        if (context == 'signup' || path.contains('/auth/signup')) {
          return 'Registration failed. Please check your details.';
        }
        return AppStrings.errorUnauthorized;
      }
      if (statusCode == 400) {
        if (context == 'signup' || path.contains('/auth/signup')) {
          return AppStrings.errorEmailAlreadyInUse;
        }
        return 'Invalid request. Please check your details and try again.';
      }
      if (statusCode == 403) {
        return AppStrings.errorForbidden;
      }
      if (statusCode == 404) {
        if (context == 'session' || path.contains('/sessions')) {
          return AppStrings.errorSessionNotFound;
        }
        return AppStrings.errorNotFound;
      }
      if (statusCode == 409) {
        return 'A conflicting record already exists.';
      }
      if (statusCode == 422) {
        return 'Please verify that all fields are filled out correctly.';
      }
      if (statusCode == 429) {
        return AppStrings.errorTooManyRequests;
      }
      if (statusCode >= 500) {
        return AppStrings.errorServerError;
      }
    }

    return _fallback(context);
  }

  /// Removes raw exception prefixes, stack traces, and technical metadata.
  static String _cleanRawException(String raw) {
    var cleaned = raw.trim();

    // Strip common Dart/Dio prefixes
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length).trim();
    }
    if (cleaned.startsWith('FormatException: ')) {
      cleaned = cleaned.substring('FormatException: '.length).trim();
    }
    if (cleaned.startsWith('DioException')) {
      final idx = cleaned.indexOf(']:');
      if (idx != -1) {
        cleaned = cleaned.substring(idx + 2).trim();
      }
    }

    return cleaned;
  }

  static String _map(String text, {String? context, int? statusCode}) {
    final raw = text.toLowerCase();

    // ── Check for technical stack traces / code errors ───────────────────────
    // If the error looks like raw code or stack trace, NEVER display it to users
    if (raw.contains('nosuchmethoderror') ||
        raw.contains('null check operator') ||
        raw.contains('type \'null\' is not a subtype') ||
        raw.contains('syntaxerror') ||
        raw.contains('pgerror') ||
        raw.contains('sql') ||
        raw.contains('stack trace') ||
        raw.contains('internal server error')) {
      return (statusCode != null && statusCode >= 500)
          ? AppStrings.errorServerError
          : _fallback(context);
    }

    // ── Network / connectivity ──────────────────────────────────────────────
    if (raw.contains('socket') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable') ||
        raw.contains('failed host lookup') ||
        raw.contains('errno = 111') ||
        raw.contains('errno = 7') ||
        raw.contains('handshake') ||
        raw.contains('clientexception')) {
      return AppStrings.errorNetwork;
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return AppStrings.errorTimeout;
    }
    if (raw.contains('no internet') || raw.contains('network error')) {
      return AppStrings.errorNetwork;
    }

    // ── Auth / credentials errors ───────────────────────────────────────────
    if (raw.contains('incorrect email or password') ||
        raw.contains('invalid credentials') ||
        raw.contains('invalid email or password') ||
        raw.contains('wrong password') ||
        (context == 'login' && (raw.contains('401') || statusCode == 401))) {
      return AppStrings.errorInvalidCredentials;
    }

    if (raw.contains('already registered') ||
        raw.contains('already exists') ||
        raw.contains('email already in use') ||
        (context == 'signup' && (raw.contains('400') || statusCode == 400))) {
      return AppStrings.errorEmailAlreadyInUse;
    }

    if (raw.contains('unauthorized') ||
        raw.contains('unauthenticated') ||
        raw.contains('invalid or expired refresh token') ||
        raw.contains('jwt expired') ||
        raw.contains('invalid token') ||
        statusCode == 401 ||
        raw.contains('401')) {
      return AppStrings.errorUnauthorized;
    }

    if (raw.contains('forbidden') ||
        statusCode == 403 ||
        raw.contains('403') ||
        raw.contains('permission denied')) {
      return AppStrings.errorForbidden;
    }

    // ── Session / room errors ───────────────────────────────────────────────
    if (raw.contains('session not found') ||
        (context == 'session' && (raw.contains('not found') || raw.contains('404')))) {
      return AppStrings.errorSessionNotFound;
    }
    if (raw.contains('session has ended') ||
        raw.contains('already ended') ||
        raw.contains('expired')) {
      return AppStrings.errorSessionEnded;
    }
    if (raw.contains('session is not active') ||
        raw.contains('not active') ||
        raw.contains('hasn\'t started')) {
      return AppStrings.errorSessionNotActive;
    }
    if (raw.contains('access code') ||
        raw.contains('invalid code') ||
        raw.contains('enter 6 digit code')) {
      return AppStrings.errorInvalidCode;
    }

    // ── Not found ───────────────────────────────────────────────────────────
    if (raw.contains('404') || raw.contains('not found')) {
      return AppStrings.errorNotFound;
    }

    // ── Server errors ───────────────────────────────────────────────────────
    if (raw.contains('500') ||
        raw.contains('server error') ||
        (statusCode != null && statusCode >= 500)) {
      return AppStrings.errorServerError;
    }
    if (raw.contains('503') || raw.contains('service unavailable')) {
      return AppStrings.errorServerError;
    }

    // ── Poll / vote errors ──────────────────────────────────────────────────
    if (raw.contains('voting is locked') || raw.contains('poll is locked')) {
      return AppStrings.errorVotingLocked;
    }
    if (raw.contains('already voted')) {
      return AppStrings.errorAlreadyVoted;
    }

    // ── Q&A errors ──────────────────────────────────────────────────────────
    if (raw.contains('question') && raw.contains('not found')) {
      return 'This question no longer exists.';
    }
    if (raw.contains('profan')) {
      return AppStrings.errorProfanity;
    }

    // ── Password / Profile Validation ───────────────────────────────────────
    if (raw.contains('password must be at least 6')) {
      return AppStrings.passwordLengthError;
    }
    if (raw.contains('passwords do not match')) {
      return 'Passwords do not match.';
    }

    // ── Validation ──────────────────────────────────────────────────────────
    if (raw.contains('required') || raw.contains('missing')) {
      return AppStrings.errorValidationRequired;
    }
    if (raw.contains('too long') || raw.contains('max length')) {
      return AppStrings.errorInputTooLong;
    }

    // If the text looks like a clean, user-friendly sentence without tech artifacts,
    // return it cleanly
    if (!raw.contains('{') &&
        !raw.contains('}') &&
        !raw.contains('[') &&
        !raw.contains(']') &&
        !raw.contains('dio') &&
        !raw.contains('exception') &&
        !raw.contains('error:') &&
        text.trim().isNotEmpty &&
        text.length < 120) {
      final trimmed = text.trim();
      return trimmed.endsWith('.') ? trimmed : '$trimmed.';
    }

    // ── Context-specific fallbacks ──────────────────────────────────────────
    return _fallback(context);
  }

  static String _fallback(String? context) {
    switch (context) {
      case 'login':
        return AppStrings.errorInvalidCredentials;
      case 'signup':
        return 'Unable to create your account. Please try again.';
      case 'join':
        return 'Unable to join the session. Please check the code.';
      case 'create':
        return 'Unable to create the session. Please try again.';
      case 'load':
        return 'Unable to load data. Please refresh and try again.';
      case 'submit':
        return 'Unable to submit your response. Please try again.';
      case 'poll':
        return 'Unable to update the poll. Please try again.';
      case 'quiz':
        return 'Unable to start the quiz. Please try again.';
      case 'profile':
      case 'profile_update':
        return 'Unable to update profile. Please try again.';
      case 'password':
        return 'Unable to change password. Please try again.';
      case 'analytics':
        return 'Unable to load analytics. Please try again.';
      case 'export':
        return 'Export failed. Please try again.';
      case 'scan':
        return 'Couldn\'t scan the QR code. Try again or enter the code manually.';
      default:
        return AppStrings.errorDefault;
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
