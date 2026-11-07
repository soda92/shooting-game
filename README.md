# Island Royale

一个离线单机「吃鸡」原型：Godot 4.7 + Android，你和 11 个 AI 跳伞、捡枪、缩圈、活到最后。

没有联网、没有账号、没有内购。整个 APK 约 28 MB。

## 玩法

- **12 人局**：1 个玩家 + 11 个 AI，AI 之间也会互相打
- **跳伞**：开局从 120 米高空下落，前 2.6 秒自由落体，之后自动开伞；摇杆可以控制落点
- **摇杆**：左手摇杆移动，推满自动冲刺
- **视角**：右半屏任意位置拖动转视角（第三人称过肩）
- **按钮**：开火 / 瞄准 / 跳 / 换弹 / 医疗 / 侦察
- **小地图**：左上角，显示整岛、当前安全区（青圈）、下一个圈（白圈）、你的朝向（白三角）、武器箱（金点）、医疗包（绿点）；侦察时显示敌人（红点）
- **医疗包**：白箱红十字，走过去拾取，最多带 3 个；点“医疗”按钮回 40 HP，AI 死亡有 35% 概率掉一个
- **侦察镜**：点“侦察”后 6 秒内，110 米内的敌人会在屏幕上显示红色菱形 + 距离，冷却 18 秒
- **武器**：地上金色箱子，走过去自动拾取并补满子弹
  - M4 步枪：24 伤害，540 RPM，30 发
  - UZI 冲锋枪：15 伤害，780 RPM，32 发
  - S12 霰弹枪：8 颗弹丸 × 11 伤害，6 发
  - AWM 狙击枪：85 伤害，5 发
- **安全区**：5 个阶段收缩，圈外每秒掉血并从 2 递增到 16
- **胜利条件**：活到最后

桌面端调试：WASD 移动、鼠标转视角、左键开火、右键瞄准、空格跳、R 换弹、H 医疗包、F 侦察镜。

## 构建

环境要求：

- Godot **4.7.2**（带 Android 导出模板）
- Android SDK（platform 35+、build-tools）
- JDK **17**（Godot 的 Gradle 不接受太新的 JDK）

导出模板安装到 `~/.local/share/godot/export_templates/4.7.2.stable/`，然后在 Godot 编辑器里设置：

- Editor Settings → Export → Android → Android SDK Path
- Editor Settings → Export → Android → Java SDK Path
- Debug Keystore 指向 `~/.android/debug.keystore`（alias `androiddebugkey`，密码 `android`）

命令行构建：

```bash
godot --headless --path . --export-debug "Android" build/island-royale.apk
adb install -r build/island-royale.apk
adb shell monkey -p com.soda.islandroyale -c android.intent.category.LAUNCHER 1
```

桌面端直接跑：

```bash
godot --path .
```

## 项目结构

```
project.godot          工程配置（Mobile 渲染器、横屏、ETC2/ASTC）
export_presets.cfg     Android 导出预设（arm64-v8a）
scenes/
  main.tscn            场景根：环境光、太阳、地形、安全区、HUD、触屏
  player.tscn          角色：胶囊体 + SpringArm 过肩相机 + 枪口
  bot.tscn             AI：胶囊体
  loot.tscn            补给箱：Area3D + 旋转方块 + 悬浮标签
scripts/
  input_state.gd       全局输入层（触屏 / 键盘 / 鼠标统一）
  player.gd            移动、跳伞、射击、换弹、受伤、死亡
  bot.gd               索敌、追逐、走位、射击、死亡
  character_visual.gd  方块小人（程序化建模 + 跑步摆臂 + 举枪姿势）
  skins.gd             皮肤配色表
  world.gd             程序化岛屿（高度场网格 + 水面 + 树 + 石头）
  zone.gd              缩圈阶段与圈外伤害
  loot.gd              武器箱拾取
  medkit.gd            医疗包拾取
  minimap.gd           小地图（整岛贴图 + 安全区 + 物资 + 敌人）
  game.gd              开局生成、存活统计、胜负判定
  hud.gd               血条、弹药、存活数、缩圈提示、结算面板
  touch_controls.gd    虚拟摇杆、视角拖动、按钮
  weapons.gd           武器数值表
  sfx.gd               音效池（2D + 3D 距离衰减）
```

