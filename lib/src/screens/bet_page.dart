import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/bet_target.dart';
import '../models/room_member.dart';
import '../models/room_session.dart';
import '../state/room_scope.dart';
import '../state/room_state.dart';
import '../widgets/bet_target_card.dart';
import '../widgets/payout_result_dialog.dart';
import 'room_page.dart';

class BetPage extends StatefulWidget {
  const BetPage({super.key});

  @override
  State<BetPage> createState() => _BetPageState();
}

class _BetPageState extends State<BetPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Set<String> _committingTargetIds = <String>{};
  RoomSession? _previousSession;
  bool _isShowingPayoutDialog = false;

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

    _handlePayoutTransition(
      nextSession: session,
      currentUserId: currentUser.id,
    );

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

      final controller = _controllers[target.id];
      final focusNode = _focusNodes[target.id];
      if (controller == null || focusNode == null) {
        continue;
      }

      // サーバー状態を入力欄に同期（結果確定後のベットリセットを反映）
      // 編集中のフィールドは上書きしない。
      if (!focusNode.hasFocus) {
        final syncedAmount = roomState.betAmountFor(
          memberId: currentUser.id,
          targetId: target.id,
        );
        final syncedText = _displayText(syncedAmount);
        if (controller.text != syncedText) {
          controller.value = TextEditingValue(
            text: syncedText,
            selection: TextSelection.collapsed(offset: syncedText.length),
          );
        }
      }
    }

    _previousSession = session;
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
    if (_committingTargetIds.contains(targetId)) {
      return;
    }

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

    _committingTargetIds.add(targetId);
    try {
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
    } finally {
      _committingTargetIds.remove(targetId);
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
                  _AnimatedCoinCounter(
                    value: remainingCoins,
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
                '入力値は Enter キーまたはフォーカスが外れたときに確定します。各対象のカード内で、その対象に誰がいくら賭けているかを確認できます。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: session.betTargets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final target = session.betTargets[index];
                    return BetTargetCard(
                      target: target,
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
                      betInput: BetAmountInput(
                        controller: _controllers[target.id]!,
                        focusNode: _focusNodes[target.id]!,
                        enabled:
                            !roomState.isSubmittingBet &&
                            !session.raceStatus.isRacing,
                        onSubmitted: () => _commitBet(target.id),
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

  List<PlayerTargetBetStatus> _playerStatusesForTarget({
    required RoomState roomState,
    required List<RoomMember> members,
    required BetTarget target,
  }) {
    final statuses = <PlayerTargetBetStatus>[];

    for (final member in members) {
      final amount = roomState.betAmountFor(
        memberId: member.id,
        targetId: target.id,
      );
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

  void _handlePayoutTransition({
    required RoomSession nextSession,
    required String currentUserId,
  }) {
    final previousSession = _previousSession;
    if (previousSession == null || _isShowingPayoutDialog) {
      return;
    }

    RoomMember? previousMember;
    for (final member in previousSession.members) {
      if (member.id == currentUserId) {
        previousMember = member;
        break;
      }
    }
    RoomMember? nextMember;
    for (final member in nextSession.members) {
      if (member.id == currentUserId) {
        nextMember = member;
        break;
      }
    }
    if (previousMember == null || nextMember == null) {
      return;
    }
    final previousCoins = previousMember.coins;
    final nextCoins = nextMember.coins;

    final previousBetTotal = _totalBetForMember(previousSession, currentUserId);
    final nextBetTotal = _totalBetForMember(nextSession, currentUserId);
    final isPayoutSettled =
        previousBetTotal > 0 &&
        nextBetTotal == 0 &&
        nextSession.results.isNotEmpty;
    if (!isPayoutSettled) {
      return;
    }

    final coinDelta = nextCoins - previousCoins;
    _isShowingPayoutDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isShowingPayoutDialog = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => PayoutResultDialog(
          isWin: coinDelta > 0,
          previousCoins: previousCoins,
          nextCoins: nextCoins,
          gainedCoins: math.max(0, coinDelta),
        ),
      );
      _isShowingPayoutDialog = false;
    });
  }

  int _totalBetForMember(RoomSession session, String memberId) {
    var total = 0;
    for (final bet in session.bets) {
      if (bet.memberId == memberId) {
        total += bet.amount;
      }
    }
    return total;
  }
}

class _AnimatedCoinCounter extends StatefulWidget {
  const _AnimatedCoinCounter({required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  State<_AnimatedCoinCounter> createState() => _AnimatedCoinCounterState();
}

class _AnimatedCoinCounterState extends State<_AnimatedCoinCounter> {
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(_AnimatedCoinCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text('${animatedValue.round()}枚', style: widget.style);
      },
    );
  }
}
