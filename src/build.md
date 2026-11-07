# 构建与运行

## 环境要求

- **Godot 4.7.2**（含 Android 导出模板）
- **Android SDK**：platform 35+、build-tools
- **JDK 17**（Godot 的 Gradle 不接受过新的 JDK，27 会失败）
- **mdBook 0.5+**（只用于构建本文档）

## 安装导出模板

把官方导出模板解压到：

```
~/.local/share/godot/export_templates/4.7.2.stable/
```

目录里应当能直接看到 `android_debug.apk`、`android_release.apk` 等文件。

## 配置 Godot

在 Godot 编辑器 → Editor Settings → Export → Android 中设置：

| 项 | 值 |
|---|---|
| Android SDK Path | `~/Android/Sdk` |
| Java SDK Path | `/usr/lib/jvm/java-17-openjdk` |
| Debug Keystore | `~/.android/debug.keystore` |
| Keystore User | `androiddebugkey` |
| Keystore Pass | `android` |

没有 debug keystore 可以用 `keytool` 生成一个。

## 构建 APK

```bash
godot --headless --path . --export-debug "Android" build/island-royale.apk
adb install -r build/island-royale.apk
adb shell monkey -p com.soda.islandroyale -c android.intent.category.LAUNCHER 1
```

包名在 `export_presets.cfg` 的 `package/unique_name` 中修改。

## 桌面端

```bash
godot --path .
```

桌面端会自动捕获鼠标，WASD 移动、鼠标转视角、左键开火、右键瞄准、空格跳、R 换弹、H 医疗、F 侦察、Q 切枪、V 切视角。

## 构建文档

```bash
mdbook serve --open   # 本地预览，默认 http://localhost:3000
mdbook build          # 输出静态站到 book/
```

也可以用仓库根目录的 `make docs` / `make docs-serve`。

## 常见问题

**导出时报 ETC2/ASTC 错误**
`project.godot` 里需要开启 `rendering/textures/vram_compression/import_etc2_astc=true`，然后在 Godot 里重新导入一次资源。

**Gradle / JDK 报错**
确认 `export/android/java_sdk_path` 指向 JDK 17，而不是系统的 JDK 27。

**找不到导出模板**
确认模板目录名严格是 `4.7.2.stable`，与 Godot 版本一致。

**手机安装失败**
debug APK 需要允许“安装未知来源应用”；如果签名冲突，先卸载旧版本再装。
