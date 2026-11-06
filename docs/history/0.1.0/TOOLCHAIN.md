# 工具链记录

本轮日期：2026-11-03（北京时间）。所有新安装工具位于本任务 `tooling/` 目录，不打包进源码。

| 工具 | 实际版本 / 配置 |
| --- | --- |
| Flutter | 3.47.9 stable，revision `c197ca5199e9ee5661e865596c9c07294dfab51c` |
| Dart | 3.13.7 |
| Flutter Engine | `9e025265bef30b838c0c1b68cad19decf97048f2` |
| 构建 JDK | Eclipse Temurin 21.0.13+9-LTS；javac 21.0.13；Java/Kotlin target17 |
| 初始 Java | OpenJDK 21.0.12.1 实际为 JRE（没有 javac）；完整 JDK 修复见下文 |
| Android SDK | compileSDK 36 / targetSDK 36 / minSDK 24（Flutter 自动迁移后的最低版本，Android 7.0） |
| SDK Platform | Android 36 revision 2 |
| Android Build Tools | 36.0.0 |
| Android Platform Tools | 37.0.1 |
| Android CMake | 3.22.1（JNI依赖构建使用） |
| Android NDK | 28.2.13676358（Flutter stable 默认值） |
| Android SDK Command-line Tools | 19.0（实际用于安装组件） |
| Gradle wrapper | 9.3.1，bin 发行包 |
| Android Gradle Plugin | 9.1.0（Flutter 模板默认） |
| Kotlin Gradle Plugin | 2.4.0（Flutter 模板默认） |
| Android emulator | 37.2.13；API35 Google APIs x86_64 系统镜像；本环境没有 `/dev/kvm` |

## 安装与依赖

初始 PATH 中仅发现 Java 运行时，没有 Flutter/Dart/Android SDK/adb。Flutter 从官方 `releases_linux.json` 指定的 stable 归档下载；归档 SHA-256 已校验为：

`25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a`

Android SDK 从 Google 官方仓库安装。新 Command-line Tools 23.0 的 sdkmanager 转调 Android CLI 下载失败，因此改用官方 19.0 sdkmanager，按所需版本安装 SDK36、Build Tools36、NDK28.2 和 platform-tools。没有升级系统 Java；首次编译发现系统 Java 缺少 javac 后，在任务目录安装完整 JDK。

Flutter 工具的首次联网依赖解析较慢，先使用已存在的包缓存离线完成工具 bootstrap；项目 `flutter pub get` 实际联网完成，精确版本与内容校验值保存在 `pubspec.lock`。不应手工更新 lock。

当前云端命令通过继承代理访问官方源。旧 `GRADLE_OPTS` 使用了本环境不适用的固定代理地址，因此每次构建从当前 `HTTPS_PROXY` 读取主机和端口，给 Gradle JVM 设置 `http.proxyHost/Port` 与 `https.proxyHost/Port`；不禁用 TLS 校验、不绕过网络代理。源码不保存临时代理地址、凭据或 SDK 绝对路径。

发现宿主 Flutter 全局配置指向旧工作区 SDK，构建已通过任务专用 `XDG_CONFIG_HOME` 隔离配置，并显式设置 `ANDROID_HOME`/`ANDROID_SDK_ROOT` 为本任务 SDK。`android/local.properties` 自动生成并排除交付。

Gradle 堆上限 3GB、Metaspace 1GB、2 workers，关闭持久 daemon，并将项目 Kotlin 编译配置为 in-process。标准开发机可按资源情况调整。

## 可复现命令

在安装 Flutter 3.47.9、JDK21、Android SDK36 后，从工程根目录执行：

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

如果本地已有 Flutter 全局 SDK 配置，请确保其指向可用的 SDK。当前云端运行时额外使用 `CI=true`、`FLUTTER_SUPPRESS_ANALYTICS=true`、任务专用 `XDG_CONFIG_HOME` 和上述 Android SDK 环境变量。

实际验证结论以 README / 验证报告为准；安装工具或构建成功本身不等于真机验收。

## 环境检查的实际结果

隔离配置后的 `flutter doctor -v` 确认 Android toolchain、SDK36 组件、许可证、预期网络资源检查通过。Flutter 未添加到系统 PATH，命令使用任务内绝对路径。Chrome 和 Linux 桌面工具链未配置，不影响本次 Android 目标；代理自检枚举网络接口出现 `SocketException: Failed listing interfaces (OS Error: Bad value for ai_flags)`，但实际 pub / Gradle 下载已运行。构建命令的结果以构建日志为准，不把 doctor 结果当作 APK 成功。

本任务继续开发时，所有 Flutter 命令必须使用相同的隔离环境变量，防止其他 Flutter 命令把 `android/local.properties` 重写为宿主旧 SDK 路径：

```sh
export XDG_CONFIG_HOME=/workspace/scratch/ea74cfb99cac/tooling/config
export ANDROID_HOME=/workspace/scratch/ea74cfb99cac/tooling/android-sdk
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true
export JAVA_HOME=/workspace/scratch/ea74cfb99cac/tooling/jdk-21.0.13+9
/workspace/scratch/ea74cfb99cac/tooling/flutter/bin/flutter --no-version-check build apk --debug --target-platform android-arm64
```

上述绝对路径只适用于本次云端工作区；下载源码后应改用本机 SDK 路径。

Debug manifest 保留 Flutter 标准 INTERNET 权限，供本机 Dart VM 调试服务使用；main/release manifest 不声明网络权限。账本业务不发起网络请求，不依赖远程接口或素材，也不申请广泛存储权限。

完整 JDK 从 Adoptium 官方 API 指定的 Temurin21 发行包下载，SHA-256 校验通过：`d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c`。只在任务目录解压，并复用系统公开 CA 信任库，使 Java HTTPS 经过继承代理时保持证书校验。`javac -version` 实际返回 `javac 21.0.13`。

APK原生库 ABI 过滤按 Flutter `target-platform` 映射；arm64交付包只保留 `arm64-v8a`，防止JNI传递依赖的其他架构库使设备误判兼容性。首个构建核验发现辅助库包含额外架构后已加此过滤并重新构建。
