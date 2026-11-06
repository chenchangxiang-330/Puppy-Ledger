# 小狗账本 · 开发交接

交接基线为 **0.1.9+10**，交付日期为 **2026-11-06**。小狗账本是一个离线安卓记账应用。用户可以记录收支、管理分类、查看日／周／月统计、生成每日小票，并通过 ZIP 备份迁移账本。应用数据保存在本机，换机时使用「我的」里的备份恢复功能。

## 1. 首次上传到 GitHub

解压 `puppy-ledger-0.1.9-source.zip`，把内层 `puppy_ledger/` 的**内容**放到仓库根目录。本文件应与 `README.md`、`pubspec.yaml` 同级。上传解压后的源码，保留 `pubspec.lock`、两个 `.gitignore`、`.metadata` 和内置素材。已构建的 APK 和截图压缩包可作为 GitHub Release 附件单独上传。

**首次提交有一个容易漏掉的步骤。** 源码包带有完整的 Gradle Wrapper，但 `android/.gitignore` 会忽略其中三个文件。在已初始化的 Git 仓库根目录执行以下命令，可让下一位接手人克隆后拿到相同的构建入口。

```sh
git add .
git add -f -- android/gradlew android/gradlew.bat android/gradle/wrapper/gradle-wrapper.jar
git update-index --chmod=+x -- android/gradlew
git diff --cached --name-only
```

提交前查看最后一条命令的输出。签名私钥（`.jks`、`.keystore`）、`key.properties`、`android/local.properties`、真实账本数据库和用户备份都应留在仓库外。角色插画、头像和图标的来源记录见[素材说明](docs/ASSETS.md)。如果准备公开仓库，请分别确认代码许可证和图片的公开分发范围。

## 2. 在新电脑运行和构建

| 项目 | 已交付版本使用的配置 |
| --- | --- |
| Flutter / Dart | Flutter 3.47.9，Dart 3.13.7 |
| 安卓构建环境 | JDK 21，Gradle Wrapper 9.3.1，Android SDK Platform 36（同时安装 35 供插件使用），Build Tools 36.0.0，NDK 28.2.13676358 |
| 应用标识 | 名称「小狗账本」，flavor 为 `linepuppy`，最终包名为 `com.example.puppy_ledger.linepuppy` |
| 安装范围 | Android 7.0（API 24）及以上，交付 APK 包含 `arm64-v8a` 和 `x86_64` |

