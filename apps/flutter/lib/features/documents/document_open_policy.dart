import 'dart:convert';

enum DocumentOpenPolicy {
  external('external'),
  systemApp('system_app'),
  attachmentOnly('attachment_only'),
  downloadOnly('download_only'),
  blocked('blocked');

  const DocumentOpenPolicy(this.wireName);

  final String wireName;

  static DocumentOpenPolicy fromWire(String? value) => switch (value) {
    'external' => external,
    'system_app' => systemApp,
    'attachment_only' => attachmentOnly,
    'blocked' => blocked,
    _ => downloadOnly,
  };

  bool get allowsLocalOpen =>
      this == DocumentOpenPolicy.external ||
      this == DocumentOpenPolicy.systemApp;
}

class DocumentMetadata {
  const DocumentMetadata({
    required this.filename,
    required this.extension,
    required this.mimeType,
    required this.openPolicy,
  });

  factory DocumentMetadata.fromImport({
    required String filename,
    required String mimeType,
    List<int>? probeBytes,
  }) {
    final safeName = sanitizeDocumentFilename(filename);
    final extension = documentExtension(safeName);
    final normalizedMime = normalizeDocumentMime(mimeType);
    final declaredPolicy = classifyDocumentOpenPolicy(
      extension,
      normalizedMime,
    );
    final policy = declaredPolicy == DocumentOpenPolicy.blocked
        ? declaredPolicy
        : probeDocumentOpenPolicy(
            extension,
            normalizedMime,
            probeBytes ?? const <int>[],
          );
    if (policy == DocumentOpenPolicy.blocked) {
      throw UnsafeDocumentTypeException(safeName);
    }
    return DocumentMetadata(
      filename: safeName,
      extension: extension,
      mimeType: normalizedMime,
      openPolicy: policy,
    );
  }

  final String filename;
  final String? extension;
  final String mimeType;
  final DocumentOpenPolicy openPolicy;
}

const documentContentProbeLimit = 8192;

/// Confirms only the document formats Matome can safely hand to another app.
/// This is intentionally a small allow-list, not a general file-type detector.
DocumentOpenPolicy probeDocumentOpenPolicy(
  String? extension,
  String mimeType,
  List<int> bytes,
) {
  final declared = classifyDocumentOpenPolicy(extension, mimeType);
  if (declared == DocumentOpenPolicy.blocked ||
      declared == DocumentOpenPolicy.attachmentOnly ||
      declared == DocumentOpenPolicy.downloadOnly) {
    return declared;
  }

  final probe = bytes.length <= documentContentProbeLimit
      ? bytes
      : bytes.sublist(0, documentContentProbeLimit);
  final ext = extension?.toLowerCase();
  final matches = switch (ext) {
    'pdf' => _startsWith(probe, const [0x25, 0x50, 0x44, 0x46, 0x2d]),
    'doc' || 'xls' || 'ppt' => _startsWith(probe, const [
      0xd0,
      0xcf,
      0x11,
      0xe0,
      0xa1,
      0xb1,
      0x1a,
      0xe1,
    ]),
    'docx' || 'xlsx' || 'pptx' || 'odt' || 'ods' || 'odp' => _isZip(probe),
    'rtf' => _startsWith(probe, const [0x7b, 0x5c, 0x72, 0x74, 0x66]),
    'txt' || 'text' || 'log' => _isPlausiblePlainText(probe),
    _ => false,
  };
  return matches ? declared : DocumentOpenPolicy.downloadOnly;
}

