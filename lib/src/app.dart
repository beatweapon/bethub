import 'package:flutter/material.dart';

import 'data/room_repository.dart';
import 'data/web_socket_room_repository.dart';
import 'screens/entry_page.dart';
import 'state/room_scope.dart';
import 'state/room_state.dart';

class BetHubApp extends StatefulWidget {
  const BetHubApp({super.key});

  @override
  State<BetHubApp> createState() => _BetHubAppState();
}

class _BetHubAppState extends State<BetHubApp> {
  late final RoomState _roomState;

  @override
  void initState() {
    super.initState();
    _roomState = RoomState(repository: _buildRepository());
  }

  RoomRepository _buildRepository() {
    const roomServerUrl = String.fromEnvironment(
      'ROOM_SERVER_URL',
      defaultValue: 'ws://localhost:8080',
    );
    return WebSocketRoomRepository(serverUrl: roomServerUrl);
  }

  @override
  void dispose() {
    _roomState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoomScope(
      state: _roomState,
      child: MaterialApp(
        title: 'Bet Hub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A7F64)),
          scaffoldBackgroundColor: const Color(0xFFF4F7F3),
          useMaterial3: true,
        ),
        home: const EntryPage(),
      ),
    );
  }
}
