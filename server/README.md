# Bet Hub WebSocket Server

## Start

```bash
npm install
npm start
```

The server starts on `ws://localhost:8080` by default.

## Flutter connection

Run the Flutter app with:

```bash
flutter run --dart-define=ROOM_SERVER_URL=ws://localhost:8080
```

If `ROOM_SERVER_URL` is not provided, the app falls back to the in-memory mock repository used by tests.
