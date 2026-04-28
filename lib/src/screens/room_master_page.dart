import 'package:flutter/material.dart';

import '../models/race_status.dart';
import '../models/room_member.dart';
import '../state/room_scope.dart';

class RoomMasterPage extends StatefulWidget {
  const RoomMasterPage({super.key});

  @override
  State<RoomMasterPage> createState() => _RoomMasterPageState();
}

class _RoomMasterPageState extends State<RoomMasterPage> {
  final _targetNameController = TextEditingController();
  final Map<String, int> _betTargetRankings = {};
  bool _isInitialized = false;
  static const double _defaultOdds = 2.5;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) {
      return;
    }

    final roomState = RoomScope.of(context);
    final session = roomState.session;
    if (session != null) {
      // Initialize rankings with bet targets
      for (final target in session.betTargets) {
        _betTargetRankings[target.id] = 0;
      }
    }

    _isInitialized = true;
  }

  @override
  void dispose() {
    _targetNameController.dispose();
    super.dispose();
  }

  Future<void> _addBetTarget() async {
    if (_targetNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ベット対象名を入力してください')));
      return;
    }

    final roomState = RoomScope.of(context);
    try {
      await roomState.addBetTarget(
        targetName: _targetNameController.text.trim(),
        odds: _defaultOdds,
      );
      _targetNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ベット対象を追加しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  Future<void> _startRace() async {
    final roomState = RoomScope.of(context);
    try {
      await roomState.updateRaceStatus(RaceStatus.racing);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('レースを開始しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  Future<void> _submitResults() async {
    // Validate that all rankings are set
    final notRanked = _betTargetRankings.values.where((rank) => rank == 0);
    if (notRanked.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すべてのベット対象に順位を割り当ててください')));
      return;
    }

    // Sort targets by ranking
    final sortedTargets = _betTargetRankings.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final betTargetIds = sortedTargets.map((e) => e.key).toList();

    final roomState = RoomScope.of(context);
    try {
      await roomState.submitRaceResults(betTargetIds);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('結果を提出しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = RoomScope.of(context);
    final session = roomState.session;

    if (session == null) {
      return const Scaffold(body: Center(child: Text('部屋情報が見つかりませんでした。')));
    }

    final isRacing = session.raceStatus == RaceStatus.racing;

    return Scaffold(
      appBar: AppBar(title: const Text('ルームマスター管理画面')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room info card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.roomName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ステータス: ${isRacing ? 'レース中' : 'ベット受付中'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!isRacing) ...[
              // Bet target registration section
              Text('ベット対象管理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _targetNameController,
                        decoration: const InputDecoration(
                          labelText: 'ベット対象名',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !roomState.isAddingBetTarget,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'オッズは自動算出予定のため、現在は固定値 ${_defaultOdds.toStringAsFixed(1)} を設定します。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: roomState.isAddingBetTarget
                            ? null
                            : _addBetTarget,
                        child: roomState.isAddingBetTarget
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('追加'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Current bet targets
              if (session.betTargets.isNotEmpty) ...[
                Text(
                  '登録済みベット対象',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ...session.betTargets.map(
                  (target) => Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(target.name),
                                Text(
                                  'オッズ: ${target.odds}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Race control buttons
              FilledButton.tonal(
                onPressed: roomState.isUpdatingRaceStatus ? null : _startRace,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  roomState.isUpdatingRaceStatus ? '処理中...' : 'レースを開始',
                ),
              ),
            ] else ...[
              // Race results section
              Text('レース結果入力', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                'ベット対象の最終順位を入力してください',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ..._buildRankingInputs(session),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: roomState.isSubmittingRaceResults
                    ? null
                    : _submitResults,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: roomState.isSubmittingRaceResults
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('結果を提出'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRankingInputs(dynamic session) {
    final targets = session.betTargets;
    final widgets = <Widget>[];

    for (int i = 0; i < targets.length; i++) {
      final target = targets[i];
      widgets.add(
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(target.name)),
                SizedBox(
                  width: 60,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '順位',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _betTargetRankings[target.id] = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (i < targets.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }
}
