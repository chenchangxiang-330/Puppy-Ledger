# 小狗账本 · 线条版

中文离线个人记账 Android Demo，版本 **0.1.1+2**。基于上传的 0.1.0 源码改造；保留支出/退款、历史补记、日周月统计、自定义图片、分类管理和完整 ZIP 备份恢复。首次启动仍为空账本。

## 这次修改

- 白色小狗与小金毛的双角色记账插画，随 APK 内置。
- 奶油背景、黑色线条圆角卡片；奶油黄、蜜桃粉、草地绿三套强调色。
- 首页金额卡、记账分类选择、统计、我的、空状态与反馈提示统一风格。
- 新的双小狗桌面图标与启动背景。
- 默认配色改为奶油黄；已有备份中的自选配色、自定义图片、名称和文案继续保留。

## 安装与旧数据

交付的是 arm64 Debug 测试 APK，需要 Android 7.0 或更新系统及 arm64 设备。

本次采用 `linepuppy` flavor，包名 **com.example.puppy_ledger.linepuppy**，桌面名 **小狗账本·线条版**。旧源码没有附带原签名私钥，因此采用独立安装的测试版；可以和旧版同时存在，安装不会覆盖旧版数据。

如需带入旧账目：
1. 旧版「我的」→「导出完整备份」，保存原始 ZIP。
2. 安装并打开线条版，在「我的」→「从备份恢复」选择这个 ZIP。
3. 核对账目数量后确认恢复。此操作覆盖线条版自己的数据，不影响旧 App。

导入旧备份会一并恢复旧主题和自定义首页图片。如需本次默认效果，可在「我的」选择「奶油黄」，并点「恢复默认小狗」。请勿将交付源码 ZIP 当作账本备份导入。

## 开发

工具链：Flutter 3.47.9 / Dart 3.13.7 / JDK 21 / Android SDK 36。依赖精确版本保留在 `pubspec.lock`。

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor linepuppy --target-platform android-arm64
```

APK 输出：`build/app/outputs/flutter-apk/app-linepuppy-debug.apk`。源码不含 SDK、缓存、用户账本或签名私钥。新开发环境使用自己的调试签名；将来若需直接覆盖本次已安装包，必须使用同一签名。

## 结构与素材

- `lib/core/`：原有 SQLite、金额计算、备份与图片持久化。数据库和备份格式仍为 v1。
- `lib/ui/`：四个主要页面与共用视觉组件。
- `assets/illustrations/puppy_pair.png`：本次生成的透明双角色插画。
- `assets/puppy_icon.svg`：可编辑的图标源文件；`python3 tool/generate_icon.py` 可重建各密度图标（依赖 cairosvg）。
- `tool/preview_test.dart`：真实 Flutter 组件渲染预览，使用独立临时数据库和演示数据，不向 App 注入数据。
- `docs/VALIDATION.md`：本版本实际验证结果；`docs/history/0.1.0/` 仅为旧版历史记录。

金额按整数分存储，净支出=支出−退款。周从周一开始，退款归实际退款日期。备份保持原有未压缩 ZIP 约定，不能重新压缩或手动修改。备份、相册和文件提供器操作需要在目标手机继续体验确认。
