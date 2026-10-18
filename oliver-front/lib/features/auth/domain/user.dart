class User {
  const User({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final DateTime? createdAt;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  String get firstName => fullName.trim().split(' ').length > 1
      ? fullName.trim().split(' ')[1]
      : fullName.trim().split(' ').first;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'].toString(),
        fullName: (j['fullName'] ?? '') as String,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        role: j['role'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString())
            : null,
      );

  User copyWith({String? fullName, String? avatarUrl, String? phone}) => User(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
        createdAt: createdAt,
      );
}
