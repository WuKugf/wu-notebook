import 'package:flutter/material.dart';

import '../../theme/wu_theme.dart';

/// 网页预览环境的视频占位：网页端不读取本地文件，因此不提供播放。
class LocalVideoView extends StatelessWidget {
  const LocalVideoView({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(WuSpace.lg),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(WuSpace.radiusS),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_outlined, size: 26, color: colors.inkTertiary),
          const SizedBox(height: WuSpace.xs),
          Text(
            '网页预览不支持播放本地视频',
            style: context.texts.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
