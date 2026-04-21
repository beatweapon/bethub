class RoomMember {
  const RoomMember({
    required this.id,
    required this.name,
    required this.coins,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final int coins;
  final bool isCurrentUser;

  RoomMember copyWith({
    String? id,
    String? name,
    int? coins,
    bool? isCurrentUser,
  }) {
    return RoomMember(
      id: id ?? this.id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] as String,
      name: json['name'] as String,
      coins: json['coins'] as int,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coins': coins,
      'isCurrentUser': isCurrentUser,
    };
  }
}
