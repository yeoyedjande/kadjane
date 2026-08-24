// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kadjane';

  @override
  String get appTagline => 'Tontine, with full transparency.';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonStart => 'Get started';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonAll => 'All';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinueLabel => 'Continue';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonNone => 'None';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonDone => 'Done';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonExport => 'Export';

  @override
  String get commonComment => 'Comment';

  @override
  String get commonReference => 'Reference';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonDate => 'Date';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonNoResults => 'No results';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonErrorGeneric => 'Unable to load data. Please try again.';

  @override
  String get commonEmptyTitle => 'Nothing to show';

  @override
  String get commonOfflineTitle => 'You are offline';

  @override
  String get commonOfflineMessage => 'Displayed data may not be up to date.';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonRequiredField => 'This field is required';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonNotAvailable => 'Not available';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignInSubtitle =>
      'Access your tontines and your organization.';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authSignUpSubtitle => 'Join Kadjane in seconds.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPhone => 'Phone';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotPasswordSubtitle =>
      'Enter your phone number to receive a verification code.';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authOtpTitle => 'Verification';

  @override
  String authOtpSubtitle(String target) {
    return 'Enter the 6-digit code sent to $target.';
  }

  @override
  String get authResendCode => 'Resend code';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authResetPasswordTitle => 'New password';

  @override
  String get authResetPasswordSubtitle =>
      'Choose a secure password for your account.';

  @override
  String get authAlreadyHaveAccount => 'Already have an account?';

  @override
  String get authNoAccount => 'No account yet?';

  @override
  String get authLogout => 'Log out';

  @override
  String get authLogoutConfirm => 'Do you really want to log out?';

  @override
  String get authFirstName => 'First name';

  @override
  String get authLastName => 'Last name';

  @override
  String get authInvalidEmail => 'Invalid email';

  @override
  String get authInvalidPhone => 'Invalid phone number';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authChangePassword => 'Change password';

  @override
  String get authCurrentPassword => 'Current password';

  @override
  String get authPasswordChanged => 'Password changed';

  @override
  String get authChangePasswordHint =>
      'If your administrator gave you a temporary password, this is where you replace it.';

  @override
  String get authInvalidCredentials => 'Invalid credentials';

  @override
  String get authInvalidOtp => 'Invalid verification code';

  @override
  String get authDemoHint =>
      'Demo: password kadjane, verification code 123456.';

  @override
  String get onboardingTitle1 => 'Manage your tontine easily';

  @override
  String get onboardingBody1 =>
      'Track contributions, beneficiaries and due dates from your phone.';

  @override
  String get onboardingTitle2 => 'Transparent draws';

  @override
  String get onboardingBody2 =>
      'Run the draws and keep every result recorded automatically.';

  @override
  String get onboardingTitle3 => 'Keep track of everything';

  @override
  String get onboardingBody3 =>
      'Payments, beneficiaries, history and activity stay available.';

  @override
  String get navHome => 'Home';

  @override
  String get navTontines => 'Tontines';

  @override
  String get navContributions => 'Contributions';

  @override
  String get navActivity => 'Activity';

  @override
  String get navProfile => 'Profile';

  @override
  String dashboardGreeting(String name) {
    return 'Hello $name';
  }

  @override
  String get dashboardMembers => 'Members';

  @override
  String get dashboardActiveTontines => 'Active tontines';

  @override
  String get dashboardExpectedThisMonth => 'Expected this month';

  @override
  String get dashboardCollected => 'Collected';

  @override
  String get dashboardRemaining => 'Remaining';

  @override
  String get dashboardLateContributions => 'Late contributions';

  @override
  String get dashboardNextDraw => 'Next draw';

  @override
  String get dashboardCurrentBeneficiary => 'Current beneficiary';

  @override
  String get dashboardUpcomingDeadlines => 'Upcoming deadlines';

  @override
  String get dashboardMyContribution => 'My contribution';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardCollectionProgress => 'Collection progress';

  @override
  String get dashboardContributionsTrend => 'Contributions trend';

  @override
  String get dashboardNoUpcomingDraw => 'No scheduled draw';

  @override
  String get dashboardQuickActions => 'Quick actions';

  @override
  String get membersTitle => 'Members';

  @override
  String get membersAdd => 'Add a member';

  @override
  String get membersDetails => 'Member profile';

  @override
  String get membersRole => 'Role';

  @override
  String get membersJoinedOn => 'Member since';

  @override
  String get membersTotalPaid => 'Amounts paid';

  @override
  String get membersTotalReceived => 'Amounts received';

  @override
  String get membersGender => 'Gender';

  @override
  String get membersMale => 'Male';

  @override
  String get membersFemale => 'Female';

  @override
  String get membersBirthDate => 'Date of birth';

  @override
  String get membersPhoto => 'Photo';

  @override
  String get membersSearchHint => 'Search a member';

  @override
  String get membersEmpty => 'No member yet';

  @override
  String get membersSaved => 'Member saved';

  @override
  String get membersInviteSoon => 'Invitation by link is coming soon';

  @override
  String get membersTontines => 'Member tontines';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get statusPending => 'Pending';

  @override
  String get roleSuperAdmin => 'Super admin';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get rolePresident => 'President';

  @override
  String get roleTreasurer => 'Treasurer';

  @override
  String get roleAuditor => 'Auditor';

  @override
  String get roleMember => 'Member';

  @override
  String get tontinesTitle => 'My tontines';

  @override
  String get tontinesCreate => 'Create a tontine';

  @override
  String get tontinesName => 'Tontine name';

  @override
  String get tontinesDescription => 'Description';

  @override
  String get tontinesContributionAmount => 'Contribution amount';

  @override
  String get tontinesCurrency => 'Currency';

  @override
  String get tontinesFrequency => 'Frequency';

  @override
  String get tontinesStartDate => 'Start date';

  @override
  String get tontinesDueDay => 'Due day';

  @override
  String get tontinesParticipants => 'Participants';

  @override
  String get tontinesEstimatedPot => 'Estimated pot';

  @override
  String get tontinesPot => 'Pot';

  @override
  String get tontinesProgress => 'Progress';

  @override
  String get tontinesEmpty => 'No tontine yet';

  @override
  String get tontinesCreated => 'Tontine created successfully';

  @override
  String get tontinesCyclesCompleted => 'Completed cycles';

  @override
  String get tontinesPreviousBeneficiary => 'Previous beneficiary';

  @override
  String get tontinesNextDraws => 'Upcoming draws';

  @override
  String get tontinesSelectParticipants => 'Select participants';

  @override
  String tontinesParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String tontinesPotFormula(int count, String amount) {
    return '$count members x $amount';
  }

  @override
  String get tontinesStepInfo => 'Information';

  @override
  String get tontinesStepParticipants => 'Participants';

  @override
  String get tontinesStepMode => 'Allocation';

  @override
  String get tontinesStepSummary => 'Summary';

  @override
  String get tontinesTabOverview => 'Overview';

  @override
  String get tontinesTabContributions => 'Contributions';

  @override
  String get tontinesTabDraws => 'Draws';

  @override
  String get tontinesTabParticipants => 'Participants';

  @override
  String get tontinesTabHistory => 'History';

  @override
  String get tontinesTabSettings => 'Settings';

  @override
  String tontinesCycle(int index) {
    return 'Cycle $index';
  }

  @override
  String get tontinesMinParticipants => 'Select at least 2 participants';

  @override
  String get tontineStatusDraft => 'Draft';

  @override
  String get tontineStatusPending => 'Pending';

  @override
  String get tontineStatusActive => 'Active';

  @override
  String get tontineStatusSuspended => 'Suspended';

  @override
  String get tontineStatusCompleted => 'Completed';

  @override
  String get tontineStatusCancelled => 'Cancelled';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyBiweekly => 'Twice a month';

  @override
  String get frequencyMonthly => 'Monthly';

  @override
  String get frequencyCustom => 'Custom';

  @override
  String get allocationMode => 'Allocation mode';

  @override
  String get allocationMonthlyDraw => 'Draw every period';

  @override
  String get allocationMonthlyDrawDesc =>
      'A beneficiary is drawn every period among members who have not received the pot yet.';

  @override
  String get allocationFullOrder => 'Full order by draw';

  @override
  String get allocationFullOrderDesc =>
      'A single draw at the beginning sets the order for every participant.';

  @override
  String get allocationManualOrder => 'Manual order';

  @override
  String get allocationManualOrderDesc =>
      'The administrator defines the order of participants manually.';

  @override
  String get contributionsTitle => 'Contributions';

  @override
  String get contributionsPeriod => 'Period';

  @override
  String get contributionsExpected => 'Expected';

  @override
  String get contributionsCollected => 'Collected';

  @override
  String get contributionsRemaining => 'Remaining';

  @override
  String contributionsPaidMembers(int paid, int total) {
    return '$paid of $total members have paid';
  }

  @override
  String get contributionsRecordPayment => 'Record a payment';

  @override
  String get contributionsPaymentMethod => 'Payment method';

  @override
  String get contributionsProof => 'Proof';

  @override
  String get contributionsAddProof => 'Add a proof';

  @override
  String get contributionsTakePhoto => 'Take a photo';

  @override
  String get contributionsChooseImage => 'Choose an image';

  @override
  String get contributionsViewProof => 'View proof';

  @override
  String get contributionsRecorded => 'Payment recorded';

  @override
  String get contributionsMine => 'My contributions';

  @override
  String get contributionsTotalPaid => 'Total paid';

  @override
  String get contributionsPaymentsCount => 'Payments';

  @override
  String get contributionsUpcoming => 'Upcoming payments';

  @override
  String get contributionsEmpty => 'No contribution recorded';

  @override
  String get contributionsLate => 'Late';

  @override
  String get contributionsSelectMember => 'Member';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get paymentStatusConfirmed => 'Paid';

  @override
  String get paymentStatusRejected => 'Rejected';

  @override
  String get paymentStatusCancelled => 'Cancelled';

  @override
  String get methodWave => 'Wave';

  @override
  String get methodOrangeMoney => 'Orange Money';

  @override
  String get methodMtnMomo => 'MTN MoMo';

  @override
  String get methodMoovMoney => 'Moov Money';

  @override
  String get methodBankTransfer => 'Bank transfer';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodOther => 'Other';

  @override
  String get drawTitle => 'Draw of the period';

  @override
  String get drawSpin => 'Start the draw';

  @override
  String get drawSpinning => 'Drawing...';

  @override
  String drawParticipantsAtStart(int count) {
    return '$count participants at start';
  }

  @override
  String drawRemainingToDraw(int count) {
    return '$count members left to draw';
  }

  @override
  String get drawUnavailable => 'Draw unavailable';

  @override
  String drawUnavailableReason(int count) {
    return '$count contribution(s) still pending.';
  }

  @override
  String get drawConfirmTitle => 'Confirm the draw?';

  @override
  String get drawConfirmMessage =>
      'This operation will permanently designate the beneficiary of the period.';

  @override
  String get drawCongratulations => 'Congratulations!';

  @override
  String drawBeneficiaryOf(String period) {
    return 'is the beneficiary for $period.';
  }

  @override
  String get drawViewResult => 'View result';

  @override
  String get drawHistory => 'Draw history';

  @override
  String get drawLaunchedBy => 'Launched by';

  @override
  String get drawReference => 'Reference';

  @override
  String get drawEligibleParticipants => 'Eligible participants';

  @override
  String get drawNoEligible => 'No eligible participant for this draw';

  @override
  String get drawOverrideTitle => 'Force the draw';

  @override
  String get drawOverrideMessage =>
      'The rules require every contribution to be paid. Forcing the draw will be recorded in the audit log.';

  @override
  String get drawOverrideReason => 'Override reason';

  @override
  String get drawOverrideUsed => 'Draw forced by an administrator';

  @override
  String get drawCancelAction => 'Cancel the draw';

  @override
  String get drawInvalidate => 'Invalidate the draw';

  @override
  String get drawInvalidateReason => 'Invalidation reason';

  @override
  String get drawAlreadyDone => 'The draw for this period has already been run';

  @override
  String get drawNoPermission => 'You are not allowed to run a draw';

  @override
  String get drawOrderGenerated => 'Order generated';

  @override
  String drawScheduledOn(String date) {
    return 'Draw scheduled on $date';
  }

  @override
  String get drawStatusScheduled => 'Scheduled';

  @override
  String get drawStatusCompleted => 'Validated';

  @override
  String get drawStatusCancelled => 'Cancelled';

  @override
  String get drawStatusInvalidated => 'Invalidated';

  @override
  String get beneficiaryTitle => 'Beneficiary of the period';

  @override
  String get beneficiaryPayout => 'Payout';

  @override
  String get beneficiaryRecordPayout => 'Record the payout';

  @override
  String get beneficiaryAmountSent => 'Amount sent';

  @override
  String get beneficiaryPayoutRecorded => 'Payout recorded';

  @override
  String get beneficiaryStepContributions => 'Contributions';

  @override
  String get beneficiaryStepPot => 'Pot complete';

  @override
  String get beneficiaryStepDraw => 'Draw';

  @override
  String get beneficiaryStepBeneficiary => 'Beneficiary';

  @override
  String get beneficiaryStepPayout => 'Payout';

  @override
  String get beneficiaryStepConfirmation => 'Confirmation';

  @override
  String get beneficiaryNone => 'No beneficiary designated';

  @override
  String get payoutStatusPending => 'Pending';

  @override
  String get payoutStatusProcessing => 'Processing';

  @override
  String get payoutStatusPaid => 'Paid';

  @override
  String get payoutStatusFailed => 'Failed';

  @override
  String get positionTitle => 'My position';

  @override
  String get positionNotReceived => 'You have not received your pot yet.';

  @override
  String positionRemaining(int remaining, int total) {
    return 'Participants left to draw: $remaining / $total.';
  }

  @override
  String positionReceivedIn(String period) {
    return 'You received your pot in $period.';
  }

  @override
  String get positionKeepContributing =>
      'You must keep contributing until the end of the tontine.';

  @override
  String positionOrder(int position) {
    return 'Your turn: position $position';
  }

  @override
  String positionEstimatedPeriod(String period) {
    return 'Estimated period: $period';
  }

  @override
  String get positionNotParticipant => 'You do not take part in this tontine.';

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityEmpty => 'No activity recorded';

  @override
  String get activityAudit => 'Audit log';

  @override
  String get activityToday => 'Today';

  @override
  String get activityYesterday => 'Yesterday';

  @override
  String get activityEarlier => 'Earlier';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsEmpty => 'No notification';

  @override
  String get treasuryTitle => 'Treasury';

  @override
  String get treasuryBalance => 'Balance';

  @override
  String get treasuryInflows => 'Inflows';

  @override
  String get treasuryOutflows => 'Outflows';

  @override
  String get treasuryAddTransaction => 'New operation';

  @override
  String get treasuryType => 'Operation type';

  @override
  String get treasuryIncome => 'Income';

  @override
  String get treasuryExpense => 'Expense';

  @override
  String get treasuryCategory => 'Category';

  @override
  String get treasuryEmpty => 'No treasury operation';

  @override
  String get treasurySaved => 'Operation saved';

  @override
  String get treasuryCashboxes => 'Cashboxes';

  @override
  String get treasuryCashboxCreate => 'Create a cashbox';

  @override
  String get treasuryCashboxName => 'Cashbox name';

  @override
  String get treasuryOpeningBalance => 'Opening balance';

  @override
  String get treasuryCashboxSaved => 'Cashbox opened';

  @override
  String get treasuryMonthFlows => 'This month';

  @override
  String get treasuryExpected => 'Expected';

  @override
  String get treasuryCollected => 'Collected';

  @override
  String get treasuryRemaining => 'Left to collect';

  @override
  String get treasuryLate => 'Overdue';

  @override
  String get treasuryRecoveryRate => 'Recovery';

  @override
  String get campaignsTitle => 'Contributions';

  @override
  String get campaignsCreate => 'New contribution';

  @override
  String get campaignsEmpty =>
      'No contribution yet. A contribution is a commitment: the cashbox only grows once a member pays.';

  @override
  String get campaignTitleField => 'Title';

  @override
  String get campaignType => 'Kind';

  @override
  String get campaignTypeAssociation => 'Association';

  @override
  String get campaignTypeExceptional => 'Exceptional';

  @override
  String get campaignTypeVoluntary => 'Voluntary';

  @override
  String get campaignAmountMode => 'Amount';

  @override
  String get campaignAmountFixed => 'Fixed amount';

  @override
  String get campaignAmountFree => 'Free amount';

  @override
  String get campaignAmountPerMember => 'Amount per member';

  @override
  String get campaignDueDate => 'Due date';

  @override
  String get campaignCashbox => 'Destination cashbox';

  @override
  String get campaignMembers => 'Members concerned';

  @override
  String get campaignAllMembers => 'All active members';

  @override
  String get campaignMandatory => 'Mandatory';

  @override
  String get campaignCreated => 'Contribution created';

  @override
  String campaignMembersCount(int count) {
    return '$count member(s)';
  }

  @override
  String get campaignPay => 'Record a payment';

  @override
  String get campaignPaymentAmount => 'Amount received';

  @override
  String get campaignPaymentMethod => 'Payment method';

  @override
  String get campaignPaymentReference => 'Reference';

  @override
  String get campaignPaymentSaved =>
      'Payment recorded and posted to the cashbox';

  @override
  String get campaignExempt => 'Exempt';

  @override
  String get campaignExemptReason => 'Exemption reason';

  @override
  String get campaignExempted => 'Member exempted';

  @override
  String campaignPaidOf(String paid, String expected) {
    return '$paid of $expected';
  }

  @override
  String get unpaidTitle => 'Unpaid';

  @override
  String get unpaidEmpty =>
      'Nothing unpaid. Everything expected has been collected.';

  @override
  String unpaidDaysLate(int days) {
    return '$days day(s) overdue';
  }

  @override
  String get roleLabel => 'Role';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsTotalContributions => 'Total contributions';

  @override
  String get reportsUnpaid => 'Unpaid';

  @override
  String get reportsRecoveryRate => 'Recovery rate';

  @override
  String get reportsDistributed => 'Distributed amounts';

  @override
  String get reportsExportPdf => 'Export as PDF';

  @override
  String get reportsExportExcel => 'Export as Excel';

  @override
  String get reportsExportMocked =>
      'Mocked export: backend integration coming soon.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMyOrganizations => 'My organizations';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profileSecurity => 'Security';

  @override
  String get profileTheme => 'Theme';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileThemeSystem => 'System';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileFrench => 'French';

  @override
  String get profileEnglish => 'English';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileEdit => 'Edit my profile';

  @override
  String get profileVersion => 'Version';

  @override
  String get profileSaved => 'Profile updated';

  @override
  String get orgSettingsTitle => 'Organization settings';

  @override
  String get orgName => 'Organization name';

  @override
  String get orgLogo => 'Logo';

  @override
  String get orgCountry => 'Country';

  @override
  String get orgAddress => 'Address';

  @override
  String get orgRules => 'Rules';

  @override
  String get orgOfficers => 'Officers';

  @override
  String get orgSwitch => 'Switch organization';

  @override
  String get orgCreate => 'Create an organization';

  @override
  String get orgRequireFullPayment =>
      'Require all contributions before the draw';

  @override
  String get orgAllowOverride => 'Allow forcing the draw';

  @override
  String get orgGraceDays => 'Grace days before late';

  @override
  String get orgSaved => 'Organization updated';

  @override
  String get orgNoPermission => 'Action not allowed for your role';

  @override
  String get adminTitle => 'Kadjane Admin';

  @override
  String get adminConsole => 'Administration console';

  @override
  String get adminNavOverview => 'Overview';

  @override
  String get adminNavMembers => 'Members';

  @override
  String get adminNavRoles => 'Roles and permissions';

  @override
  String get adminNavReminders => 'Reminders';

  @override
  String get adminNavTontines => 'Tontines';

  @override
  String get adminNavAudit => 'Audit';

  @override
  String get adminNavSettings => 'Settings';

  @override
  String get adminCollectionRate => 'Recovery rate';

  @override
  String get adminOutstanding => 'Outstanding amount';

  @override
  String get adminAlerts => 'Attention points';

  @override
  String get adminNoAlerts => 'Nothing needs attention';

  @override
  String adminAlertLateMembers(int count) {
    return '$count member(s) late on contributions';
  }

  @override
  String adminAlertBlockedDraw(int count) {
    return '$count draw(s) blocked by unpaid contributions';
  }

  @override
  String adminAlertPendingPayout(int count) {
    return '$count payout(s) pending';
  }

  @override
  String get adminSearch => 'Search';

  @override
  String adminSelected(int count) {
    return '$count selected';
  }

  @override
  String get adminChangeRole => 'Change role';

  @override
  String get adminMemberUpdated => 'Member updated';

  @override
  String get adminRoleMatrix => 'Permission matrix';

  @override
  String get adminRoleMatrixHint =>
      'Tick the rights granted to each role. Changes apply immediately, on mobile as well as in the console.';

  @override
  String get adminRoleReset => 'Restore default rights';

  @override
  String get adminRoleSaved => 'Permissions updated';

  @override
  String get adminRoleCustomized => 'Customized';

  @override
  String get adminRoleDefault => 'Default';

  @override
  String adminPermissionsCount(int count) {
    return '$count rights';
  }

  @override
  String adminMembersWithRole(int count) {
    return '$count member(s)';
  }

  @override
  String get adminOpenMobileHint =>
      'Roles defined here also drive the mobile application.';

  @override
  String get permModuleOrganization => 'Organization';

  @override
  String get permModuleMember => 'Members';

  @override
  String get permModuleTontine => 'Tontines';

  @override
  String get permModuleContribution => 'Contributions';

  @override
  String get permModuleDraw => 'Draws';

  @override
  String get permModulePayout => 'Payouts';

  @override
  String get permModuleTreasury => 'Treasury';

  @override
  String get permModuleReport => 'Reports';

  @override
  String get permModuleAudit => 'Audit';

  @override
  String get permModuleReminder => 'Reminders';

  @override
  String get permActionView => 'View';

  @override
  String get permActionEdit => 'Edit';

  @override
  String get permActionCreate => 'Create';

  @override
  String get permActionManageOfficers => 'Manage officers';

  @override
  String get permActionInvite => 'Invite';

  @override
  String get permActionValidate => 'Validate';

  @override
  String get permActionRecord => 'Record';

  @override
  String get permActionConfirm => 'Confirm';

  @override
  String get permActionCancel => 'Cancel';

  @override
  String get permActionRun => 'Run';

  @override
  String get permActionOverride => 'Override';

  @override
  String get permActionInvalidate => 'Invalidate';

  @override
  String get permActionManage => 'Manage';

  @override
  String get permActionSend => 'Send';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersCenter => 'Reminder center';

  @override
  String get remindersToRemind => 'To remind';

  @override
  String get remindersSend => 'Send reminders';

  @override
  String get remindersSendShort => 'Remind';

  @override
  String get remindersChannel => 'Channel';

  @override
  String get remindersChannelInApp => 'Notification';

  @override
  String get remindersChannelSms => 'SMS';

  @override
  String get remindersChannelWhatsapp => 'WhatsApp';

  @override
  String get remindersChannelEmail => 'Email';

  @override
  String get remindersChannelPush => 'Push';

  @override
  String get remindersLevelUpcoming => 'Due soon';

  @override
  String get remindersLevelDueToday => 'Due today';

  @override
  String get remindersLevelLate => 'Late';

  @override
  String get remindersLevelEscalated => 'Critically late';

  @override
  String get remindersMessage => 'Message';

  @override
  String get remindersPreview => 'Message preview';

  @override
  String remindersSentCount(int count) {
    return '$count reminder(s) sent';
  }

  @override
  String get remindersHistory => 'Reminder history';

  @override
  String get remindersNoTargets => 'No unpaid contribution: nothing to remind';

  @override
  String get remindersNoHistory => 'No reminder sent';

  @override
  String get remindersMine => 'My reminders';

  @override
  String get remindersReceived => 'Reminder received';

  @override
  String remindersLastSent(String date) {
    return 'Last reminder: $date';
  }

  @override
  String get remindersStatusQueued => 'Queued';

  @override
  String get remindersStatusSent => 'Sent';

  @override
  String get remindersStatusRead => 'Read';

  @override
  String get remindersStatusFailed => 'Failed';

  @override
  String get remindersCampaign => 'Campaign';

  @override
  String get remindersTargets => 'Recipients';

  @override
  String get remindersAudited =>
      'Every reminder is timestamped and recorded in the audit log.';

  @override
  String get remindersSelectAll => 'Select all';

  @override
  String remindersDaysLate(int count) {
    return '$count day(s) late';
  }

  @override
  String get remindersConfirmTitle => 'Send reminders?';

  @override
  String remindersConfirmMessage(int count) {
    return '$count member(s) will be notified on the selected channels.';
  }

  @override
  String get duesTitle => 'Fund contributions';

  @override
  String get duesTotalDue => 'Total due';

  @override
  String get duesAllSettled =>
      'You are up to date with your fund contributions.';

  @override
  String duesUnpaidCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instalments',
      one: '1 instalment',
      zero: 'no instalment',
    );
    return '$_temp0';
  }

  @override
  String duesDueOn(String date) {
    return 'due on $date';
  }

  @override
  String get duesCollectTitle => 'Collect contributions';

  @override
  String get duesNoPlan =>
      'No fund contribution is defined for this organisation.';

  @override
  String get duesOnlyUnpaid => 'Unpaid only';

  @override
  String get duesNothingToCollect => 'Nothing to collect for this period.';

  @override
  String get duesPerMember => 'per member';

  @override
  String get duesCollected => 'Collected';

  @override
  String get duesUnpaidLabel => 'Unpaid';

  @override
  String get duesPaymentRecorded => 'Payment recorded';
}
