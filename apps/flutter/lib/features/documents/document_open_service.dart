import 'package:flutter/foundation.dart';

import 'document_local_file.dart';
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
    this.localPath,
    this.extension,
    this.mimeType,
  });

  final int? coreId;
  final String? localPath;
  final DocumentOpenPolicy openPolicy;
  final String? extension;
  final String? mimeType;
}

typedef DocumentDescriptorSource =
    Future<DocumentOpenDescriptor> Function(int coreId);
typedef LocalFileExists = Future<bool> Function(String path);
typedef LocalContentProbe =
    Future<List<int>> Function(String path, int maxBytes);

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
    LocalFileExists? localFileExists,
    LocalContentProbe? localContentProbe,
    DateTime Function()? clock,
  }) : _localFileExists = localFileExists ?? documentLocalFileExists,
       _localContentProbe = localContentProbe ?? readDocumentLocalPrefix,
       _clock = clock ?? DateTime.now;

  final DocumentDescriptorSource descriptorSource;
  final ExternalDocumentLauncher launcher;
  final DocumentOpenEnvironment environment;
  final LocalFileExists _localFileExists;
  final LocalContentProbe _localContentProbe;
  final DateTime Function() _clock;

  Future<DocumentOpenResult> open(DocumentOpenRequest request) async {
    if (request.openPolicy == DocumentOpenPolicy.blocked) {
      return DocumentOpenResult.blocked;
    }

    // On web this opens about:blank during the user gesture. The descriptor is
    // fetched only afterwards, then the reserved tab is navigated to the URL.
    ExternalOpenReservation? reservation;
    try {
      reservation = launcher.reserve();
      final localPath = request.localPath;
      if (environment == DocumentOpenEnvironment.desktop &&
          request.openPolicy.allowsLocalOpen &&
          localPath != null &&
          await _localMatchesRequest(localPath, request)) {
        try {
          if (await reservation.launch(Uri.file(localPath))) {
            return DocumentOpenResult.openedLocal;
          }
        } catch (_) {
          // A stale path or platform launcher failure still gets a fresh URL.
        }
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

  Future<bool> _localMatchesRequest(
    String path,
    DocumentOpenRequest request,
  ) async {
    try {
      if (!await _localFileExists(path)) return false;
      final bytes = await _localContentProbe(path, documentContentProbeLimit);
      return probeDocumentOpenPolicy(
            request.extension,
            request.mimeType ?? 'application/octet-stream',
            bytes,
          ) ==
          request.openPolicy;
    } catch (_) {
      return false;
    }
  }

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
