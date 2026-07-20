import 'package:flutter/material.dart';

import '../../features/details/file_detail_screen.dart';
import '../../features/files/files_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/items/text_item_host.dart';
import '../../features/matome/matome_detail_screen.dart';
import '../screens/recording_screen.dart';
import '../screens/meeting_recording_screen.dart';

/// Canonical route target for `/recording`.
class RecordingPage extends StatelessWidget {
  RecordingPage({super.key, RecorderBinding? binding})
    : binding = binding ?? RecorderBinding.mic;

  final RecorderBinding binding;

  @override
  Widget build(BuildContext context) => RecordingScreen(binding: binding);
}

/// Canonical route target for `/meeting`.
class MeetingRecordingPage extends StatelessWidget {
  MeetingRecordingPage({super.key, MeetingRecordingBinding? binding})
    : binding = binding ?? MeetingRecordingBinding();

  final MeetingRecordingBinding binding;

  @override
  Widget build(BuildContext context) =>
      MeetingRecordingScreen(binding: binding);
}

/// Canonical route target for `/matome/:id`.
class MatomeDetailPage extends StatelessWidget {
  const MatomeDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => MatomeDetailScreen(id: id);
}

/// Canonical route target for `/files`.
class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) => const FilesScreen();
}

/// Canonical route target for recording file detail routes.
class FileDetailPage extends StatelessWidget {
  const FileDetailPage.audio({super.key, required this.id})
    : _kind = _FileDetailPageKind.audio;

  const FileDetailPage.image({super.key, required this.id})
    : _kind = _FileDetailPageKind.image;

  const FileDetailPage.document({super.key, required this.id})
    : _kind = _FileDetailPageKind.document;

  const FileDetailPage.video({super.key, required this.id})
    : _kind = _FileDetailPageKind.video;

  final String id;
  final _FileDetailPageKind _kind;

  @override
  Widget build(BuildContext context) {
    return switch (_kind) {
      _FileDetailPageKind.audio => FileDetailScreen.byId(id: id),
      _FileDetailPageKind.image => FileDetailScreen.imageById(id: id),
      _FileDetailPageKind.document => FileDetailScreen.documentById(id: id),
      _FileDetailPageKind.video => FileDetailScreen.videoById(id: id),
    };
  }
}

enum _FileDetailPageKind { audio, image, document, video }

/// Canonical route target for `/items/text/:id`.
class TextItemPage extends StatelessWidget {
  const TextItemPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => TextItemHost(itemId: id);
}

/// Canonical route target for `/inbox`.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
