import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('hi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NeuroPilot'**
  String get appTitle;

  /// No description provided for @homeTaskFlow.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow'**
  String get homeTaskFlow;

  /// No description provided for @homeTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get homeTime;

  /// No description provided for @homeDecision.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get homeDecision;

  /// No description provided for @homeExternal.
  ///
  /// In en, this message translates to:
  /// **'External Brain'**
  String get homeExternal;

  /// No description provided for @taskflowTitle.
  ///
  /// In en, this message translates to:
  /// **'TaskFlow'**
  String get taskflowTitle;

  /// No description provided for @taskDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Task description'**
  String get taskDescriptionLabel;

  /// No description provided for @atomize.
  ///
  /// In en, this message translates to:
  /// **'Atomize'**
  String get atomize;

  /// No description provided for @microSteps.
  ///
  /// In en, this message translates to:
  /// **'Micro-steps:'**
  String get microSteps;

  /// No description provided for @timeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Perception'**
  String get timeTitle;

  /// No description provided for @targetIsoLabel.
  ///
  /// In en, this message translates to:
  /// **'Target ISO time'**
  String get targetIsoLabel;

  /// No description provided for @createCountdown.
  ///
  /// In en, this message translates to:
  /// **'Create Countdown'**
  String get createCountdown;

  /// No description provided for @decisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Decision Support'**
  String get decisionTitle;

  /// No description provided for @optionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options (comma-separated)'**
  String get optionsLabel;

  /// No description provided for @reduceTo3.
  ///
  /// In en, this message translates to:
  /// **'Reduce to 3'**
  String get reduceTo3;

  /// No description provided for @externalTitle.
  ///
  /// In en, this message translates to:
  /// **'External Brain'**
  String get externalTitle;

  /// No description provided for @transcriptLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice note transcript'**
  String get transcriptLabel;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get healthTitle;

  /// No description provided for @checkHealth.
  ///
  /// In en, this message translates to:
  /// **'Check Health'**
  String get checkHealth;

  /// No description provided for @baseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrlLabel;

  /// No description provided for @tokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get tokenLabel;

  /// No description provided for @presentLabel.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get presentLabel;

  /// No description provided for @absentLabel.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absentLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @clearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearLabel;

  /// No description provided for @resetLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetLabel;

  /// No description provided for @cancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel Timer'**
  String get cancelTimer;

  /// No description provided for @latencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get latencyLabel;

  /// No description provided for @checkLatency.
  ///
  /// In en, this message translates to:
  /// **'Check Latency'**
  String get checkLatency;

  /// No description provided for @checkMcp.
  ///
  /// In en, this message translates to:
  /// **'Check MCP'**
  String get checkMcp;

  /// No description provided for @mcpReady.
  ///
  /// In en, this message translates to:
  /// **'MCP Ready'**
  String get mcpReady;

  /// No description provided for @mcpNotReady.
  ///
  /// In en, this message translates to:
  /// **'MCP Not Ready'**
  String get mcpNotReady;

  /// No description provided for @unknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownLabel;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @typeMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeMessageLabel;

  /// No description provided for @sendLabel.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendLabel;

  /// No description provided for @voiceModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice transcript'**
  String get voiceModeLabel;

  /// No description provided for @recordLabel.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordLabel;

  /// No description provided for @voiceToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceToggleLabel;

  /// No description provided for @recordTranscriptLabel.
  ///
  /// In en, this message translates to:
  /// **'Paste or type your voice transcript'**
  String get recordTranscriptLabel;

  /// No description provided for @suggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestionsLabel;

  /// No description provided for @advancedToolsLabel.
  ///
  /// In en, this message translates to:
  /// **'Advanced tools'**
  String get advancedToolsLabel;

  /// No description provided for @suggestAtomize.
  ///
  /// In en, this message translates to:
  /// **'Atomize task'**
  String get suggestAtomize;

  /// No description provided for @suggestCountdown.
  ///
  /// In en, this message translates to:
  /// **'Set countdown'**
  String get suggestCountdown;

  /// No description provided for @suggestReduce.
  ///
  /// In en, this message translates to:
  /// **'Reduce options'**
  String get suggestReduce;

  /// No description provided for @suggestEnergyMatch.
  ///
  /// In en, this message translates to:
  /// **'Energy match'**
  String get suggestEnergyMatch;

  /// No description provided for @suggestCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture note'**
  String get suggestCapture;

  /// No description provided for @suggestOverview.
  ///
  /// In en, this message translates to:
  /// **'Today overview'**
  String get suggestOverview;

  /// No description provided for @exampleAtomize.
  ///
  /// In en, this message translates to:
  /// **'Atomize: Plan weekend trip'**
  String get exampleAtomize;

  /// No description provided for @exampleCountdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown: 2025-12-31T23:59:00'**
  String get exampleCountdown;

  /// No description provided for @exampleReduce.
  ///
  /// In en, this message translates to:
  /// **'Reduce: A, B, C, D'**
  String get exampleReduce;

  /// No description provided for @exampleEnergyMatch.
  ///
  /// In en, this message translates to:
  /// **'Energy match: email, code, review'**
  String get exampleEnergyMatch;

  /// No description provided for @exampleCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture: Met with team; follow-ups'**
  String get exampleCapture;

  /// No description provided for @exampleOverview.
  ///
  /// In en, this message translates to:
  /// **'What is planned for today?'**
  String get exampleOverview;

  /// No description provided for @focusModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Focus Mode'**
  String get focusModeLabel;

  /// No description provided for @minimalModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimal Mode'**
  String get minimalModeLabel;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
