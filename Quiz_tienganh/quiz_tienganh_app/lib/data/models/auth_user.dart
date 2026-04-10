class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.level,
    required this.xp,
  });

  final int id;
  final String username;
  final String role;
  final int level;
  final int xp;

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    return AuthUser(
      id: (j['id'] as num).toInt(),
      username: j['username'] as String,
      role: j['role'] as String? ?? 'learner',
      level: (j['level'] as num?)?.toInt() ?? 1,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
    );
  }
}