## 调参入口

| 想改什么 | 去哪 |
|---|---|
| AI 数量 | `scripts/game.gd` → `BOT_COUNT` |
| 武器伤害 / 射速 / 弹匣 | `scripts/weapons.gd` |
| 医疗包数量 / 回血量 | `scripts/game.gd` → `MEDKIT_COUNT`；`scripts/player.gd` → `MEDKIT_HEAL` |
| 侦察镜时长 / 冷却 / 范围 | `scripts/player.gd` → `SCAN_TIME` / `SCAN_CD`；`scripts/hud.gd` 与 `scripts/minimap.gd` 里的 `110.0` |
| 缩圈节奏 / 圈外伤害 | `scripts/zone.gd` → `PHASES` |
| 岛的大小 / 地形精度 | `scripts/world.gd` → `WORLD_SIZE` / `RES` |
| 移动速度 / 跳跃 / 灵敏度 | `scripts/player.gd` 顶部常量 |
| 摇杆和按钮位置 | `scripts/touch_controls.gd` → `_layout()` |

## 已知限制

- 美术是程序化方块小人 + 圆锥树，没有骨骼动画和贴图
- 音效是程序合成的占位素材
- AI 是很轻量的状态机：没有寻路，靠直线走位和射线检测
- 没有载具、没有背包、没有多人和存档
- debug APK 需要手机允许安装未知来源应用

## 音效

全部在 `assets/audio/`，16-bit 单声道 44.1kHz WAV，占位素材是用 Python 合成的（见 `tools/gen_sfx.py`）。

- **替换**：直接覆盖同名 `.wav` 即可，不用改代码
- **新增**：文件放进 `assets/audio/`，再把名字加进 `scripts/sfx.gd` 的 `NAMES`
- **播放 API**：
  - `Sfx.play("hit", -6.0)` —— 2D，用于自己的枪声、UI 反馈
  - `Sfx.play_at("shot_rifle", pos, -7.0)` —— 3D，用于 AI 枪声、死亡，带距离衰减
- 音量单位是 dB：`0` 最响，`-6` 约一半，`-18` 很轻
- 短音效用 `.wav`；长音频/背景音乐用 `.ogg`（导入时可勾选循环）

### 混音与细节

- 两条总线：`SFX`（2D）和 `World`（3D）；`World` 上挂了 `AudioEffectReverb`，Master 上挂了 `AudioEffectLimiter`
- 3D 音效开了距离低通（`attenuation_filter_cutoff_hz = 7000`），远处枪声会变闷
- 每次播放随机 ±3% 音高、±1 dB 音量，避免机关枪一样的机械重复
- 脚步有 3 个变体随机切换；另有一条 5 秒风声环境音循环
- 真实素材的关键是**分层**：击发瞬态（transient）+ 枪身（body）+ 尾音（tail），再叠加距离低通，质感会立刻不一样

### 去哪找素材

- Kenney（CC0，直接商用）：https://kenney.nl/assets?q=audio
- Freesound（CC0 / CC-BY，注意署名）：https://freesound.org
- Sonniss GDC 音频包（免费商用）：https://sonniss.com/gameaudiogdc

## 皮肤

`scripts/skins.gd` 是一张配色表，每套包含 `shirt / vest / pants / helmet / skin` 五个颜色。右上角“换肤”按钮会在 6 套之间循环，立即生效，重开也会保留。

- 玩家默认“特战蓝”，AI 从其余 5 套里随机
- 加皮肤：往 `LIST` 里追加一个字典即可
- 换真正的模型：把角色换成带骨骼的 glTF，保留 `character_visual.gd` 的 `set_skin()` 和 `tick(delta, speed, aiming)` 接口，`player.gd` / `bot.gd` 不用改
