import 'package:flutter/material.dart';

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
      return const Scaffold(
        body: Center(
          child: Text('部屋情報が見つかりませんでした。'),
        ),
      );
    }

    final totalBetCoins = roomState.totalBetCoinsFor(currentUser.id);
    final remainingCoins = currentUser.coins - totalBetCoins;

    return Scaffold(
      appBar: AppBar(title: const Text('ベット画面')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${currentUser.name}の所持コイン',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${currentUser.coins}枚',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '入力済みベット',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$totalBetCoins枚',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '残りベット可能コイン',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '$remainingCoins枚',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '賭け対象一覧',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
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
                      onSubmitted: () => _commitBet(target.id),
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
                  child: const Text('結果画面へ進む'),
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
          coins: member.coins,
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

class _BetTargetCard extends StatelessWidget {
  const _BetTargetCard({
    required this.target,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmitted,
    required this.playerBetStatuses,
  });

  final BetTarget target;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmitted;
  final List<_PlayerTargetBetStatus> playerBetStatuses;

  @override
  Widget build(BuildContext context) {
    final winRatePercent = (target.winRate * 100).toStringAsFixed(0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _MetricColumn(
                    label: 'オッズ',
                    value: '${target.odds.toStringAsFixed(1)}倍',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    enabled: !isSubmitting,
                    onSubmitted: (_) => onSubmitted(),
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
            const SizedBox(height: 20),
            Text(
              'この対象へのベット状況',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (playerBetStatuses.isEmpty)
              Text(
                'まだ誰もベットしていません',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            for (final status in playerBetStatuses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TargetPlayerBetRow(status: status),
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetPlayerBetRow extends StatelessWidget {
  const _TargetPlayerBetRow({required this.status});

  final _PlayerTargetBetStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    status.memberName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status.isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Text(
                    'あなた',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '所持 ${status.coins}枚',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            '${status.amount}枚',
            style: Theme.of(context).textTheme.titleSmall,
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PlayerTargetBetStatus {
  const _PlayerTargetBetStatus({
    required this.memberName,
    required this.coins,
    required this.amount,
    required this.isCurrentUser,
  });

  final String memberName;
  final int coins;
  final int amount;
  final bool isCurrentUser;
}
