# 0.1.8 构建与签名

Flutter 3.47.9 / Dart 3.13.7 / JDK 21.0.13 / Gradle 9.3.1。应用编译 SDK 36、JNI 插件编译 SDK 35、NDK 28.2.13676358，依赖锁文件与 0.1.7 一致。

实际执行 `flutter build apk --release --flavor linepuppy --target-platform android-arm64 --no-pub`。包名 `com.example.puppy_ledger.linepuppy`，版本 0.1.8，versionCode 9，最低 Android 7.0。APK 共 22,715,930 字节，SHA-256 `fdd689213f91ecc2d7151e4279cc064b313b869d3e69a76e45c7cd4ab391f07b`。

沿用 0.1.7 的签名配置和实际密钥，两个 APK 的证书 SHA-256 相同，均为 `e533dc8123fdade572b142b95fd6503e1e09eac6f73be3f542ac98ce4ad40d4a`。0.1.7 的 versionCode 为 8，0.1.8 可覆盖安装。Android SDK 工具已验证 APK v2 签名及 16KB ZIP 对齐。源码包不含私钥或构建缓存。