bool _startsWith(List<int> bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

bool _isZip(List<int> bytes) =>
    _startsWith(bytes, const [0x50, 0x4b, 0x03, 0x04]) ||
    _startsWith(bytes, const [0x50, 0x4b, 0x05, 0x06]) ||
    _startsWith(bytes, const [0x50, 0x4b, 0x07, 0x08]);

bool _isPlausiblePlainText(List<int> bytes) {
  if (bytes.isEmpty || bytes.contains(0)) return false;
  late final String text;
  try {
    text = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return false;
  }
  final trimmed = text.trimLeft().toLowerCase();
  if (trimmed.startsWith('<') ||
      trimmed.startsWith('{\\rtf') ||
      const [
        '<html',
        '<svg',
        '<?xml',
        '<!doctype',
        '<script',
      ].any(trimmed.contains)) {
    return false;
  }
  final controls = text.codeUnits.where(
    (unit) => unit < 0x20 && unit != 0x09 && unit != 0x0a && unit != 0x0d,
  );
  return controls.length * 20 <= text.length;
}

class UnsafeDocumentTypeException implements Exception {
  const UnsafeDocumentTypeException(this.filename);

  final String filename;

  @override
  String toString() => 'Unsafe document type: $filename';
}

const _activeExtensions = {'html', 'htm', 'xhtml', 'svg', 'xml', 'xsl', 'xslt'};
const _activeMimeTypes = {
  'application/xhtml+xml',
  'application/xml',
  'image/svg+xml',
  'text/html',
  'text/xml',
};
const _unsafeExtensions = {
  'apk',
  'app',
  'bat',
  'bash',
  'cmd',
  'com',
  'cpl',
  'deb',
  'dll',
  'dmg',
  'exe',
  'fish',
  'gadget',
  'hta',
  'inf',
  'ins',
  'isp',
  'jar',
  'js',
  'jse',
  'ksh',
  'lnk',
  'mjs',
  'msc',
  'msi',
  'msp',
  'mst',
  'php',
  'pif',
  'pl',
  'ps1',
  'py',
  'rb',
  'reg',
  'rpm',
  'run',
  'scr',
  'sh',
  'sys',
  'vb',
  'vbe',
  'vbs',
  'vhd',
  'vhdx',
  'vmdk',
  'wsf',
  'wsh',
  'zsh',
};
const _unsafeMimeTypes = {
  'application/javascript',
  'application/x-bat',
  'application/x-dosexec',
  'application/x-executable',
  'application/x-httpd-php',
  'application/x-msdownload',
  'application/x-msdos-program',
  'application/x-sh',
  'application/x-shellscript',
  'text/javascript',
  'text/x-python',
  'text/x-script.python',
  'text/x-shellscript',
};
const _officeMimeTypes = <String, Set<String>>{
  'doc': {'application/msword'},
  'docx': {
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  },
  'xls': {'application/vnd.ms-excel'},
  'xlsx': {'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'},
  'ppt': {'application/vnd.ms-powerpoint'},
  'pptx': {
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  },
  'rtf': {'application/rtf', 'text/rtf'},
  'odt': {'application/vnd.oasis.opendocument.text'},
  'ods': {'application/vnd.oasis.opendocument.spreadsheet'},
  'odp': {'application/vnd.oasis.opendocument.presentation'},
};

DocumentOpenPolicy classifyDocumentOpenPolicy(
  String? extension,
  String mimeType,
) {
  final ext = extension?.toLowerCase();
  final mime = normalizeDocumentMime(mimeType);
  if (_unsafeExtensions.contains(ext) || _unsafeMimeTypes.contains(mime)) {
    return DocumentOpenPolicy.blocked;
  }
  if (_activeExtensions.contains(ext) || _activeMimeTypes.contains(mime)) {
    return DocumentOpenPolicy.attachmentOnly;
  }
  if (ext == 'pdf' && mime == 'application/pdf') {
    return DocumentOpenPolicy.external;
  }
  if (const {'txt', 'text', 'log'}.contains(ext) && mime == 'text/plain') {
    return DocumentOpenPolicy.external;
  }
  if (_officeMimeTypes[ext]?.contains(mime) ?? false) {
    return DocumentOpenPolicy.systemApp;
  }
  return DocumentOpenPolicy.downloadOnly;
}

String sanitizeDocumentFilename(String filename) {
  final segments = filename.split(RegExp(r'[/\\]'));
  final basename = segments.where((segment) => segment.isNotEmpty).lastOrNull;
  final sanitized = (basename ?? 'download')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_')
      .trim();
  final nonEmpty = sanitized.isEmpty ? 'download' : sanitized;
  return String.fromCharCodes(nonEmpty.runes.take(255));
}

String? documentExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot <= 0 || dot == filename.length - 1) return null;
  final extension = filename.substring(dot + 1).toLowerCase();
  return RegExp(r'^[a-z0-9][a-z0-9+_-]{0,31}$').hasMatch(extension)
      ? extension
      : null;
}

String normalizeDocumentMime(String? mimeType) {
  final normalized = mimeType?.split(';').first.trim().toLowerCase();
  return normalized != null &&
          RegExp(
            r'^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$',
          ).hasMatch(normalized)
      ? normalized
      : 'application/octet-stream';
}
