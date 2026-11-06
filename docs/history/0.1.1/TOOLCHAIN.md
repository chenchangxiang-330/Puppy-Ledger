# 本版本工具链

- Flutter 3.47.9 stable，framework c197ca5199，Dart 3.13.7。
- Flutter SDK 官方归档 SHA-256：25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a（已校验）。
- Eclipse Temurin JDK 21.0.13+9，Java/Kotlin 编译目标 17。
- Android SDK Platform 36、Build Tools 36.0.0、NDK 28.2.13676358、CMake 3.22.1。
- Gradle 9.3.1、AGP 9.1.0、项目 Kotlin 插件配置 2.4.0；保持原工程版本。
- 保留原始 pubspec.lock；下载缺失的包归档时均按 lock 中的 SHA-256 校验，再由 dart pub cache preload 导入缓存。
- 当前环境所有联网命令使用继承的 HTTPS 代理；Java 信任系统 CA。Gradle JVM 代理地址从每次命令的当前环境解析，未写入源码。
- SDK、JDK、Pub 缓存、Gradle 缓存与工作区配置独立放置，不打包交付。

## 本机重建

安装上述工具，设好本机 JAVA_HOME 和 ANDROID_HOME 后：

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor linepuppy --target-platform android-arm64
```

本源码含 Gradle wrapper。应用 namespace 保留 com.example.puppy_ledger；linepuppy flavor 为 applicationId 增加 .linepuppy 后缀，以便与旧 APK 并存。系统 Activity 使用完整类名，避免 flavor 后缀影响入口解析。

## 预览复现

`tool/preview_test.dart` 使用本地中文字体渲染截图。示例环境需要配置 TASK_ROOT（其下 tooling/flutter 指向 Flutter SDK），以及 CJK_FONT 和 PREVIEW_DIR。仅截图工具依赖这些测试环境路径，App 本身不依赖；正式 App 使用系统中文字体。

预览使用 390×912 逻辑像素、2 倍像素导出。截图为真实 Flutter widget 树渲染，未通过图片生成工具绘制界面。临时账本包含演示数据，测试后自动删除。
