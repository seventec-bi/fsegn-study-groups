import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/media_storage_service.dart';

class GroupCover extends StatelessWidget {
  final String? imagePath;
  final double size;
  final double radius;
  const GroupCover({
    super.key,
    this.imagePath,
    this.size = 54,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.tealLight,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.groups_2_rounded,
        size: size * .52,
        color: AppTheme.primaryNavy,
      ),
    );
    if (path == null || path.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<String>(
        future: MediaStorageService.instance.groupCoverUrl(path),
        builder: (context, snapshot) => snapshot.hasData
            ? Image.network(
                snapshot.data!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
