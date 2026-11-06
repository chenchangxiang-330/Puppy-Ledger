# 0.1.7 构建记录

Flutter 3.47.9、Dart 3.13.7、JDK 21.0.13、Gradle 9.3.1。使用已锁定的项目依赖，应用编译 SDK 36，JNI 插件编译 SDK 35，NDK 28.2.13676358。

实际执行 `flutter build apk --release --flavor linepuppy --target-platform android-arm64 --no-pub`，生成 Release AOT APK。应用 ID `com.example.puppy_ledger.linepuppy`，版本 `0.1.7+8`，最低 Android 7.0。APK 大小 22,649,990 字节，SHA-256 `97919ececebea453080d42c2e6121b7b852cb0d47099fc7f55c6b981e43e62e7`。

沿用项目的 release 构建及已有 debug 签名配置。上版签名私钥未随源码交付，本次构建使用新密钥，APK 不能直接覆盖上版。

| APK | 签名证书 SHA-256 |
| --- | --- |
| 0.1.6 | `bcc788fa8c54ea40584ea8a98b6eb9667e57e5e6c36a69ee4748f705663ee278` |
| 0.1.7 | `e533dc8123fdade572b142b95fd6503e1e09eac6f73be3f542ac98ce4ad40d4a` |

APK v2 签名验证和 16KB ZIP 对齐通过。私钥和 SDK 缓存均未打包进源码。`docs/evidence` 包含最终构建、分析、测试、证书和视频记录。
