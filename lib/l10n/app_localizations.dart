import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[
    Locale('ja'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static const Map<String, String> _ja = {
    'appTitle': 'Game Member Generator',
    'navMembers': 'メンバー',
    'navMatchHistory': '試合履歴',
    'navExpense': '費用計算',
    'navOther': 'その他',
    'manualGuideTitle': '使い方ガイド',
    'manualStep1Title': '1. メンバー画面で準備する',
    'manualStep1Item1': '「メンバー」タブで + ボタンから登録し、参加メンバーをONにします。',
    'manualStep1Item2': '同時出場制限を設定すると、夫婦でどちらかが小さい子供を見る必要がある場合などにどちらかは必ず休みになります。',
    'manualStep1Item3': '検索バーで名前・よみがなをすぐに探せます。',
    'manualStep1Item4': '右上メニューからCSV/JSONで保存・読み込み、複数メンバーの登録・削除ができます。',
    'manualStep2Title': '2. 試合履歴画面で進行する',
    'manualStep2Item1': '自動で試合タイプを提案(男女の入る回数を平滑化)し、必要なら手動で編集できます。',
    'manualStep2Item2': 'ペア回数の記録を見える化し、偏りの確認がしやすいです。',
    'manualStep2Item3': 'できるだけ連続休みを避けつつ、種目バランス・ペア回数・敵になる回数を考慮して試合生成します。',
    'manualStep2Item4': '履歴は時系列で追えるので、進行が見失いにくいです。',
    'manualStep3Title': '3. 費用計算画面で精算する',
    'manualStep3Item1': '予め買っておいたシャトル・ボールの価格を登録しておけます。',
    'manualStep3Item2': '当日使った個数を入力すると、消耗分の費用を自動計算できます。',
    'manualStep3Item3': 'コート代など他の費用も追加して、1人あたり金額をまとめて算出できます。',
    'manualStep3Item4': '男子/女子/全員など分担対象を切り替えられます。',
    'manualTipsTitle': '使いこなしのコツ',
    'manualTipsChipRegister': 'まずは8〜12人を登録',
    'manualTipsChipCourt': '今日のコート数を設定',
    'manualTipsChipGenerate': '試合生成画面で自動で試合生成！',
    'manualHeroTitle': 'はじめてでも3ステップ',
    'manualHeroSubtitle': 'メンバー登録 → 試合生成 → 試合開始！',
    'otherInquiryBug': '不具合',
    'otherInquiryRequest': '機能改善要望',
    'otherInquiryOther': 'その他',
    'otherVersionFallback': '取得できませんでした',
    'otherUpdateHistory': 'アップデート履歴',
    'otherInquiryTitle': 'ご意見・お問い合わせ',
    'otherInquiryReportBug': '不具合を報告する',
    'otherInquiryRequestFeature': '機能改善を要望する',
    'otherInquiryElse': 'その他のお問い合わせ',
    'otherUnknown': 'Unknown',
    'otherWeb': 'Web',
    'otherOpenFormFailed': 'フォームを開けませんでした',
    'otherPrivacyPolicy': 'プライバシーポリシー',
    'otherPrivacySection1Title': '1. 情報の収集',
    'otherPrivacySection1Body': '本アプリでは、お問い合わせ時にメールアドレス、端末情報（OSバージョン、機種名）、およびお問い合わせ内容を収集します。',
    'otherPrivacySection2Title': '2. 利用目的',
    'otherPrivacySection2Body': '収集した情報は、不具合の調査、機能改善の検討、およびお問い合わせへの回答のみに利用します。',
    'otherPrivacySection3Title': '3. 第三者提供',
    'otherPrivacySection3Body': '法令に基づく場合を除き、取得した個人情報を第三者に提供することはありません。',
    'otherPrivacySection4Title': '4. データの管理',
    'otherPrivacySection4Body': '収集したデータは、Google Cloud Firestore にて適切に管理・保存されます。',
    'otherScreenTitle': 'その他',
    'otherManual': 'マニュアル',
    'otherInquiry': 'ご意見・お問い合わせ',
    'otherInquirySubtitle': '不具合の報告や機能改善の要望はこちら',
    'otherVersion': 'バージョン',
    'otherLicenseInfo': 'ライセンス情報',
    'otherSupportTitle': '🏸 応援する',
    'otherSupportSubtitle': '開発者が無償で作成しています。\n練習のお供に役立ったら、ぜひ応援をお願いします！',
    'otherMoveToExternal': '外部サイトへ移動',
    'otherMoveToExternalDescription': '応援ページ（外部サイト）へ移動します。よろしいですか？',
    'commonCancel': 'キャンセル',
    'otherMove': '移動する',
  };

  String _text(String key) => _ja[key] ?? key;

  String get appTitle => _text('appTitle');
  String get navMembers => _text('navMembers');
  String get navMatchHistory => _text('navMatchHistory');
  String get navExpense => _text('navExpense');
  String get navOther => _text('navOther');
  String get manualGuideTitle => _text('manualGuideTitle');
  String get manualStep1Title => _text('manualStep1Title');
  String get manualStep1Item1 => _text('manualStep1Item1');
  String get manualStep1Item2 => _text('manualStep1Item2');
  String get manualStep1Item3 => _text('manualStep1Item3');
  String get manualStep1Item4 => _text('manualStep1Item4');
  String get manualStep2Title => _text('manualStep2Title');
  String get manualStep2Item1 => _text('manualStep2Item1');
  String get manualStep2Item2 => _text('manualStep2Item2');
  String get manualStep2Item3 => _text('manualStep2Item3');
  String get manualStep2Item4 => _text('manualStep2Item4');
  String get manualStep3Title => _text('manualStep3Title');
  String get manualStep3Item1 => _text('manualStep3Item1');
  String get manualStep3Item2 => _text('manualStep3Item2');
  String get manualStep3Item3 => _text('manualStep3Item3');
  String get manualStep3Item4 => _text('manualStep3Item4');
  String get manualTipsTitle => _text('manualTipsTitle');
  String get manualTipsChipRegister => _text('manualTipsChipRegister');
  String get manualTipsChipCourt => _text('manualTipsChipCourt');
  String get manualTipsChipGenerate => _text('manualTipsChipGenerate');
  String get manualHeroTitle => _text('manualHeroTitle');
  String get manualHeroSubtitle => _text('manualHeroSubtitle');
  String get otherInquiryBug => _text('otherInquiryBug');
  String get otherInquiryRequest => _text('otherInquiryRequest');
  String get otherInquiryOther => _text('otherInquiryOther');
  String get otherVersionFallback => _text('otherVersionFallback');
  String get otherUpdateHistory => _text('otherUpdateHistory');
  String get otherInquiryTitle => _text('otherInquiryTitle');
  String get otherInquiryReportBug => _text('otherInquiryReportBug');
  String get otherInquiryRequestFeature => _text('otherInquiryRequestFeature');
  String get otherInquiryElse => _text('otherInquiryElse');
  String get otherUnknown => _text('otherUnknown');
  String get otherWeb => _text('otherWeb');
  String otherAndroid(String release) => 'Android $release';
  String otherIos(String version) => 'iOS $version';
  String otherInquiryTemplate(String appVersion, String osVersion) =>
      '【環境情報】\nApp: v$appVersion\nOS: $osVersion\n\n【お問い合わせ内容】\n';
  String get otherOpenFormFailed => _text('otherOpenFormFailed');
  String get otherPrivacyPolicy => _text('otherPrivacyPolicy');
  String get otherPrivacySection1Title => _text('otherPrivacySection1Title');
  String get otherPrivacySection1Body => _text('otherPrivacySection1Body');
  String get otherPrivacySection2Title => _text('otherPrivacySection2Title');
  String get otherPrivacySection2Body => _text('otherPrivacySection2Body');
  String get otherPrivacySection3Title => _text('otherPrivacySection3Title');
  String get otherPrivacySection3Body => _text('otherPrivacySection3Body');
  String get otherPrivacySection4Title => _text('otherPrivacySection4Title');
  String get otherPrivacySection4Body => _text('otherPrivacySection4Body');
  String get otherScreenTitle => _text('otherScreenTitle');
  String get otherManual => _text('otherManual');
  String get otherInquiry => _text('otherInquiry');
  String get otherInquirySubtitle => _text('otherInquirySubtitle');
  String get otherVersion => _text('otherVersion');
  String otherVersionBuild(String version, String buildDate) => '$version (Build: $buildDate)';
  String get otherLicenseInfo => _text('otherLicenseInfo');
  String get otherSupportTitle => _text('otherSupportTitle');
  String get otherSupportSubtitle => _text('otherSupportSubtitle');
  String get otherMoveToExternal => _text('otherMoveToExternal');
  String get otherMoveToExternalDescription => _text('otherMoveToExternalDescription');
  String get commonCancel => _text('commonCancel');
  String get otherMove => _text('otherMove');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
