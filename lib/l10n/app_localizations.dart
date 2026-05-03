import 'package:flutter/material.dart';

/// Hand-written localizations for Regulit.
/// Supports: English (en), Hebrew (he · RTL), Spanish (es), French (fr), Russian (ru).
///
/// Usage:
///   final l10n = AppLocalizations.of(context);
///   Text(l10n.signIn)
///
/// Add new strings:
///   1. Add a getter below.
///   2. Add the key to every language map in [_strings].
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  /// Retrieve the nearest [AppLocalizations] from the widget tree.
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// Convenience: try to get localizations, return null if not yet available.
  static AppLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const delegate = _AppLocalizationsDelegate();

  /// Whether [locale] uses right-to-left layout.
  static bool isRtl(Locale locale) => locale.languageCode == 'he';

  bool get rtl => isRtl(locale);

  // ── Internal lookup ──────────────────────────────────────────────────────
  String _t(String key) =>
      _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;

  // ── Common ───────────────────────────────────────────────────────────────
  String get appName         => _t('appName');
  String get cancel          => _t('cancel');
  String get save            => _t('save');
  String get close           => _t('close');
  String get retry           => _t('retry');
  String get loading         => _t('loading');
  String get error           => _t('error');
  String get required        => _t('required');
  String get signOut         => _t('signOut');
  String get settings        => _t('settings');
  String get noResults       => _t('noResults');
  String get search          => _t('search');
  String get add             => _t('add');

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get emailAddress       => _t('emailAddress');
  String get emailPlaceholder   => _t('emailPlaceholder');
  String get password           => _t('password');
  String get signIn             => _t('signIn');
  String get forgotPassword     => _t('forgotPassword');
  String get enterValidEmail    => _t('enterValidEmail');
  String get atLeast8Chars      => _t('atLeast8Chars');
  String get orContinueWith     => _t('orContinueWith');
  String get microsoftSso       => _t('microsoftSso');
  String get resetPassword      => _t('resetPassword');
  String get enterEmailForReset => _t('enterEmailForReset');
  String get resetLinkSent      => _t('resetLinkSent');
  String get sendLink           => _t('sendLink');
  String get loginTagline       => _t('loginTagline');
  String get loginFooter        => _t('loginFooter');
  String get demoLabel          => _t('demoLabel');

  // ── Navigation labels ─────────────────────────────────────────────────────
  String get navUsers         => _t('navUsers');
  String get navCustomers     => _t('navCustomers');
  String get navDashboard     => _t('navDashboard');
  String get navAdminDash     => _t('navAdminDash');
  String get navClients       => _t('navClients');
  String get navEvidenceQueue => _t('navEvidenceQueue');
  String get navAlerts        => _t('navAlerts');
  String get navReports       => _t('navReports');
  String get navMyTasks       => _t('navMyTasks');
  String get navKanban        => _t('navKanban');
  String get navDocuments     => _t('navDocuments');
  String get navAuditPack     => _t('navAuditPack');
  String get navAiAssistant   => _t('navAiAssistant');
  String get navQuizzes       => _t('navQuizzes');
  String get navWorkflows     => _t('navWorkflows');
  String get navAgents        => _t('navAgents');
  String get navSessionFiles  => _t('navSessionFiles');

  // ── Agents screen ─────────────────────────────────────────────────────────
  String get agentsSubtitle  => _t('agentsSubtitle');
  String get addAgent        => _t('addAgent');
  String get editAgent       => _t('editAgent');
  String get noAgentsFound   => _t('noAgentsFound');
  String get showInactive    => _t('showInactive');
  String get agentName       => _t('agentName');
  String get agentType       => _t('agentType');
  String get agentSchedule   => _t('agentSchedule');
  String get agentPrompt     => _t('agentPrompt');
  String get agentBehavior   => _t('agentBehavior');
  String get agentTriggered  => _t('agentTriggered');
  String get agentDefault    => _t('agentDefault');
  String get agentIsDefault  => _t('agentIsDefault');
  String get inactive        => _t('inactive');
  String get active          => _t('active');
  String get deactivate      => _t('deactivate');
  String get edit            => _t('edit');
  String get description     => _t('description');
  String get llmConfig       => _t('llmConfig');
  String get llmProvider     => _t('llmProvider');
  String get llmModel        => _t('llmModel');
  String get llmApiKey       => _t('llmApiKey');
  String get llmMaxTokens    => _t('llmMaxTokens');
  String get llmTemperature  => _t('llmTemperature');
  String get llmAgentUrl     => _t('llmAgentUrl');
  String get duplicate        => _t('duplicate');
  String get agentDuplicated  => _t('agentDuplicated');
  String get jsonOutputSchema => _t('jsonOutputSchema');
  String get addEvidence      => _t('addEvidence');

  // ── Workspace / Customer select ───────────────────────────────────────────
  String get selectWorkspace      => _t('selectWorkspace');
  String get failedLoadWorkspaces => _t('failedLoadWorkspaces');
  String get noWorkspacesFound    => _t('noWorkspacesFound');
  String get notLinkedToCustomer  => _t('notLinkedToCustomer');
  String get switchWorkspace      => _t('switchWorkspace');

  /// Greeting with user name interpolated.
  String hiChooseWorkspace(String name) =>
      _t('hiChooseWorkspace').replaceFirst('{name}', name);

  // ── Customer users panel ──────────────────────────────────────────────────
  String get linkedUsers     => _t('linkedUsers');
  String get noUsersLinked   => _t('noUsersLinked');
  String get linkFirstUser   => _t('linkFirstUser');
  String get linkAUser       => _t('linkAUser');
  String get searchUser      => _t('searchUser');
  String get typeNameOrEmail => _t('typeNameOrEmail');
  String get roleLabel       => _t('roleLabel');
  String get notesLabel      => _t('notesLabel');
  String get link            => _t('link');
  String get unlink          => _t('unlink');

  // ── Role display names ────────────────────────────────────────────────────
  String get roleClientAdmin  => _t('roleClientAdmin');
  String get roleItExecutor   => _t('roleItExecutor');
  String get roleEmployee     => _t('roleEmployee');
  String get roleReguLitAdmin => _t('roleReguLitAdmin');
  String get roleCsm          => _t('roleCsm');
  String get roleAnalyst      => _t('roleAnalyst');

  // ── Audit Pack ────────────────────────────────────────────────────────────
  String get auditPackTitle        => _t('auditPackTitle');
  String get auditPackSubtitle     => _t('auditPackSubtitle');
  String get auditYourOrganisation => _t('auditYourOrganisation');
  String get statAssigned          => _t('statAssigned');
  String get statInProgress        => _t('statInProgress');
  String get statActive            => _t('statActive');
  String get statusActive          => _t('statusActive');
  String get statusInactive        => _t('statusInactive');
  String get timeJustNow           => _t('timeJustNow');
  String timeMinutesAgo(int n)     => _t('timeMinutesAgo').replaceFirst('{n}', '$n');
  String timeHoursAgo(int n)       => _t('timeHoursAgo').replaceFirst('{n}', '$n');
  String timeDaysAgo(int n)        => _t('timeDaysAgo').replaceFirst('{n}', '$n');
  String timeMonthsAgo(int n)      => _t('timeMonthsAgo').replaceFirst('{n}', '$n');
  String timeYearsAgo(int n)       => _t('timeYearsAgo').replaceFirst('{n}', '$n');
  String get auditLastSession      => _t('auditLastSession');
  String auditAnswerCount(int n)   =>
      n == 1 ? _t('auditAnswerSingular') : _t('auditAnswerPlural').replaceFirst('{n}', '$n');
  String get workflowInactive      => _t('workflowInactive');
  String get actionStarting        => _t('actionStarting');
  String get actionStartFill       => _t('actionStartFill');
  String get actionNewFill         => _t('actionNewFill');
  String get actionEditLast        => _t('actionEditLast');
  String get noWorkspaceSelected   => _t('noWorkspaceSelected');
  String get selectWorkspaceFirst  => _t('selectWorkspaceFirst');
  String get noWorkflowsAssigned   => _t('noWorkflowsAssigned');
  String get workflowsAssignedBy   => _t('workflowsAssignedBy');
  String get loadingWorkflows      => _t('loadingWorkflows');
  String get tryAgain              => _t('tryAgain');
  String get back                  => _t('back');
  String get next                  => _t('next');
  String get finish                => _t('finish');
  String get yes                   => _t('yes');
  String get no                    => _t('no');
  String get pressY                => _t('pressY');
  String get pressN                => _t('pressN');
  String get selectAllThatApply    => _t('selectAllThatApply');
  String get allDone               => _t('allDone');
  String get goToDashboard         => _t('goToDashboard');
  String youCompleted(String name) => _t('youCompleted').replaceFirst('{name}', name);
  String questionsAnsweredPct(int pct) => _t('questionsAnsweredPct').replaceFirst('{pct}', '$pct');
  String viewAnswers(int n)            => _t('viewAnswers').replaceFirst('{n}', '$n');
  String get setActive                 => _t('setActive');
  String get view                      => _t('view');

  // ── Task Board ────────────────────────────────────────────────────────────
  String get taskToDo          => _t('taskToDo');
  String get taskInProgress    => _t('taskInProgress');
  String get taskPendingReview => _t('taskPendingReview');
  String get taskDone          => _t('taskDone');
  String get taskOverdue       => _t('taskOverdue');
  String get taskAssigned      => _t('taskAssigned');
  String get taskCompleted     => _t('taskCompleted');
  String get taskFilterAll     => _t('taskFilterAll');
  String get taskNoItems       => _t('taskNoItems');
  String get taskDueLabel      => _t('taskDueLabel');
  String get taskRequired      => _t('taskRequired');
  String overdueWarning(int n) => _t('overdueWarning').replaceFirst('{n}', '$n');
  String get createTask        => _t('createTask');
  String get taskNameLabel     => _t('taskNameLabel');
  String get whatToDoLabel     => _t('whatToDoLabel');
  String get taskRiskLabel     => _t('taskRiskLabel');
  String get dueDateLabel      => _t('dueDateLabel');
  String get isRequiredLabel   => _t('isRequiredLabel');
  String get taskStatusLabel   => _t('taskStatusLabel');
  String get noDueDate          => _t('noDueDate');
  String get assignToLabel      => _t('assignToLabel');
  String get unassigned         => _t('unassigned');
  String get estimatedFineLabel => _t('estimatedFineLabel');
  String get editTask           => _t('editTask');
  String get taskDetails        => _t('taskDetails');
  String get myTasks            => _t('myTasks');
  String get otherTasks         => _t('otherTasks');

  // ── Client-admin user management ─────────────────────────────────────────
  String get addUser        => _t('addUser');
  String get newUser        => _t('newUser');
  String get existingUser   => _t('existingUser');
  String get firstName      => _t('firstName');
  String get lastName       => _t('lastName');
  String get createAndLink  => _t('createAndLink');

  // ── Task list screen ──────────────────────────────────────────────────────
  String get allTasks               => _t('allTasks');
  String get noCustomerSelected     => _t('noCustomerSelected');
  String get selectSessionAbove     => _t('selectSessionAbove');
  String get failedToLoadSessions   => _t('failedToLoadSessions');
  String get noActiveSessions       => _t('noActiveSessions');
  String get sessionLabel           => _t('sessionLabel');
  String get searchTasksHint        => _t('searchTasksHint');
  String get switchToKanban         => _t('switchToKanban');
  String noTasksMatch(String q)     => _t('noTasksMatch').replaceFirst('{q}', q);
  String get noTasksForSession      => _t('noTasksForSession');

  // ── Workflow answer screen ────────────────────────────────────────────────
  String get fillingWorkflow        => _t('fillingWorkflow');
  String get aiAnalyzingDocument    => _t('aiAnalyzingDocument');
  String get noDescriptionAvailable => _t('noDescriptionAvailable');
  String get aiGeneratedDescription => _t('aiGeneratedDescription');
  String get loadingQuestions       => _t('loadingQuestions');

  // ── Executive dashboard ───────────────────────────────────────────────────
  String get complianceDashboard         => _t('complianceDashboard');
  String get analyzeAgain                => _t('analyzeAgain');
  String get noCustomerContextSelected   => _t('noCustomerContextSelected');
  String get noActiveAssessmentSessions  => _t('noActiveAssessmentSessions');
  String get assessmentLabel             => _t('assessmentLabel');
  String get riskExposureTrend           => _t('riskExposureTrend');
  String get monthly                     => _t('monthly');
  String get weekly                      => _t('weekly');
  String get reviewNow                   => _t('reviewNow');
  String get seeAll                      => _t('seeAll');
  String get noOpenRisks                 => _t('noOpenRisks');
  String get selectSession               => _t('selectSession');
  // metric cards
  String get totalExposure              => _t('totalExposure');
  String get complianceScore            => _t('complianceScore');
  String get openTasksLabel             => _t('openTasksLabel');
  String get tasksClosedLabel           => _t('tasksClosedLabel');
  String get runAnalysisToPopulate      => _t('runAnalysisToPopulate');
  String get requireAttention           => _t('requireAttention');
  String get allClear                   => _t('allClear');
  String ofNTotal(int n)                => _t('ofNTotal').replaceFirst('{n}', '$n');
  // action banner
  String get actionRequired             => _t('actionRequired');
  String tasksNeedApproval(int n)       => _t('tasksNeedApproval').replaceFirst('{n}', '$n');
  // charts / cards
  String get riskByCategory             => _t('riskByCategory');
  String get topOpenRisks               => _t('topOpenRisks');
  String get failedToLoadTrend          => _t('failedToLoadTrend');
  String get noEvaluationData           => _t('noEvaluationData');
  String get failedToLoadDashboard      => _t('failedToLoadDashboard');
  String nTasks(int n)                  => _t('nTasks').replaceFirst('{n}', '$n');
  // task status labels
  String get statusToDo                 => _t('statusToDo');
  String get statusInProgress           => _t('statusInProgress');
  String get statusPendingReview        => _t('statusPendingReview');
  String get statusApproved             => _t('statusApproved');
  String get statusOverdue              => _t('statusOverdue');
  // analysis snackbars
  String analysisCompleteNew(int n)     => _t('analysisCompleteNew').replaceFirst('{n}', '$n');
  String get analysisCompleteNoGaps     => _t('analysisCompleteNoGaps');
  String get analysisFailed             => _t('analysisFailed');

  // ── Session files screen ──────────────────────────────────────────────────
  String get sessionFilesTitle  => _t('sessionFilesTitle');
  String get noFilesUploaded    => _t('noFilesUploaded');
  String get failedToLoadFiles  => _t('failedToLoadFiles');
  String get sourceTask         => _t('sourceTask');
  String get sourceAnswer       => _t('sourceAnswer');
  String get viewText           => _t('viewText');
  String get downloadFile       => _t('downloadFile');
  String get downloadAll        => _t('downloadAll');
  String nFiles(int n)          => _t('nFiles').replaceFirst('{n}', '$n');
  String get noTextAvailable    => _t('noTextAvailable');

  // ── Language names (always shown in native script) ────────────────────────
  String get langEnglish => 'English';
  String get langHebrew  => 'עברית';
  String get langSpanish => 'Español';
  String get langFrench  => 'Français';
  String get langRussian => 'Русский';

  // ══════════════════════════════════════════════════════════════════════════
  // Translation maps — add new keys to EVERY language
  // ══════════════════════════════════════════════════════════════════════════
  static const _strings = <String, Map<String, String>>{
    // ── English ─────────────────────────────────────────────────────────────
    'en': {
      'appName': 'Regulit',
      'cancel': 'Cancel',
      'save': 'Save',
      'close': 'Close',
      'retry': 'Retry',
      'loading': 'Loading…',
      'error': 'Error',
      'required': 'Required',
      'signOut': 'Sign out',
      'settings': 'Settings',
      'noResults': 'No results',
      'search': 'Search',
      'add': 'Add',
      // Auth
      'emailAddress': 'Email address',
      'emailPlaceholder': 'david@company.co.il',
      'password': 'Password',
      'signIn': 'Sign in',
      'forgotPassword': 'Forgot password?',
      'enterValidEmail': 'Enter a valid email',
      'atLeast8Chars': 'At least 8 characters',
      'orContinueWith': 'or continue with',
      'microsoftSso': 'Microsoft SSO',
      'resetPassword': 'Reset password',
      'enterEmailForReset': 'Enter your email to receive a reset link.',
      'resetLinkSent': 'If this email exists, a reset link has been sent.',
      'sendLink': 'Send link',
      'loginTagline': 'Compliance that protects. Clarity that moves.',
      'loginFooter': 'Regulit · Privacy compliant by design\nData stored in Israel / EU',
      'demoLabel': 'Demo — no backend needed',
      // Nav
      'navUsers': 'Users',
      'navCustomers': 'Customers',
      'navDashboard': 'Dashboard',
      'navAdminDash': 'Dashboard',
      'navClients': 'Clients',
      'navEvidenceQueue': 'Evidence Queue',
      'navAlerts': 'Alerts',
      'navReports': 'Reports',
      'navMyTasks': 'My Tasks',
      'navKanban': 'Kanban Board',
      'navDocuments': 'Documents',
      'navAuditPack': 'Audit Pack',
      'navAiAssistant': 'AI Assistant',
      'navQuizzes': 'Quizzes',
      'navWorkflows': 'Workflows',
      'navAgents': 'AI Agents',
      'navSessionFiles': 'Evidence Files',
      // Agents
      'agentsSubtitle': 'Manage the AI agents that automate compliance tasks.',
      'addAgent': 'Add Agent',
      'editAgent': 'Edit Agent',
      'noAgentsFound': 'No agents found',
      'showInactive': 'Show Inactive',
      'agentName': 'Agent Name',
      'agentType': 'Agent Type',
      'agentSchedule': 'Schedule (cron)',
      'agentPrompt': 'LLM Prompt',
      'agentBehavior': 'Behavior & Schedule',
      'agentTriggered': 'Triggered',
      'agentDefault': 'Default',
      'agentIsDefault': 'Is Default Agent',
      'inactive': 'Inactive',
      'active': 'Active',
      'deactivate': 'Deactivate',
      'edit': 'Edit',
      'description': 'Description',
      'llmConfig': 'LLM Configuration',
      'llmProvider': 'LLM Provider',
      'llmModel': 'LLM Model',
      'llmApiKey': 'API Key',
      'llmMaxTokens': 'Max Tokens',
      'llmTemperature': 'Temperature',
      'llmAgentUrl': 'Agent URL',
      'duplicate': 'Duplicate',
      'agentDuplicated': 'Agent duplicated successfully',
      'jsonOutputSchema': 'Expected JSON Output Schema',
      'addEvidence': 'Add Evidence',
      // Workspace
      'selectWorkspace': 'Select workspace',
      'failedLoadWorkspaces': 'Failed to load workspaces',
      'noWorkspacesFound': 'No workspaces found',
      'notLinkedToCustomer': 'You are not linked to any customer yet.\nContact your administrator.',
      'switchWorkspace': 'Switch',
      'hiChooseWorkspace': 'Hi {name}! Choose the customer workspace you want to work in.',
      // Customer users
      'linkedUsers': 'Linked Users',
      'noUsersLinked': 'No users linked yet.',
      'linkFirstUser': 'Link first user',
      'linkAUser': 'Link a user',
      'searchUser': 'Search user',
      'typeNameOrEmail': 'Type a name or email…',
      'roleLabel': 'Role',
      'notesLabel': 'Notes',
      'link': 'Link',
      'unlink': 'Unlink',
      // Roles
      'roleClientAdmin': 'Client Admin',
      'roleItExecutor': 'IT Executor',
      'roleEmployee': 'Employee',
      'roleReguLitAdmin': 'Regulit Admin',
      'roleCsm': 'Customer Success Manager',
      'roleAnalyst': 'Compliance Analyst',
      // Audit Pack
      'auditPackTitle': 'Audit Pack',
      'auditPackSubtitle': 'Complete your compliance workflows below. Resume any previous session or start fresh.',
      'auditYourOrganisation': 'Your Organisation',
      'statAssigned': 'Assigned',
      'statInProgress': 'In Progress',
      'statActive': 'Active',
      'statusActive': 'Active',
      'statusInactive': 'Inactive',
      'timeJustNow': 'just now',
      'timeMinutesAgo': '{n}m ago',
      'timeHoursAgo': '{n}h ago',
      'timeDaysAgo': '{n}d ago',
      'timeMonthsAgo': '{n}mo ago',
      'timeYearsAgo': '{n}y ago',
      'auditLastSession': 'Last session',
      'auditAnswerSingular': '1 answer',
      'auditAnswerPlural': '{n} answers',
      'workflowInactive': 'Workflow Inactive',
      'actionStarting': 'Starting…',
      'actionStartFill': 'Start Fill',
      'actionNewFill': 'New Fill',
      'actionEditLast': 'Edit Last',
      'noWorkspaceSelected': 'No workspace selected',
      'selectWorkspaceFirst': 'Please select a customer workspace first.',
      'noWorkflowsAssigned': 'No workflows assigned yet.',
      'workflowsAssignedBy': 'Your administrator will assign workflows\nto your organisation.',
      'loadingWorkflows': 'Loading your workflows…',
      'tryAgain': 'Try Again',
      'back': 'Back',
      'next': 'Next',
      'finish': 'Finish',
      'yes': 'Yes',
      'no': 'No',
      'pressY': 'Press Y',
      'selectAllThatApply': 'Select all that apply',
      'pressN': 'Press N',
      'allDone': 'All Done! 🎉',
      'goToDashboard': 'Go to Dashboard',
      'youCompleted': 'You completed "{name}"',
      'questionsAnsweredPct': 'questions answered: {pct}%',
      'viewAnswers': 'Answers ({n})',
      'setActive': 'Set Active',
      'view': 'View',
      // Task Board
      'taskToDo': 'To Do',
      'taskInProgress': 'In Progress',
      'taskPendingReview': 'Pending Review',
      'taskDone': 'Done',
      'taskOverdue': 'Overdue',
      'taskAssigned': 'Assigned',
      'taskCompleted': 'Completed',
      'taskFilterAll': 'All',
      'taskNoItems': 'No tasks here',
      'taskDueLabel': 'Due',
      'taskRequired': 'Required',
      'overdueWarning': '⚠️ {n} overdue',
      'createTask': 'New Task',
      'taskNameLabel': 'Task Name',
      'whatToDoLabel': 'What To Do',
      'taskRiskLabel': 'Risk',
      'dueDateLabel': 'Due Date',
      'isRequiredLabel': 'Required Task',
      'taskStatusLabel': 'Status',
      'noDueDate': 'No due date',
      'assignToLabel': 'Assign To',
      'unassigned': 'Unassigned',
      'estimatedFineLabel': 'Estimated Fine (₪)',
      'editTask': 'Edit Task',
      'taskDetails': 'Task Details',
      'myTasks': 'My Tasks',
      'otherTasks': 'Other Tasks',
      // Client-admin user management
      'addUser': 'Add User',
      'newUser': 'New User',
      'existingUser': 'Existing User',
      'firstName': 'First Name',
      'lastName': 'Last Name',
      'createAndLink': 'Create & Link',
      // Task list
      'allTasks': 'All Tasks',
      'noCustomerSelected': 'No customer selected.',
      'selectSessionAbove': 'Select an assessment session above.',
      'failedToLoadSessions': 'Failed to load sessions',
      'noActiveSessions': 'No active sessions',
      'sessionLabel': 'Session:',
      'searchTasksHint': 'Search tasks…',
      'switchToKanban': 'Switch to Kanban View',
      'noTasksMatch': 'No tasks match "{q}"',
      'noTasksForSession': 'No tasks found for this session.',
      // Workflow answer
      'fillingWorkflow': 'Filling Workflow',
      'aiAnalyzingDocument': 'AI analyzing document…',
      'noDescriptionAvailable': 'No description available.',
      'aiGeneratedDescription': 'AI-Generated Description',
      'loadingQuestions': 'Loading questions…',
      // Executive dashboard
      'complianceDashboard': 'Compliance Dashboard',
      'analyzeAgain': 'Analyze Again',
      'noCustomerContextSelected': 'No customer context selected.',
      'noActiveAssessmentSessions': 'No active assessment sessions.',
      'assessmentLabel': 'Assessment:',
      'riskExposureTrend': 'Risk Exposure Trend (₪)',
      'monthly': 'Monthly',
      'weekly': 'Weekly',
      'reviewNow': 'Review now →',
      'seeAll': 'See all →',
      'noOpenRisks': 'No open risks — great compliance!',
      'selectSession': 'Select a session…',
      'totalExposure': 'Total Exposure',
      'complianceScore': 'Compliance Score',
      'openTasksLabel': 'Open Tasks',
      'tasksClosedLabel': 'Tasks Closed',
      'runAnalysisToPopulate': 'Run analysis to populate',
      'requireAttention': 'Require attention',
      'allClear': 'All clear',
      'ofNTotal': 'of {n} total',
      'actionRequired': 'Action required:',
      'tasksNeedApproval': '{n} tasks need your approval.',
      'riskByCategory': 'Risk by Category',
      'topOpenRisks': 'Top Open Risks',
      'failedToLoadTrend': 'Failed to load trend data',
      'noEvaluationData': 'No evaluation data yet.\nRun an assessment analysis to see trends.',
      'failedToLoadDashboard': 'Failed to load dashboard',
      'nTasks': '{n} tasks',
      'statusToDo': 'To Do',
      'statusInProgress': 'In Progress',
      'statusPendingReview': 'Pending Review',
      'statusApproved': 'Approved',
      'statusOverdue': 'Overdue',
      'analysisCompleteNew': 'Analysis complete — {n} new tasks created.',
      'analysisCompleteNoGaps': 'Analysis complete — no new gaps found.',
      'analysisFailed': 'Analysis failed',
      // Session files
      'sessionFilesTitle': 'Session Files',
      'noFilesUploaded': 'No files uploaded yet.',
      'failedToLoadFiles': 'Failed to load files',
      'sourceTask': 'Task',
      'sourceAnswer': 'Answer',
      'viewText': 'View Text',
      'downloadFile': 'Download',
      'downloadAll': 'Download All',
      'nFiles': '{n} files',
      'noTextAvailable': 'No text content available.',
    },

    // ── Hebrew (RTL) ─────────────────────────────────────────────────────────
    'he': {
      'appName': 'רגוליט',
      'cancel': 'ביטול',
      'save': 'שמור',
      'close': 'סגור',
      'retry': 'נסה שוב',
      'loading': 'טוען…',
      'error': 'שגיאה',
      'required': 'שדה חובה',
      'signOut': 'התנתקות',
      'settings': 'הגדרות',
      'noResults': 'אין תוצאות',
      'search': 'חיפוש',
      'add': 'הוסף',
      // Auth
      'emailAddress': 'כתובת אימייל',
      'emailPlaceholder': 'david@company.co.il',
      'password': 'סיסמה',
      'signIn': 'כניסה',
      'forgotPassword': 'שכחת סיסמה?',
      'enterValidEmail': 'הזן אימייל תקין',
      'atLeast8Chars': 'לפחות 8 תווים',
      'orContinueWith': 'או המשך עם',
      'microsoftSso': 'Microsoft SSO',
      'resetPassword': 'איפוס סיסמה',
      'enterEmailForReset': 'הזן את האימייל שלך לקבלת קישור לאיפוס.',
      'resetLinkSent': 'אם האימייל קיים במערכת, קישור לאיפוס נשלח.',
      'sendLink': 'שלח קישור',
      'loginTagline': 'ציות שמגן. בהירות שמניעה.',
      'loginFooter': 'רגוליט · פרטיות כבסיס עיצובי\nנתונים מאוחסנים בישראל / אירופה',
      'demoLabel': 'הדגמה — ללא שרת',
      // Nav
      'navUsers': 'משתמשים',
      'navCustomers': 'לקוחות',
      'navDashboard': 'לוח בקרה',
      'navAdminDash': 'לוח בקרה',
      'navClients': 'לקוחות',
      'navEvidenceQueue': 'תור ראיות',
      'navAlerts': 'התראות',
      'navReports': 'דוחות',
      'navMyTasks': 'המשימות שלי',
      'navKanban': 'לוח קנבן',
      'navDocuments': 'מסמכים',
      'navAuditPack': 'חבילת ביקורת',
      'navAiAssistant': 'עוזר AI',
      'navQuizzes': 'שאלונים',
      'navWorkflows': 'תהליכי עבודה',
      'navAgents': 'סוכני AI',
      'navSessionFiles': 'קבצי ראיות',
      // Agents
      'agentsSubtitle': 'נהל את סוכני ה-AI שמייעלים את משימות הציות.',
      'addAgent': 'הוסף סוכן',
      'editAgent': 'ערוך סוכן',
      'noAgentsFound': 'לא נמצאו סוכנים',
      'showInactive': 'הצג לא פעילים',
      'agentName': 'שם הסוכן',
      'agentType': 'סוג הסוכן',
      'agentSchedule': 'לוח זמנים (cron)',
      'agentPrompt': 'הנחיית LLM',
      'agentBehavior': 'התנהגות ולוח זמנים',
      'agentTriggered': 'מופעל לפי אירוע',
      'agentDefault': 'ברירת מחדל',
      'agentIsDefault': 'סוכן ברירת מחדל',
      'inactive': 'לא פעיל',
      'active': 'פעיל',
      'deactivate': 'השבת',
      'edit': 'ערוך',
      'description': 'תיאור',
      'llmConfig': 'הגדרות LLM',
      'llmProvider': 'ספק LLM',
      'llmModel': 'מודל LLM',
      'llmApiKey': 'מפתח API',
      'llmMaxTokens': 'מקסימום טוקנים',
      'llmTemperature': 'טמפרטורה',
      'llmAgentUrl': 'כתובת הסוכן',
      'duplicate': 'שכפל',
      'agentDuplicated': 'הסוכן שוכפל בהצלחה',
      'jsonOutputSchema': 'סכמת פלט JSON צפויה',
      'addEvidence': 'הוסף ראיה',
      // Workspace
      'selectWorkspace': 'בחר סביבת עבודה',
      'failedLoadWorkspaces': 'טעינת סביבות עבודה נכשלה',
      'noWorkspacesFound': 'לא נמצאו סביבות עבודה',
      'notLinkedToCustomer': 'אינך מקושר ללקוח כלשהו.\nפנה למנהל המערכת.',
      'switchWorkspace': 'החלף',
      'hiChooseWorkspace': 'שלום {name}! בחר את סביבת העבודה של הלקוח שברצונך לעבוד בה.',
      // Customer users
      'linkedUsers': 'משתמשים מקושרים',
      'noUsersLinked': 'אין משתמשים מקושרים עדיין.',
      'linkFirstUser': 'קשר משתמש ראשון',
      'linkAUser': 'קשר משתמש',
      'searchUser': 'חפש משתמש',
      'typeNameOrEmail': 'הקלד שם או אימייל…',
      'roleLabel': 'תפקיד',
      'notesLabel': 'הערות',
      'link': 'קשר',
      'unlink': 'נתק',
      // Roles
      'roleClientAdmin': 'מנהל לקוח',
      'roleItExecutor': 'מנהל IT',
      'roleEmployee': 'עובד',
      'roleReguLitAdmin': 'מנהל רגוליט',
      'roleCsm': 'מנהל הצלחת לקוח',
      'roleAnalyst': 'אנליסט ציות',
      // Audit Pack
      'auditPackTitle': 'חבילת ביקורת',
      'auditPackSubtitle': 'השלם את תהליכי הציות שלך. המשך מפגישה קודמת או התחל מחדש.',
      'auditYourOrganisation': 'הארגון שלך',
      'statAssigned': 'מוקצה',
      'statInProgress': 'בתהליך',
      'statActive': 'פעיל',
      'statusActive': 'פעיל',
      'statusInactive': 'לא פעיל',
      'timeJustNow': 'עכשיו',
      'timeMinutesAgo': 'לפני {n} דק׳',
      'timeHoursAgo': 'לפני {n} שע׳',
      'timeDaysAgo': 'לפני {n} ימים',
      'timeMonthsAgo': 'לפני {n} חו׳',
      'timeYearsAgo': 'לפני {n} שנ׳',
      'auditLastSession': 'פגישה אחרונה',
      'auditAnswerSingular': 'תשובה אחת',
      'auditAnswerPlural': '{n} תשובות',
      'workflowInactive': 'תהליך עבודה לא פעיל',
      'actionStarting': 'מתחיל…',
      'actionStartFill': 'התחל מילוי',
      'actionNewFill': 'מילוי חדש',
      'actionEditLast': 'ערוך אחרון',
      'noWorkspaceSelected': 'לא נבחרה סביבת עבודה',
      'selectWorkspaceFirst': 'אנא בחר תחילה סביבת עבודה של לקוח.',
      'noWorkflowsAssigned': 'אין תהליכי עבודה מוקצים עדיין.',
      'workflowsAssignedBy': 'המנהל שלך ישייך תהליכי עבודה\nלארגון שלך.',
      'loadingWorkflows': 'טוען את תהליכי העבודה שלך…',
      'tryAgain': 'נסה שוב',
      'back': 'חזור',
      'next': 'הבא',
      'finish': 'סיום',
      'yes': 'כן',
      'no': 'לא',
      'pressY': 'לחץ K',
      'selectAllThatApply': 'בחר את כל המתאים',
      'pressN': 'לחץ L',
      'allDone': 'הכל הושלם! 🎉',
      'goToDashboard': 'עבור ללוח הבקרה',
      'youCompleted': 'סיימת את "{name}"',
      'questionsAnsweredPct': 'שאלות שנענו: {pct}%',
      'viewAnswers': 'תשובות ({n})',
      'setActive': 'הגדר פעיל',
      'view': 'צפייה',
      // Task Board
      'taskToDo': 'לביצוע',
      'taskInProgress': 'בתהליך',
      'taskPendingReview': 'ממתין לאישור',
      'taskDone': 'הושלם',
      'taskOverdue': 'באיחור',
      'taskAssigned': 'מוקצות',
      'taskCompleted': 'הושלמו',
      'taskFilterAll': 'הכל',
      'taskNoItems': 'אין משימות כאן',
      'taskDueLabel': 'יעד',
      'taskRequired': 'חובה',
      'overdueWarning': '⚠️ {n} באיחור',
      'createTask': 'משימה חדשה',
      'taskNameLabel': 'שם משימה',
      'whatToDoLabel': 'מה לעשות',
      'taskRiskLabel': 'סיכון',
      'dueDateLabel': 'תאריך יעד',
      'isRequiredLabel': 'משימת חובה',
      'taskStatusLabel': 'סטטוס',
      'noDueDate': 'ללא תאריך יעד',
      'assignToLabel': 'הקצה ל',
      'unassigned': 'לא מוקצה',
      'estimatedFineLabel': 'קנס משוער (₪)',
      'editTask': 'ערוך משימה',
      'taskDetails': 'פרטי משימה',
      'myTasks': 'המשימות שלי',
      'otherTasks': 'משימות אחרות',
      // Client-admin user management
      'addUser': 'הוסף משתמש',
      'newUser': 'משתמש חדש',
      'existingUser': 'משתמש קיים',
      'firstName': 'שם פרטי',
      'lastName': 'שם משפחה',
      'createAndLink': 'צור וקשר',
      // Task list
      'allTasks': 'כל המשימות',
      'noCustomerSelected': 'לא נבחר לקוח.',
      'selectSessionAbove': 'בחר פגישת הערכה למעלה.',
      'failedToLoadSessions': 'טעינת פגישות נכשלה',
      'noActiveSessions': 'אין פגישות פעילות',
      'sessionLabel': 'פגישה:',
      'searchTasksHint': 'חיפוש משימות…',
      'switchToKanban': 'מעבר לתצוגת קנבן',
      'noTasksMatch': 'אין משימות התואמות לחיפוש "{q}"',
      'noTasksForSession': 'לא נמצאו משימות לפגישה זו.',
      // Workflow answer
      'fillingWorkflow': 'ממלא תהליך עבודה',
      'aiAnalyzingDocument': 'AI מנתח מסמך…',
      'noDescriptionAvailable': 'אין תיאור זמין.',
      'aiGeneratedDescription': 'תיאור שנוצר ע"י AI',
      'loadingQuestions': 'טוען שאלות…',
      // Executive dashboard
      'complianceDashboard': 'לוח בקרת ציות',
      'analyzeAgain': 'נתח שוב',
      'noCustomerContextSelected': 'לא נבחר לקוח.',
      'noActiveAssessmentSessions': 'אין פגישות הערכה פעילות.',
      'assessmentLabel': 'הערכה:',
      'riskExposureTrend': 'מגמת חשיפת סיכון (₪)',
      'monthly': 'חודשי',
      'weekly': 'שבועי',
      'reviewNow': '← לביקורת עכשיו',
      'seeAll': '← ראה הכל',
      'noOpenRisks': 'אין סיכונים פתוחים — ציות מצוין!',
      'selectSession': 'בחר פגישה…',
      'totalExposure': 'סה"כ חשיפה',
      'complianceScore': 'ציון ציות',
      'openTasksLabel': 'משימות פתוחות',
      'tasksClosedLabel': 'משימות סגורות',
      'runAnalysisToPopulate': 'הפעל ניתוח כדי למלא',
      'requireAttention': 'דורשות תשומת לב',
      'allClear': 'הכל תקין',
      'ofNTotal': 'מתוך {n}',
      'actionRequired': 'נדרשת פעולה:',
      'tasksNeedApproval': '{n} משימות מחכות לאישורך.',
      'riskByCategory': 'סיכון לפי קטגוריה',
      'topOpenRisks': 'סיכונים פתוחים מובילים',
      'failedToLoadTrend': 'טעינת נתוני המגמה נכשלה',
      'noEvaluationData': 'אין נתוני הערכה עדיין.\nהפעל ניתוח הערכה לצפייה במגמות.',
      'failedToLoadDashboard': 'טעינת לוח הבקרה נכשלה',
      'nTasks': '{n} משימות',
      'statusToDo': 'לביצוע',
      'statusInProgress': 'בתהליך',
      'statusPendingReview': 'ממתין לבדיקה',
      'statusApproved': 'אושר',
      'statusOverdue': 'באיחור',
      'analysisCompleteNew': 'הניתוח הושלם — {n} משימות חדשות נוצרו.',
      'analysisCompleteNoGaps': 'הניתוח הושלם — לא נמצאו פערים חדשים.',
      'analysisFailed': 'הניתוח נכשל',
      // Session files
      'sessionFilesTitle': 'קבצי פגישה',
      'noFilesUploaded': 'לא הועלו קבצים עדיין.',
      'failedToLoadFiles': 'טעינת קבצים נכשלה',
      'sourceTask': 'משימה',
      'sourceAnswer': 'תשובה',
      'viewText': 'צפה בטקסט',
      'downloadFile': 'הורד',
      'downloadAll': 'הורד הכל',
      'nFiles': '{n} קבצים',
      'noTextAvailable': 'אין תוכן טקסט זמין.',
    },

    // ── Spanish ──────────────────────────────────────────────────────────────
    'es': {
      'appName': 'Regulit',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'close': 'Cerrar',
      'retry': 'Reintentar',
      'loading': 'Cargando…',
      'error': 'Error',
      'required': 'Requerido',
      'signOut': 'Cerrar sesión',
      'settings': 'Configuración',
      'noResults': 'Sin resultados',
      'search': 'Buscar',
      'add': 'Agregar',
      // Auth
      'emailAddress': 'Correo electrónico',
      'emailPlaceholder': 'david@empresa.com',
      'password': 'Contraseña',
      'signIn': 'Iniciar sesión',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'enterValidEmail': 'Ingresa un correo válido',
      'atLeast8Chars': 'Mínimo 8 caracteres',
      'orContinueWith': 'o continuar con',
      'microsoftSso': 'Microsoft SSO',
      'resetPassword': 'Restablecer contraseña',
      'enterEmailForReset': 'Ingresa tu correo para recibir un enlace de restablecimiento.',
      'resetLinkSent': 'Si este correo existe, se ha enviado un enlace de restablecimiento.',
      'sendLink': 'Enviar enlace',
      'loginTagline': 'Cumplimiento que protege. Claridad que avanza.',
      'loginFooter': 'Regulit · Privacidad por diseño\nDatos almacenados en Israel / UE',
      'demoLabel': 'Demo — sin backend',
      // Nav
      'navUsers': 'Usuarios',
      'navCustomers': 'Clientes',
      'navDashboard': 'Panel',
      'navAdminDash': 'Panel admin.',
      'navClients': 'Clientes',
      'navEvidenceQueue': 'Cola de evidencias',
      'navAlerts': 'Alertas',
      'navReports': 'Informes',
      'navMyTasks': 'Mis Tareas',
      'navKanban': 'Tablero Kanban',
      'navDocuments': 'Documentos',
      'navAuditPack': 'Paquete de auditoría',
      'navAiAssistant': 'Asistente IA',
      'navQuizzes': 'Cuestionarios',
      'navWorkflows': 'Flujos de trabajo',
      'navAgents': 'Agentes IA',
      'navSessionFiles': 'Archivos de evidencia',
      // Agents
      'agentsSubtitle': 'Gestiona los agentes IA que automatizan las tareas de cumplimiento.',
      'addAgent': 'Agregar agente',
      'editAgent': 'Editar agente',
      'noAgentsFound': 'No se encontraron agentes',
      'showInactive': 'Mostrar inactivos',
      'agentName': 'Nombre del agente',
      'agentType': 'Tipo de agente',
      'agentSchedule': 'Programación (cron)',
      'agentPrompt': 'Instrucción LLM',
      'agentBehavior': 'Comportamiento y programación',
      'agentTriggered': 'Por evento',
      'agentDefault': 'Por defecto',
      'agentIsDefault': 'Agente por defecto',
      'inactive': 'Inactivo',
      'active': 'Activo',
      'deactivate': 'Desactivar',
      'edit': 'Editar',
      'description': 'Descripción',
      'llmConfig': 'Configuración LLM',
      'llmProvider': 'Proveedor LLM',
      'llmModel': 'Modelo LLM',
      'llmApiKey': 'Clave API',
      'llmMaxTokens': 'Máx. tokens',
      'llmTemperature': 'Temperatura',
      'llmAgentUrl': 'URL del agente',
      'duplicate': 'Duplicar',
      'agentDuplicated': 'Agente duplicado correctamente',
      'jsonOutputSchema': 'Esquema de salida JSON esperado',
      'addEvidence': 'Agregar evidencia',
      // Workspace
      'selectWorkspace': 'Seleccionar área de trabajo',
      'failedLoadWorkspaces': 'Error al cargar espacios de trabajo',
      'noWorkspacesFound': 'No se encontraron espacios de trabajo',
      'notLinkedToCustomer': 'Aún no estás vinculado a ningún cliente.\nContacta a tu administrador.',
      'switchWorkspace': 'Cambiar',
      'hiChooseWorkspace': '¡Hola {name}! Elige el espacio de trabajo del cliente.',
      // Customer users
      'linkedUsers': 'Usuarios vinculados',
      'noUsersLinked': 'Sin usuarios vinculados aún.',
      'linkFirstUser': 'Vincular primer usuario',
      'linkAUser': 'Vincular usuario',
      'searchUser': 'Buscar usuario',
      'typeNameOrEmail': 'Escribe un nombre o correo…',
      'roleLabel': 'Rol',
      'notesLabel': 'Notas',
      'link': 'Vincular',
      'unlink': 'Desvincular',
      // Roles
      'roleClientAdmin': 'Admin. cliente',
      'roleItExecutor': 'Ejecutor de TI',
      'roleEmployee': 'Empleado',
      'roleReguLitAdmin': 'Admin. Regulit',
      'roleCsm': 'Gestor de éxito del cliente',
      'roleAnalyst': 'Analista de cumplimiento',
      // Audit Pack
      'auditPackTitle': 'Paquete de auditoría',
      'auditPackSubtitle': 'Completa tus flujos de trabajo a continuación. Retoma cualquier sesión o empieza de cero.',
      'auditYourOrganisation': 'Tu Organización',
      'statAssigned': 'Asignados',
      'statInProgress': 'En curso',
      'statActive': 'Activos',
      'statusActive': 'Activo',
      'statusInactive': 'Inactivo',
      'timeJustNow': 'ahora mismo',
      'timeMinutesAgo': 'hace {n} min',
      'timeHoursAgo': 'hace {n} h',
      'timeDaysAgo': 'hace {n} días',
      'timeMonthsAgo': 'hace {n} meses',
      'timeYearsAgo': 'hace {n} años',
      'auditLastSession': 'Última sesión',
      'auditAnswerSingular': '1 respuesta',
      'auditAnswerPlural': '{n} respuestas',
      'workflowInactive': 'Flujo de trabajo inactivo',
      'actionStarting': 'Iniciando…',
      'actionStartFill': 'Iniciar relleno',
      'actionNewFill': 'Nuevo relleno',
      'actionEditLast': 'Editar último',
      'noWorkspaceSelected': 'No hay espacio de trabajo seleccionado',
      'selectWorkspaceFirst': 'Por favor, selecciona un espacio de trabajo primero.',
      'noWorkflowsAssigned': 'No hay flujos de trabajo asignados.',
      'workflowsAssignedBy': 'Tu administrador asignará flujos\na tu organización.',
      'loadingWorkflows': 'Cargando tus flujos de trabajo…',
      'tryAgain': 'Intentar de nuevo',
      'back': 'Atrás',
      'next': 'Siguiente',
      'finish': 'Finalizar',
      'yes': 'Sí',
      'no': 'No',
      'pressY': 'Pulsa S',
      'selectAllThatApply': 'Selecciona todas las que apliquen',
      'pressN': 'Pulsa N',
      'allDone': '¡Todo listo! 🎉',
      'goToDashboard': 'Ir al Panel',
      'youCompleted': 'Completaste "{name}"',
      'questionsAnsweredPct': 'preguntas respondidas: {pct}%',
      'viewAnswers': 'Respuestas ({n})',
      'setActive': 'Activar',
      'view': 'Ver',
      // Task Board
      'taskToDo': 'Por hacer',
      'taskInProgress': 'En progreso',
      'taskPendingReview': 'Pendiente de revisión',
      'taskDone': 'Hecho',
      'taskOverdue': 'Vencido',
      'taskAssigned': 'Asignadas',
      'taskCompleted': 'Completadas',
      'taskFilterAll': 'Todas',
      'taskNoItems': 'Sin tareas aquí',
      'taskDueLabel': 'Vence',
      'taskRequired': 'Obligatorio',
      'overdueWarning': '⚠️ {n} vencida(s)',
      'createTask': 'Nueva tarea',
      'taskNameLabel': 'Nombre de tarea',
      'whatToDoLabel': 'Qué hacer',
      'taskRiskLabel': 'Riesgo',
      'dueDateLabel': 'Fecha límite',
      'isRequiredLabel': 'Tarea obligatoria',
      'taskStatusLabel': 'Estado',
      'noDueDate': 'Sin fecha límite',
      'assignToLabel': 'Asignar a',
      'unassigned': 'Sin asignar',
      'estimatedFineLabel': 'Multa estimada (₪)',
      'editTask': 'Editar tarea',
      'taskDetails': 'Detalles de tarea',
      'myTasks': 'Mis tareas',
      'otherTasks': 'Otras tareas',
      // Client-admin user management
      'addUser': 'Añadir usuario',
      'newUser': 'Nuevo usuario',
      'existingUser': 'Usuario existente',
      'firstName': 'Nombre',
      'lastName': 'Apellido',
      'createAndLink': 'Crear y vincular',
      // Task list
      'allTasks': 'Todas las tareas',
      'noCustomerSelected': 'Sin cliente seleccionado.',
      'selectSessionAbove': 'Selecciona una sesión de evaluación arriba.',
      'failedToLoadSessions': 'Error al cargar sesiones',
      'noActiveSessions': 'Sin sesiones activas',
      'sessionLabel': 'Sesión:',
      'searchTasksHint': 'Buscar tareas…',
      'switchToKanban': 'Cambiar a vista Kanban',
      'noTasksMatch': 'Sin tareas que coincidan con "{q}"',
      'noTasksForSession': 'Sin tareas para esta sesión.',
      // Workflow answer
      'fillingWorkflow': 'Completando flujo de trabajo',
      'aiAnalyzingDocument': 'IA analizando documento…',
      'noDescriptionAvailable': 'Sin descripción disponible.',
      'aiGeneratedDescription': 'Descripción generada por IA',
      'loadingQuestions': 'Cargando preguntas…',
      // Executive dashboard
      'complianceDashboard': 'Panel de cumplimiento',
      'analyzeAgain': 'Analizar de nuevo',
      'noCustomerContextSelected': 'Sin cliente seleccionado.',
      'noActiveAssessmentSessions': 'Sin sesiones de evaluación activas.',
      'assessmentLabel': 'Evaluación:',
      'riskExposureTrend': 'Tendencia de exposición al riesgo (₪)',
      'monthly': 'Mensual',
      'weekly': 'Semanal',
      'reviewNow': 'Revisar ahora →',
      'seeAll': 'Ver todo →',
      'noOpenRisks': '¡Sin riesgos abiertos — excelente cumplimiento!',
      'selectSession': 'Seleccionar sesión…',
      'totalExposure': 'Exposición total',
      'complianceScore': 'Puntuación de cumplimiento',
      'openTasksLabel': 'Tareas abiertas',
      'tasksClosedLabel': 'Tareas cerradas',
      'runAnalysisToPopulate': 'Ejecutar análisis para rellenar',
      'requireAttention': 'Requieren atención',
      'allClear': 'Todo en orden',
      'ofNTotal': 'de {n} en total',
      'actionRequired': 'Acción requerida:',
      'tasksNeedApproval': '{n} tareas necesitan su aprobación.',
      'riskByCategory': 'Riesgo por categoría',
      'topOpenRisks': 'Principales riesgos abiertos',
      'failedToLoadTrend': 'Error al cargar datos de tendencia',
      'noEvaluationData': 'Aún no hay datos de evaluación.\nEjecute un análisis para ver tendencias.',
      'failedToLoadDashboard': 'Error al cargar el panel',
      'nTasks': '{n} tareas',
      'statusToDo': 'Por hacer',
      'statusInProgress': 'En progreso',
      'statusPendingReview': 'Pendiente de revisión',
      'statusApproved': 'Aprobado',
      'statusOverdue': 'Vencido',
      'analysisCompleteNew': 'Análisis completo — {n} nuevas tareas creadas.',
      'analysisCompleteNoGaps': 'Análisis completo — no se encontraron nuevas brechas.',
      'analysisFailed': 'El análisis falló',
      // Session files
      'sessionFilesTitle': 'Archivos de sesión',
      'noFilesUploaded': 'Aún no se han subido archivos.',
      'failedToLoadFiles': 'Error al cargar archivos',
      'sourceTask': 'Tarea',
      'sourceAnswer': 'Respuesta',
      'viewText': 'Ver texto',
      'downloadFile': 'Descargar',
      'downloadAll': 'Descargar todo',
      'nFiles': '{n} archivos',
      'noTextAvailable': 'Sin contenido de texto disponible.',
    },

    // ── French ───────────────────────────────────────────────────────────────
    'fr': {
      'appName': 'Regulit',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'close': 'Fermer',
      'retry': 'Réessayer',
      'loading': 'Chargement…',
      'error': 'Erreur',
      'required': 'Requis',
      'signOut': 'Se déconnecter',
      'settings': 'Paramètres',
      'noResults': 'Aucun résultat',
      'search': 'Rechercher',
      'add': 'Ajouter',
      // Auth
      'emailAddress': 'Adresse e-mail',
      'emailPlaceholder': 'david@entreprise.fr',
      'password': 'Mot de passe',
      'signIn': 'Se connecter',
      'forgotPassword': 'Mot de passe oublié ?',
      'enterValidEmail': 'Entrez un e-mail valide',
      'atLeast8Chars': 'Au moins 8 caractères',
      'orContinueWith': 'ou continuer avec',
      'microsoftSso': 'Microsoft SSO',
      'resetPassword': 'Réinitialiser le mot de passe',
      'enterEmailForReset': 'Entrez votre e-mail pour recevoir un lien de réinitialisation.',
      'resetLinkSent': 'Si cet e-mail existe, un lien de réinitialisation a été envoyé.',
      'sendLink': 'Envoyer le lien',
      'loginTagline': 'Conformité qui protège. Clarté qui avance.',
      'loginFooter': 'Regulit · Respect de la vie privée par conception\nDonnées stockées en Israël / UE',
      'demoLabel': 'Démo — sans backend',
      // Nav
      'navUsers': 'Utilisateurs',
      'navCustomers': 'Clients',
      'navDashboard': 'Tableau de bord',
      'navAdminDash': 'Tableau admin.',
      'navClients': 'Clients',
      'navEvidenceQueue': 'File de preuves',
      'navAlerts': 'Alertes',
      'navReports': 'Rapports',
      'navMyTasks': 'Mes Tâches',
      'navKanban': 'Tableau Kanban',
      'navDocuments': 'Documents',
      'navAuditPack': "Pack d'audit",
      'navAiAssistant': 'Assistant IA',
      'navQuizzes': 'Questionnaires',
      'navWorkflows': 'Flux de travail',
      'navAgents': 'Agents IA',
      'navSessionFiles': 'Fichiers de preuves',
      // Agents
      'agentsSubtitle': 'Gérez les agents IA qui automatisent les tâches de conformité.',
      'addAgent': 'Ajouter un agent',
      'editAgent': 'Modifier l\'agent',
      'noAgentsFound': 'Aucun agent trouvé',
      'showInactive': 'Afficher inactifs',
      'agentName': 'Nom de l\'agent',
      'agentType': 'Type d\'agent',
      'agentSchedule': 'Planification (cron)',
      'agentPrompt': 'Instruction LLM',
      'agentBehavior': 'Comportement et planification',
      'agentTriggered': 'Déclenché',
      'agentDefault': 'Par défaut',
      'agentIsDefault': 'Agent par défaut',
      'inactive': 'Inactif',
      'active': 'Actif',
      'deactivate': 'Désactiver',
      'edit': 'Modifier',
      'description': 'Description',
      'llmConfig': 'Configuration LLM',
      'llmProvider': 'Fournisseur LLM',
      'llmModel': 'Modèle LLM',
      'llmApiKey': 'Clé API',
      'llmMaxTokens': 'Max tokens',
      'llmTemperature': 'Température',
      'llmAgentUrl': 'URL de l\'agent',
      'duplicate': 'Dupliquer',
      'agentDuplicated': 'Agent dupliqué avec succès',
      'jsonOutputSchema': 'Schéma de sortie JSON attendu',
      'addEvidence': 'Ajouter une preuve',
      // Workspace
      'selectWorkspace': 'Sélectionner un espace de travail',
      'failedLoadWorkspaces': 'Échec du chargement des espaces de travail',
      'noWorkspacesFound': 'Aucun espace de travail trouvé',
      'notLinkedToCustomer': "Vous n'êtes lié à aucun client.\nContactez votre administrateur.",
      'switchWorkspace': 'Changer',
      'hiChooseWorkspace': 'Bonjour {name} ! Choisissez votre espace de travail client.',
      // Customer users
      'linkedUsers': 'Utilisateurs liés',
      'noUsersLinked': 'Aucun utilisateur lié pour le moment.',
      'linkFirstUser': 'Lier le premier utilisateur',
      'linkAUser': 'Lier un utilisateur',
      'searchUser': 'Rechercher un utilisateur',
      'typeNameOrEmail': 'Saisissez un nom ou un e-mail…',
      'roleLabel': 'Rôle',
      'notesLabel': 'Notes',
      'link': 'Lier',
      'unlink': 'Délier',
      // Roles
      'roleClientAdmin': 'Admin. client',
      'roleItExecutor': 'Responsable IT',
      'roleEmployee': 'Employé',
      'roleReguLitAdmin': 'Admin. Regulit',
      'roleCsm': 'Responsable succès client',
      'roleAnalyst': 'Analyste conformité',
      // Audit Pack
      'auditPackTitle': "Pack d'audit",
      'auditPackSubtitle': 'Complétez vos workflows de conformité ci-dessous. Reprenez une session ou recommencez.',
      'auditYourOrganisation': 'Votre Organisation',
      'statAssigned': 'Assignés',
      'statInProgress': 'En cours',
      'statActive': 'Actifs',
      'statusActive': 'Actif',
      'statusInactive': 'Inactif',
      'timeJustNow': "à l'instant",
      'timeMinutesAgo': 'il y a {n} min',
      'timeHoursAgo': 'il y a {n} h',
      'timeDaysAgo': 'il y a {n} j',
      'timeMonthsAgo': 'il y a {n} mois',
      'timeYearsAgo': 'il y a {n} an(s)',
      'auditLastSession': 'Dernière session',
      'auditAnswerSingular': '1 réponse',
      'auditAnswerPlural': '{n} réponses',
      'workflowInactive': 'Workflow inactif',
      'actionStarting': 'Démarrage…',
      'actionStartFill': 'Commencer',
      'actionNewFill': 'Nouveau',
      'actionEditLast': 'Modifier dernier',
      'noWorkspaceSelected': 'Aucun espace de travail sélectionné',
      'selectWorkspaceFirst': "Veuillez d'abord sélectionner un espace de travail.",
      'noWorkflowsAssigned': 'Aucun workflow assigné pour le moment.',
      'workflowsAssignedBy': 'Votre administrateur assignera des workflows\nà votre organisation.',
      'loadingWorkflows': 'Chargement de vos workflows…',
      'tryAgain': 'Réessayer',
      'back': 'Retour',
      'next': 'Suivant',
      'finish': 'Terminer',
      'yes': 'Oui',
      'no': 'Non',
      'pressY': 'Appuyez O',
      'selectAllThatApply': 'Sélectionnez tout ce qui s\'applique',
      'pressN': 'Appuyez N',
      'allDone': 'Tout est fait ! 🎉',
      'goToDashboard': 'Aller au tableau de bord',
      'youCompleted': 'Vous avez terminé "{name}"',
      'questionsAnsweredPct': 'questions répondues : {pct}%',
      'viewAnswers': 'Réponses ({n})',
      'setActive': 'Activer',
      'view': 'Voir',
      // Task Board
      'taskToDo': 'À faire',
      'taskInProgress': 'En cours',
      'taskPendingReview': 'En attente de révision',
      'taskDone': 'Terminé',
      'taskOverdue': 'En retard',
      'taskAssigned': 'Assignées',
      'taskCompleted': 'Complétées',
      'taskFilterAll': 'Toutes',
      'taskNoItems': 'Aucune tâche ici',
      'taskDueLabel': 'Échéance',
      'taskRequired': 'Obligatoire',
      'overdueWarning': '⚠️ {n} en retard',
      'createTask': 'Nouvelle tâche',
      'taskNameLabel': 'Nom de la tâche',
      'whatToDoLabel': 'Que faire',
      'taskRiskLabel': 'Risque',
      'dueDateLabel': 'Date d\'échéance',
      'isRequiredLabel': 'Tâche obligatoire',
      'taskStatusLabel': 'Statut',
      'noDueDate': 'Sans date limite',
      'assignToLabel': 'Assigner à',
      'unassigned': 'Non assigné',
      'estimatedFineLabel': 'Amende estimée (₪)',
      'editTask': 'Modifier la tâche',
      'taskDetails': 'Détails de la tâche',
      'myTasks': 'Mes tâches',
      'otherTasks': 'Autres tâches',
      // Client-admin user management
      'addUser': 'Ajouter un utilisateur',
      'newUser': 'Nouvel utilisateur',
      'existingUser': 'Utilisateur existant',
      'firstName': 'Prénom',
      'lastName': 'Nom de famille',
      'createAndLink': 'Créer et lier',
      // Task list
      'allTasks': 'Toutes les tâches',
      'noCustomerSelected': 'Aucun client sélectionné.',
      'selectSessionAbove': 'Sélectionnez une session d\'évaluation ci-dessus.',
      'failedToLoadSessions': 'Échec du chargement des sessions',
      'noActiveSessions': 'Aucune session active',
      'sessionLabel': 'Session :',
      'searchTasksHint': 'Rechercher des tâches…',
      'switchToKanban': 'Passer à la vue Kanban',
      'noTasksMatch': 'Aucune tâche ne correspond à "{q}"',
      'noTasksForSession': 'Aucune tâche trouvée pour cette session.',
      // Workflow answer
      'fillingWorkflow': 'Remplissage du workflow',
      'aiAnalyzingDocument': 'IA en cours d\'analyse…',
      'noDescriptionAvailable': 'Aucune description disponible.',
      'aiGeneratedDescription': 'Description générée par IA',
      'loadingQuestions': 'Chargement des questions…',
      // Executive dashboard
      'complianceDashboard': 'Tableau de bord conformité',
      'analyzeAgain': 'Analyser à nouveau',
      'noCustomerContextSelected': 'Aucun client sélectionné.',
      'noActiveAssessmentSessions': 'Aucune session d\'évaluation active.',
      'assessmentLabel': 'Évaluation :',
      'riskExposureTrend': 'Tendance d\'exposition au risque (₪)',
      'monthly': 'Mensuel',
      'weekly': 'Hebdomadaire',
      'reviewNow': 'Réviser maintenant →',
      'seeAll': 'Voir tout →',
      'noOpenRisks': 'Aucun risque ouvert — conformité exemplaire !',
      'selectSession': 'Sélectionner une session…',
      'totalExposure': 'Exposition totale',
      'complianceScore': 'Score de conformité',
      'openTasksLabel': 'Tâches ouvertes',
      'tasksClosedLabel': 'Tâches fermées',
      'runAnalysisToPopulate': 'Lancer une analyse pour remplir',
      'requireAttention': 'Requièrent attention',
      'allClear': 'Tout est bon',
      'ofNTotal': 'sur {n} au total',
      'actionRequired': 'Action requise :',
      'tasksNeedApproval': '{n} tâches nécessitent votre approbation.',
      'riskByCategory': 'Risque par catégorie',
      'topOpenRisks': 'Principaux risques ouverts',
      'failedToLoadTrend': 'Échec du chargement des données de tendance',
      'noEvaluationData': 'Aucune donnée d\'évaluation pour l\'instant.\nLancez une analyse pour voir les tendances.',
      'failedToLoadDashboard': 'Échec du chargement du tableau de bord',
      'nTasks': '{n} tâches',
      'statusToDo': 'À faire',
      'statusInProgress': 'En cours',
      'statusPendingReview': 'En attente de révision',
      'statusApproved': 'Approuvé',
      'statusOverdue': 'En retard',
      'analysisCompleteNew': 'Analyse terminée — {n} nouvelles tâches créées.',
      'analysisCompleteNoGaps': 'Analyse terminée — aucune nouvelle lacune.',
      'analysisFailed': 'L\'analyse a échoué',
      // Session files
      'sessionFilesTitle': 'Fichiers de session',
      'noFilesUploaded': 'Aucun fichier téléversé pour le moment.',
      'failedToLoadFiles': 'Échec du chargement des fichiers',
      'sourceTask': 'Tâche',
      'sourceAnswer': 'Réponse',
      'viewText': 'Voir le texte',
      'downloadFile': 'Télécharger',
      'downloadAll': 'Tout télécharger',
      'nFiles': '{n} fichiers',
      'noTextAvailable': 'Aucun contenu textuel disponible.',
    },

    // ── Russian ──────────────────────────────────────────────────────────────
    'ru': {
      'appName': 'Regulit',
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'close': 'Закрыть',
      'retry': 'Повторить',
      'loading': 'Загрузка…',
      'error': 'Ошибка',
      'required': 'Обязательно',
      'signOut': 'Выйти',
      'settings': 'Настройки',
      'noResults': 'Нет результатов',
      'search': 'Поиск',
      'add': 'Добавить',
      // Auth
      'emailAddress': 'Адрес эл. почты',
      'emailPlaceholder': 'ivan@company.ru',
      'password': 'Пароль',
      'signIn': 'Войти',
      'forgotPassword': 'Забыли пароль?',
      'enterValidEmail': 'Введите корректный email',
      'atLeast8Chars': 'Минимум 8 символов',
      'orContinueWith': 'или продолжить через',
      'microsoftSso': 'Microsoft SSO',
      'resetPassword': 'Сброс пароля',
      'enterEmailForReset': 'Введите email для получения ссылки сброса пароля.',
      'resetLinkSent': 'Если этот email зарегистрирован, ссылка для сброса отправлена.',
      'sendLink': 'Отправить ссылку',
      'loginTagline': 'Соответствие, которое защищает. Ясность, которая движет.',
      'loginFooter': 'Regulit · Конфиденциальность по дизайну\nДанные хранятся в Израиле / ЕС',
      'demoLabel': 'Демо — без сервера',
      // Nav
      'navUsers': 'Пользователи',
      'navCustomers': 'Клиенты',
      'navDashboard': 'Панель',
      'navAdminDash': 'Панель адм.',
      'navClients': 'Клиенты',
      'navEvidenceQueue': 'Очередь доказательств',
      'navAlerts': 'Оповещения',
      'navReports': 'Отчёты',
      'navMyTasks': 'Мои задачи',
      'navKanban': 'Канбан-доска',
      'navDocuments': 'Документы',
      'navAuditPack': 'Пакет аудита',
      'navAiAssistant': 'ИИ-помощник',
      'navQuizzes': 'Опросники',
      'navWorkflows': 'Рабочие процессы',
      'navAgents': 'ИИ-агенты',
      'navSessionFiles': 'Файлы доказательств',
      // Agents
      'agentsSubtitle': 'Управляйте ИИ-агентами, автоматизирующими задачи соответствия.',
      'addAgent': 'Добавить агента',
      'editAgent': 'Редактировать агента',
      'noAgentsFound': 'Агенты не найдены',
      'showInactive': 'Показать неактивных',
      'agentName': 'Имя агента',
      'agentType': 'Тип агента',
      'agentSchedule': 'Расписание (cron)',
      'agentPrompt': 'Инструкция LLM',
      'agentBehavior': 'Поведение и расписание',
      'agentTriggered': 'По событию',
      'agentDefault': 'По умолчанию',
      'agentIsDefault': 'Агент по умолчанию',
      'inactive': 'Неактивен',
      'active': 'Активен',
      'deactivate': 'Деактивировать',
      'edit': 'Изменить',
      'description': 'Описание',
      'llmConfig': 'Настройки LLM',
      'llmProvider': 'Провайдер LLM',
      'llmModel': 'Модель LLM',
      'llmApiKey': 'API-ключ',
      'llmMaxTokens': 'Макс. токенов',
      'llmTemperature': 'Температура',
      'llmAgentUrl': 'URL агента',
      'duplicate': 'Дублировать',
      'agentDuplicated': 'Агент успешно дублирован',
      'jsonOutputSchema': 'Ожидаемая JSON-схема вывода',
      'addEvidence': 'Добавить доказательство',
      // Workspace
      'selectWorkspace': 'Выбор рабочего пространства',
      'failedLoadWorkspaces': 'Ошибка загрузки рабочих пространств',
      'noWorkspacesFound': 'Рабочие пространства не найдены',
      'notLinkedToCustomer': 'Вы не связаны ни с одним клиентом.\nСвяжитесь с администратором.',
      'switchWorkspace': 'Сменить',
      'hiChooseWorkspace': 'Привет, {name}! Выберите рабочее пространство клиента.',
      // Customer users
      'linkedUsers': 'Привязанные пользователи',
      'noUsersLinked': 'Пользователи ещё не привязаны.',
      'linkFirstUser': 'Привязать первого пользователя',
      'linkAUser': 'Привязать пользователя',
      'searchUser': 'Поиск пользователя',
      'typeNameOrEmail': 'Введите имя или email…',
      'roleLabel': 'Роль',
      'notesLabel': 'Заметки',
      'link': 'Привязать',
      'unlink': 'Отвязать',
      // Roles
      'roleClientAdmin': 'Администратор',
      'roleItExecutor': 'IT-менеджер',
      'roleEmployee': 'Сотрудник',
      'roleReguLitAdmin': 'Адм. Regulit',
      'roleCsm': 'Менеджер по работе с клиентами',
      'roleAnalyst': 'Аналитик соответствия',
      // Audit Pack
      'auditPackTitle': 'Пакет аудита',
      'auditPackSubtitle': 'Выполните свои рабочие процессы ниже. Продолжите предыдущий сеанс или начните заново.',
      'auditYourOrganisation': 'Ваша Организация',
      'statAssigned': 'Назначено',
      'statInProgress': 'В процессе',
      'statActive': 'Активных',
      'statusActive': 'Активен',
      'statusInactive': 'Неактивен',
      'timeJustNow': 'только что',
      'timeMinutesAgo': '{n} мин назад',
      'timeHoursAgo': '{n} ч назад',
      'timeDaysAgo': '{n} дн назад',
      'timeMonthsAgo': '{n} мес назад',
      'timeYearsAgo': '{n} л назад',
      'auditLastSession': 'Последний сеанс',
      'auditAnswerSingular': '1 ответ',
      'auditAnswerPlural': '{n} ответов',
      'workflowInactive': 'Процесс неактивен',
      'actionStarting': 'Запуск…',
      'actionStartFill': 'Начать',
      'actionNewFill': 'Новый',
      'actionEditLast': 'Изменить последний',
      'noWorkspaceSelected': 'Рабочее пространство не выбрано',
      'selectWorkspaceFirst': 'Сначала выберите рабочее пространство клиента.',
      'noWorkflowsAssigned': 'Рабочие процессы не назначены.',
      'workflowsAssignedBy': 'Ваш администратор назначит рабочие процессы\nвашей организации.',
      'loadingWorkflows': 'Загрузка рабочих процессов…',
      'tryAgain': 'Попробовать снова',
      'back': 'Назад',
      'next': 'Далее',
      'finish': 'Завершить',
      'yes': 'Да',
      'no': 'Нет',
      'pressY': 'Нажмите Д',
      'selectAllThatApply': 'Выберите все подходящие варианты',
      'pressN': 'Нажмите Н',
      'allDone': 'Всё готово! 🎉',
      'goToDashboard': 'Перейти на панель',
      'youCompleted': 'Вы завершили "{name}"',
      'questionsAnsweredPct': 'отвечено вопросов: {pct}%',
      'viewAnswers': 'Ответы ({n})',
      'setActive': 'Сделать активным',
      'view': 'Просмотр',
      // Task Board
      'taskToDo': 'К выполнению',
      'taskInProgress': 'В процессе',
      'taskPendingReview': 'На проверке',
      'taskDone': 'Выполнено',
      'taskOverdue': 'Просрочено',
      'taskAssigned': 'Назначено',
      'taskCompleted': 'Завершено',
      'taskFilterAll': 'Все',
      'taskNoItems': 'Нет задач',
      'taskDueLabel': 'Срок',
      'taskRequired': 'Обязательно',
      'overdueWarning': '⚠️ {n} просрочено',
      'createTask': 'Новая задача',
      'taskNameLabel': 'Название задачи',
      'whatToDoLabel': 'Что делать',
      'taskRiskLabel': 'Риск',
      'dueDateLabel': 'Срок выполнения',
      'isRequiredLabel': 'Обязательная задача',
      'taskStatusLabel': 'Статус',
      'noDueDate': 'Без срока',
      'assignToLabel': 'Назначить',
      'unassigned': 'Не назначено',
      'estimatedFineLabel': 'Штраф (₪)',
      'editTask': 'Редактировать задачу',
      'taskDetails': 'Детали задачи',
      'myTasks': 'Мои задачи',
      'otherTasks': 'Другие задачи',
      // Client-admin user management
      'addUser': 'Добавить пользователя',
      'newUser': 'Новый пользователь',
      'existingUser': 'Существующий',
      'firstName': 'Имя',
      'lastName': 'Фамилия',
      'createAndLink': 'Создать и привязать',
      // Task list
      'allTasks': 'Все задачи',
      'noCustomerSelected': 'Клиент не выбран.',
      'selectSessionAbove': 'Выберите сессию оценки выше.',
      'failedToLoadSessions': 'Ошибка загрузки сессий',
      'noActiveSessions': 'Нет активных сессий',
      'sessionLabel': 'Сессия:',
      'searchTasksHint': 'Поиск задач…',
      'switchToKanban': 'Перейти к канбан-доске',
      'noTasksMatch': 'Задачи по запросу "{q}" не найдены',
      'noTasksForSession': 'Для этой сессии задач нет.',
      // Workflow answer
      'fillingWorkflow': 'Заполнение процесса',
      'aiAnalyzingDocument': 'ИИ анализирует документ…',
      'noDescriptionAvailable': 'Описание недоступно.',
      'aiGeneratedDescription': 'Описание от ИИ',
      'loadingQuestions': 'Загрузка вопросов…',
      // Executive dashboard
      'complianceDashboard': 'Панель соответствия',
      'analyzeAgain': 'Повторить анализ',
      'noCustomerContextSelected': 'Клиент не выбран.',
      'noActiveAssessmentSessions': 'Нет активных сессий оценки.',
      'assessmentLabel': 'Оценка:',
      'riskExposureTrend': 'Тренд рисков (₪)',
      'monthly': 'По месяцам',
      'weekly': 'По неделям',
      'reviewNow': 'Проверить →',
      'seeAll': 'Все →',
      'noOpenRisks': 'Открытых рисков нет — отличное соответствие!',
      'selectSession': 'Выбрать сессию…',
      'totalExposure': 'Общая экспозиция',
      'complianceScore': 'Оценка соответствия',
      'openTasksLabel': 'Открытые задачи',
      'tasksClosedLabel': 'Закрытые задачи',
      'runAnalysisToPopulate': 'Запустите анализ для заполнения',
      'requireAttention': 'Требуют внимания',
      'allClear': 'Всё в порядке',
      'ofNTotal': 'из {n}',
      'actionRequired': 'Требуется действие:',
      'tasksNeedApproval': '{n} задач ожидают вашего одобрения.',
      'riskByCategory': 'Риск по категориям',
      'topOpenRisks': 'Главные открытые риски',
      'failedToLoadTrend': 'Ошибка загрузки данных тренда',
      'noEvaluationData': 'Данных оценки пока нет.\nЗапустите анализ для просмотра трендов.',
      'failedToLoadDashboard': 'Ошибка загрузки панели',
      'nTasks': '{n} задач',
      'statusToDo': 'К выполнению',
      'statusInProgress': 'В процессе',
      'statusPendingReview': 'На проверке',
      'statusApproved': 'Одобрено',
      'statusOverdue': 'Просрочено',
      'analysisCompleteNew': 'Анализ завершён — создано {n} новых задач.',
      'analysisCompleteNoGaps': 'Анализ завершён — новых пробелов не найдено.',
      'analysisFailed': 'Анализ не удался',
      // Session files
      'sessionFilesTitle': 'Файлы сессии',
      'noFilesUploaded': 'Файлы ещё не загружены.',
      'failedToLoadFiles': 'Ошибка загрузки файлов',
      'sourceTask': 'Задача',
      'sourceAnswer': 'Ответ',
      'viewText': 'Текст',
      'downloadFile': 'Скачать',
      'downloadAll': 'Скачать всё',
      'nFiles': '{n} файлов',
      'noTextAvailable': 'Текстовое содержимое недоступно.',
    },
  };
}

// ── Localizations Delegate ────────────────────────────────────────────────────
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  static const _supported = {'en', 'he', 'es', 'fr', 'ru'};

  @override
  bool isSupported(Locale locale) =>
      _supported.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
