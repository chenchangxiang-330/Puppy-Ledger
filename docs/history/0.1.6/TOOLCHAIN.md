# 0.1.6 工具链与复现

- Flutter 3.47.9 stable，framework c197ca5199，Dart 3.13.7。
- Flutter SDK 官方归档 SHA-256：25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a（基线安装时已校验）。
- Eclipse Temurin JDK 21.0.13+9，Java/Kotlin 编译目标 17。
- Android SDK Platform 36、Build Tools 36.0.0、NDK 28.2.13676358、CMake 3.22.1。
- Gradle 9.3.1、AGP 9.1.0、项目 Kotlin 插件配置 2.4.0；沿用原工程版本和 Gradle wrapper。
- pubspec.lock 与 0.1.5 逐字节一致，无新增运行依赖。SDK、JDK、缓存、环境代理配置不打包。

## 构建与验证

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release --flavor linepuppy --target-platform android-arm64
```

最终实际构建为 Release AOT APK；本次 Gradle 构建耗时 64.5 秒。输出 build/app/outputs/flutter-apk/app-linepuppy-release.apk，22,156,423 字节（约 22.16 MB）。这是 release 优化构建，签名沿用原项目已有的 debug signing config。APK 内含 arm64-v8a/libapp.so 和 Flutter 引擎，非源码占位文件。

- applicationId：com.example.puppy_ledger.linepuppy
- versionName：0.1.6；versionCode：7
- minSdk：24（Android 7.0）；targetSdk：36
- 桌面名称：小狗账本
- 启动 Activity：com.example.puppy_ledger.MainActivity
- APK Signature Scheme v2 验证通过；16KB ZIP 对齐验证通过。
- 证书 SHA-256：bcc788fa8c54ea40584ea8a98b6eb9667e57e5e6c36a69ee4748f705663ee278
- 与已交付 0.1.5 的签名证书相同；包名相同，版本号从 6 递增到 7。
- Release manifest 无 INTERNET 权限；素材和数据均在本地。

源码不包含签名私钥。在其他开发机直接构建会采用该机器的调试密钥；要覆盖本次安装包需配置同一签名。

## 交互视频复现

设置 TASK_ROOT（其下 tooling/flutter 为 Flutter SDK）、CJK_FONT（本地中文字体文件）和 MOTION_DIR（帧输出目录），运行：

```sh
flutter test --no-pub tool/motion_recording_test.dart
ffmpeg -framerate 20 -i "$MOTION_DIR/%05d.png" -vf scale=624:1600 -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart interactions.mp4
```

录制工具以 390×1000 逻辑像素绘制，底部 60px 为视频字幕区；2 倍像素捕获，最终导出 624×1600、20fps H.264 MP4，共 712 帧，时长 35.6 秒。仅工具依赖上述字体与环境路径，App 使用手机系统字体。每次录制创建临时 SQLite 并自动删除，交付 App 首次运行仍为空。

视频来自 Flutter 测试引擎驱动的真实 UI 与手势，不是 Android 屏幕录制，也不是性能测试。tool/preview_test.dart 保留原有静态截图能力。
