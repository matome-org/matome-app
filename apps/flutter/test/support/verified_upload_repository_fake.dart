import 'dart:io';

import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';

/// Adapts legacy single-PUT repository fakes to Core's verified lifecycle.
/// Queue-specific multipart behavior is tested with a stateful fake instead.
mixin VerifiedSingleUploadRepositoryFake on RecordingsRepository {
  int verifiedUploadRequestCalls = 0;
  int? _verifiedItemId;
  int? _verifiedByteSize;
  String? _verifiedChecksum;

  UploadDescriptor descriptorForVerifiedUpload(int itemId) => UploadDescriptor(
    method: 'PUT',
    url: 'memory://upload/$itemId',
    storageKey: 'k$itemId',
    uploadId: 'item-$itemId-upload-1',
    uploadGeneration: 1,
    mode: UploadMode.single,
    state: UploadState.uploading,
  );

  @override
  Future<UploadDescriptor> requestUpload(
    int itemId, {
    required int inputRevision,
    required int byteSize,
    required String checksumSha256,
    String? contentType,
  }) async {
    verifiedUploadRequestCalls++;
    _verifiedItemId = itemId;
    _verifiedByteSize = byteSize;
    _verifiedChecksum = checksumSha256;
    return descriptorForVerifiedUpload(itemId);
  }

  @override
  Future<String> uploadFileRange(
    UploadRequest request,
    File file, {
    required int start,
    required int endExclusive,
  }) async {
    final itemId = _verifiedItemId!;
    if (start != 0 || endExclusive != _verifiedByteSize) {
      throw StateError('Single-upload fake received a partial file range');
    }
    final descriptor = descriptorForVerifiedUpload(itemId);
    await uploadFile(descriptor, file);
    return 'etag-$itemId';
  }

  @override
  Future<UploadDescriptor> completeUpload(
    String uploadId, {
    required int uploadGeneration,
    required String checksumSha256,
    String? etag,
    List<UploadPart> parts = const [],
  }) async {
    if (checksumSha256 != _verifiedChecksum ||
        etag == null ||
        parts.isNotEmpty) {
      throw StateError('Single-upload completion evidence did not match');
    }
    return UploadDescriptor(
      method: 'PUT',
      url: '',
      storageKey: 'k$_verifiedItemId',
      uploadId: uploadId,
      uploadGeneration: uploadGeneration,
      mode: UploadMode.single,
      state: UploadState.uploaded,
      verifiedByteSize: _verifiedByteSize,
      verifiedChecksumSha256: checksumSha256,
    );
  }
}
