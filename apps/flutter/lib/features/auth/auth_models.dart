import '../../core/http/json_utils.dart';

/// Authenticated user, as returned by `/api/auth/login` and `/api/auth/me`.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final int id;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(id: asInt(json['id']), email: asString(json['email']));
  }
}

/// Result of a successful login/refresh: the user plus Guardian JWTs.
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
  });

  final AuthUser user;
  final String accessToken;
  final String? refreshToken;
  final String tokenType;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthSession(
      user: AuthUser.fromJson(
        userJson is Map<String, dynamic> ? userJson : const {},
      ),
      accessToken: asString(json['access_token']),
      refreshToken: asStringOrNull(json['refresh_token']),
      tokenType: asString(json['token_type'], fallback: 'Bearer'),
    );
  }
}
