import 'package:flutter/material.dart';
import 'package:meeting_capture/meeting_capture.dart';

void main() => runApp(const MeetingCaptureExampleApp());

class MeetingCaptureExampleApp extends StatelessWidget {
  const MeetingCaptureExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('meeting_capture_macos')),
        body: Center(
          child: FutureBuilder<MeetingCaptureCapability>(
            future: MeetingCapturePlatform.instance.probe(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              final capability = snapshot.data!;
              return Text(
                'backend: ${capability.backendId}\n'
                'supported: ${capability.supported}\n'
                'reason: ${capability.reason ?? "-"}',
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
    );
  }
}
