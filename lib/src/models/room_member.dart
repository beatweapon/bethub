enum MemberRole {
  player, // 参加者
  roomMaster, // ルームマスター（胴元）
}

class RoomMember {
  const RoomMember({
    required this.id,
    required this.name,
    required this.coins,
    this.isCurrentUser = false,
    this.role = MemberRole.player,
  });

  final String id;
  final String name;
  final int coins;
  final bool isCurrentUser;
  final MemberRole role;

  RoomMember copyWith({
    String? id,
    String? name,
    int? coins,
    bool? isCurrentUser,
    MemberRole? role,
  }) {
    return RoomMember(
      id: id ?? this.id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      role: role ?? this.role,
    );
  }

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] as String,
      name: json['name'] as String,
      coins: json['coins'] as int,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      role: _roleFromString(json['role'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coins': coins,
      'isCurrentUser': isCurrentUser,
      'role': role.toString(),
    };
  }

  static MemberRole _roleFromString(String? value) {
    if (value == null) return MemberRole.player;
    return MemberRole.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => MemberRole.player,
    );
  }
}
