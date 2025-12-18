import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../utils/item_assets.dart';

class ItemAssetPreview extends StatelessWidget {
  const ItemAssetPreview({
    super.key,
    required this.assetPath,
    required this.assetType,
    required this.placeholderIcon,
    this.borderRadius = 16,
    this.placeholderIconSize = 40,
    this.imageFit = BoxFit.cover,
    this.riveFit = rive.Fit.cover,
  });

  final String? assetPath;
  final String? assetType;
  final IconData placeholderIcon;
  final double borderRadius;
  final double placeholderIconSize;
  final BoxFit imageFit;
  final rive.Fit riveFit;

  @override
  Widget build(BuildContext context) {
    final ref = resolveItemAssetRef(assetPath: assetPath, assetType: assetType);
    final fallback = _placeholder();
    if (ref == null) return fallback;

    if (ref.kind == ItemAssetKind.rive) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _RivePreview(
          path: ref.path,
          isNetwork: ref.isNetwork,
          fit: riveFit,
          fallback: fallback,
        ),
      );
    }

    if (ref.isNetwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          ref.path,
          fit: imageFit,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_rounded)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        ref.path,
        fit: imageFit,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.image_not_supported_rounded)),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(child: Icon(placeholderIcon, size: placeholderIconSize)),
    );
  }
}

class _RivePreview extends StatefulWidget {
  const _RivePreview({
    required this.path,
    required this.isNetwork,
    required this.fit,
    required this.fallback,
  });

  final String path;
  final bool isNetwork;
  final rive.Fit fit;
  final Widget fallback;

  @override
  State<_RivePreview> createState() => _RivePreviewState();
}

class _RivePreviewState extends State<_RivePreview> {
  late rive.FileLoader _fileLoader;

  @override
  void initState() {
    super.initState();
    _fileLoader = _createLoader();
  }

  @override
  void didUpdateWidget(covariant _RivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.isNetwork != widget.isNetwork) {
      _fileLoader.dispose();
      _fileLoader = _createLoader();
    }
  }

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  rive.FileLoader _createLoader() {
    return widget.isNetwork
        ? rive.FileLoader.fromUrl(widget.path, riveFactory: rive.Factory.rive)
        : rive.FileLoader.fromAsset(widget.path, riveFactory: rive.Factory.rive);
  }

  @override
  Widget build(BuildContext context) {
    return rive.RiveWidgetBuilder(
      fileLoader: _fileLoader,
      builder: (context, state) => switch (state) {
        rive.RiveLoading() => Stack(
            fit: StackFit.expand,
            children: [
              widget.fallback,
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        rive.RiveFailed() => widget.fallback,
        rive.RiveLoaded() => rive.RiveWidget(
            controller: state.controller,
            fit: widget.fit,
          ),
      },
    );
  }
}