以下命令都在含 `pubspec.yaml` 的目录运行。先用 `flutter doctor -v` 确认 Flutter 能找到 Android SDK、JDK 和设备。

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter devices
flutter run --flavor linepuppy
```

有多台设备时，在最后一条命令后追加 `-d 设备ID`。日常开发使用独立模拟器或测试账本。生成与本次交付架构相同的 Release APK 可执行以下命令。

```sh
flutter build apk --release --flavor linepuppy --target-platform android-arm64,android-x64
```

产物位于 `build/app/outputs/flutter-apk/app-linepuppy-release.apk`。准备给现有用户更新时，还需完成第 5 节的签名核对。[构建环境记录](docs/TOOLCHAIN.md)

## 3. 从哪处源码开始改

| 要改的内容 | 维护入口 |
| --- | --- |
| 启动、首页、记一笔、每日明细 | [应用入口](lib/main.dart)、[首页与导航](lib/ui/app.dart)、[记账表单](lib/ui/entry_page.dart)、[每日明细](lib/ui/daily_details.dart) |
| 保存、编辑、删除撤销、分类与设置 | [账本控制器](lib/core/controller.dart)、[SQLite 存储及升级](lib/core/store.dart)、[设置页](lib/ui/settings_page.dart) |
| 统计金额、时间分组与图表 | [计算和排序](lib/core/logic.dart)、[统计页](lib/ui/stats_page.dart)、[每日收支图](lib/ui/daily_flow_chart.dart) |
| 备份与旧数据 | [备份编解码及恢复](lib/core/backup.dart)、[旧退款转换](lib/core/migration.dart)、[数据模型](lib/core/models.dart) |
| 小狗素材、连续圆角和小票 | [通用组件与头像](lib/ui/widgets.dart)、[形状](lib/ui/shapes.dart)、[打印预览](lib/ui/receipt_page.dart)、[长图排版与导出](lib/ui/receipt_paper.dart) |
| 安卓桌面组件与系统分享 | [Flutter 桌面事件](lib/ui/widget_links.dart)、[原生入口及文件操作](android/app/src/main/kotlin/com/example/puppy_ledger/MainActivity.kt)、[三个组件及数据查询](android/app/src/main/kotlin/com/example/puppy_ledger/LedgerWidgets.kt) |

写入账目和设置应经过 `LedgerController`。保存成功后，控制器更新界面并通知安卓小组件刷新。小组件从同一份 SQLite 账本读取已提交的数据。如果修改表结构、收支枚举或统计口径，要同时检查 Flutter 和 Kotlin 两端。

## 4. 维护时要守住的数据约定

- **金额与分类。** `cents` 以正整数分存储，`kind` 区分收入和支出。退款归入收入，结余等于收入减支出。两类账目各用自己的分类。停用分类后，旧账仍能查看和编辑。
- **日期与时间。** `date` 是实际发生的本地日期，`occurredMinute` 是当日第几分钟（0–1439）。空值表示「未记录时间」，整数 0 表示真实 `00:00`。`createdAt`、`updatedAt` 用于记录写入和修改时间。日统计按发生时间分到 24 个小时，空时间单列并计入当天合计。周、月按日期汇总。
- **账本与备份。** 数据库位于应用文档目录的 `puppy_ledger.db`，当前 schema 为 3。ZIP 备份 v3 的主文件为 `backup.json`，旧自定义图片可存为可选的 `home.img`。导入兼容 v1/v2。旧退款转为「收入－退款」，保留原分类信息，只有日期的记录保留空时间。恢复会整体覆盖当前账本，操作前先导出当前备份。
- **筛选与小票。** 首页「全部／支出／收入」只筛选逐笔列表。当天合计、月汇总和小票均使用各自完整周期的账目。长图要包含最后一笔和底部合计。
- **主题与分工。** 奶油黄、蜜桃粉、草地绿控制配色和双狗表情。默认小鸡毛负责收入、小白负责支出。交换后更新展示角色，历史账目仍使用原有收支类型。两张抱金币头像位于 `assets/avatars/`，三套主题图位于 `assets/illustrations/`。

## 5. 下一版如何覆盖安装

0.1.9 已在 Android 11 模拟器上成功覆盖 0.1.8，并读取了旧账目。下一次发版要保留 `linepuppy` 和最终包名，在 `pubspec.yaml` 递增版本，新的构建号（加号后的数字）须大于 **10**。

**签名是交接时最容易中断升级的一项。** 当前 Release 构建使用项目的 `debug` 签名配置，0.1.8 和 0.1.9 实际使用了同一把密钥。源码包未附私钥。新电脑或 CI 自动创建的密钥通常不同。要继续覆盖已有安装，需要私下取得原密钥，并让 Gradle 使用它。[签名配置](android/app/build.gradle.kts)

Android SDK Build Tools 提供 `apksigner`。将它加入 PATH 后，在实际生成的 APK 上核对证书。

```sh
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-linepuppy-release.apk
```

| 核对对象 | 0.1.9 的 SHA-256 |
| --- | --- |
| 签名证书，后续覆盖升级时比对这一项 | `e533dc8123fdade572b142b95fd6503e1e09eac6f73be3f542ac98ce4ad40d4a` |
| 此次交付的 APK 文件，校验下载完整性时使用 | `231c97ddfe170c045a2b8c3d1c9a15cf8ebea1a53aa5209f6e48340659650790` |

如果只能使用另一把签名，先在旧版打开「我的 → 导出完整备份」，确认 ZIP 已保存到应用之外，再卸载旧版、安装新版，通过「我的 → 从备份恢复」导入，并核对账目和合计。

## 6. 最小回归与验证边界

在独立测试账本中，用同一天的三笔流水验收。录入 12:35 午餐支出 28 元、12:50 地铁支出 6 元、19:10 退款收入 100 元。

| 操作 | 应看到的结果 |
| --- | --- |
| 打开首页当天明细 | 收入 100 元、支出 34 元，三行各自显示实际发生时间 |
| 打开「统计 → 日 → 每日收支」 | 支出模式点 12 时合计 34 元，展开有两笔。收入模式点 19 时合计 100 元 |
| 首页只看支出，再生成小票 | 小票包含三笔，收入 100 元、支出 34 元、结余 66 元 |
| 导入旧备份，再新增一笔午夜记录 | 前者在「未记录时间」，后者在 00 时。删除撤销和重启后仍可区分 |
| 从安卓桌面进入 | 点「餐饮」直接进入已选好分类的支出表单，保存后概览刷新。点日历某天进入对应日期的明细 |

0.1.9 交付时静态分析通过，83 项 Flutter 测试和 5 项界面渲染／长图检查通过，覆盖三套主题、320 逻辑像素宽、双倍字号和减少动态效果。Android 11（API 30、x86_64）模拟器上验证了覆盖安装、组件冷启动、跨月刷新、系统分享和 PNG 保存，并把「收支概览」实际放到了 Pixel Launcher 桌面。尚待验证的是实体手机和不同厂商桌面。

自动化用例位于 [test/](test/)。额外的[截图测试](tool/release_preview_test.dart)需指定中文字体文件 `CJK_FONT`、输出目录 `PREVIEW_DIR`，并让 `TASK_ROOT/tooling/flutter` 指向已安装的 Flutter SDK。这些变量仅供截图脚本使用。安卓组件另有[独立测试宿主](tool/android_widget_host/README.md)。完整结果见[验证记录](docs/VALIDATION.md)。
