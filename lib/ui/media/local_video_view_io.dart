import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../theme/wu_theme.dart';

/// 本地视频播放（手机 / 电脑端实现）。
/// 直接播放应用私有目录里的文件，不会走网络。
class LocalVideoView extends StatefulWidget {
  const LocalVideoView({super.key, required this.path});

  final String path;

  @override
  State<LocalVideoView> createState() => _LocalVideoViewState();
}

class _LocalVideoViewState extends State<LocalVideoView> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = File(widget.path);
    if (!await file.exists()) {
      if (mounted) setState(() => _error = '视频文件不存在');
      return;
    }
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() => _controller = controller);
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = '无法播放这个视频：$error');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = _controller;

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(WuSpace.lg),
        alignment: Alignment.center,
        child: Text(_error!, textAlign: TextAlign.center, style: context.texts.bodyMedium),
      );
    }
    if (controller == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final aspect = controller.value.aspectRatio;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: aspect.isFinite && aspect > 0 ? aspect : 16 / 9,
          child: VideoPlayer(controller),
        ),
        VideoProgressIndicator(controller, allowScrubbing: true, padding: EdgeInsets.zero),
        Padding(
          padding: const EdgeInsets.only(top: WuSpace.xxs),
          child: Row(
            children: [
              IconButton(
                tooltip: controller.value.isPlaying ? '暂停' : '播放',
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                ),
                color: colors.ink,
                onPressed: () {
                  setState(() {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  });
                },
              ),
              Expanded(
                child: Text(
                  '本地视频 · 不会联网',
                  style: context.texts.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
