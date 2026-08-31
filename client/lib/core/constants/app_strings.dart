/// Centralized text constants for the entire QLix application.
class AppStrings {
  // Brand & App
  static const String appTitle = 'QLix';
  static const String appName = 'QLix';
  static const String appTagline = 'Engage Every Audience Live';
  static const String liveSession = 'QLix Live Session';
  static const String loadingExperiences = 'Loading amazing experiences...';

  // Common Actions
  static const String login = 'Login';
  static const String signUp = 'Sign Up';
  static const String logout = 'Logout';
  static const String submit = 'Submit';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String save = 'Save';
  static const String create = 'Create';
  static const String next = 'Next';
  static const String getStarted = 'Get Started';
  static const String skip = 'Skip';
  static const String close = 'Close';
  static const String copy = 'Copy';
  static const String copied = 'Copied';
  static const String share = 'Share';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String retry = 'Retry';
  static const String or = 'OR';
  static const String live = 'LIVE';
  static const String anonymous = 'Anonymous';
  static const String guest = 'Guest';

  // Onboarding
  static const String onboardingSlide1Title = 'Create Live Polls';
  static const String onboardingSlide1Desc =
      'Ask questions, run polls and get instant feedback from your audience.';
  static const String onboardingSlide2Title = 'Manage Q&A';
  static const String onboardingSlide2Desc =
      'Let your audience ask questions and upvote the ones that matter most.';
  static const String onboardingSlide3Title = 'Run Interactive Quizzes';
  static const String onboardingSlide3Desc =
      'Gamify your sessions with live timers, instant scoring and leaderboards.';

  // Authentication
  static const String welcomeBack = 'Welcome Back!';
  static const String welcomeSubtitle = 'Login to join live sessions.';
  static const String createAccount = 'Create Account';
  static const String createAccountSubtitle =
      'Create an account to host and join live sessions.';
  static const String emailHint = 'Email address';
  static const String passwordHint = 'Password';
  static const String fullNameHint = 'Full Name';
  static const String rememberMe = 'Remember me';
  static const String forgotPassword = 'Forgot password?';
  static const String forgotPasswordDev =
      'Password reset functionality is under development.';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String validEmailError = 'Enter a valid email';
  static const String passwordLengthError =
      'Password must be at least 6 characters';
  static const String nameRequiredError = 'Please enter your name';

  // Host Dashboard & Navigation
  static const String hostDashboard = 'Host Dashboard';
  static const String mySessions = 'My Sessions';
  static const String liveControl = 'Live Control Panel';
  static const String createSession = 'Create Session';
  static const String createNewSession = 'Create New Session';
  static const String settings = 'Settings';
  static const String presenterMode = 'Presenter Mode';
  static const String analytics = 'Analytics';
  static const String serverSettings = 'Server Settings';
  static const String sessionCreatedSuccess = 'Session created successfully';
  static const String sessionUpdatedSuccess = 'Session updated successfully';
  static const String sessionDeletedSuccess = 'Session deleted successfully';
  static const String noSessionsFound = 'No sessions found';
  static const String createFirstSession =
      'Create your first interactive session to engage your audience.';
  static const String sessionTitleLabel = 'Session Title';
  static const String sessionTitleHint = 'Weekly Team Sync, All Hands';
  static const String sessionDescLabel = 'Description';
  static const String sessionDescHint = 'Brief overview of the session agenda';
  static const String qaModerationLabel = 'Enable Q&A Moderation';
  static const String qaModerationSubtitle =
      'Questions require host approval before being visible to everyone';

  // Session State Labels
  static const String stateDraft = 'Draft';
  static const String stateActive = 'Active';
  static const String stateEnded = 'Ended';

  // Join Session (Participant)
  static const String joinTitle = 'Join Session';
  static const String joinSubTitle =
      'Enter a room code to ask questions and vote';
  static const String accessCodeLabel = '6 Digit Access Code';
  static const String codeError = 'Enter 6 digit code';
  static const String enterSessionCodeHint = 'Enter 6 digit Code';
  static const String guestNameLabel = 'Your Name';
  static const String guestNameHint = 'Enter your name';
  static const String postAnonymously = 'Post Anonymously';
  static const String scanQrTitle = 'Scan Invite QR Code';
  static const String scanQrSubtitle =
      'Point your camera at the QR code displayed on screen';
  static const String sessionQrCode = 'Session QR Code';
  static const String scanToJoinInstant = 'Scan to join the session instantly.';
  static const String joinSessionButton = 'Join Session';
  static const String invalidQrCode = 'This is not a QLix Session QR code!';
  static const String noQrInImage = 'No QR code found in selected image';

  // Participant Workspace
  static const String participantTitle = 'Participant Screen';
  static const String livePollsTab = 'Live Polls';
  static const String qaTab = 'Q&A';
  static const String noActivePoll = 'No Active Poll running';
  static const String noActivePollSub =
      'Wait for the host to activate a poll or quiz';
  static const String submitResponse = 'Submit Response';
  static const String responseSubmitted = 'Response submitted successfully!';
  static const String successVoteSubmit = 'Response submitted successfully!';
  static const String alreadyVoted = 'You have already voted on this poll.';
  static const String wordCloudHint = 'Type your response here...';
  static const String rankingGuide =
      'Drag & drop options to rank them in order of priority';

  // Quiz Competition
  static const String quizTitle = 'Quiz Competition';
  static const String answerSubmitted = 'Answer submitted';
  static const String quizWaitResults =
      'Wait for the timer to end to see results';
  static const String leaderboard = 'Leaderboard';
  static const String score = 'Score';
  static const String rank = 'Rank';
  static const String points = 'pts';

  // Q&A List & Submission
  static const String topQuestions = 'Top Questions';
  static const String askQuestionHint = 'Ask your question...';
  static const String successQuestionSubmit = 'Question submitted';
  static const String questionStatusApproved = 'Approved';
  static const String questionStatusPending = 'Pending';
  static const String questionStatusAnswered = 'Answered';
  static const String questionStatusDismissed = 'Dismissed';

  // Analytics Overview
  static const String analyticsOverview = 'Analytics Overview';
  static const String totalSessions = 'Total Sessions';
  static const String totalParticipants = 'Total Participants';
  static const String totalResponses = 'Total Responses';
  static const String totalQuizzes = 'Total Quizzes';
  static const String exportCsv = 'Export CSV';
  static const String exportPdf = 'Export PDF';
  static const String pollStatistics = 'Poll Statistics';
  static const String activityTimeline = 'Activity Timeline';
}
