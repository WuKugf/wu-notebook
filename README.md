# WU本子 · WU Notebook

一本放在自己设备里的本子：**密码本、备忘录、待办、倒数日、文件库**。
完全离线，不登录、不注册、不联网、不上传任何数据，所有内容只保存在本机。

- **一套 Flutter 代码**：手机端是底部六个 Tab，电脑端是左侧常驻导航（宽度自适应）
- **本地加密**：密码本条目与加密笔记用 AES-256-GCM，密钥由解锁密码经 PBKDF2-HMAC-SHA256（10 万次）派生
- **`.wuback` 加密备份**：手动导出、手动传输、手动导入，不是云同步
- **克制的外观**：低饱和米白纸面 / 墨色深色模式、线性图标、淡入淡出动画，可调字体大小

> ⚠️ 解锁密码是唯一入口：**忘记密码无法恢复**，也没有任何找回机制。详见 [使用教程.md](./使用教程.md)。

## 功能

| 模块 | 说明 |
| --- | --- |
| 密码本 | 标题 / 账号 / 密码 / 备注 / 标签 / 置顶，敏感字段加密存储，内置本地密码生成器 |
| 备忘录 | 标题 / 正文 / 图片 / 标签 / 置顶，可标记为加密笔记（只在解锁后解密显示） |
| 待办 | 优先级（低 / 中 / 高）、截止日期、重复规则（每天 / 每周 / 每月），重复待办完成后自动生成下一条 |
| 倒数日 | 目标日期、剩余天数、颜色标记、置顶 |
| 文件库 | 导入图片 / 视频 / 文档到应用私有目录，本地预览、导出、彻底删除 |
| 设置 | 主题、字体大小、修改解锁密码、自动锁屏、立即锁屏、导入备份、回收站、清除本地数据、关于 |

另有：回收站（四类数据可恢复）、`.wuback` 备份导入导出（合并 / 覆盖两种模式）、自动锁屏（无操作后回到解锁页）。

## 运行

需要先安装 Flutter SDK（Dart >= 3.6.0，对应 Flutter 3.27+ 稳定版）。

```powershell
flutter pub get
flutter run -d windows          # Windows 桌面
flutter run -d <安卓设备 id>     # 安卓真机 / 模拟器
flutter run -d chrome           # 网页预览（仅看界面：附件、备份、本地视频不可用）
```

## 构建

```powershell
flutter build apk --release      # 产物：build\app\outputs\flutter-apk\app-release.apk
flutter build windows --release  # 产物：build\windows\x64\runner\Release\wu_notebook.exe
flutter build web --release      # 产物：build\web（预览用）
```

- 安卓需要 JDK 17 + Android SDK（实测 SDK Platform 36 / Build-Tools 36.0.0，minSdk 24 / targetSdk 36）
- Windows 需要 Visual Studio 2022 的「使用 C++ 的桌面开发」工作负载，并开启系统「开发者模式」
- 当前 `release` 构建复用 debug 签名（见 `android/app/build.gradle.kts`），正式分发前请配置自己的 keystore

## 隐私与网络权限

安卓清单里**没有声明 `INTERNET`**，并显式移除了插件带入的 `ACCESS_NETWORK_STATE`：

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" tools:node="remove" />
```

也就是说安装包本身不具备联网能力；Windows 端同样不发起任何网络请求。网页预览模式只是为了先看界面。

## 自查

```powershell
flutter analyze   # 静态检查
flutter test      # 4 个测试文件，共 17 个用例（存储 / 备份 / 界面流程 / 工具函数）
```

## 目录结构

```text
lib/
  main.dart                  启动入口
  app.dart                   MaterialApp、主题、字体缩放、锁屏门禁
  core/utils.dart            UUID、日期与大小格式化、密码规则
  theme/wu_theme.dart        颜色 / 间距 / 圆角 / 字号 token 与 ThemeData
  data/                      加密服务、Hive 存储、附件仓库、备份服务、全局状态、数据模型
  services/                  导出目录、打开文件夹、系统打开文件、安卓权限
  ui/                        shell、screens、backup、media、widgets
test/                        存储 / 备份 / 界面流程 / 工具函数测试
tool/preview_server.js       预览 flutter build web 产物的零依赖静态服务器
android/  windows/  web/     各平台工程文件
```

完整的搭建、构建、备份用法与限制说明见 [使用教程.md](./使用教程.md)。

## 许可

本项目自有代码以 **MIT License** 发布，见 [LICENSE](./LICENSE)。

第三方依赖（Hive、cryptography、file_picker、path_provider、url_launcher、video_player、
permission_handler、uuid 等）遵循各自在 pub.dev 上声明的开源许可，完整版本见 `pubspec.lock`。

## 免责声明

WU本子是一个本地工具：数据只存在你的设备上，作者无法访问、也无法帮你恢复。
请自行保管好解锁密码与 `.wuback` 备份文件——**密码丢失后，本子里的加密内容将永久无法打开**。
