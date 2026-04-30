import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/race_status.dart';
import '../models/room_session.dart';
import 'room_repository.dart';

class WebSocketRoomRepository implements RoomRepository {
  WebSocketRoomRepository({required this.serverUrl, this.roomId = 'main-room'});

  final String serverUrl;
  final String roomId;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  StreamController<RoomSession>? _controller;
  Future<void>? _connectFuture;
  Future<void>? _prewarmFuture;
  RoomSession? _session;
  String? _memberId;
  bool _isRoomMaster = false;
  String? _joiningUserName;
  String? _joinedUserName;
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  Completer<RoomSession>? _joinCompleter;
  Completer<RoomSession>? _submitBetCompleter;
  Completer<RoomSession>? _updateRaceStatusCompleter;
  Completer<RoomSession>? _addBetTargetCompleter;
  Completer<RoomSession>? _submitRaceResultsCompleter;

  @override
  Future<void> prewarmServer() async {
    final pending = _prewarmFuture;
    if (pending != null) {
      return pending;
    }

    final future = _sendWarmUpRequest();
    _prewarmFuture = future;
    try {
      await future;
    } finally {
      _prewarmFuture = null;
    }
  }

  @override
  Future<RoomSession> joinRoom({required String userName}) async {
    try {
      await _ensureConnected();
    } catch (error) {
      throw RoomJoinException('サーバー接続に失敗しました: $error');
    }

    final existingJoin = _joinCompleter;
    if (existingJoin != null && !existingJoin.isCompleted) {
      throw const RoomJoinException('別の入室処理が進行中です。');
    }

    final completer = Completer<RoomSession>();
    _joinCompleter = completer;
    _joiningUserName = userName;
    _sendMessage('join_room', {'roomId': roomId, 'userName': userName});

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _joinCompleter = null;
        _joiningUserName = null;
        throw const RoomJoinException('サーバーから入室結果を取得できませんでした。');
      },
    );
  }

  @override
  Stream<RoomSession> watchRoom(String roomId) {
    final controller = _controller ??=
        StreamController<RoomSession>.broadcast();
    final session = _session;
    if (session == null || session.roomId != roomId) {
      return controller.stream.where((next) => next.roomId == roomId);
    }

    return Stream<RoomSession>.multi((multi) {
      multi.add(session);
      final subscription = controller.stream
          .where((next) => next.roomId == roomId)
          .listen(multi.add, onError: multi.addError, onDone: multi.close);
      multi.onCancel = subscription.cancel;
    });
  }

  @override
  Future<RoomSession> submitBet({
    required String roomId,
    required String memberId,
    required String targetId,
    required int amount,
  }) async {
    await _ensureConnected();

    final existingSubmit = _submitBetCompleter;
    if (existingSubmit != null && !existingSubmit.isCompleted) {
      throw StateError('Another bet submission is in progress.');
    }

    final completer = Completer<RoomSession>();
    _submitBetCompleter = completer;
    _sendMessage('submit_bet', {
      'roomId': roomId,
      'memberId': memberId,
      'targetId': targetId,
      'amount': amount,
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _submitBetCompleter = null;
        throw StateError('Timed out while waiting for bet update.');
      },
    );
  }

  Future<void> _ensureConnected() async {
    if (_channel != null) {
      return;
    }

    final pending = _connectFuture;
    if (pending != null) {
      return pending;
    }

    final future = _connect();
    _connectFuture = future;
    try {
      await future;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> _connect() async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _channel = channel;
      _controller ??= StreamController<RoomSession>.broadcast();

      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _handleStreamClosed(error);
        },
        onDone: () {
          _handleStreamClosed();
        },
      );

      await channel.ready.timeout(const Duration(seconds: 5));
      _startKeepAlive();
    } catch (error) {
      _handleStreamClosed(error);
      rethrow;
    }
  }

  Future<void> _sendWarmUpRequest() async {
    final uri = _buildHealthCheckUri();
    if (uri == null) {
      return;
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      throw StateError('Health check failed with status ${response.statusCode}.');
    }
  }

  Uri? _buildHealthCheckUri() {
    final serverUri = Uri.tryParse(serverUrl);
    if (serverUri == null || !serverUri.hasScheme) {
      return null;
    }

    final scheme = switch (serverUri.scheme) {
      'ws' => 'http',
      'wss' => 'https',
      'http' || 'https' => serverUri.scheme,
      _ => null,
    };
    if (scheme == null) {
      return null;
    }

    return serverUri.replace(scheme: scheme, path: '/health', query: null);
  }

  void _handleMessage(Object? rawMessage) {
    final json = jsonDecode(rawMessage as String) as Map<String, dynamic>;
    final type = json['type'] as String? ?? '';
    final payload = json['payload'] as Map<String, dynamic>? ?? const {};

    switch (type) {
      case 'join_room_success':
        _memberId = payload['memberId'] as String?;
        _isRoomMaster = payload['isRoomMaster'] as bool? ?? false;
        _joinedUserName = _joiningUserName;
        _joiningUserName = null;
        _cancelReconnect();
        _reconnectAttempts = 0;
        break;
      case 'room_snapshot':
        final session = _parseSession(payload);
        _session = session;
        _controller?.add(session);

        final joinCompleter = _joinCompleter;
        if (joinCompleter != null &&
            !joinCompleter.isCompleted &&
            (_isRoomMaster ||
                session.members.any((member) => member.isCurrentUser))) {
          joinCompleter.complete(session);
          _joinCompleter = null;
        }

        final submitBetCompleter = _submitBetCompleter;
        if (submitBetCompleter != null && !submitBetCompleter.isCompleted) {
          submitBetCompleter.complete(session);
          _submitBetCompleter = null;
        }

        final updateRaceStatusCompleter = _updateRaceStatusCompleter;
        if (updateRaceStatusCompleter != null &&
            !updateRaceStatusCompleter.isCompleted) {
          updateRaceStatusCompleter.complete(session);
          _updateRaceStatusCompleter = null;
        }

        final addBetTargetCompleter = _addBetTargetCompleter;
        if (addBetTargetCompleter != null &&
            !addBetTargetCompleter.isCompleted) {
          addBetTargetCompleter.complete(session);
          _addBetTargetCompleter = null;
        }

        final submitRaceResultsCompleter = _submitRaceResultsCompleter;
        if (submitRaceResultsCompleter != null &&
            !submitRaceResultsCompleter.isCompleted) {
          submitRaceResultsCompleter.complete(session);
          _submitRaceResultsCompleter = null;
        }
        break;
      case 'error':
        final message =
            payload['message'] as String? ?? 'Unknown server error.';
        final joinCompleter = _joinCompleter;
        if (joinCompleter != null && !joinCompleter.isCompleted) {
          _joiningUserName = null;
          joinCompleter.completeError(RoomJoinException(message));
          _joinCompleter = null;
          return;
        }

        final submitBetCompleter = _submitBetCompleter;
        if (submitBetCompleter != null && !submitBetCompleter.isCompleted) {
          submitBetCompleter.completeError(StateError(message));
          _submitBetCompleter = null;
        }

        final updateRaceStatusCompleter = _updateRaceStatusCompleter;
        if (updateRaceStatusCompleter != null &&
            !updateRaceStatusCompleter.isCompleted) {
          updateRaceStatusCompleter.completeError(StateError(message));
          _updateRaceStatusCompleter = null;
        }

        final addBetTargetCompleter = _addBetTargetCompleter;
        if (addBetTargetCompleter != null &&
            !addBetTargetCompleter.isCompleted) {
          addBetTargetCompleter.completeError(StateError(message));
          _addBetTargetCompleter = null;
        }

        final submitRaceResultsCompleter = _submitRaceResultsCompleter;
        if (submitRaceResultsCompleter != null &&
            !submitRaceResultsCompleter.isCompleted) {
          submitRaceResultsCompleter.completeError(StateError(message));
          _submitRaceResultsCompleter = null;
        }
        break;
      case 'pong':
        break;
    }
  }

  RoomSession _parseSession(Map<String, dynamic> payload) {
    final session = RoomSession.fromJson(payload);
    final currentMemberId = _memberId;
    if (currentMemberId == null) {
      return session;
    }

    final nextMembers = session.members
        .map(
          (member) =>
              member.copyWith(isCurrentUser: member.id == currentMemberId),
        )
        .toList();

    return session.copyWith(members: nextMembers);
  }

  void _handleStreamClosed([Object? error]) {
    if (_channel == null && _subscription == null) {
      return;
    }

    _stopKeepAlive();
    _subscription = null;
    _channel = null;
    final joinCompleter = _joinCompleter;
    if (joinCompleter != null && !joinCompleter.isCompleted) {
      _joiningUserName = null;
      joinCompleter.completeError(
        RoomJoinException('サーバー接続に失敗しました: ${error ?? '接続が切断されました'}'),
      );
      _joinCompleter = null;
    }

    final submitBetCompleter = _submitBetCompleter;
    if (submitBetCompleter != null && !submitBetCompleter.isCompleted) {
      submitBetCompleter.completeError(StateError('ベット更新の受信に失敗しました: $error'));
      _submitBetCompleter = null;
    }

    final updateRaceStatusCompleter = _updateRaceStatusCompleter;
    if (updateRaceStatusCompleter != null &&
        !updateRaceStatusCompleter.isCompleted) {
      updateRaceStatusCompleter.completeError(
        StateError('レースステータス更新に失敗しました: $error'),
      );
      _updateRaceStatusCompleter = null;
    }

    final addBetTargetCompleter = _addBetTargetCompleter;
    if (addBetTargetCompleter != null && !addBetTargetCompleter.isCompleted) {
      addBetTargetCompleter.completeError(StateError('ベット対象追加に失敗しました: $error'));
      _addBetTargetCompleter = null;
    }

    final submitRaceResultsCompleter = _submitRaceResultsCompleter;
    if (submitRaceResultsCompleter != null &&
        !submitRaceResultsCompleter.isCompleted) {
      submitRaceResultsCompleter.completeError(
        StateError('レース結果提出に失敗しました: ${error ?? '接続が切断されました'}'),
      );
      _submitRaceResultsCompleter = null;
    }

    _scheduleReconnect();
  }

  void _sendMessage(String type, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WebSocket is not connected.');
    }

    final message = jsonEncode({'type': type, 'payload': payload});
    channel.sink.add(message);
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      final channel = _channel;
      if (channel == null) {
        _stopKeepAlive();
        return;
      }

      final message = jsonEncode({
        'type': 'ping',
        'payload': {'timestamp': DateTime.now().toUtc().toIso8601String()},
      });
      try {
        channel.sink.add(message);
      } catch (error) {
        _handleStreamClosed(error);
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _scheduleReconnect() {
    final userName = _joinedUserName;
    if (_isDisposed || userName == null || _reconnectTimer != null) {
      return;
    }

    final delaySeconds = min(30, 2 << _reconnectAttempts);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      if (_isDisposed || _channel != null) {
        return;
      }

      try {
        await prewarmServer();
        await joinRoom(userName: userName);
        _reconnectAttempts = 0;
      } catch (_) {
        _reconnectAttempts += 1;
        _scheduleReconnect();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  Future<RoomSession> updateRaceStatus({
    required String roomId,
    required RaceStatus status,
  }) async {
    await _ensureConnected();

    final completer = Completer<RoomSession>();
    _updateRaceStatusCompleter = completer;
    _sendMessage('update_race_status', {
      'roomId': roomId,
      'status': status.toString(),
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _updateRaceStatusCompleter = null;
        throw StateError('Timed out while waiting for race status update.');
      },
    );
  }

  @override
  Future<RoomSession> addBetTarget({
    required String roomId,
    required String targetName,
  }) async {
    await _ensureConnected();

    final completer = Completer<RoomSession>();
    _addBetTargetCompleter = completer;
    _sendMessage('add_bet_target', {
      'roomId': roomId,
      'targetName': targetName,
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _addBetTargetCompleter = null;
        throw StateError('Timed out while waiting for bet target creation.');
      },
    );
  }

  @override
  Future<RoomSession> submitRaceResults({
    required String roomId,
    required List<String> betTargetIds,
  }) async {
    await _ensureConnected();

    final completer = Completer<RoomSession>();
    _submitRaceResultsCompleter = completer;
    _sendMessage('submit_race_results', {
      'roomId': roomId,
      'betTargetIds': betTargetIds,
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _submitRaceResultsCompleter = null;
        throw StateError(
          'Timed out while waiting for race results submission.',
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _stopKeepAlive();
    _cancelReconnect();
    await _subscription?.cancel();
    final channel = _channel;
    if (channel != null) {
      await channel.sink.close();
    }
    await _controller?.close();
    _channel = null;
    _subscription = null;
    _controller = null;
  }
}
