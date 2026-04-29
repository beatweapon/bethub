import 'dart:async';

import 'package:flutter/material.dart';

import '../data/room_repository.dart';
import '../state/room_scope.dart';
import 'bet_page.dart';
import 'room_master_page.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(RoomScope.of(context).prewarmServer());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userName = _nameController.text.trim();
    final isRoomMaster = userName == '管理者';

    final roomState = RoomScope.of(context);
    try {
      await roomState.joinRoom(userName);
    } on RoomJoinException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted || roomState.session == null) {
      return;
    }

    final destinationPage = isRoomMaster
        ? const RoomMasterPage()
        : const BetPage();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destinationPage));
  }

  @override
  Widget build(BuildContext context) {
    final roomState = RoomScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bet Hub',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ユーザー名を入力して部屋に入室します。入室時に初期コイン500枚を付与します。',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'ユーザー名',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'ユーザー名を入力してください';
                            }
                            if (trimmed.length > 20) {
                              return '20文字以内で入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: roomState.isJoining ? null : _handleJoin,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: roomState.isJoining
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('入室する'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
