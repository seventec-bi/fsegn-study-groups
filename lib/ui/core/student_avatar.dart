import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/media_storage_service.dart';

class StudentAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarKey;
  final double radius;
  final Color? backgroundColor;

  const StudentAvatar({
    super.key,
    required this.displayName,
    this.avatarKey,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final key = avatarKey;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.tealLight,
      child: Text(
        displayName.trim().isEmpty ? 'E' : displayName.trim()[0].toUpperCase(),
        style: TextStyle(
          color: AppTheme.primaryNavy,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (key == null || key.isEmpty) return fallback;

    return FutureBuilder<String>(
      future: MediaStorageService.instance.viewUrl(key),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) return fallback;
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? AppTheme.tealLight,
          backgroundImage: NetworkImage(snapshot.data!),
        );
      },
    );
  }
}
