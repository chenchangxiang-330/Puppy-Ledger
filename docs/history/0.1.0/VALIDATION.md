# 验证记录

验证日期：2026-11-03（北京时间）。工程版本：0.1.0+1。

## 已实际执行

| 验证 | 结果 |
| --- | --- |
| `flutter analyze` | 通过，No issues found |
| `flutter test --reporter expanded` | 通过，39/39 |
| 金额精度 | 0.10 + 0.20 = 30 分 = ￥0.30；空、零、负数、超过两位小数均拒绝 |
| 日期边界 | 周一至周日、自然月、闰日、月末月初、跨年周已测 |
| 退款 | 跨月退款归退款发生月；负净支出、分类冲减已测 |
| SQLite CRUD | 增加、历史补记、改金额/日期/类型、删除，与汇总一致 |
| 持久化 | 关闭数据库后从相同临时文件重开，账目、分类、设置仍在 |
| 分类 | 新增/改名/停用；停用保留原账目；不允许新账使用停用分类 |
| 图片 | 模拟系统返回图片后真实复制到持久目录；取消保持原图；数据库重开后引用与图片字节仍在；恢复默认已测 |
| 备份完整性 | 全部账目、分类、名称、短文案、主题、图片字节导出/恢复并重开一致；ZIP使用相对引用 |
| 损坏备份 | CRC、错误版本、缺字段、非法日期金额、重复ID、分类悬空、无效图片、结构异常等均拒绝 |
| 恢复原子性 | 实际SQLite触发器故障注入，事务中途失败后旧账目/设置/图片保持，新临时图片被清理 |
| 重复保存 | 并发重复点击仅产生一笔；页面状态只在写入成功后更新 |
| UI真实Flutter测试 | 空账本→无效金额保留→填写0.10并保存→首页/统计刷新 |
| UI布局与返回 | 360×800、1.5倍字体三页无溢出；280px键盘下保存按钮可滚动进入可见区域；未保存输入返回确认 |

测试全部使用独立临时SQLite数据库；不访问真实用户账本。原始完整输出在 `verification/flutter-analyze.txt` 和 `verification/flutter-test.txt`。

系统选择器的 MethodChannel 在控制器测试里使用模拟返回值；这验证持久复制、取消与备份数据流，**不等于已经在手机上验证系统相册/文件提供器**。

## 构建与设备

构建状态：成功。实际执行 `flutter --no-version-check build apk --debug --target-platform android-arm64 --verbose`，最终重建 exit 0、Gradle 22 秒。`apksigner verify --verbose --print-certs` 与 `aapt2 dump badging` 均 exit 0；Debug v2 签名通过，包名 `com.example.puppy_ledger`，versionName 0.1.0 / versionCode 1，minSDK24 / targetSDK36，仅 arm64-v8a。

交付APK：`puppy_ledger-0.1.0-debug-arm64.apk`，84,735,449 bytes（80.81 MiB）。SHA-256：`7675c3d1c2cf28f9d868da30ca0d593b2027cbfee199f36ef5d51321985271a4`。原始核验摘录见 `verification/apk-build-and-checks.txt`。
设备状态：已实际尝试软件模拟器（API35、无KVM）。最终APK推送完成，但Android尚未完成初始化，PackageInstallerService因StorageManager未就绪报错，安装命令退出255、未返回Success。随后限时结束，未启动App，也未进行设备端记账、重启、图片选择、备份恢复验证。没有App运行截图。详见 `verification/device-attempt.txt`。

**APK 构建成功；安装和真机体验待验证。**

## 已知限制

- Demo、Debug调试签名、个人单账本人民币，仅支出与退款。
- 界面日期选择/导航为1900–2100年；数据层独立校验纯日期，无UTC转换。
- 只接受本App导出的完整未压缩ZIP；请勿重压缩或编辑备份内部文件。完整覆盖、不合并。
- ZIP最多64MiB，JSON32MiB，图片12MiB/4000万像素；备份未加密。
- 替换/恢复后不再引用的旧图片可能继续留在私有目录；不会进入后续完整备份，卸载时由系统清理。
- 真机厂商差异、系统文件提供器、手机重启/进程终止后的端到端流程仍以设备实测为准。数据库关闭重开与图片持久化已有自动化验证。
- 没有登录/联网服务/同步/预算/收入余额/CSV/OCR。首次为空账本，无自动加载示例数据。

## 继续开发

先读本文件、`TOOLCHAIN.md`、根目录 `README.md`；应用入口 `lib/main.dart`。核心写入与图片在 `core/controller.dart`，SQLite版本入口在 `core/store.dart`，备份在 `core/backup.dart` 和 `core/zip_guard.dart`，界面在 `ui/`。

下一步优先在实际目标安卓机验证安装、记账编辑、结束进程后重开、更换图片、导出到下载目录、恢复备份；遇到问题保留机型/安卓版本与可复现步骤，再迭代到0.1.1。
