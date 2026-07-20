import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_state.dart';

/// Authenticated Core owner id used for every local Item read and mutation.
/// Signed-out callers receive null and must fail closed.
final currentOwnerIdProvider = Provider<String?>((ref) {
  final id = ref.watch(authStateProvider).user?.id;
  return id?.toString();
});
