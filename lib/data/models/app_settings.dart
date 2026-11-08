/// 本子的全局设置与解锁密码相关的元数据。
/// 盐与校验值都是可落盘的（校验值是密文），解锁密码本身永远不会写入磁盘。
class AppSettings {
  AppSettings({
    this.themeModeIndex = 0,
    this.fontScale = 1.0,
    this.autoLockMinutes = 5,
    this.passwordSalt,
    this.passwordCheck,
    this.hasPassword = false,
  });

  /// 0 跟随系统 / 1 浅色 / 2 深色
  final int themeModeIndex;

  /// 字体缩放倍数（0.9 - 1.3）
  final double fontScale;

  /// 自动锁屏时间（分钟），0 表示关闭。
  final int autoLockMinutes;

  /// PBKDF2 用的随机盐（base64）。
  final String? passwordSalt;

  /// 用派生密钥加密的固定校验串（base64），用来判断解锁密码是否正确。
  final String? passwordCheck;

  final bool hasPassword;

  AppSettings copyWith({
    int? themeModeIndex,
    double? fontScale,
    int? autoLockMinutes,
    String? passwordSalt,
    String? passwordCheck,
    bool? hasPassword,
  }) {
    return AppSettings(
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      fontScale: fontScale ?? this.fontScale,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      passwordCheck: passwordCheck ?? this.passwordCheck,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeModeIndex': themeModeIndex,
        'fontScale': fontScale,
        'autoLockMinutes': autoLockMinutes,
        'passwordSalt': passwordSalt,
        'passwordCheck': passwordCheck,
        'hasPassword': hasPassword,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      themeModeIndex: (map['themeModeIndex'] as num?)?.toInt() ?? 0,
      fontScale: ((map['fontScale'] as num?)?.toDouble() ?? 1.0).clamp(0.85, 1.4),
      autoLockMinutes: (map['autoLockMinutes'] as num?)?.toInt() ?? 5,
      passwordSalt: map['passwordSalt']?.toString(),
      passwordCheck: map['passwordCheck']?.toString(),
      hasPassword: map['hasPassword'] == true,
    );
  }
}
