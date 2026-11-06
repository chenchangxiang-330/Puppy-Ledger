# 小狗账本 0.1.7

小鸡毛和小白换成了用户指定的两张抱金币原图。打开「我的 → 账本管理 → 小狗分工」可以查看和交换分工。首页收支卡片、记账表单和实际保存后的提示显示同一只负责的小狗。

本版仅更新角色头像，沿用 0.1.6 的 SQLite schema 2 和 v2 备份。v1 旧账本及旧备份仍按原有规则迁移，收支、统计、三种主题、编辑删除撤销及本地存储继续使用原实现。

## 安装与数据迁入

应用 ID 为 `com.example.puppy_ledger.linepuppy`，版本为 0.1.7+8。APK 面向 Android 7.0 及以上的 arm64 手机。0.1.6 使用的签名私钥未包含在其交付物中，本次构建使用新签名。

- 从已交付的 0.1.6 迁入：先在旧版「我的」导出完整备份 ZIP 到下载目录，确认文件已保存。然后卸载旧版，安装 0.1.7，从「我的」导入这份备份。账目、分类、主题和小狗分工随备份恢复。卸载会清除旧版的本地数据，必须先导出备份。
- 新手机直接安装 APK。

## 复现

Flutter 3.47.9、Dart 3.13.7、JDK 21、Android SDK 36。

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --flavor linepuppy --target-platform android-arm64
```

`docs/ASSETS.md` 记录所用图片，`docs/VALIDATION.md` 记录验收范围，`docs/history/0.1.6` 保存上一版说明。
