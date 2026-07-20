import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:matome_vault/matome_vault.dart';

MediaInput mediaInputFromFile(
  File file, {
  required String filename,
  String? contentType,
  int? knownLength,
}) => _AppMediaInput(
  filename: filename,
  contentType: contentType,
  knownLength: knownLength,
  open: file.openRead,
);

MediaInput mediaInputFromPlatformFile(
  PlatformFile file, {
  String? contentType,
}) {
  final stream = file.readStream;
  final bytes = file.bytes;
  final path = file.path;
  if (stream != null) {
    return _AppMediaInput(
      filename: file.name,
      contentType: contentType,
      knownLength: file.size,
      open: () => stream,
    );
  }
  if (bytes != null) {
    return _AppMediaInput(
      filename: file.name,
      contentType: contentType,
      knownLength: file.size,
      open: () => Stream.value(bytes),
    );
  }
  if (path != null) {
    return mediaInputFromFile(
      File(path),
      filename: file.name,
      contentType: contentType,
      knownLength: file.size,
    );
  }
  throw StateError('Picker returned no readable media handle.');
}

final class _AppMediaInput implements MediaInput {
  _AppMediaInput({
    required this.filename,
    required this.contentType,
    required this.knownLength,
    required this.open,
  });

  @override
  final String filename;
  @override
  final String? contentType;
  @override
  final int? knownLength;
  final Stream<List<int>> Function() open;
  bool _opened = false;

  @override
  Stream<List<int>> openRead() {
    if (_opened) throw StateError('Media input is single-consumer.');
    _opened = true;
    return open();
  }
}
