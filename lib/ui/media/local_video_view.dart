/// 本地视频播放组件。
/// 手机 / 电脑端使用 video_player 播放应用私有目录里的视频文件；
/// 网页预览环境没有本地文件系统，使用一个占位提示。
library;

export 'local_video_view_web.dart' if (dart.library.io) 'local_video_view_io.dart';
