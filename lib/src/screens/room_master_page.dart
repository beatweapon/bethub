import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bet_target.dart';
import '../models/player_bet.dart';
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
    _betTargetRankings.removeWhere(
      (targetId, _) => !nextTargetIds.contains(targetId),
    );
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
    final previousSession = roomState.session;
    try {
      await roomState.submitRaceResults(betTargetIds);
      if (!mounted) {
        return;
      }

      final nextSession = roomState.session;
      if (previousSession != null && nextSession != null) {
        await _playPayoutPresentation(
          previousSession: previousSession,
          nextSession: nextSession,
          rankedTargetIds: betTargetIds,
        );
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!roomState.isAddingBetTarget) {
                              _addBetTarget();
                            }
                          },
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
          totalCoins: _totalBetCoinsForTarget(
            session: session,
            targetId: target.id,
          ),
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

  Future<void> _playPayoutPresentation({
    required RoomSession previousSession,
    required RoomSession nextSession,
    required List<String> rankedTargetIds,
  }) async {
    if (rankedTargetIds.isEmpty) {
      return;
    }

    final winningTargetId = rankedTargetIds.first;
    final winningTarget = _findTargetById(
      session: previousSession,
      targetId: winningTargetId,
    );
    final winnerPayouts = _winnerPayouts(
      previousSession: previousSession,
      nextSession: nextSession,
      winningTargetId: winningTargetId,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'payout_presentation',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) {
        return _RoomMasterPayoutPresentation(
          winningTargetName: winningTarget?.name ?? '不明',
          payouts: winnerPayouts,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  BetTarget? _findTargetById({
    required RoomSession session,
    required String targetId,
  }) {
    for (final target in session.betTargets) {
      if (target.id == targetId) {
        return target;
      }
    }
    return null;
  }

  List<_WinnerPayout> _winnerPayouts({
    required RoomSession previousSession,
    required RoomSession nextSession,
    required String winningTargetId,
  }) {
    final betsByMemberId = <String, PlayerBet>{};
    for (final bet in previousSession.bets) {
      if (bet.targetId == winningTargetId) {
        betsByMemberId[bet.memberId] = bet;
      }
    }

    final nextMemberById = <String, RoomMember>{
      for (final member in nextSession.members) member.id: member,
    };

    final payouts = <_WinnerPayout>[];
    for (final member in previousSession.members) {
      final winningBet = betsByMemberId[member.id];
      final nextMember = nextMemberById[member.id];
      if (winningBet == null || nextMember == null) {
        continue;
      }
      payouts.add(
        _WinnerPayout(
          memberName: member.name,
          previousCoins: member.coins,
          nextCoins: nextMember.coins,
          betAmount: winningBet.amount,
        ),
      );
    }

    payouts.sort((a, b) => b.nextCoins.compareTo(a.nextCoins));
    return payouts;
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

class _WinnerPayout {
  const _WinnerPayout({
    required this.memberName,
    required this.previousCoins,
    required this.nextCoins,
    required this.betAmount,
  });

  final String memberName;
  final int previousCoins;
  final int nextCoins;
  final int betAmount;

  int get gainedCoins => nextCoins - previousCoins;
}

class _RoomMasterPayoutPresentation extends StatefulWidget {
  const _RoomMasterPayoutPresentation({
    required this.winningTargetName,
    required this.payouts,
  });

  final String winningTargetName;
  final List<_WinnerPayout> payouts;

  @override
  State<_RoomMasterPayoutPresentation> createState() =>
      _RoomMasterPayoutPresentationState();
}

class _RoomMasterPayoutPresentationState
    extends State<_RoomMasterPayoutPresentation> {
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) {
      return;
    }
    setState(() {
      _canProceed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasWinners = widget.payouts.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: hasWinners
                      ? const [Color(0xFFFFF3B0), Color(0xFFFFC46B)]
                      : const [Color(0xFFE0E0E0), Color(0xFFB8B8B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 32,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hasWinners ? 'JACKPOT!' : 'NO WINNER',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1着 ${widget.winningTargetName}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (!hasWinners) ...[
                      Text(
                        '今回は的中者はいませんでした',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 20),
                    if (hasWinners)
                      ..._buildWinnerCards()
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '次のレースで巻き返しましょう。',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _canProceed ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: FilledButton(
                        onPressed: _canProceed
                            ? () => Navigator.of(context).pop()
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('次へ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWinnerCards() {
    final cards = <Widget>[];
    for (var i = 0; i < widget.payouts.length; i++) {
      final payout = widget.payouts[i];
      cards.add(_WinnerPayoutCard(payout: payout));
      if (i < widget.payouts.length - 1) {
        cards.add(const SizedBox(height: 10));
      }
    }
    return cards;
  }
}

class _WinnerPayoutCard extends StatelessWidget {
  const _WinnerPayoutCard({required this.payout});

  final _WinnerPayout payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  payout.memberName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: payout.previousCoins.toDouble(),
                  end: payout.nextCoins.toDouble(),
                ),
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, _) {
                  return Text(
                    '${animatedValue.round()}枚',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '的中ベット ${payout.betAmount}枚',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '+${payout.gainedCoins}枚',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
