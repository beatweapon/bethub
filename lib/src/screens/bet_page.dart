import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bet_target.dart';
import '../models/room_member.dart';
import '../state/room_scope.dart';
import '../state/room_state.dart';
import 'room_page.dart';

class BetPage extends StatefulWidget {
  const BetPage({super.key});

  @override
  State<BetPage> createState() => _BetPageState();
}

class _BetPageState extends State<BetPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roomState = RoomScope.of(context);

    // ルームの更新を監視（RoomScopeのInheritedNotifierとしての依存性を確保）
    // これにより、roomStateが更新されるたびにこのウィジェットが再構築される

    final session = roomState.session;
    final currentUser = roomState.currentUser;
    if (session == null || currentUser == null) {
      return;
    }

    for (final target in session.betTargets) {
      _controllers.putIfAbsent(
        target.id,
        () => TextEditingController(
          text: _displayText(
            roomState.betAmountFor(
              memberId: currentUser.id,
              targetId: target.id,
            ),
          ),
        ),
      );
      _focusNodes.putIfAbsent(target.id, () {
        final node = FocusNode();
        node.addListener(() {
          if (!node.hasFocus) {
            _commitBet(target.id);
          }
        });
        return node;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _displayText(int value) {
    return value == 0 ? '' : value.toString();
  }

  Future<void> _commitBet(String targetId) async {
    final roomState = RoomScope.of(context);
    final session = roomState.session;
    if (session == null) {
      return;
    }

    final controller = _controllers[targetId];
    if (controller == null) {
      return;
    }

    BetTarget? target;
    for (final item in session.betTargets) {
      if (item.id == targetId) {
        target = item;
        break;
      }
    }

    if (target == null) {
      return;
    }

    final requestedAmount = int.tryParse(controller.text) ?? 0;
    final acceptedAmount = await roomState.submitBet(
      targetId: target.id,
      requestedAmount: requestedAmount,
    );

    final nextText = _displayText(acceptedAmount);
    if (controller.text != nextText) {
      controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  Future<void> _openResults() async {
    FocusScope.of(context).unfocus();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RoomPage()));
  }

  @override
  Widget build(BuildContext context) {
    final roomState = RoomScope.of(context);
    final session = roomState.session;
    final currentUser = roomState.currentUser;

    if (session == null || currentUser == null) {
      return const Scaffold(body: Center(child: Text('部屋情報が見つかりませんでした。')));
    }

    final totalBetCoins = roomState.totalBetCoinsFor(currentUser.id);
    final remainingCoins = currentUser.coins - totalBetCoins;
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
      appBar: AppBar(
        title: const Text('ベット画面'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('所持コイン', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(width: 8),
                  Text(
                    '$remainingCoins枚',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('賭け対象一覧', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '入力値はフォーカスが外れたときに確定します。各対象のカード内で、その対象に誰がいくら賭けているかを確認できます。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: session.betTargets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final target = session.betTargets[index];
                    return _BetTargetCard(
                      target: target,
                      controller: _controllers[target.id]!,
                      focusNode: _focusNodes[target.id]!,
                      isSubmitting: roomState.isSubmittingBet,
                      isRacing: session.raceStatus.isRacing,
                      onSubmitted: () => _commitBet(target.id),
                      isHighestWinRate:
                          (target.winRate - maxWinRate).abs() < 0.0001,
                      isHighestAverageRank:
                          minAverageRank != null &&
                          target.averageRank != null &&
                          (target.averageRank! - minAverageRank).abs() < 0.0001,
                      isHighestOdds: (target.odds - maxOdds).abs() < 0.0001,
                      isLowestOdds: (target.odds - minOdds).abs() < 0.0001,
                      playerBetStatuses: _playerStatusesForTarget(
                        roomState: roomState,
                        members: session.members,
                        target: target,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openResults,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('所持コインランキング'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_PlayerTargetBetStatus> _playerStatusesForTarget({
    required RoomState roomState,
    required List<RoomMember> members,
    required BetTarget target,
  }) {
    final statuses = <_PlayerTargetBetStatus>[];

    for (final member in members) {
      final amount = roomState.betAmountFor(
        memberId: member.id,
        targetId: target.id,
      );
      if (amount <= 0) {
        continue;
      }
      statuses.add(
        _PlayerTargetBetStatus(
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
}

class _BetTargetCard extends StatefulWidget {
  const _BetTargetCard({
    required this.target,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.isRacing,
    required this.onSubmitted,
    required this.isHighestWinRate,
    required this.isHighestAverageRank,
    required this.isHighestOdds,
    required this.isLowestOdds,
    required this.playerBetStatuses,
  });

  final BetTarget target;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final bool isRacing;
  final VoidCallback onSubmitted;
  final bool isHighestWinRate;
  final bool isHighestAverageRank;
  final bool isHighestOdds;
  final bool isLowestOdds;
  final List<_PlayerTargetBetStatus> playerBetStatuses;

  @override
  State<_BetTargetCard> createState() => _BetTargetCardState();
}

class _BetTargetCardState extends State<_BetTargetCard> {
  late double _previousOdds;

  @override
  void initState() {
    super.initState();
    _previousOdds = widget.target.odds;
  }

  @override
  void didUpdateWidget(_BetTargetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // オッズが更新されたかチェック（UI更新をトリガーするため）
    if (oldWidget.target.odds != widget.target.odds) {
      _previousOdds = widget.target.odds;
      // 状態を更新してアニメーションを実行できます
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final winRatePercent = (target.winRate * 100).toStringAsFixed(0);
    final averageRankText = target.averageRank == null
        ? '-'
        : target.averageRank!.toStringAsFixed(1);
    final oddsValueColor = widget.isHighestOdds && widget.isLowestOdds
        ? null
        : widget.isHighestOdds
        ? Theme.of(context).colorScheme.error
        : widget.isLowestOdds
        ? Theme.of(context).colorScheme.primary
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    target.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _MetricColumn(
                    label: '勝率',
                    value: '$winRatePercent%',
                    showCrown: widget.isHighestWinRate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _MetricColumn(
                    label: '平均順位',
                    value: averageRankText,
                    showCrown: widget.isHighestAverageRank,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _MetricColumn(
                    label: 'オッズ',
                    value: '${target.odds.toStringAsFixed(1)}倍',
                    valueColor: oddsValueColor,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !widget.isSubmitting && !widget.isRacing,
                    onSubmitted: (_) => widget.onSubmitted(),
                    decoration: const InputDecoration(
                      labelText: '賭けるコイン',
                      hintText: '100',
                      suffixText: '枚',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.playerBetStatuses.isEmpty)
              Text(
                'まだ誰もベットしていません',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (widget.playerBetStatuses.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in widget.playerBetStatuses)
                    _TargetPlayerBetChip(status: status),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetPlayerBetChip extends StatelessWidget {
  const _TargetPlayerBetChip({required this.status});

  final _PlayerTargetBetStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.memberName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (status.isCurrentUser) ...[
            const SizedBox(width: 6),
            Text('あなた', style: Theme.of(context).textTheme.labelSmall),
          ],
          const SizedBox(width: 8),
          Text(
            '${status.amount}枚',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    this.showCrown = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool showCrown;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            if (showCrown) ...[const SizedBox(width: 2), const Text('👑')],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class _PlayerTargetBetStatus {
  const _PlayerTargetBetStatus({
    required this.memberName,
    required this.amount,
    required this.isCurrentUser,
  });

  final String memberName;
  final int amount;
  final bool isCurrentUser;
}
