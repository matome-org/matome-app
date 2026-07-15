import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final contract = _readJson('../../contracts/v1/platform.json');
  final fixtures = _readJson('../../contracts/v1/fixtures/canonical.json');
  final known = _readJson('../../contracts/v1/fixtures/known-mismatches.json');

  test('loads the frozen work and upload v1 contract', () {
    expect(contract['version'], '1.0.0');
    expect(contract['wire_version'], '1');

    final work = contract['work'] as Map<String, dynamic>;
    expect(work['states'], <String>[
      'local_saved',
      'work_queued',
      'parent_item_reconciled',
      'uploading',
      'uploaded',
      'processing_queued',
      'processing',
      'succeeded',
      'failed',
    ]);
    expect(work['upload_states'], contains('uploaded'));
    expect(work['processing_states'], contains('not_requested'));
    expect(work['upload_only_completion'], <String, dynamic>{
      'upload_state': 'uploaded',
      'processing_state': 'not_requested',
      'work_state': 'succeeded',
    });
    expect(work['device_upload_stages'], <String>[
      'reconcile_parent',
      'hash_file',
      'create_remote',
      'request_upload',
      'upload_single_or_missing_parts',
      'complete_upload',
      'enqueue_processing_or_upload_only_complete',
    ]);
    expect(work['capture_rule'], contains('no upload or Core request'));
    expect(work['upload_progress_rule'], contains('provider-accepted'));

    final states = (work['states'] as List<dynamic>).cast<String>().toSet();
    final transitions = (work['legal_transitions'] as Map<String, dynamic>);
    expect(transitions.keys.toSet(), states);
    for (final targets in transitions.values) {
      expect(
        (targets as List<dynamic>).cast<String>().toSet().difference(states),
        isEmpty,
      );
    }

    final create = fixtures['item_create_response'] as Map<String, dynamic>;
    expect(create['upload'], isA<Map<String, dynamic>>());
    final item = create['item'] as Map<String, dynamic>;
    expect(item['client_id'], startsWith('rec_local_'));
    expect(item['presign'], isNull);
    expect(contract['upload']['operations'], <String>[
      'request',
      'inspect',
      'presign_part',
      'complete',
      'abort',
    ]);
    expect(
      contract['upload']['multipart']['device_persistence'],
      contains('signed URLs and headers are memory-only'),
    );
  });

  test('loads bounded event and desired/applied config contracts', () {
    final events = contract['events'] as Map<String, dynamic>;
    expect(events['classes'], <String>['security', 'operational', 'product']);
    expect(events['reject_unknown_payload_keys'], isTrue);
    expect(events['max_payload_bytes'], 4096);

    final catalog = (events['catalog'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      catalog.where((entry) => entry['required'] == true),
      everyElement(containsPair('enabled', true)),
    );
    expect(catalog, everyElement(contains('payload_allowlist')));
    final prohibited = (events['prohibited_payload_keys'] as List<dynamic>)
        .cast<String>()
        .toSet();
    for (final entry in catalog) {
      final allowlist = (entry['payload_allowlist'] as List<dynamic>)
          .cast<String>()
          .toSet();
      expect(allowlist.intersection(prohibited), isEmpty);
    }

    final config = fixtures['system_config'] as Map<String, dynamic>;
    final document = config['document'] as Map<String, dynamic>;
    final device = config['device_application'] as Map<String, dynamic>;
    expect(document['revision'], 7);
    expect((document['applied'] as Map<String, dynamic>)['core_revision'], 7);
    expect(device['desired_revision'], 7);
    expect(device['applied_revision'], 6);
    expect(device['status'], 'stale');

    final schema = _readJson('../../contracts/v1/system-config.schema.json');
    expect(schema['required'], <String>[
      'schema_version',
      'revision',
      'desired',
      'applied',
    ]);
  });

  test('executes all known current mismatch proofs', () {
    final mismatches = (known['mismatches'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final detected = <String, String?>{
      for (final mismatch in mismatches)
        mismatch['id'] as String: _detectViolation(mismatch),
    };
    final expected = <String, String>{
      for (final mismatch in mismatches)
        mismatch['id'] as String: mismatch['expected_violation'] as String,
    };

    expect(detected, expected);
    expect(detected.keys.toSet(), <String>{'retry'});
  });

  test('pins the reset-safe 1:1 payload model decision', () {
    final decisions = contract['data_model_decisions'] as Map<String, dynamic>;
    expect(decisions['retain'], <String>[
      'items',
      'file_blobs',
      'text_contents',
    ]);
    expect(decisions['avoid_domain_tables'], <String>[
      'processing_attempts',
      'derivations',
      'upload_sessions',
    ]);
    expect(decisions['migration_policy'], 'clean_schema_reset');
    expect(decisions['reason'], 'no_users_and_no_deployment');
  });
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

String? _detectViolation(Map<String, dynamic> mismatch) {
  final current = mismatch['current'] as Map<String, dynamic>;

  switch (mismatch['id']) {
    case 'retry':
      if (current['jobs_after_second_process'] == 1 &&
          current['first_job_identity'] == current['second_job_identity'] &&
          (current['dedupe_states'] as List<dynamic>).contains('completed')) {
        return 'processing.retry_reuses_completed_run';
      }
  }
  return null;
}
