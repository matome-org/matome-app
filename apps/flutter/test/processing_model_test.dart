import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

Map<String, dynamic> _item({
  required String state,
  String? runId = 'run-current',
  int attempt = 2,
  String itemType = 'file',
  String mediaType = 'audio',
  Map<String, dynamic> outputs = const {},
  Map<String, dynamic>? error,
}) {
  return <String, dynamic>{
    'id': 7,
    'owner_id': 1,
    'client_id': 'item-7',
    'item_type': itemType,
    'title': 'Explicit item',
    'notes': 'User note',
    'processing_state': state,
    'processing_run_id': runId,
    'processing_attempt': attempt,
    'processing_requested_outputs': outputs.keys.toList(),
    'processing_outputs': outputs,
    'processing_error': error,
    'file': itemType == 'file'
        ? <String, dynamic>{'media_type': mediaType, 'upload_state': 'uploaded'}
        : null,
    'text': itemType == 'text'
        ? <String, dynamic>{'body': 'User-authored body'}
        : null,
  };
}

void main() {
  test('parses the explicit processing run without metadata inference', () {
    final item = _item(state: 'queued')
      ..['metadata'] = <String, dynamic>{'status': 'done'};

    final recording = Recording.fromItemJson(item);

    expect(recording.processing.state, ProcessingState.queued);
    expect(recording.processing.runId, 'run-current');
    expect(recording.processing.attempt, 2);
    expect(recording.transcript, isNull);
  });

  test('does not infer success from output presence', () {
    final recording = Recording.fromItemJson(
      _item(
        state: 'processing',
        outputs: const {
          'transcript': {
            'type': 'transcript',
            'text': 'Prior successful transcript',
          },
        },
      ),
    );

    expect(recording.processing.state, ProcessingState.processing);
    expect(recording.transcript, 'Prior successful transcript');
  });

  test('projects every typed modality output without touching notes', () {
    final audio = Recording.fromItemJson(
      _item(
        state: 'succeeded',
        outputs: const {
          'transcript': {
            'type': 'transcript',
            'text': 'Spoken words',
            'language': 'en',
            'duration_ms': 42000,
          },
          'summary': {'type': 'summary', 'markdown': 'Audio summary'},
        },
      ),
    );
    final image = Recording.fromItemJson(
      _item(
        state: 'partial',
        mediaType: 'image',
        outputs: const {
          'description': {
            'type': 'description',
            'text': 'A whiteboard',
          },
          'ocr_text': {'type': 'ocr_text', 'text': 'Launch Friday'},
        },
      ),
    );
    final document = Recording.fromItemJson(
      _item(
        state: 'succeeded',
        mediaType: 'document',
        outputs: const {
          'extracted_text': {
            'type': 'extracted_text',
            'text': 'Document body',
          },
          'summary': {'type': 'summary', 'markdown': 'Document summary'},
        },
      ),
    );
    final text = Recording.fromItemJson(
      _item(
        state: 'succeeded',
        itemType: 'text',
        runId: 'run-text',
        outputs: const {
          'summary': {'type': 'summary', 'markdown': 'Text summary'},
        },
      ),
    );

    expect(audio.processing.outputs.transcript?.text, 'Spoken words');
    expect(audio.processing.outputs.summary?.markdown, 'Audio summary');
    expect(image.processing.outputs.description?.text, 'A whiteboard');
    expect(image.processing.outputs.ocrText?.text, 'Launch Friday');
    expect(document.processing.outputs.extractedText?.text, 'Document body');
    expect(document.processing.outputs.summary?.markdown, 'Document summary');
    expect(text.processing.outputs.summary?.markdown, 'Text summary');
    expect(text.notes, 'User note');
  });

  test('parses failed and not_available as terminal Core states', () {
    final failed = Recording.fromItemJson(
      _item(
        state: 'failed',
        error: const {
          'code': 'processor_unavailable',
          'message': 'Safe message',
          'retryable': true,
        },
      ),
    );
    final unavailable = Recording.fromItemJson(
      _item(state: 'not_available', outputs: const {}),
    );

    expect(failed.processing.state, ProcessingState.failed);
    expect(failed.processing.error?.code, 'processor_unavailable');
    expect(failed.processing.error?.retryable, isTrue);
    expect(unavailable.processing.state, ProcessingState.notAvailable);
    expect(unavailable.processing.isTerminal, isTrue);
  });
}
