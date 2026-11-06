# 0.1.1+2 实际验证记录

本版本为线条小狗风格改造。以下记录均来自本次运行；旧版记录独立保存在 history/0.1.0。

## 验证结果

- Flutter analyze：通过，无问题。
- 原有完整测试：39/39 通过；覆盖金额精度、日期边界、SQLite CRUD 与重开持久化、分类、图片、备份校验与恢复事务、重复保存、真实表单记账。
- 视觉调整后 UI 测试再次通过：2/2；包含 360×800、1.5 倍字号、280px 键盘和返回确认。
- 四页 Flutter 渲染：通过；390×912、2 倍像素输出，检查中文、图标、插画、分类按钮和布局。包含隔离演示数据，不是手机截图，也不写入交付 App。
- Android Debug APK：构建成功，Gradle 7m27s，退出码 0。
- apksigner verify：通过（v2 签名）。
- aapt2：包名 com.example.puppy_ledger.linepuppy，versionName 0.1.1 / versionCode 2，minSDK24 / targetSDK36，桌面名称 小狗账本·线条版。
- 启动入口为 com.example.puppy_ledger.MainActivity；已核对 flavor 后缀不改变入口类名。
- zipalign -c -P 16 4：通过。
- APK ZIP CRC：通过；内置插画与源码资产字节一致；原生库仅 arm64-v8a。

APK 大小：85,711,256 bytes（81.74 MiB）。
SHA-256：`9199b9b57d9943d5feb69a620b666534113c436335712d2efce6da38b1c64548`。

## 数据兼容性

pubspec.lock、SQLite store、金额/日期 logic、backup、zip_guard 与上传 0.1.0 源码逐字节相同。controller 仅有 Dart 格式化换行；models 仅将新账本默认强调色从 peach 改为 lemon。数据库 schema 与备份 formatVersion 未改。

独立包安装不会自动读取旧版应用私有数据。迁移请使用旧版导出备份、线条版恢复的原有流程。恢复会带入旧主题及自定义图片，可在我的页面切换奶油黄与恢复默认小狗。

## 设备边界

adb devices -l 未发现已连接设备。本次没有声称完成真机安装、系统相册/文件提供器或手机进程重启测试；现有 MethodChannel 测试采用模拟系统返回值。APK 构建与签名验证成功不能代替具体手机安装验收。

Debug manifest 的 INTERNET 权限供 Flutter 调试使用；业务和插画均离线。此次未增加登录、远端接口或数据上传。

原始输出摘录见 verification/。
