class AppChat {
  const AppChat({
    required this.id,
    required this.counterpartName,
    required this.counterpartAvatarUrl,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.unreadCount,
    required this.canWrite,
    this.lastMessage,
  });

  final String id;
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final String origin;
  final String destination;
  final DateTime? departureAt;
  final int unreadCount;
  final bool canWrite;
  final AppChatMessage? lastMessage;

  factory AppChat.fromJson(
    Map<String, dynamic> json, {
    required String mediaBaseUrl,
  }) {
    final counterpart = _map(json['counterpart']);
    final trip = _map(json['trip']);
    final avatar = counterpart['avatar_url'] as String?;
    final first = counterpart['first_name'] as String? ?? 'Пользователь';
    final last = counterpart['last_name'] as String?;
    return AppChat(
      id: json['id']?.toString() ?? '',
      counterpartName: [
        first,
        if (last != null && last.trim().isNotEmpty) last.trim(),
      ].join(' '),
      counterpartAvatarUrl: avatar == null || avatar.isEmpty
          ? null
          : avatar.startsWith('http')
          ? avatar
          : '$mediaBaseUrl$avatar',
      origin: trip['origin'] as String? ?? '',
      destination: trip['destination'] as String? ?? '',
      departureAt: DateTime.tryParse(trip['departure_at']?.toString() ?? ''),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      canWrite: json['can_write'] == true,
      lastMessage: json['last_message'] is Map
          ? AppChatMessage.fromJson(_map(json['last_message']))
          : null,
    );
  }
}

class AppChatMessage {
  const AppChatMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  final int id;
  final String text;
  final DateTime? createdAt;
  final bool isMine;

  factory AppChatMessage.fromJson(Map<String, dynamic> json) => AppChatMessage(
    id: (json['id'] as num?)?.toInt() ?? 0,
    text: json['text'] as String? ?? '',
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    isMine: json['is_mine'] == true,
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
