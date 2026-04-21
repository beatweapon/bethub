class BetTarget {
  const BetTarget({
    required this.id,
    required this.name,
    required this.winRate,
    required this.odds,
  });

  final String id;
  final String name;
  final double winRate;
  final double odds;

  factory BetTarget.fromJson(Map<String, dynamic> json) {
    return BetTarget(
      id: json['id'] as String,
      name: json['name'] as String,
      winRate: (json['winRate'] as num).toDouble(),
      odds: (json['odds'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'winRate': winRate, 'odds': odds};
  }
}
