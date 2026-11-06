# Android AppWidgetHost 验证宿主

这个测试 Activity 通过系统 `AppWidgetManager` 绑定三个已安装的 Provider，并由 `AppWidgetHostView` 显示生产 APK 提供的 RemoteViews。它是独立测试工具，不包含在小狗账本 APK 内。截图中的数据来自模拟器独立 SQLite 账本。

在 Android SDK 环境运行 `bash tool/android_widget_host/build.sh /tmp/widget-test-host.apk` 构建独立宿主。它使用临时测试签名。将其和账本的 Release APK 安装到测试设备后执行：

```sh
adb shell appwidget grantbind --package com.example.ledgerwidgethost --user 0
adb shell am start -n com.example.ledgerwidgethost/.HostActivity
```

在宿主中点击分类或日期会触发生产 PendingIntent。验证其他安卓桌面时，可直接在桌面小组件选择列表添加「小狗账本」的三种组件。
