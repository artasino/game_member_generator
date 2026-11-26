# Game Member Generator

バドミントン・テニス・卓球などの練習会で、コートごとの組み合わせと休憩メンバーを決めるFlutterアプリです。参加者の登録から試合進行、当日の費用計算まで扱えます。

- [ブラウザで使う](https://game-member-generator.web.app/)
- [Windows版をダウンロードする](https://github.com/artasino/game_member_generator/releases/latest)
- [練習会の運営マニュアルを読む](docs/manual.md)

iPhoneでは、初回に通信できる場所で準備すると圏外でも使えます。 [iPhoneでのオフライン準備](docs/manual.md#iphoneでオフラインに備える)

## 最初のラウンドを作る

1. **メンバー**で参加者を登録し、当日参加する人をオンにします。
2. **試合履歴**で**最初の試合を作成**を押します。自動で試合形式を提案する場合はコート数を選び、自分で決める場合はコートごとの試合形式を選びます。
3. **スタート**を押し、コート別の組み合わせと休憩メンバーを確認します。次のラウンドは右下の **＋** から作成します。

アプリ内では **その他 → マニュアル** からも手順を確認できます。

## できること

- **組み合わせの自動生成**。出場・休憩の履歴、ペアや対戦相手の重複を考慮し、組み合わせを作ります。男子・女子・混合ダブルスに加え、性別の組み合わせを指定しない形式も選べます。
- **同時出場制限と手動交代**。子守りなどで同時に出場できないペアを設定すると、自動生成に反映されます。けがなどの際は、運営者の判断で試合形式や同時出場制限を外れる交代もできます。
- **メンバー管理**。当日の参加、一時休み、早退を設定できます。メンバー一覧はCSV・JSONで読み込み・書き出しできます。
- **費用計算**。コート代やシャトル・ボール代をまとめ、全員または男女別の集金額と立替額を確認できます。

## 開発・公開

Flutter環境で次のコマンドを実行すると、Chromeでアプリを起動できます。

```sh
flutter pub get
flutter run -d chrome
```

[GitHub Actions](.github/workflows/deploy_firebase_hosting.yml) は `master` へのpush、`v*.*.*` タグのpush、手動実行でWeb版とWindows版をビルドします。タグのpushと手動実行はビルド確認に使えます。

公開するには、GitHubの **Releases** でバージョンタグ（例 `v2.4.0`）を選び、**Publish release** を押します。公開イベントを受けて、Web版をFirebase Hostingへデプロイし、Windows版のZIPを公開済みのリリースに添付します。

Web版のバージョンは公開タグから取得します。公開タグと一致する変更概要が `assets/changelog.json` にあれば優先し、なければ前回のタグ以降のコミットから概要を作ります。Web版では **その他 → バージョン** で確認できます。

Firebase Hostingへの公開には、プロジェクト `game-member-generator` にデプロイできるサービスアカウントのJSONを、GitHub Actionsのシークレット `FIREBASE_SERVICE_ACCOUNT_GAME_MEMBER_GENERATOR` に設定します。
