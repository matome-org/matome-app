import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/matome/matome.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';

/// Contract-faithful parent Core leg for tests that already fake item creation.
Override testParentSyncOverride({int coreId = 42}) => matomesRepositoryProvider
    .overrideWithValue(_TestParentRepository(coreId: coreId));

class _TestParentRepository extends MatomesRepository {
  _TestParentRepository({required this.coreId})
    : super(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio()..close(),
        ),
      );

  final int coreId;

  @override
  Future<Matome> createMatome({
    required String clientId,
    required String title,
    int? workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async => Matome(
    id: coreId,
    ownerId: '1',
    title: title,
    workspaceId: workspaceId,
    happenedAt: happenedAt,
    description: description,
    aggregatedSummary: aggregatedSummary,
  );
}
