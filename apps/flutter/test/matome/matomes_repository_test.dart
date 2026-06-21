import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/features/contacts/contacts_repository.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';

/// HTTP-contract tests for the space-scoped sync repos (task #1377), mirroring
/// `recordings_repository_test.dart`: a mock-adapter dio, Bearer injection, and
/// the create/attach/detach status handling against the backend contract.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore tokenStore;
  late MatomesRepository matomesRepo;
  late ContactsRepository contactsRepo;

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    matomesRepo = MatomesRepository(apiClient: client);
    contactsRepo = ContactsRepository(apiClient: client);
  });

  test('fetchMatomes parses list + contact edges and injects Bearer', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onGet(
      '/api/matomes',
      (server) => server.reply(200, {
        'matomes': [
          {
            'id': 7,
            'owner_id': 1,
            'title': 'Standup',
            'workspace_id': 42,
            'aggregated_summary': 'rolled up',
            'contacts': [
              {'contact_id': 5, 'role': 'organizer'},
            ],
          },
        ],
      }),
      headers: {'Authorization': 'Bearer access-123'},
    );

    final matomes = await matomesRepo.fetchMatomes();
    expect(matomes, hasLength(1));
    expect(matomes.single.id, 7);
    expect(matomes.single.workspaceId, 42);
    expect(matomes.single.aggregatedSummary, 'rolled up');
    expect(matomes.single.contacts.single.contactId, 5);
    expect(matomes.single.contacts.single.role, 'organizer');
  });

  test('createMatome returns the created remote (carrying its Core id)',
      () async {
    adapter.onPost(
      '/api/matomes',
      (server) => server.reply(201, {
        'matome': {'id': 99, 'owner_id': 1, 'title': 'New', 'workspace_id': 42},
      }),
      data: Matchers.any,
    );

    final created =
        await matomesRepo.createMatome(title: 'New', workspaceId: 42);
    expect(created.id, 99);
    expect(created.workspaceId, 42);
  });

  test('updateMatome PATCHes title + happenedAt and parses the result',
      () async {
    final happenedAt = DateTime.utc(2026, 1, 15, 10, 30);
    adapter.onPatch(
      '/api/matomes/7',
      (server) => server.reply(200, {
        'matome': {
          'id': 7,
          'owner_id': 1,
          'title': 'Renamed',
          'workspace_id': 42,
          'happened_at': '2026-01-15T10:30:00Z',
        },
      }),
      data: Matchers.any,
    );

    final updated = await matomesRepo.updateMatome(
      7,
      title: 'Renamed',
      happenedAt: happenedAt,
    );
    expect(updated.id, 7);
    expect(updated.title, 'Renamed');
    expect(updated.happenedAt, happenedAt);
  });

  test('updateMatome surfaces a 422 validation error as an ApiException',
      () async {
    adapter.onPatch(
      '/api/matomes/7',
      (server) => server.reply(422, {
        'errors': {
          'happened_at': ['is too far in the future'],
        },
      }),
      data: Matchers.any,
    );
    expect(
      matomesRepo.updateMatome(7, title: ''),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 422)),
    );
  });

  test('attachContact accepts 201; detachContact accepts 204', () async {
    adapter
      ..onPost(
        '/api/matomes/7/contacts',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      )
      ..onDelete(
        '/api/matomes/7/contacts/5',
        (server) => server.reply(204, null),
      );

    await matomesRepo.attachContact(matomeId: 7, contactId: 5, role: 'speaker');
    await matomesRepo.detachContact(matomeId: 7, contactId: 5);
    // No throw == success.
  });

  test('matomes 401 maps to unauthorized ApiException', () async {
    adapter.onGet(
      '/api/matomes',
      (server) => server.reply(401, {'error': 'unauthenticated'}),
    );
    expect(
      matomesRepo.fetchMatomes(),
      throwsA(isA<ApiException>()
          .having((e) => e.isUnauthorized, 'isUnauthorized', true)),
    );
  });

  test('fetchContacts parses the list', () async {
    adapter.onGet(
      '/api/contacts',
      (server) => server.reply(200, {
        'contacts': [
          {
            'id': 5,
            'owner_id': 1,
            'display_name': 'Ada',
            'metadata': {'email': 'ada@x.io'},
          },
        ],
      }),
    );
    final contacts = await contactsRepo.fetchContacts();
    expect(contacts.single.id, 5);
    expect(contacts.single.displayName, 'Ada');
    // Decoded JSON object metadata is re-encoded to a TEXT blob.
    expect(contacts.single.metadata, contains('ada@x.io'));
  });

  test('createContact returns the created remote (with its Core id)', () async {
    adapter.onPost(
      '/api/contacts',
      (server) => server.reply(201, {
        'contact': {'id': 21, 'owner_id': 1, 'display_name': 'Grace'},
      }),
      data: Matchers.any,
    );
    final created = await contactsRepo.createContact(displayName: 'Grace');
    expect(created.id, 21);
    expect(created.displayName, 'Grace');
  });
}
