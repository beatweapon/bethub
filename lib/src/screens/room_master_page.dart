import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/race_status.dart';
import '../models/room_member.dart';
import '../models/room_session.dart';
import '../state/room_scope.dart';
import '../state/room_state.dart';
import '../widgets/bet_target_card.dart';

class RoomMasterPage extends StatefulWidget {
  const RoomMasterPage({super.key});

  @override
  State<RoomMasterPage> createState() => _RoomMasterPageState();
}

class _RoomMasterPageState extends State<RoomMasterPage> {
  final _targetNameController = TextEditingController();
  final Map<String, int> _betTargetRankings = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roomState = RoomScope.of(context);
    final session = roomState.session;
    if (session == null) {
      return;
    }

    final nextTargetIds = session.betTargets.map((target) => target.id).toSet();
    _betTargetRankings.removeWhere((targetId, _) => !nextTargetIds.contains(targetId));
    for (final target in session.betTargets) {
      _betTargetRankings.putIfAbsent(target.id, () => 0);
    }
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
    final sortedMembers = [...session.members]
      ..sort((a, b) {
        final coinComparison = b.coins.compareTo(a.coins);
        if (coinComparison != 0) {
          return coinComparison;
        }
        return a.name.compareTo(b.name);
      });
    final betTargets = session.betTargets;
    final maxWinRate = betTargets.isEmpty
        ? 0.0
        : betTargets.map((target) => target.winRate).reduce(math.max);
    final averageRanks = betTargets
        .map((target) => target.averageRank)
        .whereType<double>()
        .toList();
    final minAverageRank = averageRanks.isEmpty
        ? null
        : averageRanks.reduce(math.min);
    final maxOdds = betTargets.isEmpty
        ? 0.0
        : betTargets.map((target) => target.odds).reduce(math.max);
    final minOdds = betTargets.isEmpty
        ? 0.0
        : betTargets.map((target) => target.odds).reduce(math.min);

    return Scaffold(
      appBar: AppBar(title: const Text('ルームマスター管理画面')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('参加者', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (sortedMembers.isEmpty)
              const Text('まだ参加者はいません')
            else
              ..._buildMemberSummaryCards(
                members: sortedMembers,
                roomState: roomState,
              ),
            const SizedBox(height: 16),
            if (isRacing) ...[
              Text('現在のベット状況', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._buildBetTargetOverviewCards(
                session: session,
                maxWinRate: maxWinRate,
                minAverageRank: minAverageRank,
                maxOdds: maxOdds,
                minOdds: minOdds,
              ),
              const SizedBox(height: 16),
              // Race results section
              Text('レース結果入力', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'ベット対象の最終順位を入力してください',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ..._buildRankingInputs(session),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: roomState.isSubmittingRaceResults
                    ? null
                    : _submitResults,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
            if (!isRacing) ...[
              Text('現在のベット状況', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (session.betTargets.isEmpty)
                const Text('ベット対象を追加するとここに一覧が表示されます')
              else
                ..._buildBetTargetOverviewCards(
                  session: session,
                  maxWinRate: maxWinRate,
                  minAverageRank: minAverageRank,
                  maxOdds: maxOdds,
                  minOdds: minOdds,
                ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetNameController,
                          decoration: const InputDecoration(
                            labelText: 'ベット対象名',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !roomState.isAddingBetTarget,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: roomState.isAddingBetTarget
                            ? null
                            : _addBetTarget,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: roomState.isAddingBetTarget
                            ? const SizedBox(
                                width: 18,
                                height: 18,
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
              FilledButton.tonal(
                onPressed: roomState.isUpdatingRaceStatus ? null : _startRace,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  roomState.isUpdatingRaceStatus ? '処理中...' : 'レースを開始',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMemberSummaryCards({
    required List<RoomMember> members,
    required RoomState roomState,
  }) {
    final widgets = <Widget>[];

    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final totalBetCoins = roomState.totalBetCoinsFor(member.id);
      widgets.add(
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            leading: CircleAvatar(child: Text(member.name.characters.first)),
            title: Text(member.name),
            subtitle: Text('現在のベット: $totalBetCoins枚'),
            trailing: Text('${member.coins}枚'),
          ),
        ),
      );
      if (i < members.length - 1) {
        widgets.add(const SizedBox(height: 6));
      }
    }

    return widgets;
  }

  List<Widget> _buildBetTargetOverviewCards({
    required RoomSession session,
    required double maxWinRate,
    required double? minAverageRank,
    required double maxOdds,
    required double minOdds,
  }) {
    final widgets = <Widget>[];

    for (int i = 0; i < session.betTargets.length; i++) {
      final target = session.betTargets[i];
      widgets.add(
        BetTargetCard(
          target: target,
          isHighestWinRate: (target.winRate - maxWinRate).abs() < 0.0001,
          isHighestAverageRank:
              minAverageRank != null &&
              target.averageRank != null &&
              (target.averageRank! - minAverageRank).abs() < 0.0001,
          isHighestOdds: (target.odds - maxOdds).abs() < 0.0001,
          isLowestOdds: (target.odds - minOdds).abs() < 0.0001,
          totalCoins: _totalBetCoinsForTarget(session: session, targetId: target.id),
          playerBetStatuses: _playerStatusesForTarget(
            members: session.members,
            session: session,
            targetId: target.id,
          ),
        ),
      );
      if (i < session.betTargets.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }

  List<PlayerTargetBetStatus> _playerStatusesForTarget({
    required List<RoomMember> members,
    required RoomSession session,
    required String targetId,
  }) {
    final statuses = <PlayerTargetBetStatus>[];

    for (final member in members) {
      var amount = 0;
      for (final bet in session.bets) {
        if (bet.memberId == member.id && bet.targetId == targetId) {
          amount = bet.amount;
          break;
        }
      }

      if (amount <= 0) {
        continue;
      }

      statuses.add(
        PlayerTargetBetStatus(
          memberName: member.name,
          amount: amount,
          isCurrentUser: member.isCurrentUser,
        ),
      );
    }

    statuses.sort((a, b) {
      final amountComparison = b.amount.compareTo(a.amount);
      if (amountComparison != 0) {
        return amountComparison;
      }
      return a.memberName.compareTo(b.memberName);
    });

    return statuses;
  }

  int _totalBetCoinsForTarget({
    required RoomSession session,
    required String targetId,
  }) {
    var total = 0;
    for (final bet in session.bets) {
      if (bet.targetId == targetId) {
        total += bet.amount;
      }
    }
    return total;
  }

  List<Widget> _buildRankingInputs(RoomSession session) {
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
            padding: const EdgeInsets.all(10),
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
                        vertical: 6,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
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
        widgets.add(const SizedBox(height: 6));
      }
    }

    return widgets;
  }
}
