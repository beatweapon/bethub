import 'dart:math' as math;

import 'package:flutter/material.dart';

class PayoutResultDialog extends StatelessWidget {
  const PayoutResultDialog({
    super.key,
    required this.isWin,
    this.previousCoins,
    this.nextCoins,
    this.gainedCoins,
    this.headline,
    this.message,
    this.amountLabel,
    this.summaryLabel,
    this.detailLabel,
  });

  final bool isWin;
  final int? previousCoins;
  final int? nextCoins;
  final int? gainedCoins;
  final String? headline;
  final String? message;
  final String? amountLabel;
  final String? summaryLabel;
  final String? detailLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedHeadline = headline ?? (isWin ? 'JACKPOT!' : 'ざんねん...');
    final resolvedMessage =
        message ?? (isWin ? '予想的中！コイン獲得！' : '今回は当たりなし。次のレースで巻き返そう。');
    final resolvedAmountLabel =
        amountLabel ?? (isWin ? '+${math.max(0, gainedCoins ?? 0)}枚' : '+0枚');
    final resolvedSummaryLabel =
        summaryLabel ??
        ((previousCoins != null && nextCoins != null)
            ? '所持コイン ${nextCoins!}枚'
            : null);
    final surfaceColor = isWin
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isWin
              ? const LinearGradient(
                  colors: [Color(0xFFFFF59D), Color(0xFFFFCC80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(resolvedHeadline, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(resolvedMessage, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              if (isWin)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: const [
                    Text('🪙'),
                    Text('✨'),
                    Text('🪙'),
                    Text('🎉'),
                  ],
                )
              else
                const Text('💨'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      resolvedAmountLabel,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (resolvedSummaryLabel != null) ...[
                      const SizedBox(height: 8),
                      if (previousCoins != null && nextCoins != null)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: previousCoins!.toDouble(),
                            end: nextCoins!.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 1300),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedValue, _) {
                            return Text(
                              '所持コイン ${animatedValue.round()}枚',
                              style: Theme.of(context).textTheme.titleLarge,
                            );
                          },
                        )
                      else
                        Text(
                          resolvedSummaryLabel,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                    ],
                    if (detailLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        detailLabel!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
