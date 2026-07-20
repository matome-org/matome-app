import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matome_vault/matome_vault.dart';

import '../providers.dart';
import 'vault_image_provider.dart';

/// Preview policy: only authenticated images up to 25 MiB are materialized.
/// Larger originals require a future bounded thumbnail pipeline.
const int kMaxVaultImagePreviewBytes = 25 * 1024 * 1024;

class VaultLeaseImage extends ConsumerStatefulWidget {
  const VaultLeaseImage({
    super.key,
    required this.blobId,
    required this.fit,
    required this.errorBuilder,
  });

  final String? blobId;
  final BoxFit fit;
  final WidgetBuilder errorBuilder;

  @override
  ConsumerState<VaultLeaseImage> createState() => _VaultLeaseImageState();
}

class _VaultLeaseImageState extends ConsumerState<VaultLeaseImage> {
  VaultPlaintextLease? _lease;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant VaultLeaseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blobId != widget.blobId) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final previous = _lease;
    _lease = null;
    final raw = widget.blobId;
    if (raw == null || raw.isEmpty) {
      await previous?.dispose();
      if (mounted) setState(() => _error = StateError('Image unavailable.'));
      return;
    }
    try {
      final store = ref.read(mediaBlobStoreProvider);
      await previous?.dispose();
      final id = VaultBlobId(raw);
      final stat = await store.stat(id);
      if (stat.state != VaultBlobState.ready ||
          stat.plaintextLength == null ||
          stat.plaintextLength! > kMaxVaultImagePreviewBytes) {
        throw const VaultFailure(
          VaultFailureCode.blobNotReady,
          'Image preview is unavailable.',
        );
      }
      final lease = await store.createLease(
        id,
        purpose: VaultLeasePurpose.preview,
        ttl: const Duration(minutes: 15),
      );
      if (!mounted || generation != _generation) {
        await lease.dispose();
        return;
      }
      setState(() {
        _lease = lease;
        _error = null;
      });
    } catch (error) {
      await previous?.dispose();
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_lease?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lease = _lease;
    if (_error != null) return widget.errorBuilder(context);
    if (lease == null) return const Center(child: CircularProgressIndicator());
    return Image(
      image: imageProviderForVaultLease(lease.location),
      fit: widget.fit,
      errorBuilder: (context, _, _) => widget.errorBuilder(context),
    );
  }
}
