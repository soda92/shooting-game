# Island Royale

离线单机「吃鸡」原型：**Godot 4.7 + Android**。你和 11 个 AI 跳伞、捡枪、缩圈、活到最后。

没有联网、没有账号、没有内购，APK 约 28 MB。

- 12 人局、程序化岛屿、3 个可进入的房区
- 双武器槽 + 瞄具配件（红点 / 4x / 8x）
- 第一/第三人称开镜实时切换
- 小地图、侦察镜、医疗包、击杀播报、受击方向
- 程序化音效与皮肤，支持 GLB 模型皮肤
- 内置 3 套 Blender 生成的二次元角色（骨骼 + Idle/Run/Aim）
- 护甲、手雷、可持久化的设置页
- 开始界面（模式 / 难度 / 皮肤 3D 预览）、训练场和死亡观战

## 文档（mdBook）

完整文档在 `src/`，用 mdBook 维护：

```bash
mdbook serve --open   # 本地预览
mdbook build          # 输出静态站到 book/
```

主要章节：

- [简介](src/README.md)
- [操作与 HUD](src/gameplay.md)
- [武器与战斗](src/combat.md)
- [岛屿与安全区](src/world.md)
- [构建与运行](src/build.md)
- [调参手册](src/tuning.md)

## 快速构建

```bash
godot --headless --path . --export-debug "Android" build/island-royale.apk
adb install -r build/island-royale.apk
adb shell monkey -p com.soda.islandroyale -c android.intent.category.LAUNCHER 1
```
