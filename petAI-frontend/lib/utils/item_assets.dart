enum ItemAssetKind { png, rive, unknown }

class ItemAssetRef {
  const ItemAssetRef({
    required this.path,
    required this.kind,
    required this.isNetwork,
  });

  final String path;
  final ItemAssetKind kind;
  final bool isNetwork;
}

ItemAssetRef? resolveItemAssetRef({required String? assetPath, String? assetType}) {
  final rawPath = (assetPath ?? "").trim();
  if (rawPath.isEmpty) return null;

  final normalizedPath = rawPath.replaceAll("\\", "/");
  final kind = _resolveKind(assetType: assetType, assetPath: normalizedPath);

  if (_isNetwork(normalizedPath)) {
    return ItemAssetRef(path: normalizedPath, kind: kind, isNetwork: true);
  }

  String resolved = normalizedPath;

  if (resolved.startsWith("/")) {
    resolved = resolved.substring(1);
  }

  if (resolved.startsWith("assets/")) {
    final after = resolved.substring("assets/".length);
    if (!after.contains("/")) {
      resolved = "assets/items/$after";
    }
  } else if (resolved.startsWith("items/")) {
    resolved = "assets/$resolved";
  } else if (resolved.startsWith("rive/")) {
    resolved = "assets/$resolved";
  } else if (!resolved.contains("/")) {
    resolved = "assets/items/$resolved";
  } else {
    resolved = "assets/$resolved";
  }

  if (!_hasExtension(resolved)) {
    if (kind == ItemAssetKind.rive) {
      resolved = "$resolved.riv";
    } else if (kind == ItemAssetKind.png) {
      resolved = "$resolved.png";
    }
  }

  return ItemAssetRef(path: resolved, kind: kind, isNetwork: false);
}

bool _isNetwork(String value) {
  return value.startsWith("http://") || value.startsWith("https://");
}

bool _hasExtension(String value) {
  return RegExp(r"\.[a-z0-9]+$", caseSensitive: false).hasMatch(value);
}

ItemAssetKind _resolveKind({required String? assetType, required String assetPath}) {
  final type = (assetType ?? "").trim().toLowerCase();
  if (type == "rive" || type == "riv") return ItemAssetKind.rive;
  if (type == "png" || type == "image") return ItemAssetKind.png;

  final path = assetPath.trim().toLowerCase();
  if (path.endsWith(".riv")) return ItemAssetKind.rive;
  if (path.endsWith(".png") ||
      path.endsWith(".jpg") ||
      path.endsWith(".jpeg") ||
      path.endsWith(".webp")) {
    return ItemAssetKind.png;
  }

  return ItemAssetKind.unknown;
}
