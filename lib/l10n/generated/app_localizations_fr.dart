// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Kadjane';

  @override
  String get appTagline => 'La tontine, en toute transparence.';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSkip => 'Passer';

  @override
  String get commonStart => 'Commencer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonFilter => 'Filtrer';

  @override
  String get commonAll => 'Tous';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonSeeAll => 'Tout voir';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonContinueLabel => 'Continuer';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonNone => 'Aucun';

  @override
  String get commonOptional => 'Facultatif';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonExport => 'Exporter';

  @override
  String get commonComment => 'Commentaire';

  @override
  String get commonReference => 'Référence';

  @override
  String get commonAmount => 'Montant';

  @override
  String get commonDate => 'Date';

  @override
  String get commonStatus => 'Statut';

  @override
  String get commonDetails => 'Détails';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get commonNoResults => 'Aucun résultat';

  @override
  String get commonErrorTitle => 'Une erreur est survenue';

  @override
  String get commonErrorGeneric =>
      'Impossible de charger les données. Veuillez réessayer.';

  @override
  String get commonEmptyTitle => 'Rien à afficher';

  @override
  String get commonOfflineTitle => 'Vous êtes hors ligne';

  @override
  String get commonOfflineMessage =>
      'Les données affichées peuvent ne pas être à jour.';

  @override
  String get commonComingSoon => 'Bientôt disponible';

  @override
  String get commonRequiredField => 'Ce champ est obligatoire';

  @override
  String get commonSelect => 'Sélectionner';

  @override
  String get commonNotAvailable => 'Non disponible';

  @override
  String get authSignIn => 'Connexion';

  @override
  String get authSignInSubtitle =>
      'Accédez à vos tontines et à votre organisation.';

  @override
  String get authSignUp => 'Créer un compte';

  @override
  String get authSignUpSubtitle => 'Rejoignez Kadjane en quelques secondes.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPhone => 'Téléphone';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authForgotPasswordSubtitle =>
      'Saisissez votre numéro de téléphone pour recevoir un code de vérification.';

  @override
  String get authSendCode => 'Envoyer le code';

  @override
  String get authOtpTitle => 'Vérification';

  @override
  String authOtpSubtitle(String target) {
    return 'Saisissez le code à 6 chiffres envoyé au $target.';
  }

  @override
  String get authResendCode => 'Renvoyer le code';

  @override
  String get authNewPassword => 'Nouveau mot de passe';

  @override
  String get authResetPasswordTitle => 'Nouveau mot de passe';

  @override
  String get authResetPasswordSubtitle =>
      'Choisissez un mot de passe sécurisé pour votre compte.';

  @override
  String get authAlreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get authNoAccount => 'Pas encore de compte ?';

  @override
  String get authLogout => 'Se déconnecter';

  @override
  String get authLogoutConfirm => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get authFirstName => 'Prénom';

  @override
  String get authLastName => 'Nom';

  @override
  String get authInvalidEmail => 'Email invalide';

  @override
  String get authInvalidPhone => 'Numéro de téléphone invalide';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get authPasswordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get authInvalidCredentials => 'Identifiants incorrects';

  @override
  String get authInvalidOtp => 'Code de vérification incorrect';

  @override
  String get authDemoHint =>
      'Démo : mot de passe kadjane, code de vérification 123456.';

  @override
  String get onboardingTitle1 => 'Gérez votre tontine simplement';

  @override
  String get onboardingBody1 =>
      'Suivez les cotisations, bénéficiaires et échéances depuis votre téléphone.';

  @override
  String get onboardingTitle2 => 'Des tirages transparents';

  @override
  String get onboardingBody2 =>
      'Effectuez les tirages au sort et conservez automatiquement les résultats.';

  @override
  String get onboardingTitle3 => 'Gardez une trace de tout';

  @override
  String get onboardingBody3 =>
      'Paiements, bénéficiaires, historiques et activités restent accessibles.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navTontines => 'Tontines';

  @override
  String get navContributions => 'Cotisations';

  @override
  String get navActivity => 'Activités';

  @override
  String get navProfile => 'Profil';

  @override
  String dashboardGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String get dashboardMembers => 'Membres';

  @override
  String get dashboardActiveTontines => 'Tontines actives';

  @override
  String get dashboardExpectedThisMonth => 'Attendu ce mois';

  @override
  String get dashboardCollected => 'Collecté';

  @override
  String get dashboardRemaining => 'Restant';

  @override
  String get dashboardLateContributions => 'Cotisations en retard';

  @override
  String get dashboardNextDraw => 'Prochain tirage';

  @override
  String get dashboardCurrentBeneficiary => 'Bénéficiaire actuel';

  @override
  String get dashboardUpcomingDeadlines => 'Prochaines échéances';

  @override
  String get dashboardMyContribution => 'Ma cotisation';

  @override
  String get dashboardRecentActivity => 'Activité récente';

  @override
  String get dashboardCollectionProgress => 'Progression de la collecte';

  @override
  String get dashboardContributionsTrend => 'Évolution des cotisations';

  @override
  String get dashboardNoUpcomingDraw => 'Aucun tirage programmé';

  @override
  String get dashboardQuickActions => 'Accès rapide';

  @override
  String get membersTitle => 'Membres';

  @override
  String get membersAdd => 'Ajouter un membre';

  @override
  String get membersDetails => 'Fiche du membre';

  @override
  String get membersRole => 'Rôle';

  @override
  String get membersJoinedOn => 'Membre depuis';

  @override
  String get membersTotalPaid => 'Sommes versées';

  @override
  String get membersTotalReceived => 'Sommes reçues';

  @override
  String get membersGender => 'Sexe';

  @override
  String get membersMale => 'Homme';

  @override
  String get membersFemale => 'Femme';

  @override
  String get membersBirthDate => 'Date de naissance';

  @override
  String get membersPhoto => 'Photo';

  @override
  String get membersSearchHint => 'Rechercher un membre';

  @override
  String get membersEmpty => 'Aucun membre pour le moment';

  @override
  String get membersSaved => 'Membre enregistré';

  @override
  String get membersInviteSoon =>
      'Invitation par lien disponible prochainement';

  @override
  String get membersTontines => 'Tontines du membre';

  @override
  String get statusActive => 'Actif';

  @override
  String get statusInactive => 'Inactif';

  @override
  String get statusSuspended => 'Suspendu';

  @override
  String get statusPending => 'En attente';

  @override
  String get roleSuperAdmin => 'Super Admin';

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get rolePresident => 'Président';

  @override
  String get roleTreasurer => 'Trésorier';

  @override
  String get roleAuditor => 'Commissaire aux comptes';

  @override
  String get roleMember => 'Membre';

  @override
  String get tontinesTitle => 'Mes tontines';

  @override
  String get tontinesCreate => 'Créer une tontine';

  @override
  String get tontinesName => 'Nom de la tontine';

  @override
  String get tontinesDescription => 'Description';

  @override
  String get tontinesContributionAmount => 'Montant de la cotisation';

  @override
  String get tontinesCurrency => 'Devise';

  @override
  String get tontinesFrequency => 'Fréquence';

  @override
  String get tontinesStartDate => 'Date de début';

  @override
  String get tontinesDueDay => 'Jour d\'échéance';

  @override
  String get tontinesParticipants => 'Participants';

  @override
  String get tontinesEstimatedPot => 'Cagnotte estimée';

  @override
  String get tontinesPot => 'Cagnotte';

  @override
  String get tontinesProgress => 'Progression';

  @override
  String get tontinesEmpty => 'Aucune tontine pour le moment';

  @override
  String get tontinesCreated => 'Tontine créée avec succès';

  @override
  String get tontinesCyclesCompleted => 'Cycles terminés';

  @override
  String get tontinesPreviousBeneficiary => 'Bénéficiaire précédent';

  @override
  String get tontinesNextDraws => 'Prochains tirages';

  @override
  String get tontinesSelectParticipants => 'Sélectionner les participants';

  @override
  String tontinesParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String tontinesPotFormula(int count, String amount) {
    return '$count membres x $amount';
  }

  @override
  String get tontinesStepInfo => 'Informations';

  @override
  String get tontinesStepParticipants => 'Participants';

  @override
  String get tontinesStepMode => 'Attribution';

  @override
  String get tontinesStepSummary => 'Récapitulatif';

  @override
  String get tontinesTabOverview => 'Vue d\'ensemble';

  @override
  String get tontinesTabContributions => 'Cotisations';

  @override
  String get tontinesTabDraws => 'Tirages';

  @override
  String get tontinesTabParticipants => 'Participants';

  @override
  String get tontinesTabHistory => 'Historique';

  @override
  String get tontinesTabSettings => 'Paramètres';

  @override
  String tontinesCycle(int index) {
    return 'Cycle $index';
  }

  @override
  String get tontinesMinParticipants => 'Sélectionnez au moins 2 participants';

  @override
  String get tontineStatusDraft => 'Brouillon';

  @override
  String get tontineStatusPending => 'En attente';

  @override
  String get tontineStatusActive => 'Active';

  @override
  String get tontineStatusSuspended => 'Suspendue';

  @override
  String get tontineStatusCompleted => 'Terminée';

  @override
  String get tontineStatusCancelled => 'Annulée';

  @override
  String get frequencyWeekly => 'Hebdomadaire';

  @override
  String get frequencyBiweekly => 'Bimensuelle';

  @override
  String get frequencyMonthly => 'Mensuelle';

  @override
  String get frequencyCustom => 'Personnalisée';

  @override
  String get allocationMode => 'Mode d\'attribution';

  @override
  String get allocationMonthlyDraw => 'Tirage à chaque période';

  @override
  String get allocationMonthlyDrawDesc =>
      'Un bénéficiaire est tiré au sort à chaque période parmi les membres n\'ayant pas encore reçu la cagnotte.';

  @override
  String get allocationFullOrder => 'Ordre complet par tirage';

  @override
  String get allocationFullOrderDesc =>
      'Un tirage unique en début de tontine fixe l\'ordre de passage de tous les participants.';

  @override
  String get allocationManualOrder => 'Ordre manuel';

  @override
  String get allocationManualOrderDesc =>
      'L\'administrateur définit lui-même l\'ordre de passage des participants.';

  @override
  String get contributionsTitle => 'Cotisations';

  @override
  String get contributionsPeriod => 'Période';

  @override
  String get contributionsExpected => 'Attendu';

  @override
  String get contributionsCollected => 'Collecté';

  @override
  String get contributionsRemaining => 'Restant';

  @override
  String contributionsPaidMembers(int paid, int total) {
    return '$paid membres sur $total ont payé';
  }

  @override
  String get contributionsRecordPayment => 'Enregistrer un paiement';

  @override
  String get contributionsPaymentMethod => 'Moyen de paiement';

  @override
  String get contributionsProof => 'Justificatif';

  @override
  String get contributionsAddProof => 'Ajouter un justificatif';

  @override
  String get contributionsTakePhoto => 'Prendre une photo';

  @override
  String get contributionsChooseImage => 'Choisir une image';

  @override
  String get contributionsViewProof => 'Voir le justificatif';

  @override
  String get contributionsRecorded => 'Paiement enregistré';

  @override
  String get contributionsMine => 'Mes cotisations';

  @override
  String get contributionsTotalPaid => 'Total versé';

  @override
  String get contributionsPaymentsCount => 'Paiements';

  @override
  String get contributionsUpcoming => 'Prochains paiements';

  @override
  String get contributionsEmpty => 'Aucune cotisation enregistrée';

  @override
  String get contributionsLate => 'En retard';

  @override
  String get contributionsSelectMember => 'Membre';

  @override
  String get paymentStatusPending => 'En attente';

  @override
  String get paymentStatusConfirmed => 'Payé';

  @override
  String get paymentStatusRejected => 'Rejeté';

  @override
  String get paymentStatusCancelled => 'Annulé';

  @override
  String get methodWave => 'Wave';

  @override
  String get methodOrangeMoney => 'Orange Money';

  @override
  String get methodMtnMomo => 'MTN MoMo';

  @override
  String get methodMoovMoney => 'Moov Money';

  @override
  String get methodBankTransfer => 'Virement bancaire';

  @override
  String get methodCash => 'Espèces';

  @override
  String get methodOther => 'Autre';

  @override
  String get drawTitle => 'Tirage du mois';

  @override
  String get drawSpin => 'Lancer le tirage';

  @override
  String get drawSpinning => 'Tirage en cours...';

  @override
  String drawParticipantsAtStart(int count) {
    return '$count participants au départ';
  }

  @override
  String drawRemainingToDraw(int count) {
    return '$count membres restent à tirer';
  }

  @override
  String get drawUnavailable => 'Tirage indisponible';

  @override
  String drawUnavailableReason(int count) {
    return '$count cotisation(s) restent à régler.';
  }

  @override
  String get drawConfirmTitle => 'Confirmer le tirage ?';

  @override
  String get drawConfirmMessage =>
      'Cette opération désignera définitivement le bénéficiaire de la période.';

  @override
  String get drawCongratulations => 'Félicitations !';

  @override
  String drawBeneficiaryOf(String period) {
    return 'est le bénéficiaire de la période $period.';
  }

  @override
  String get drawViewResult => 'Voir le résultat';

  @override
  String get drawHistory => 'Historique des tirages';

  @override
  String get drawLaunchedBy => 'Lancé par';

  @override
  String get drawReference => 'Référence';

  @override
  String get drawEligibleParticipants => 'Participants éligibles';

  @override
  String get drawNoEligible => 'Aucun participant éligible pour ce tirage';

  @override
  String get drawOverrideTitle => 'Forcer le tirage';

  @override
  String get drawOverrideMessage =>
      'Le règlement exige que toutes les cotisations soient réglées. Forcer le tirage sera enregistré dans l\'audit.';

  @override
  String get drawOverrideReason => 'Motif du forçage';

  @override
  String get drawOverrideUsed => 'Tirage forcé par un administrateur';

  @override
  String get drawCancelAction => 'Annuler le tirage';

  @override
  String get drawInvalidate => 'Invalider le tirage';

  @override
  String get drawInvalidateReason => 'Motif de l\'invalidation';

  @override
  String get drawAlreadyDone =>
      'Le tirage de cette période a déjà été effectué';

  @override
  String get drawNoPermission =>
      'Vous n\'avez pas la permission de lancer un tirage';

  @override
  String get drawOrderGenerated => 'Ordre de passage généré';

  @override
  String drawScheduledOn(String date) {
    return 'Tirage prévu le $date';
  }

  @override
  String get drawStatusScheduled => 'Programmé';

  @override
  String get drawStatusCompleted => 'Validé';

  @override
  String get drawStatusCancelled => 'Annulé';

  @override
  String get drawStatusInvalidated => 'Invalidé';

  @override
  String get beneficiaryTitle => 'Bénéficiaire de la période';

  @override
  String get beneficiaryPayout => 'Versement';

  @override
  String get beneficiaryRecordPayout => 'Enregistrer le versement';

  @override
  String get beneficiaryAmountSent => 'Montant envoyé';

  @override
  String get beneficiaryPayoutRecorded => 'Versement enregistré';

  @override
  String get beneficiaryStepContributions => 'Cotisations';

  @override
  String get beneficiaryStepPot => 'Cagnotte complète';

  @override
  String get beneficiaryStepDraw => 'Tirage';

  @override
  String get beneficiaryStepBeneficiary => 'Bénéficiaire';

  @override
  String get beneficiaryStepPayout => 'Versement';

  @override
  String get beneficiaryStepConfirmation => 'Confirmation';

  @override
  String get beneficiaryNone => 'Aucun bénéficiaire désigné';

  @override
  String get payoutStatusPending => 'En attente';

  @override
  String get payoutStatusProcessing => 'En cours';

  @override
  String get payoutStatusPaid => 'Versé';

  @override
  String get payoutStatusFailed => 'Échoué';

  @override
  String get positionTitle => 'Ma position';

  @override
  String get positionNotReceived =>
      'Vous n\'avez pas encore reçu votre cagnotte.';

  @override
  String positionRemaining(int remaining, int total) {
    return 'Participants restant à tirer : $remaining / $total.';
  }

  @override
  String positionReceivedIn(String period) {
    return 'Vous avez reçu votre cagnotte en $period.';
  }

  @override
  String get positionKeepContributing =>
      'Vous devez continuer vos cotisations jusqu\'à la fin de la tontine.';

  @override
  String positionOrder(int position) {
    return 'Votre passage : position $position';
  }

  @override
  String positionEstimatedPeriod(String period) {
    return 'Période estimée : $period';
  }

  @override
  String get positionNotParticipant =>
      'Vous ne participez pas à cette tontine.';

  @override
  String get activityTitle => 'Activités';

  @override
  String get activityEmpty => 'Aucune activité enregistrée';

  @override
  String get activityAudit => 'Journal d\'audit';

  @override
  String get activityToday => 'Aujourd\'hui';

  @override
  String get activityYesterday => 'Hier';

  @override
  String get activityEarlier => 'Plus tôt';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationsEmpty => 'Aucune notification';

  @override
  String get treasuryTitle => 'Caisse';

  @override
  String get treasuryBalance => 'Solde';

  @override
  String get treasuryInflows => 'Entrées';

  @override
  String get treasuryOutflows => 'Sorties';

  @override
  String get treasuryAddTransaction => 'Nouvelle opération';

  @override
  String get treasuryType => 'Type d\'opération';

  @override
  String get treasuryIncome => 'Entrée';

  @override
  String get treasuryExpense => 'Sortie';

  @override
  String get treasuryCategory => 'Catégorie';

  @override
  String get treasuryEmpty => 'Aucune opération de caisse';

  @override
  String get treasurySaved => 'Opération enregistrée';

  @override
  String get reportsTitle => 'Rapports';

  @override
  String get reportsTotalContributions => 'Total cotisations';

  @override
  String get reportsUnpaid => 'Impayés';

  @override
  String get reportsRecoveryRate => 'Taux de recouvrement';

  @override
  String get reportsDistributed => 'Sommes distribuées';

  @override
  String get reportsExportPdf => 'Exporter en PDF';

  @override
  String get reportsExportExcel => 'Exporter en Excel';

  @override
  String get reportsExportMocked =>
      'Export simulé : intégration backend à venir.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMyOrganizations => 'Mes organisations';

  @override
  String get profilePreferences => 'Préférences';

  @override
  String get profileSecurity => 'Sécurité';

  @override
  String get profileTheme => 'Thème';

  @override
  String get profileThemeLight => 'Clair';

  @override
  String get profileThemeDark => 'Sombre';

  @override
  String get profileThemeSystem => 'Système';

  @override
  String get profileLanguage => 'Langue';

  @override
  String get profileFrench => 'Français';

  @override
  String get profileEnglish => 'Anglais';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileEdit => 'Modifier mon profil';

  @override
  String get profileVersion => 'Version';

  @override
  String get profileSaved => 'Profil mis à jour';

  @override
  String get orgSettingsTitle => 'Paramètres de l\'organisation';

  @override
  String get orgName => 'Nom de l\'organisation';

  @override
  String get orgLogo => 'Logo';

  @override
  String get orgCountry => 'Pays';

  @override
  String get orgAddress => 'Adresse';

  @override
  String get orgRules => 'Règles';

  @override
  String get orgOfficers => 'Responsables';

  @override
  String get orgSwitch => 'Changer d\'organisation';

  @override
  String get orgCreate => 'Créer une organisation';

  @override
  String get orgRequireFullPayment =>
      'Exiger toutes les cotisations avant le tirage';

  @override
  String get orgAllowOverride => 'Autoriser le forçage du tirage';

  @override
  String get orgGraceDays => 'Jours de tolérance avant retard';

  @override
  String get orgSaved => 'Organisation mise à jour';

  @override
  String get orgNoPermission => 'Action non autorisée pour votre rôle';

  @override
  String get adminTitle => 'Kadjane Admin';

  @override
  String get adminConsole => 'Console d\'administration';

  @override
  String get adminNavOverview => 'Vue d\'ensemble';

  @override
  String get adminNavMembers => 'Membres';

  @override
  String get adminNavRoles => 'Rôles et permissions';

  @override
  String get adminNavReminders => 'Relances';

  @override
  String get adminNavTontines => 'Tontines';

  @override
  String get adminNavAudit => 'Audit';

  @override
  String get adminNavSettings => 'Paramètres';

  @override
  String get adminCollectionRate => 'Taux de recouvrement';

  @override
  String get adminOutstanding => 'Encours impayé';

  @override
  String get adminAlerts => 'Points de vigilance';

  @override
  String get adminNoAlerts => 'Aucun point de vigilance';

  @override
  String adminAlertLateMembers(int count) {
    return '$count membre(s) en retard de cotisation';
  }

  @override
  String adminAlertBlockedDraw(int count) {
    return '$count tirage(s) bloqué(s) par des impayés';
  }

  @override
  String adminAlertPendingPayout(int count) {
    return '$count versement(s) en attente';
  }

  @override
  String get adminSearch => 'Rechercher';

  @override
  String adminSelected(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get adminChangeRole => 'Changer le rôle';

  @override
  String get adminMemberUpdated => 'Membre mis à jour';

  @override
  String get adminRoleMatrix => 'Matrice des permissions';

  @override
  String get adminRoleMatrixHint =>
      'Cochez les droits accordés à chaque rôle. La modification s\'applique immédiatement, sur mobile comme sur la console.';

  @override
  String get adminRoleReset => 'Rétablir les droits par défaut';

  @override
  String get adminRoleSaved => 'Permissions mises à jour';

  @override
  String get adminRoleCustomized => 'Personnalisé';

  @override
  String get adminRoleDefault => 'Par défaut';

  @override
  String adminPermissionsCount(int count) {
    return '$count droits';
  }

  @override
  String adminMembersWithRole(int count) {
    return '$count membre(s)';
  }

  @override
  String get adminOpenMobileHint =>
      'Les rôles définis ici pilotent aussi l\'application mobile.';

  @override
  String get permModuleOrganization => 'Organisation';

  @override
  String get permModuleMember => 'Membres';

  @override
  String get permModuleTontine => 'Tontines';

  @override
  String get permModuleContribution => 'Cotisations';

  @override
  String get permModuleDraw => 'Tirages';

  @override
  String get permModulePayout => 'Versements';

  @override
  String get permModuleTreasury => 'Caisse';

  @override
  String get permModuleReport => 'Rapports';

  @override
  String get permModuleAudit => 'Audit';

  @override
  String get permModuleReminder => 'Relances';

  @override
  String get permActionView => 'Consulter';

  @override
  String get permActionEdit => 'Modifier';

  @override
  String get permActionCreate => 'Créer';

  @override
  String get permActionManageOfficers => 'Gérer le bureau';

  @override
  String get permActionInvite => 'Inviter';

  @override
  String get permActionValidate => 'Valider';

  @override
  String get permActionRecord => 'Enregistrer';

  @override
  String get permActionConfirm => 'Confirmer';

  @override
  String get permActionCancel => 'Annuler';

  @override
  String get permActionRun => 'Lancer';

  @override
  String get permActionOverride => 'Forcer';

  @override
  String get permActionInvalidate => 'Invalider';

  @override
  String get permActionManage => 'Gérer';

  @override
  String get permActionSend => 'Envoyer';

  @override
  String get remindersTitle => 'Relances';

  @override
  String get remindersCenter => 'Centre de relance';

  @override
  String get remindersToRemind => 'À relancer';

  @override
  String get remindersSend => 'Envoyer les relances';

  @override
  String get remindersSendShort => 'Relancer';

  @override
  String get remindersChannel => 'Canal d\'envoi';

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
  String get remindersLevelUpcoming => 'Échéance proche';

  @override
  String get remindersLevelDueToday => 'Échéance aujourd\'hui';

  @override
  String get remindersLevelLate => 'En retard';

  @override
  String get remindersLevelEscalated => 'Retard critique';

  @override
  String get remindersMessage => 'Message';

  @override
  String get remindersPreview => 'Aperçu du message';

  @override
  String remindersSentCount(int count) {
    return '$count relance(s) envoyée(s)';
  }

  @override
  String get remindersHistory => 'Historique des relances';

  @override
  String get remindersNoTargets => 'Aucun impayé : rien à relancer';

  @override
  String get remindersNoHistory => 'Aucune relance envoyée';

  @override
  String get remindersMine => 'Mes relances';

  @override
  String get remindersReceived => 'Relance reçue';

  @override
  String remindersLastSent(String date) {
    return 'Dernière relance : $date';
  }

  @override
  String get remindersStatusQueued => 'En file';

  @override
  String get remindersStatusSent => 'Envoyée';

  @override
  String get remindersStatusRead => 'Lue';

  @override
  String get remindersStatusFailed => 'Échec';

  @override
  String get remindersCampaign => 'Campagne';

  @override
  String get remindersTargets => 'Destinataires';

  @override
  String get remindersAudited =>
      'Chaque relance est horodatée et tracée dans l\'audit.';

  @override
  String get remindersSelectAll => 'Tout sélectionner';

  @override
  String remindersDaysLate(int count) {
    return '$count jour(s) de retard';
  }

  @override
  String get remindersConfirmTitle => 'Envoyer les relances ?';

  @override
  String remindersConfirmMessage(int count) {
    return '$count membre(s) seront notifiés sur les canaux sélectionnés.';
  }
}
