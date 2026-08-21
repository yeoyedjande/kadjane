import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Kadjane'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In fr, this message translates to:
  /// **'La tontine, en toute transparence.'**
  String get appTagline;

  /// No description provided for @commonNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// No description provided for @commonSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get commonSkip;

  /// No description provided for @commonStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get commonStart;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get commonSearch;

  /// No description provided for @commonFilter.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get commonFilter;

  /// No description provided for @commonAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get commonAll;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get commonLoading;

  /// No description provided for @commonSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get commonSeeAll;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonContinueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinueLabel;

  /// No description provided for @commonYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get commonNo;

  /// No description provided for @commonNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get commonNone;

  /// No description provided for @commonOptional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif'**
  String get commonOptional;

  /// No description provided for @commonDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get commonDone;

  /// No description provided for @commonRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get commonRefresh;

  /// No description provided for @commonExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get commonExport;

  /// No description provided for @commonComment.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire'**
  String get commonComment;

  /// No description provided for @commonReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get commonReference;

  /// No description provided for @commonAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get commonAmount;

  /// No description provided for @commonDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get commonDate;

  /// No description provided for @commonStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get commonStatus;

  /// No description provided for @commonDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get commonDetails;

  /// No description provided for @commonTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get commonUnknown;

  /// No description provided for @commonNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get commonNoResults;

  /// No description provided for @commonErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get commonErrorTitle;

  /// No description provided for @commonErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les données. Veuillez réessayer.'**
  String get commonErrorGeneric;

  /// No description provided for @commonEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien à afficher'**
  String get commonEmptyTitle;

  /// No description provided for @commonOfflineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes hors ligne'**
  String get commonOfflineTitle;

  /// No description provided for @commonOfflineMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les données affichées peuvent ne pas être à jour.'**
  String get commonOfflineMessage;

  /// No description provided for @commonComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get commonComingSoon;

  /// No description provided for @commonRequiredField.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire'**
  String get commonRequiredField;

  /// No description provided for @commonSelect.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get commonSelect;

  /// No description provided for @commonNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Non disponible'**
  String get commonNotAvailable;

  /// No description provided for @authSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get authSignIn;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Accédez à vos tontines et à votre organisation.'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUp.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authSignUp;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez Kadjane en quelques secondes.'**
  String get authSignUpSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get authPhone;

  /// No description provided for @authPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get authConfirmPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get authForgotPassword;

  /// No description provided for @authForgotPasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre numéro de téléphone pour recevoir un code de vérification.'**
  String get authForgotPasswordSubtitle;

  /// No description provided for @authSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get authSendCode;

  /// No description provided for @authOtpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification'**
  String get authOtpTitle;

  /// No description provided for @authOtpSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code à 6 chiffres envoyé au {target}.'**
  String authOtpSubtitle(String target);

  /// No description provided for @authResendCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get authResendCode;

  /// No description provided for @authNewPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get authNewPassword;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un mot de passe sécurisé pour votre compte.'**
  String get authResetPasswordSubtitle;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte ?'**
  String get authAlreadyHaveAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get authNoAccount;

  /// No description provided for @authLogout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get authLogout;

  /// No description provided for @authLogoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment vous déconnecter ?'**
  String get authLogoutConfirm;

  /// No description provided for @authFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get authFirstName;

  /// No description provided for @authLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get authLastName;

  /// No description provided for @authInvalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email invalide'**
  String get authInvalidEmail;

  /// No description provided for @authInvalidPhone.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone invalide'**
  String get authInvalidPhone;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 8 caractères'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get authPasswordMismatch;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants incorrects'**
  String get authInvalidCredentials;

  /// No description provided for @authInvalidOtp.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification incorrect'**
  String get authInvalidOtp;

  /// No description provided for @authDemoHint.
  ///
  /// In fr, this message translates to:
  /// **'Démo : mot de passe kadjane, code de vérification 123456.'**
  String get authDemoHint;

  /// No description provided for @onboardingTitle1.
  ///
  /// In fr, this message translates to:
  /// **'Gérez votre tontine simplement'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In fr, this message translates to:
  /// **'Suivez les cotisations, bénéficiaires et échéances depuis votre téléphone.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In fr, this message translates to:
  /// **'Des tirages transparents'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In fr, this message translates to:
  /// **'Effectuez les tirages au sort et conservez automatiquement les résultats.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In fr, this message translates to:
  /// **'Gardez une trace de tout'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In fr, this message translates to:
  /// **'Paiements, bénéficiaires, historiques et activités restent accessibles.'**
  String get onboardingBody3;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navTontines.
  ///
  /// In fr, this message translates to:
  /// **'Tontines'**
  String get navTontines;

  /// No description provided for @navContributions.
  ///
  /// In fr, this message translates to:
  /// **'Cotisations'**
  String get navContributions;

  /// No description provided for @navActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get navActivity;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @dashboardGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}'**
  String dashboardGreeting(String name);

  /// No description provided for @dashboardMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get dashboardMembers;

  /// No description provided for @dashboardActiveTontines.
  ///
  /// In fr, this message translates to:
  /// **'Tontines actives'**
  String get dashboardActiveTontines;

  /// No description provided for @dashboardExpectedThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Attendu ce mois'**
  String get dashboardExpectedThisMonth;

  /// No description provided for @dashboardCollected.
  ///
  /// In fr, this message translates to:
  /// **'Collecté'**
  String get dashboardCollected;

  /// No description provided for @dashboardRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Restant'**
  String get dashboardRemaining;

  /// No description provided for @dashboardLateContributions.
  ///
  /// In fr, this message translates to:
  /// **'Cotisations en retard'**
  String get dashboardLateContributions;

  /// No description provided for @dashboardNextDraw.
  ///
  /// In fr, this message translates to:
  /// **'Prochain tirage'**
  String get dashboardNextDraw;

  /// No description provided for @dashboardCurrentBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire actuel'**
  String get dashboardCurrentBeneficiary;

  /// No description provided for @dashboardUpcomingDeadlines.
  ///
  /// In fr, this message translates to:
  /// **'Prochaines échéances'**
  String get dashboardUpcomingDeadlines;

  /// No description provided for @dashboardMyContribution.
  ///
  /// In fr, this message translates to:
  /// **'Ma cotisation'**
  String get dashboardMyContribution;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité récente'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardCollectionProgress.
  ///
  /// In fr, this message translates to:
  /// **'Progression de la collecte'**
  String get dashboardCollectionProgress;

  /// No description provided for @dashboardContributionsTrend.
  ///
  /// In fr, this message translates to:
  /// **'Évolution des cotisations'**
  String get dashboardContributionsTrend;

  /// No description provided for @dashboardNoUpcomingDraw.
  ///
  /// In fr, this message translates to:
  /// **'Aucun tirage programmé'**
  String get dashboardNoUpcomingDraw;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In fr, this message translates to:
  /// **'Accès rapide'**
  String get dashboardQuickActions;

  /// No description provided for @membersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get membersTitle;

  /// No description provided for @membersAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un membre'**
  String get membersAdd;

  /// No description provided for @membersDetails.
  ///
  /// In fr, this message translates to:
  /// **'Fiche du membre'**
  String get membersDetails;

  /// No description provided for @membersRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get membersRole;

  /// No description provided for @membersJoinedOn.
  ///
  /// In fr, this message translates to:
  /// **'Membre depuis'**
  String get membersJoinedOn;

  /// No description provided for @membersTotalPaid.
  ///
  /// In fr, this message translates to:
  /// **'Sommes versées'**
  String get membersTotalPaid;

  /// No description provided for @membersTotalReceived.
  ///
  /// In fr, this message translates to:
  /// **'Sommes reçues'**
  String get membersTotalReceived;

  /// No description provided for @membersGender.
  ///
  /// In fr, this message translates to:
  /// **'Sexe'**
  String get membersGender;

  /// No description provided for @membersMale.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get membersMale;

  /// No description provided for @membersFemale.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get membersFemale;

  /// No description provided for @membersBirthDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get membersBirthDate;

  /// No description provided for @membersPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get membersPhoto;

  /// No description provided for @membersSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un membre'**
  String get membersSearchHint;

  /// No description provided for @membersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre pour le moment'**
  String get membersEmpty;

  /// No description provided for @membersSaved.
  ///
  /// In fr, this message translates to:
  /// **'Membre enregistré'**
  String get membersSaved;

  /// No description provided for @membersInviteSoon.
  ///
  /// In fr, this message translates to:
  /// **'Invitation par lien disponible prochainement'**
  String get membersInviteSoon;

  /// No description provided for @membersTontines.
  ///
  /// In fr, this message translates to:
  /// **'Tontines du membre'**
  String get membersTontines;

  /// No description provided for @statusActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In fr, this message translates to:
  /// **'Inactif'**
  String get statusInactive;

  /// No description provided for @statusSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get statusSuspended;

  /// No description provided for @statusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get statusPending;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Super Admin'**
  String get roleSuperAdmin;

  /// No description provided for @roleAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur'**
  String get roleAdmin;

  /// No description provided for @rolePresident.
  ///
  /// In fr, this message translates to:
  /// **'Président'**
  String get rolePresident;

  /// No description provided for @roleTreasurer.
  ///
  /// In fr, this message translates to:
  /// **'Trésorier'**
  String get roleTreasurer;

  /// No description provided for @roleAuditor.
  ///
  /// In fr, this message translates to:
  /// **'Commissaire aux comptes'**
  String get roleAuditor;

  /// No description provided for @roleMember.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get roleMember;

  /// No description provided for @tontinesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes tontines'**
  String get tontinesTitle;

  /// No description provided for @tontinesCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer une tontine'**
  String get tontinesCreate;

  /// No description provided for @tontinesName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la tontine'**
  String get tontinesName;

  /// No description provided for @tontinesDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get tontinesDescription;

  /// No description provided for @tontinesContributionAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant de la cotisation'**
  String get tontinesContributionAmount;

  /// No description provided for @tontinesCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get tontinesCurrency;

  /// No description provided for @tontinesFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence'**
  String get tontinesFrequency;

  /// No description provided for @tontinesStartDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de début'**
  String get tontinesStartDate;

  /// No description provided for @tontinesDueDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour d\'échéance'**
  String get tontinesDueDay;

  /// No description provided for @tontinesParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get tontinesParticipants;

  /// No description provided for @tontinesEstimatedPot.
  ///
  /// In fr, this message translates to:
  /// **'Cagnotte estimée'**
  String get tontinesEstimatedPot;

  /// No description provided for @tontinesPot.
  ///
  /// In fr, this message translates to:
  /// **'Cagnotte'**
  String get tontinesPot;

  /// No description provided for @tontinesProgress.
  ///
  /// In fr, this message translates to:
  /// **'Progression'**
  String get tontinesProgress;

  /// No description provided for @tontinesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tontine pour le moment'**
  String get tontinesEmpty;

  /// No description provided for @tontinesCreated.
  ///
  /// In fr, this message translates to:
  /// **'Tontine créée avec succès'**
  String get tontinesCreated;

  /// No description provided for @tontinesCyclesCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Cycles terminés'**
  String get tontinesCyclesCompleted;

  /// No description provided for @tontinesPreviousBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire précédent'**
  String get tontinesPreviousBeneficiary;

  /// No description provided for @tontinesNextDraws.
  ///
  /// In fr, this message translates to:
  /// **'Prochains tirages'**
  String get tontinesNextDraws;

  /// No description provided for @tontinesSelectParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner les participants'**
  String get tontinesSelectParticipants;

  /// No description provided for @tontinesParticipantsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants'**
  String tontinesParticipantsCount(int count);

  /// No description provided for @tontinesPotFormula.
  ///
  /// In fr, this message translates to:
  /// **'{count} membres x {amount}'**
  String tontinesPotFormula(int count, String amount);

  /// No description provided for @tontinesStepInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get tontinesStepInfo;

  /// No description provided for @tontinesStepParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get tontinesStepParticipants;

  /// No description provided for @tontinesStepMode.
  ///
  /// In fr, this message translates to:
  /// **'Attribution'**
  String get tontinesStepMode;

  /// No description provided for @tontinesStepSummary.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get tontinesStepSummary;

  /// No description provided for @tontinesTabOverview.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get tontinesTabOverview;

  /// No description provided for @tontinesTabContributions.
  ///
  /// In fr, this message translates to:
  /// **'Cotisations'**
  String get tontinesTabContributions;

  /// No description provided for @tontinesTabDraws.
  ///
  /// In fr, this message translates to:
  /// **'Tirages'**
  String get tontinesTabDraws;

  /// No description provided for @tontinesTabParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get tontinesTabParticipants;

  /// No description provided for @tontinesTabHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get tontinesTabHistory;

  /// No description provided for @tontinesTabSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get tontinesTabSettings;

  /// No description provided for @tontinesCycle.
  ///
  /// In fr, this message translates to:
  /// **'Cycle {index}'**
  String tontinesCycle(int index);

  /// No description provided for @tontinesMinParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez au moins 2 participants'**
  String get tontinesMinParticipants;

  /// No description provided for @tontineStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get tontineStatusDraft;

  /// No description provided for @tontineStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get tontineStatusPending;

  /// No description provided for @tontineStatusActive.
  ///
  /// In fr, this message translates to:
  /// **'Active'**
  String get tontineStatusActive;

  /// No description provided for @tontineStatusSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendue'**
  String get tontineStatusSuspended;

  /// No description provided for @tontineStatusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get tontineStatusCompleted;

  /// No description provided for @tontineStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get tontineStatusCancelled;

  /// No description provided for @frequencyWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get frequencyWeekly;

  /// No description provided for @frequencyBiweekly.
  ///
  /// In fr, this message translates to:
  /// **'Bimensuelle'**
  String get frequencyBiweekly;

  /// No description provided for @frequencyMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuelle'**
  String get frequencyMonthly;

  /// No description provided for @frequencyCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisée'**
  String get frequencyCustom;

  /// No description provided for @allocationMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode d\'attribution'**
  String get allocationMode;

  /// No description provided for @allocationMonthlyDraw.
  ///
  /// In fr, this message translates to:
  /// **'Tirage à chaque période'**
  String get allocationMonthlyDraw;

  /// No description provided for @allocationMonthlyDrawDesc.
  ///
  /// In fr, this message translates to:
  /// **'Un bénéficiaire est tiré au sort à chaque période parmi les membres n\'ayant pas encore reçu la cagnotte.'**
  String get allocationMonthlyDrawDesc;

  /// No description provided for @allocationFullOrder.
  ///
  /// In fr, this message translates to:
  /// **'Ordre complet par tirage'**
  String get allocationFullOrder;

  /// No description provided for @allocationFullOrderDesc.
  ///
  /// In fr, this message translates to:
  /// **'Un tirage unique en début de tontine fixe l\'ordre de passage de tous les participants.'**
  String get allocationFullOrderDesc;

  /// No description provided for @allocationManualOrder.
  ///
  /// In fr, this message translates to:
  /// **'Ordre manuel'**
  String get allocationManualOrder;

  /// No description provided for @allocationManualOrderDesc.
  ///
  /// In fr, this message translates to:
  /// **'L\'administrateur définit lui-même l\'ordre de passage des participants.'**
  String get allocationManualOrderDesc;

  /// No description provided for @contributionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Cotisations'**
  String get contributionsTitle;

  /// No description provided for @contributionsPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get contributionsPeriod;

  /// No description provided for @contributionsExpected.
  ///
  /// In fr, this message translates to:
  /// **'Attendu'**
  String get contributionsExpected;

  /// No description provided for @contributionsCollected.
  ///
  /// In fr, this message translates to:
  /// **'Collecté'**
  String get contributionsCollected;

  /// No description provided for @contributionsRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Restant'**
  String get contributionsRemaining;

  /// No description provided for @contributionsPaidMembers.
  ///
  /// In fr, this message translates to:
  /// **'{paid} membres sur {total} ont payé'**
  String contributionsPaidMembers(int paid, int total);

  /// No description provided for @contributionsRecordPayment.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un paiement'**
  String get contributionsRecordPayment;

  /// No description provided for @contributionsPaymentMethod.
  ///
  /// In fr, this message translates to:
  /// **'Moyen de paiement'**
  String get contributionsPaymentMethod;

  /// No description provided for @contributionsProof.
  ///
  /// In fr, this message translates to:
  /// **'Justificatif'**
  String get contributionsProof;

  /// No description provided for @contributionsAddProof.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un justificatif'**
  String get contributionsAddProof;

  /// No description provided for @contributionsTakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get contributionsTakePhoto;

  /// No description provided for @contributionsChooseImage.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image'**
  String get contributionsChooseImage;

  /// No description provided for @contributionsViewProof.
  ///
  /// In fr, this message translates to:
  /// **'Voir le justificatif'**
  String get contributionsViewProof;

  /// No description provided for @contributionsRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Paiement enregistré'**
  String get contributionsRecorded;

  /// No description provided for @contributionsMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes cotisations'**
  String get contributionsMine;

  /// No description provided for @contributionsTotalPaid.
  ///
  /// In fr, this message translates to:
  /// **'Total versé'**
  String get contributionsTotalPaid;

  /// No description provided for @contributionsPaymentsCount.
  ///
  /// In fr, this message translates to:
  /// **'Paiements'**
  String get contributionsPaymentsCount;

  /// No description provided for @contributionsUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Prochains paiements'**
  String get contributionsUpcoming;

  /// No description provided for @contributionsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune cotisation enregistrée'**
  String get contributionsEmpty;

  /// No description provided for @contributionsLate.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get contributionsLate;

  /// No description provided for @contributionsSelectMember.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get contributionsSelectMember;

  /// No description provided for @paymentStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get paymentStatusConfirmed;

  /// No description provided for @paymentStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get paymentStatusRejected;

  /// No description provided for @paymentStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get paymentStatusCancelled;

  /// No description provided for @methodWave.
  ///
  /// In fr, this message translates to:
  /// **'Wave'**
  String get methodWave;

  /// No description provided for @methodOrangeMoney.
  ///
  /// In fr, this message translates to:
  /// **'Orange Money'**
  String get methodOrangeMoney;

  /// No description provided for @methodMtnMomo.
  ///
  /// In fr, this message translates to:
  /// **'MTN MoMo'**
  String get methodMtnMomo;

  /// No description provided for @methodMoovMoney.
  ///
  /// In fr, this message translates to:
  /// **'Moov Money'**
  String get methodMoovMoney;

  /// No description provided for @methodBankTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Virement bancaire'**
  String get methodBankTransfer;

  /// No description provided for @methodCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get methodCash;

  /// No description provided for @methodOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get methodOther;

  /// No description provided for @drawTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tirage du mois'**
  String get drawTitle;

  /// No description provided for @drawSpin.
  ///
  /// In fr, this message translates to:
  /// **'Lancer le tirage'**
  String get drawSpin;

  /// No description provided for @drawSpinning.
  ///
  /// In fr, this message translates to:
  /// **'Tirage en cours...'**
  String get drawSpinning;

  /// No description provided for @drawParticipantsAtStart.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants au départ'**
  String drawParticipantsAtStart(int count);

  /// No description provided for @drawRemainingToDraw.
  ///
  /// In fr, this message translates to:
  /// **'{count} membres restent à tirer'**
  String drawRemainingToDraw(int count);

  /// No description provided for @drawUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Tirage indisponible'**
  String get drawUnavailable;

  /// No description provided for @drawUnavailableReason.
  ///
  /// In fr, this message translates to:
  /// **'{count} cotisation(s) restent à régler.'**
  String drawUnavailableReason(int count);

  /// No description provided for @drawConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le tirage ?'**
  String get drawConfirmTitle;

  /// No description provided for @drawConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette opération désignera définitivement le bénéficiaire de la période.'**
  String get drawConfirmMessage;

  /// No description provided for @drawCongratulations.
  ///
  /// In fr, this message translates to:
  /// **'Félicitations !'**
  String get drawCongratulations;

  /// No description provided for @drawBeneficiaryOf.
  ///
  /// In fr, this message translates to:
  /// **'est le bénéficiaire de la période {period}.'**
  String drawBeneficiaryOf(String period);

  /// No description provided for @drawViewResult.
  ///
  /// In fr, this message translates to:
  /// **'Voir le résultat'**
  String get drawViewResult;

  /// No description provided for @drawHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des tirages'**
  String get drawHistory;

  /// No description provided for @drawLaunchedBy.
  ///
  /// In fr, this message translates to:
  /// **'Lancé par'**
  String get drawLaunchedBy;

  /// No description provided for @drawReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get drawReference;

  /// No description provided for @drawEligibleParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Participants éligibles'**
  String get drawEligibleParticipants;

  /// No description provided for @drawNoEligible.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant éligible pour ce tirage'**
  String get drawNoEligible;

  /// No description provided for @drawOverrideTitle.
  ///
  /// In fr, this message translates to:
  /// **'Forcer le tirage'**
  String get drawOverrideTitle;

  /// No description provided for @drawOverrideMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le règlement exige que toutes les cotisations soient réglées. Forcer le tirage sera enregistré dans l\'audit.'**
  String get drawOverrideMessage;

  /// No description provided for @drawOverrideReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif du forçage'**
  String get drawOverrideReason;

  /// No description provided for @drawOverrideUsed.
  ///
  /// In fr, this message translates to:
  /// **'Tirage forcé par un administrateur'**
  String get drawOverrideUsed;

  /// No description provided for @drawCancelAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le tirage'**
  String get drawCancelAction;

  /// No description provided for @drawInvalidate.
  ///
  /// In fr, this message translates to:
  /// **'Invalider le tirage'**
  String get drawInvalidate;

  /// No description provided for @drawInvalidateReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif de l\'invalidation'**
  String get drawInvalidateReason;

  /// No description provided for @drawAlreadyDone.
  ///
  /// In fr, this message translates to:
  /// **'Le tirage de cette période a déjà été effectué'**
  String get drawAlreadyDone;

  /// No description provided for @drawNoPermission.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas la permission de lancer un tirage'**
  String get drawNoPermission;

  /// No description provided for @drawOrderGenerated.
  ///
  /// In fr, this message translates to:
  /// **'Ordre de passage généré'**
  String get drawOrderGenerated;

  /// No description provided for @drawScheduledOn.
  ///
  /// In fr, this message translates to:
  /// **'Tirage prévu le {date}'**
  String drawScheduledOn(String date);

  /// No description provided for @drawStatusScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Programmé'**
  String get drawStatusScheduled;

  /// No description provided for @drawStatusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Validé'**
  String get drawStatusCompleted;

  /// No description provided for @drawStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get drawStatusCancelled;

  /// No description provided for @drawStatusInvalidated.
  ///
  /// In fr, this message translates to:
  /// **'Invalidé'**
  String get drawStatusInvalidated;

  /// No description provided for @beneficiaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire de la période'**
  String get beneficiaryTitle;

  /// No description provided for @beneficiaryPayout.
  ///
  /// In fr, this message translates to:
  /// **'Versement'**
  String get beneficiaryPayout;

  /// No description provided for @beneficiaryRecordPayout.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le versement'**
  String get beneficiaryRecordPayout;

  /// No description provided for @beneficiaryAmountSent.
  ///
  /// In fr, this message translates to:
  /// **'Montant envoyé'**
  String get beneficiaryAmountSent;

  /// No description provided for @beneficiaryPayoutRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Versement enregistré'**
  String get beneficiaryPayoutRecorded;

  /// No description provided for @beneficiaryStepContributions.
  ///
  /// In fr, this message translates to:
  /// **'Cotisations'**
  String get beneficiaryStepContributions;

  /// No description provided for @beneficiaryStepPot.
  ///
  /// In fr, this message translates to:
  /// **'Cagnotte complète'**
  String get beneficiaryStepPot;

  /// No description provided for @beneficiaryStepDraw.
  ///
  /// In fr, this message translates to:
  /// **'Tirage'**
  String get beneficiaryStepDraw;

  /// No description provided for @beneficiaryStepBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get beneficiaryStepBeneficiary;

  /// No description provided for @beneficiaryStepPayout.
  ///
  /// In fr, this message translates to:
  /// **'Versement'**
  String get beneficiaryStepPayout;

  /// No description provided for @beneficiaryStepConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Confirmation'**
  String get beneficiaryStepConfirmation;

  /// No description provided for @beneficiaryNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bénéficiaire désigné'**
  String get beneficiaryNone;

  /// No description provided for @payoutStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get payoutStatusPending;

  /// No description provided for @payoutStatusProcessing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get payoutStatusProcessing;

  /// No description provided for @payoutStatusPaid.
  ///
  /// In fr, this message translates to:
  /// **'Versé'**
  String get payoutStatusPaid;

  /// No description provided for @payoutStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get payoutStatusFailed;

  /// No description provided for @positionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ma position'**
  String get positionTitle;

  /// No description provided for @positionNotReceived.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore reçu votre cagnotte.'**
  String get positionNotReceived;

  /// No description provided for @positionRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Participants restant à tirer : {remaining} / {total}.'**
  String positionRemaining(int remaining, int total);

  /// No description provided for @positionReceivedIn.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez reçu votre cagnotte en {period}.'**
  String positionReceivedIn(String period);

  /// No description provided for @positionKeepContributing.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez continuer vos cotisations jusqu\'à la fin de la tontine.'**
  String get positionKeepContributing;

  /// No description provided for @positionOrder.
  ///
  /// In fr, this message translates to:
  /// **'Votre passage : position {position}'**
  String positionOrder(int position);

  /// No description provided for @positionEstimatedPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période estimée : {period}'**
  String positionEstimatedPeriod(String period);

  /// No description provided for @positionNotParticipant.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne participez pas à cette tontine.'**
  String get positionNotParticipant;

  /// No description provided for @activityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get activityTitle;

  /// No description provided for @activityEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée'**
  String get activityEmpty;

  /// No description provided for @activityAudit.
  ///
  /// In fr, this message translates to:
  /// **'Journal d\'audit'**
  String get activityAudit;

  /// No description provided for @activityToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get activityToday;

  /// No description provided for @activityYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get activityYesterday;

  /// No description provided for @activityEarlier.
  ///
  /// In fr, this message translates to:
  /// **'Plus tôt'**
  String get activityEarlier;

  /// No description provided for @notificationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get notificationsEmpty;

  /// No description provided for @treasuryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Caisse'**
  String get treasuryTitle;

  /// No description provided for @treasuryBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get treasuryBalance;

  /// No description provided for @treasuryInflows.
  ///
  /// In fr, this message translates to:
  /// **'Entrées'**
  String get treasuryInflows;

  /// No description provided for @treasuryOutflows.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get treasuryOutflows;

  /// No description provided for @treasuryAddTransaction.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle opération'**
  String get treasuryAddTransaction;

  /// No description provided for @treasuryType.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'opération'**
  String get treasuryType;

  /// No description provided for @treasuryIncome.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get treasuryIncome;

  /// No description provided for @treasuryExpense.
  ///
  /// In fr, this message translates to:
  /// **'Sortie'**
  String get treasuryExpense;

  /// No description provided for @treasuryCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get treasuryCategory;

  /// No description provided for @treasuryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération de caisse'**
  String get treasuryEmpty;

  /// No description provided for @treasurySaved.
  ///
  /// In fr, this message translates to:
  /// **'Opération enregistrée'**
  String get treasurySaved;

  /// No description provided for @reportsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get reportsTitle;

  /// No description provided for @reportsTotalContributions.
  ///
  /// In fr, this message translates to:
  /// **'Total cotisations'**
  String get reportsTotalContributions;

  /// No description provided for @reportsUnpaid.
  ///
  /// In fr, this message translates to:
  /// **'Impayés'**
  String get reportsUnpaid;

  /// No description provided for @reportsRecoveryRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de recouvrement'**
  String get reportsRecoveryRate;

  /// No description provided for @reportsDistributed.
  ///
  /// In fr, this message translates to:
  /// **'Sommes distribuées'**
  String get reportsDistributed;

  /// No description provided for @reportsExportPdf.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF'**
  String get reportsExportPdf;

  /// No description provided for @reportsExportExcel.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en Excel'**
  String get reportsExportExcel;

  /// No description provided for @reportsExportMocked.
  ///
  /// In fr, this message translates to:
  /// **'Export simulé : intégration backend à venir.'**
  String get reportsExportMocked;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileMyOrganizations.
  ///
  /// In fr, this message translates to:
  /// **'Mes organisations'**
  String get profileMyOrganizations;

  /// No description provided for @profilePreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get profilePreferences;

  /// No description provided for @profileSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get profileSecurity;

  /// No description provided for @profileTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get profileTheme;

  /// No description provided for @profileThemeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get profileThemeDark;

  /// No description provided for @profileThemeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get profileThemeSystem;

  /// No description provided for @profileLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get profileLanguage;

  /// No description provided for @profileFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get profileFrench;

  /// No description provided for @profileEnglish.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get profileEnglish;

  /// No description provided for @profileNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get profileEdit;

  /// No description provided for @profileVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get profileVersion;

  /// No description provided for @profileSaved.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour'**
  String get profileSaved;

  /// No description provided for @orgSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de l\'organisation'**
  String get orgSettingsTitle;

  /// No description provided for @orgName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'organisation'**
  String get orgName;

  /// No description provided for @orgLogo.
  ///
  /// In fr, this message translates to:
  /// **'Logo'**
  String get orgLogo;

  /// No description provided for @orgCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get orgCountry;

  /// No description provided for @orgAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get orgAddress;

  /// No description provided for @orgRules.
  ///
  /// In fr, this message translates to:
  /// **'Règles'**
  String get orgRules;

  /// No description provided for @orgOfficers.
  ///
  /// In fr, this message translates to:
  /// **'Responsables'**
  String get orgOfficers;

  /// No description provided for @orgSwitch.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'organisation'**
  String get orgSwitch;

  /// No description provided for @orgCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer une organisation'**
  String get orgCreate;

  /// No description provided for @orgRequireFullPayment.
  ///
  /// In fr, this message translates to:
  /// **'Exiger toutes les cotisations avant le tirage'**
  String get orgRequireFullPayment;

  /// No description provided for @orgAllowOverride.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser le forçage du tirage'**
  String get orgAllowOverride;

  /// No description provided for @orgGraceDays.
  ///
  /// In fr, this message translates to:
  /// **'Jours de tolérance avant retard'**
  String get orgGraceDays;

  /// No description provided for @orgSaved.
  ///
  /// In fr, this message translates to:
  /// **'Organisation mise à jour'**
  String get orgSaved;

  /// No description provided for @orgNoPermission.
  ///
  /// In fr, this message translates to:
  /// **'Action non autorisée pour votre rôle'**
  String get orgNoPermission;

  /// No description provided for @adminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Kadjane Admin'**
  String get adminTitle;

  /// No description provided for @adminConsole.
  ///
  /// In fr, this message translates to:
  /// **'Console d\'administration'**
  String get adminConsole;

  /// No description provided for @adminNavOverview.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get adminNavOverview;

  /// No description provided for @adminNavMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get adminNavMembers;

  /// No description provided for @adminNavRoles.
  ///
  /// In fr, this message translates to:
  /// **'Rôles et permissions'**
  String get adminNavRoles;

  /// No description provided for @adminNavReminders.
  ///
  /// In fr, this message translates to:
  /// **'Relances'**
  String get adminNavReminders;

  /// No description provided for @adminNavTontines.
  ///
  /// In fr, this message translates to:
  /// **'Tontines'**
  String get adminNavTontines;

  /// No description provided for @adminNavAudit.
  ///
  /// In fr, this message translates to:
  /// **'Audit'**
  String get adminNavAudit;

  /// No description provided for @adminNavSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get adminNavSettings;

  /// No description provided for @adminCollectionRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de recouvrement'**
  String get adminCollectionRate;

  /// No description provided for @adminOutstanding.
  ///
  /// In fr, this message translates to:
  /// **'Encours impayé'**
  String get adminOutstanding;

  /// No description provided for @adminAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Points de vigilance'**
  String get adminAlerts;

  /// No description provided for @adminNoAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun point de vigilance'**
  String get adminNoAlerts;

  /// No description provided for @adminAlertLateMembers.
  ///
  /// In fr, this message translates to:
  /// **'{count} membre(s) en retard de cotisation'**
  String adminAlertLateMembers(int count);

  /// No description provided for @adminAlertBlockedDraw.
  ///
  /// In fr, this message translates to:
  /// **'{count} tirage(s) bloqué(s) par des impayés'**
  String adminAlertBlockedDraw(int count);

  /// No description provided for @adminAlertPendingPayout.
  ///
  /// In fr, this message translates to:
  /// **'{count} versement(s) en attente'**
  String adminAlertPendingPayout(int count);

  /// No description provided for @adminSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get adminSearch;

  /// No description provided for @adminSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count} sélectionné(s)'**
  String adminSelected(int count);

  /// No description provided for @adminChangeRole.
  ///
  /// In fr, this message translates to:
  /// **'Changer le rôle'**
  String get adminChangeRole;

  /// No description provided for @adminMemberUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Membre mis à jour'**
  String get adminMemberUpdated;

  /// No description provided for @adminRoleMatrix.
  ///
  /// In fr, this message translates to:
  /// **'Matrice des permissions'**
  String get adminRoleMatrix;

  /// No description provided for @adminRoleMatrixHint.
  ///
  /// In fr, this message translates to:
  /// **'Cochez les droits accordés à chaque rôle. La modification s\'applique immédiatement, sur mobile comme sur la console.'**
  String get adminRoleMatrixHint;

  /// No description provided for @adminRoleReset.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir les droits par défaut'**
  String get adminRoleReset;

  /// No description provided for @adminRoleSaved.
  ///
  /// In fr, this message translates to:
  /// **'Permissions mises à jour'**
  String get adminRoleSaved;

  /// No description provided for @adminRoleCustomized.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get adminRoleCustomized;

  /// No description provided for @adminRoleDefault.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut'**
  String get adminRoleDefault;

  /// No description provided for @adminPermissionsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} droits'**
  String adminPermissionsCount(int count);

  /// No description provided for @adminMembersWithRole.
  ///
  /// In fr, this message translates to:
  /// **'{count} membre(s)'**
  String adminMembersWithRole(int count);

  /// No description provided for @adminOpenMobileHint.
  ///
  /// In fr, this message translates to:
  /// **'Les rôles définis ici pilotent aussi l\'application mobile.'**
  String get adminOpenMobileHint;

  /// No description provided for @permModuleOrganization.
  ///
  /// In fr, this message translates to:
  /// **'Organisation'**
  String get permModuleOrganization;

  /// No description provided for @permModuleMember.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get permModuleMember;

  /// No description provided for @permModuleTontine.
  ///
  /// In fr, this message translates to:
  /// **'Tontines'**
  String get permModuleTontine;

  /// No description provided for @permModuleContribution.
  ///
  /// In fr, this message translates to:
  /// **'Cotisations'**
  String get permModuleContribution;

  /// No description provided for @permModuleDraw.
  ///
  /// In fr, this message translates to:
  /// **'Tirages'**
  String get permModuleDraw;

  /// No description provided for @permModulePayout.
  ///
  /// In fr, this message translates to:
  /// **'Versements'**
  String get permModulePayout;

  /// No description provided for @permModuleTreasury.
  ///
  /// In fr, this message translates to:
  /// **'Caisse'**
  String get permModuleTreasury;

  /// No description provided for @permModuleReport.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get permModuleReport;

  /// No description provided for @permModuleAudit.
  ///
  /// In fr, this message translates to:
  /// **'Audit'**
  String get permModuleAudit;

  /// No description provided for @permModuleReminder.
  ///
  /// In fr, this message translates to:
  /// **'Relances'**
  String get permModuleReminder;

  /// No description provided for @permActionView.
  ///
  /// In fr, this message translates to:
  /// **'Consulter'**
  String get permActionView;

  /// No description provided for @permActionEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get permActionEdit;

  /// No description provided for @permActionCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get permActionCreate;

  /// No description provided for @permActionManageOfficers.
  ///
  /// In fr, this message translates to:
  /// **'Gérer le bureau'**
  String get permActionManageOfficers;

  /// No description provided for @permActionInvite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get permActionInvite;

  /// No description provided for @permActionValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get permActionValidate;

  /// No description provided for @permActionRecord.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get permActionRecord;

  /// No description provided for @permActionConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get permActionConfirm;

  /// No description provided for @permActionCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get permActionCancel;

  /// No description provided for @permActionRun.
  ///
  /// In fr, this message translates to:
  /// **'Lancer'**
  String get permActionRun;

  /// No description provided for @permActionOverride.
  ///
  /// In fr, this message translates to:
  /// **'Forcer'**
  String get permActionOverride;

  /// No description provided for @permActionInvalidate.
  ///
  /// In fr, this message translates to:
  /// **'Invalider'**
  String get permActionInvalidate;

  /// No description provided for @permActionManage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer'**
  String get permActionManage;

  /// No description provided for @permActionSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get permActionSend;

  /// No description provided for @remindersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Relances'**
  String get remindersTitle;

  /// No description provided for @remindersCenter.
  ///
  /// In fr, this message translates to:
  /// **'Centre de relance'**
  String get remindersCenter;

  /// No description provided for @remindersToRemind.
  ///
  /// In fr, this message translates to:
  /// **'À relancer'**
  String get remindersToRemind;

  /// No description provided for @remindersSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer les relances'**
  String get remindersSend;

  /// No description provided for @remindersSendShort.
  ///
  /// In fr, this message translates to:
  /// **'Relancer'**
  String get remindersSendShort;

  /// No description provided for @remindersChannel.
  ///
  /// In fr, this message translates to:
  /// **'Canal d\'envoi'**
  String get remindersChannel;

  /// No description provided for @remindersChannelInApp.
  ///
  /// In fr, this message translates to:
  /// **'Notification'**
  String get remindersChannelInApp;

  /// No description provided for @remindersChannelSms.
  ///
  /// In fr, this message translates to:
  /// **'SMS'**
  String get remindersChannelSms;

  /// No description provided for @remindersChannelWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get remindersChannelWhatsapp;

  /// No description provided for @remindersChannelEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get remindersChannelEmail;

  /// No description provided for @remindersChannelPush.
  ///
  /// In fr, this message translates to:
  /// **'Push'**
  String get remindersChannelPush;

  /// No description provided for @remindersLevelUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Échéance proche'**
  String get remindersLevelUpcoming;

  /// No description provided for @remindersLevelDueToday.
  ///
  /// In fr, this message translates to:
  /// **'Échéance aujourd\'hui'**
  String get remindersLevelDueToday;

  /// No description provided for @remindersLevelLate.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get remindersLevelLate;

  /// No description provided for @remindersLevelEscalated.
  ///
  /// In fr, this message translates to:
  /// **'Retard critique'**
  String get remindersLevelEscalated;

  /// No description provided for @remindersMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get remindersMessage;

  /// No description provided for @remindersPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du message'**
  String get remindersPreview;

  /// No description provided for @remindersSentCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} relance(s) envoyée(s)'**
  String remindersSentCount(int count);

  /// No description provided for @remindersHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des relances'**
  String get remindersHistory;

  /// No description provided for @remindersNoTargets.
  ///
  /// In fr, this message translates to:
  /// **'Aucun impayé : rien à relancer'**
  String get remindersNoTargets;

  /// No description provided for @remindersNoHistory.
  ///
  /// In fr, this message translates to:
  /// **'Aucune relance envoyée'**
  String get remindersNoHistory;

  /// No description provided for @remindersMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes relances'**
  String get remindersMine;

  /// No description provided for @remindersReceived.
  ///
  /// In fr, this message translates to:
  /// **'Relance reçue'**
  String get remindersReceived;

  /// No description provided for @remindersLastSent.
  ///
  /// In fr, this message translates to:
  /// **'Dernière relance : {date}'**
  String remindersLastSent(String date);

  /// No description provided for @remindersStatusQueued.
  ///
  /// In fr, this message translates to:
  /// **'En file'**
  String get remindersStatusQueued;

  /// No description provided for @remindersStatusSent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée'**
  String get remindersStatusSent;

  /// No description provided for @remindersStatusRead.
  ///
  /// In fr, this message translates to:
  /// **'Lue'**
  String get remindersStatusRead;

  /// No description provided for @remindersStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get remindersStatusFailed;

  /// No description provided for @remindersCampaign.
  ///
  /// In fr, this message translates to:
  /// **'Campagne'**
  String get remindersCampaign;

  /// No description provided for @remindersTargets.
  ///
  /// In fr, this message translates to:
  /// **'Destinataires'**
  String get remindersTargets;

  /// No description provided for @remindersAudited.
  ///
  /// In fr, this message translates to:
  /// **'Chaque relance est horodatée et tracée dans l\'audit.'**
  String get remindersAudited;

  /// No description provided for @remindersSelectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get remindersSelectAll;

  /// No description provided for @remindersDaysLate.
  ///
  /// In fr, this message translates to:
  /// **'{count} jour(s) de retard'**
  String remindersDaysLate(int count);

  /// No description provided for @remindersConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer les relances ?'**
  String get remindersConfirmTitle;

  /// No description provided for @remindersConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'{count} membre(s) seront notifiés sur les canaux sélectionnés.'**
  String remindersConfirmMessage(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
