import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

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
    Locale('ja')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'Game Member Generator'**
  String get appTitle;

  /// No description provided for @navMembers.
  ///
  /// In ja, this message translates to:
  /// **'メンバー'**
  String get navMembers;

  /// No description provided for @navMatchHistory.
  ///
  /// In ja, this message translates to:
  /// **'試合履歴'**
  String get navMatchHistory;

  /// No description provided for @navExpense.
  ///
  /// In ja, this message translates to:
  /// **'費用計算'**
  String get navExpense;

  /// No description provided for @navOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get navOther;

  /// No description provided for @manualGuideTitle.
  ///
  /// In ja, this message translates to:
  /// **'使い方ガイド'**
  String get manualGuideTitle;

  /// No description provided for @manualPrepareTitle.
  ///
  /// In ja, this message translates to:
  /// **'参加メンバーを準備する'**
  String get manualPrepareTitle;

  /// No description provided for @manualPrepareItem1.
  ///
  /// In ja, this message translates to:
  /// **'「メンバー」で名前・よみがな・性別を登録し、当日参加する人をオンにします。右上のメニューから、CSV・JSONの読み込みや書き出しもできます。'**
  String get manualPrepareItem1;

  /// No description provided for @manualPrepareItem2.
  ///
  /// In ja, this message translates to:
  /// **'子守りなどで同時に出場できない2人は、メンバー編集の「同時出場制限」で相手を選びます。自動生成では2人を同じラウンドに出場させません。'**
  String get manualPrepareItem2;

  /// No description provided for @manualPrepareItem3.
  ///
  /// In ja, this message translates to:
  /// **'次のラウンドだけ休む人は、メンバーのメニューから「一時休み」を選びます。以降のラウンドすべてを休む場合は「早退」を選びます。'**
  String get manualPrepareItem3;

  /// No description provided for @manualGenerateTitle.
  ///
  /// In ja, this message translates to:
  /// **'試合を作成する'**
  String get manualGenerateTitle;

  /// No description provided for @manualGenerateItem1.
  ///
  /// In ja, this message translates to:
  /// **'「試合履歴」で「最初の試合を作成」を押します。次のラウンドは右下の＋、表示中のラウンドを作り直すときは更新アイコンを使います。'**
  String get manualGenerateItem1;

  /// No description provided for @manualGenerateItem2.
  ///
  /// In ja, this message translates to:
  /// **'設定画面の「自動」ではコート数から形式が提案され、「手動」ではコートごとに形式を選べます。「スタート」で作成し、コート別の組み合わせと休憩メンバーを確認します。'**
  String get manualGenerateItem2;

  /// No description provided for @manualGenerateItem3.
  ///
  /// In ja, this message translates to:
  /// **'同じ出場メンバーが続くときに確認が表示されることがあります。連続休みを避けるルールを続けるか、表示された人数と休みの長さを確認して今回だけ入れ替えるかを選べます。'**
  String get manualGenerateItem3;

  /// No description provided for @manualSwapTitle.
  ///
  /// In ja, this message translates to:
  /// **'選手を手動で交代する'**
  String get manualSwapTitle;

  /// No description provided for @manualSwapItem1.
  ///
  /// In ja, this message translates to:
  /// **'表示中のラウンドで、交代する選手を長押しします。「選手を入れ替える」から最初の選手を選ぶこともできます。次に交代相手をタップします。'**
  String get manualSwapItem1;

  /// No description provided for @manualSwapItem2.
  ///
  /// In ja, this message translates to:
  /// **'例として、けがをした選手と休憩欄の選手を交代できます。手動交代では、試合形式や同時出場制限を外れる交代も運営者の判断で行えます。'**
  String get manualSwapItem2;

  /// No description provided for @manualSwapItem3.
  ///
  /// In ja, this message translates to:
  /// **'交代相手を選ぶ前なら「終了」で入れ替え操作を閉じます。交代後に直前の操作を取り消すには、画面上部の「やり直し」アイコンから「戻す」を押します。'**
  String get manualSwapItem3;

  /// No description provided for @manualTroubleshootTitle.
  ///
  /// In ja, this message translates to:
  /// **'試合を生成できないとき'**
  String get manualTroubleshootTitle;

  /// No description provided for @manualTroubleshootItem1.
  ///
  /// In ja, this message translates to:
  /// **'人数不足が表示されたら、当日の参加設定と一時休み・早退を確認します。人数に合わせてコートを減らすか、試合形式を見直します。'**
  String get manualTroubleshootItem1;

  /// No description provided for @manualTroubleshootItem2.
  ///
  /// In ja, this message translates to:
  /// **'同時出場制限で組めない場合は、ペアの片方が休めるようにコート数や形式を見直します。'**
  String get manualTroubleshootItem2;

  /// No description provided for @manualExpenseTitle.
  ///
  /// In ja, this message translates to:
  /// **'練習会の費用を精算する'**
  String get manualExpenseTitle;

  /// No description provided for @manualExpenseItem1.
  ///
  /// In ja, this message translates to:
  /// **'「費用計算」の「出費を追加」から、コート代やシャトル・ボール代などを入力します。消耗品は在庫から選ぶか、単価と使用数を入力できます。'**
  String get manualExpenseItem1;

  /// No description provided for @manualExpenseItem2.
  ///
  /// In ja, this message translates to:
  /// **'明細をタップして立替者を設定します。費用ごとに分担対象を指定するときは「男女」を選び、明細で対象を指定します。'**
  String get manualExpenseItem2;

  /// No description provided for @manualExpenseItem3.
  ///
  /// In ja, this message translates to:
  /// **'「支払調整」で1人あたりの集金額、収支、立替額を確認します。シャトルなどの使用数を入力した日は、日付を確認し「支払確定・記録を保存」で消費記録を残せます。'**
  String get manualExpenseItem3;

  /// No description provided for @otherInquiryBug.
  ///
  /// In ja, this message translates to:
  /// **'不具合'**
  String get otherInquiryBug;

  /// No description provided for @otherInquiryRequest.
  ///
  /// In ja, this message translates to:
  /// **'機能改善要望'**
  String get otherInquiryRequest;

  /// No description provided for @otherInquiryOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get otherInquiryOther;

  /// No description provided for @otherVersionFallback.
  ///
  /// In ja, this message translates to:
  /// **'取得できませんでした'**
  String get otherVersionFallback;

  /// No description provided for @otherUpdateHistory.
  ///
  /// In ja, this message translates to:
  /// **'アップデート履歴'**
  String get otherUpdateHistory;

  /// No description provided for @otherInquiryTitle.
  ///
  /// In ja, this message translates to:
  /// **'ご意見・お問い合わせ'**
  String get otherInquiryTitle;

  /// No description provided for @otherInquiryReportBug.
  ///
  /// In ja, this message translates to:
  /// **'不具合を報告する'**
  String get otherInquiryReportBug;

  /// No description provided for @otherInquiryRequestFeature.
  ///
  /// In ja, this message translates to:
  /// **'機能改善を要望する'**
  String get otherInquiryRequestFeature;

  /// No description provided for @otherInquiryElse.
  ///
  /// In ja, this message translates to:
  /// **'その他のお問い合わせ'**
  String get otherInquiryElse;

  /// No description provided for @otherUnknown.
  ///
  /// In ja, this message translates to:
  /// **'Unknown'**
  String get otherUnknown;

  /// No description provided for @otherWeb.
  ///
  /// In ja, this message translates to:
  /// **'Web'**
  String get otherWeb;

  /// No description provided for @otherAndroid.
  ///
  /// In ja, this message translates to:
  /// **'Android {release}'**
  String otherAndroid(String release);

  /// No description provided for @otherIos.
  ///
  /// In ja, this message translates to:
  /// **'iOS {version}'**
  String otherIos(String version);

  /// No description provided for @otherInquiryTemplate.
  ///
  /// In ja, this message translates to:
  /// **'【環境情報】\nApp: v{appVersion}\nOS: {osVersion}\n\n【お問い合わせ内容】\n'**
  String otherInquiryTemplate(String appVersion, String osVersion);

  /// No description provided for @otherOpenFormFailed.
  ///
  /// In ja, this message translates to:
  /// **'フォームを開けませんでした'**
  String get otherOpenFormFailed;

  /// No description provided for @otherPrivacyPolicy.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get otherPrivacyPolicy;

  /// No description provided for @otherPrivacySection1Title.
  ///
  /// In ja, this message translates to:
  /// **'1. 情報の収集'**
  String get otherPrivacySection1Title;

  /// No description provided for @otherPrivacySection1Body.
  ///
  /// In ja, this message translates to:
  /// **'本アプリでは、お問い合わせ時にメールアドレス、端末情報（OSバージョン、機種名）、およびお問い合わせ内容を収集します。'**
  String get otherPrivacySection1Body;

  /// No description provided for @otherPrivacySection2Title.
  ///
  /// In ja, this message translates to:
  /// **'2. 利用目的'**
  String get otherPrivacySection2Title;

  /// No description provided for @otherPrivacySection2Body.
  ///
  /// In ja, this message translates to:
  /// **'収集した情報は、不具合の調査、機能改善の検討、およびお問い合わせへの回答のみに利用します。'**
  String get otherPrivacySection2Body;

  /// No description provided for @otherPrivacySection3Title.
  ///
  /// In ja, this message translates to:
  /// **'3. 第三者提供'**
  String get otherPrivacySection3Title;

  /// No description provided for @otherPrivacySection3Body.
  ///
  /// In ja, this message translates to:
  /// **'法令に基づく場合を除き、取得した個人情報を第三者に提供することはありません。'**
  String get otherPrivacySection3Body;

  /// No description provided for @otherPrivacySection4Title.
  ///
  /// In ja, this message translates to:
  /// **'4. データの管理'**
  String get otherPrivacySection4Title;

  /// No description provided for @otherPrivacySection4Body.
  ///
  /// In ja, this message translates to:
  /// **'収集したデータは、Google Cloud Firestore にて適切に管理・保存されます。'**
  String get otherPrivacySection4Body;

  /// No description provided for @otherScreenTitle.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get otherScreenTitle;

  /// No description provided for @otherManual.
  ///
  /// In ja, this message translates to:
  /// **'マニュアル'**
  String get otherManual;

  /// No description provided for @otherInquiry.
  ///
  /// In ja, this message translates to:
  /// **'ご意見・お問い合わせ'**
  String get otherInquiry;

  /// No description provided for @otherInquirySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'不具合の報告や機能改善の要望はこちら'**
  String get otherInquirySubtitle;

  /// No description provided for @otherVersion.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get otherVersion;

  /// No description provided for @otherVersionBuild.
  ///
  /// In ja, this message translates to:
  /// **'{version} (Build: {buildDate})'**
  String otherVersionBuild(String version, String buildDate);

  /// No description provided for @otherLicenseInfo.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス情報'**
  String get otherLicenseInfo;

  /// No description provided for @otherSupportTitle.
  ///
  /// In ja, this message translates to:
  /// **'🏸 応援する'**
  String get otherSupportTitle;

  /// No description provided for @otherSupportSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'開発者が無償で作成しています。\n練習のお供に役立ったら、ぜひ応援をお願いします！'**
  String get otherSupportSubtitle;

  /// No description provided for @otherMoveToExternal.
  ///
  /// In ja, this message translates to:
  /// **'外部サイトへ移動'**
  String get otherMoveToExternal;

  /// No description provided for @otherMoveToExternalDescription.
  ///
  /// In ja, this message translates to:
  /// **'応援ページ（外部サイト）へ移動します。よろしいですか？'**
  String get otherMoveToExternalDescription;

  /// No description provided for @otherSupportSectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'サポート'**
  String get otherSupportSectionTitle;

  /// No description provided for @otherSupportSectionSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'お問い合わせや使い方ガイドにすぐアクセスできます。'**
  String get otherSupportSectionSubtitle;

  /// No description provided for @otherInquiryCta.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリを選択'**
  String get otherInquiryCta;

  /// No description provided for @otherInquirySemantic.
  ///
  /// In ja, this message translates to:
  /// **'ご意見・お問い合わせ。1タップでカテゴリ選択へ進みます。'**
  String get otherInquirySemantic;

  /// No description provided for @otherInquirySemanticHint.
  ///
  /// In ja, this message translates to:
  /// **'タップしてお問い合わせカテゴリを選択します。'**
  String get otherInquirySemanticHint;

  /// No description provided for @otherInquiryBottomSheetHint.
  ///
  /// In ja, this message translates to:
  /// **'タップして外部フォームを開きます。'**
  String get otherInquiryBottomSheetHint;

  /// No description provided for @otherManualSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'基本操作と進行手順を確認できます。'**
  String get otherManualSubtitle;

  /// No description provided for @otherManualSemantic.
  ///
  /// In ja, this message translates to:
  /// **'マニュアル。アプリの使い方ガイドを開きます。'**
  String get otherManualSemantic;

  /// No description provided for @otherOpenScreenSemanticHint.
  ///
  /// In ja, this message translates to:
  /// **'タップして画面を開きます。'**
  String get otherOpenScreenSemanticHint;

  /// No description provided for @otherAppInfoSectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'アプリ情報'**
  String get otherAppInfoSectionTitle;

  /// No description provided for @otherAppInfoSectionSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'バージョンや更新内容、ポリシーを確認できます。'**
  String get otherAppInfoSectionSubtitle;

  /// No description provided for @otherLatestUpdateInline.
  ///
  /// In ja, this message translates to:
  /// **'最新 v{version} ({date})\n{highlight}'**
  String otherLatestUpdateInline(String version, String date, String highlight);

  /// No description provided for @otherNoReleaseHistory.
  ///
  /// In ja, this message translates to:
  /// **'更新履歴はまだありません。'**
  String get otherNoReleaseHistory;

  /// No description provided for @otherLatestUpdateDetails.
  ///
  /// In ja, this message translates to:
  /// **'最新アップデートの詳細'**
  String get otherLatestUpdateDetails;

  /// No description provided for @otherViewAllUpdateHistory.
  ///
  /// In ja, this message translates to:
  /// **'すべての履歴を見る'**
  String get otherViewAllUpdateHistory;

  /// No description provided for @otherVersionSemantic.
  ///
  /// In ja, this message translates to:
  /// **'バージョン情報 {version} と最新更新内容を表示します。'**
  String otherVersionSemantic(String version);

  /// No description provided for @otherReleaseDetailsSemanticHint.
  ///
  /// In ja, this message translates to:
  /// **'タップして更新内容の詳細モーダルを開きます。'**
  String get otherReleaseDetailsSemanticHint;

  /// No description provided for @otherPrivacySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'個人情報の取り扱い方針を確認できます。'**
  String get otherPrivacySubtitle;

  /// No description provided for @otherPrivacySemantic.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー。情報の収集と利用方針を表示します。'**
  String get otherPrivacySemantic;

  /// No description provided for @otherOpenSheetSemanticHint.
  ///
  /// In ja, this message translates to:
  /// **'タップしてモーダルを開きます。'**
  String get otherOpenSheetSemanticHint;

  /// No description provided for @otherLicenseSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'利用ライブラリのライセンス一覧を確認できます。'**
  String get otherLicenseSubtitle;

  /// No description provided for @otherLicenseSemantic.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス情報。OSSライセンス一覧を開きます。'**
  String get otherLicenseSemantic;

  /// No description provided for @otherCommunitySectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'コミュニティ / 応援'**
  String get otherCommunitySectionTitle;

  /// No description provided for @otherCommunitySectionSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'アプリの継続開発を応援できます。'**
  String get otherCommunitySectionSubtitle;

  /// No description provided for @otherCommunitySupportSemantic.
  ///
  /// In ja, this message translates to:
  /// **'応援ページ。外部サイトで開発者を支援します。'**
  String get otherCommunitySupportSemantic;

  /// No description provided for @otherExternalLinkSemanticHint.
  ///
  /// In ja, this message translates to:
  /// **'タップすると外部サイトへ移動確認ダイアログを表示します。'**
  String get otherExternalLinkSemanticHint;

  /// No description provided for @commonCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get commonCancel;

  /// No description provided for @otherMove.
  ///
  /// In ja, this message translates to:
  /// **'移動する'**
  String get otherMove;
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
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
