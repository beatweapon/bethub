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
}
