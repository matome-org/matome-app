import 'package:flutter/foundation.dart';
import 'package:matome_vault/matome_vault.dart';

import 'document_open_policy.dart';

enum DocumentOpenEnvironment { desktop, mobile, web }

enum DocumentOpenAction { open, openInApp, download }

enum DocumentOpenResult {
  openedLocal,
  openedRemote,
  downloadStarted,
  blocked,
  unavailable,
  failed,
}

/// External-open materializes plaintext; larger documents require explicit
/// export, whose destination is outside Vault lifecycle.
const int kMaxVaultDocumentOpenBytes = 25 * 1024 * 1024;

class DocumentDescriptorUnavailableException implements Exception {
  const DocumentDescriptorUnavailableException();
}

class DocumentOpenDescriptor {
  const DocumentOpenDescriptor({
    required this.method,
    required this.url,
    required this.expiresAt,
    required this.openPolicy,
    required this.action,
  });

  final String method;
  final Uri url;
  final DateTime expiresAt;
  final DocumentOpenPolicy openPolicy;
  final DocumentOpenAction action;

  DocumentOpenDescriptor copyWith({
    String? method,
    Uri? url,
    DateTime? expiresAt,
    DocumentOpenPolicy? openPolicy,
    DocumentOpenAction? action,
  }) => DocumentOpenDescriptor(
    method: method ?? this.method,
    url: url ?? this.url,
    expiresAt: expiresAt ?? this.expiresAt,
    openPolicy: openPolicy ?? this.openPolicy,
    action: action ?? this.action,
  );
}

class DocumentOpenRequest {
  const DocumentOpenRequest({
    required this.coreId,
    required this.openPolicy,
    this.extension,
    this.mimeType,
    this.blobId,
    this.byteSize,
  });

  final int? coreId;
  final DocumentOpenPolicy openPolicy;
  final String? extension;
  final String? mimeType;
  final String? blobId;
  final int? byteSize;
}

typedef DocumentDescriptorSource =
    Future<DocumentOpenDescriptor> Function(int coreId);

abstract interface class ExternalDocumentLauncher {
  ExternalOpenReservation reserve();
}

abstract interface class ExternalOpenReservation {
  Future<bool> launch(Uri uri);
  void close();
}

class DocumentOpenService {
  DocumentOpenService({
    required this.descriptorSource,
    required this.launcher,
    required this.environment,
    this.blobStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DocumentDescriptorSource descriptorSource;
  final ExternalDocumentLauncher launcher;
  final DocumentOpenEnvironment environment;
  final MediaBlobStore Function()? blobStore;
  final DateTime Function() _clock;
  VaultPlaintextLease? _localLease;

  Future<DocumentOpenResult> open(DocumentOpenRequest request) async {
    if (request.openPolicy == DocumentOpenPolicy.blocked) {
      return DocumentOpenResult.blocked;
    }

    // On web this opens about:blank during the user gesture. The descriptor is
    // fetched only afterwards, then the reserved tab is navigated to the URL.
    ExternalOpenReservation? reservation;
    try {
      reservation = launcher.reserve();
      if (request.openPolicy == DocumentOpenPolicy.external ||
          request.openPolicy == DocumentOpenPolicy.systemApp) {
        final localResult = await _openLocal(request, reservation);
        if (localResult != null) return localResult;
      }
      final coreId = request.coreId;
      if (coreId == null) {
        return _close(reservation, DocumentOpenResult.unavailable);
      }

      final descriptor = await descriptorSource(coreId);
      if (descriptor.openPolicy == DocumentOpenPolicy.blocked) {
        return _close(reservation, DocumentOpenResult.blocked);
      }
      final now = _clock().toUtc();
      final expiresAt = descriptor.expiresAt.toUtc();
      if (descriptor.method != 'GET' ||
          !_validRemoteUri(descriptor.url) ||
          !_consistentDescriptor(descriptor) ||
          !_descriptorWithinRequestPolicy(
            request.openPolicy,
            descriptor.openPolicy,
          ) ||
          !expiresAt.isAfter(now) ||
          expiresAt.difference(now) > const Duration(minutes: 10)) {
        return _close(reservation, DocumentOpenResult.unavailable);
      }
      if (!await reservation.launch(descriptor.url)) {
        return _close(reservation, DocumentOpenResult.failed);
      }
      return descriptor.action == DocumentOpenAction.download
          ? DocumentOpenResult.downloadStarted
          : DocumentOpenResult.openedRemote;
    } on DocumentDescriptorUnavailableException {
      if (reservation != null) _safeClose(reservation);
      return DocumentOpenResult.unavailable;
    } catch (_) {
      if (reservation != null) _safeClose(reservation);
      return DocumentOpenResult.failed;
    }
  }

  Future<DocumentOpenResult?> _openLocal(
    DocumentOpenRequest request,
    ExternalOpenReservation reservation,
  ) async {
    final raw = request.blobId;
    final store = blobStore?.call();
    if (raw == null || raw.isEmpty || store == null) return null;
    if (request.byteSize != null &&
        request.byteSize! > kMaxVaultDocumentOpenBytes) {
      return null;
    }
    final previous = _localLease;
    _localLease = null;
    await previous?.dispose();
    VaultPlaintextLease lease;
    try {
      final id = VaultBlobId(raw);
      final stat = await store.stat(id);
      if (stat.state != VaultBlobState.ready ||
          stat.plaintextLength == null ||
          stat.plaintextLength! > kMaxVaultDocumentOpenBytes) {
        return null;
      }
      lease = await store.createLease(
        id,
        purpose: VaultLeasePurpose.externalOpen,
        ttl: const Duration(minutes: 15),
      );
    } on VaultFailure catch (error) {
      if (error.code == VaultFailureCode.blobMissing ||
          error.code == VaultFailureCode.blobNotReady) {
        return null;
      }
      rethrow;
    }
    if (!await reservation.launch(lease.location)) {
      await lease.dispose();
      return _close(reservation, DocumentOpenResult.failed);
    }
    _localLease = lease;
    return DocumentOpenResult.openedLocal;
  }

  Future<void> releaseLocalLease() async {
    final lease = _localLease;
    _localLease = null;
    await lease?.dispose();
  }

  DocumentOpenResult _close(
    ExternalOpenReservation reservation,
    DocumentOpenResult result,
  ) {
    _safeClose(reservation);
    return result;
  }

  void _safeClose(ExternalOpenReservation reservation) {
    try {
      reservation.close();
    } catch (_) {
      // Cleanup failures cannot strand the UI in its loading state.
    }
  }

  bool _validRemoteUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      uri.fragment.isEmpty;

  bool _consistentDescriptor(DocumentOpenDescriptor descriptor) =>
      switch (descriptor.openPolicy) {
        DocumentOpenPolicy.external =>
          descriptor.action == DocumentOpenAction.open,
        DocumentOpenPolicy.systemApp =>
          descriptor.action == DocumentOpenAction.openInApp,
        DocumentOpenPolicy.attachmentOnly || DocumentOpenPolicy.downloadOnly =>
          descriptor.action == DocumentOpenAction.download,
        DocumentOpenPolicy.blocked => false,
      };

  bool _descriptorWithinRequestPolicy(
    DocumentOpenPolicy request,
    DocumentOpenPolicy descriptor,
  ) => request == descriptor;
}

DocumentOpenEnvironment currentDocumentOpenEnvironment() {
  if (kIsWeb) return DocumentOpenEnvironment.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => DocumentOpenEnvironment.desktop,
    _ => DocumentOpenEnvironment.mobile,
  };
}
