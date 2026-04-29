# Bet Hub

Flutter Web で動くベット共有アプリです。GitHub Pages へデプロイできるようにしてあり、WebSocket サーバー URL は GitHub Actions の Variables からビルド時に注入できます。

## Local development

Flutter アプリは `ROOM_SERVER_URL` を `--dart-define` で指定して起動できます。
入室画面を開くと、同じサーバーの `/health` へ事前アクセスして Render のコールドスタートを起こしやすくします。

```bash
flutter run -d chrome --dart-define=ROOM_SERVER_URL=ws://localhost:8080
```

サーバー側は通常起動だと空のルームで立ち上がります。サンプル参加者・ベット対象付きでサクッと確認したい場合は、`server` ディレクトリで次を実行します。

```bash
npm run start:mock
```

## Deploy to GitHub Pages

`main` ブランチへ push すると、`.github/workflows/deploy-pages.yml` で Flutter Web をビルドして GitHub Pages へデプロイします。

事前に GitHub リポジトリで以下を設定してください。

1. `Settings > Pages` で `Source` を `GitHub Actions` にする
2. `Settings > Secrets and variables > Actions > Variables` に `ROOM_SERVER_URL` を追加する

例:

```text
wss://your-websocket-server.example.com
```

ワークフローはリポジトリ名に応じて `base href` を自動計算します。
`username.github.io` リポジトリなら `/`、通常のリポジトリなら `/<repo>/` を使うので、そのまま Pages 配信に乗せられます。
