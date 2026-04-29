# Bet Hub WebSocket Server

## Start

```bash
npm install
npm start
```

The server starts on `ws://localhost:8080` by default with an empty room.

## Local mock seed

When you want to quickly verify the UI with sample members, bet targets, and bets:

```bash
npm run start:mock
```

You can also enable it with an environment variable:

```bash
ENABLE_MOCK_DATA=true npm start
```

## Flutter connection

Run the Flutter app with:

```bash
flutter run --dart-define=ROOM_SERVER_URL=ws://localhost:8080
```
