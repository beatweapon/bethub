import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bet_target.dart';

class PlayerTargetBetStatus {
  const PlayerTargetBetStatus({
    required this.memberName,
    required this.amount,
    required this.isCurrentUser,
  });

  final String memberName;
  final int amount;
  final bool isCurrentUser;
}

class BetTargetCard extends StatelessWidget {
  const BetTargetCard({
    super.key,
    required this.target,
    required this.isHighestWinRate,
    required this.isHighestAverageRank,
    required this.isHighestOdds,
    required this.isLowestOdds,
    required this.playerBetStatuses,
    this.totalCoins,
    this.betInput,
  });

  final BetTarget target;
  final bool isHighestWinRate;
  final bool isHighestAverageRank;
  final bool isHighestOdds;
  final bool isLowestOdds;
  final List<PlayerTargetBetStatus> playerBetStatuses;
  final int? totalCoins;
  final Widget? betInput;

  @override
  Widget build(BuildContext context) {
    final winRatePercent = (target.winRate * 100).toStringAsFixed(0);
    final averageRankText = target.averageRank == null
        ? '-'
        : target.averageRank!.toStringAsFixed(1);
    final oddsValueColor = isHighestOdds && isLowestOdds
        ? null
        : isHighestOdds
        ? Theme.of(context).colorScheme.error
        : isLowestOdds
        ? Theme.of(context).colorScheme.primary
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact) ...[
                  Text(
                    target.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MetricColumn(
                        label: '勝率',
                        value: '$winRatePercent%',
                        showCrown: isHighestWinRate,
                      ),
                      MetricColumn(
                        label: '平均順位',
                        value: averageRankText,
                        showCrown: isHighestAverageRank,
                      ),
                      MetricColumn(
                        label: 'オッズ',
                        value: '${target.odds.toStringAsFixed(1)}倍',
                        valueColor: oddsValueColor,
                      ),
                      if (totalCoins != null)
                        MetricColumn(
                          label: '合計',
                          value: '$totalCoins枚',
                        ),
                      if (betInput != null) SizedBox(width: 160, child: betInput),
                    ],
                  ),
                ] else
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
                        child: MetricColumn(
                          label: '勝率',
                          value: '$winRatePercent%',
                          showCrown: isHighestWinRate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: MetricColumn(
                          label: '平均順位',
                          value: averageRankText,
                          showCrown: isHighestAverageRank,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: MetricColumn(
                          label: 'オッズ',
                          value: '${target.odds.toStringAsFixed(1)}倍',
                          valueColor: oddsValueColor,
                        ),
                      ),
                      if (totalCoins != null) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 88,
                          child: MetricColumn(
                            label: '合計',
                            value: '$totalCoins枚',
                          ),
                        ),
                      ],
                      if (betInput != null) ...[
                        const SizedBox(width: 12),
                        SizedBox(width: 120, child: betInput),
                      ],
                    ],
                  ),
                const SizedBox(height: 12),
                if (playerBetStatuses.isEmpty)
                  Text(
                    'まだ誰もベットしていません',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (playerBetStatuses.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in playerBetStatuses)
                        TargetPlayerBetChip(status: status),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BetAmountInput extends StatelessWidget {
  const BetAmountInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      enabled: enabled,
      onSubmitted: (_) => onSubmitted(),
      decoration: const InputDecoration(
        labelText: '賭けるコイン',
        hintText: '100',
        suffixText: '枚',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class TargetPlayerBetChip extends StatelessWidget {
  const TargetPlayerBetChip({super.key, required this.status});

  final PlayerTargetBetStatus status;

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

class MetricColumn extends StatelessWidget {
  const MetricColumn({
    super.key,
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
