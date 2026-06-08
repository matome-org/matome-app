import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';

void main() {
  runApp(const ProviderScope(child: MatomeApp()));
}

/// Minimal app root for the lab. The real Home/login UI lands in #765; this
/// just boots Riverpod and confirms the HTTP/auth/recordings layer is wired.
class MatomeApp extends StatelessWidget {
  const MatomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matome (Flutter Lab)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _LabHomePage(),
    );
  }
}

class _LabHomePage extends StatelessWidget {
  const _LabHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Matome — Flutter Lab'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Auth + recordings client wired (UI lands in #765).'),
            const SizedBox(height: 8),
            Text(
              'API base: ${AppConfig.apiBaseUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
