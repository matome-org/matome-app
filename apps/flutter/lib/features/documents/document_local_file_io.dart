import 'dart:io';

Future<bool> localFileExists(String path) => File(path).exists();

Future<List<int>> readLocalPrefix(String path, int maxBytes) async {
  final file = await File(path).open();
  try {
    return file.read(maxBytes);
  } finally {
    await file.close();
  }
}
