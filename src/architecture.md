# 项目结构

## 目录

```
project.godot          工程配置（Mobile 渲染器、横屏、ETC2/ASTC）
export_presets.cfg     Android 导出预设（arm64-v8a）
book.toml              mdBook 配置
src/                   本文档源文件
tools/gen_sfx.py       占位音效生成脚本
assets/
  audio/               音效 WAV
  models/              可选的真模型皮肤（.glb）
scenes/
  main.tscn            场景根：环境、太阳、地形、安全区、HUD、触屏
  player.tscn          玩家：碰撞体 + Visual + 过肩相机 + 枪口
  bot.tscn             AI：碰撞体 + Visual
  loot.tscn            武器箱
  medkit.tscn          医疗包
  scope.tscn           瞄具拾取物
scripts/
  input_state.gd       全局输入层（触屏 / 键盘 / 鼠标统一）
  player.gd            移动、跳伞、射击、换弹、槽位、瞄具、受伤
  bot.gd               索敌、进圈、走位、射击、死亡
  character_visual.gd  方块小人（士兵 / 二次元 / GLB 模型）
  skins.gd             皮肤配色表与模型清单
  scopes.gd            瞄具参数表
  weapons.gd           武器参数表
  world.gd             程序化岛屿、房区、物资点
  zone.gd              缩圈与圈外伤害
  loot.gd              武器箱拾取
  medkit.gd            医疗包拾取
  scope_pickup.gd      瞄具拾取
  minimap.gd           小地图
  game.gd              开局生成、存活统计、胜负判定
  hud.gd               血条、弹药、槽位、播报、配件面板、镜圈
  touch_controls.gd    虚拟摇杆、视角拖动、按钮
  sfx.gd               音效池（2D + 3D 距离衰减）
```

## 自动加载

| 名称 | 文件 | 作用 |
|---|---|---|
| `InputState` | `scripts/input_state.gd` | 汇总触屏/键盘/鼠标输入，提供 `move`、`look`、`fire`、`aim` 等状态和一次性事件 |
| `Sfx` | `scripts/sfx.gd` | 预加载音效、管理 2D/3D 播放器池、总线、混响与环境音 |

## 输入链路

```
触屏 / 键盘 / 鼠标
      ↓
InputState（每帧计算 move / fire / aim / 队列事件）
      ↓
Player._process / _physics_process
      ↓
移动、射击、换弹、切枪、开镜、医疗、侦察
      ↓
HUD / Minimap 读取 Game 与 Player 的状态并绘制
```

## 扩展指南

### 加一把枪

1. 在 `scripts/weapons.gd` 的 `DEFS` 里加一项（伤害、射速、弹匣、扩散等）
2. 把 id 加进 `ORDER`
3. 如需新的枪声，把 `assets/audio/shot_<id>.wav` 放进音效目录

### 加一个瞄具

1. 在 `scripts/scopes.gd` 的 `LIST` 里加一项（`fov`、`overlay`）
2. 把 id 加进 `ORDER`
3. `scripts/game.gd` 的 `SCOPE_IDS` 决定刷新池
4. `hud.gd` 的 `Scope` 会根据 `overlay` 绘制不同镜圈

### 加一套配色皮肤

往 `scripts/skins.gd` 的 `LIST` 追加字典：

```gdscript
{
    "name": "新皮肤",
    "shirt": Color(...), "vest": Color(...),
    "pants": Color(...), "helmet": Color(...), "skin": Color(...),
}
```

### 加一个模型皮肤

1. 放 `.glb` 到 `assets/models/`
2. 在 `MODEL_MANIFEST` 里加路径
3. 需要时设置 `model_yaw` 修正朝向

## 性能注意

- 角色静态部件用 `SurfaceTool` 合并成少数 mesh，避免几十个 draw call
- 地形一整块网格 + 一次三角网碰撞
- 树用 MultiMesh
- 音效使用固定大小的播放器池
- 小地图贴图只生成一次，之后每帧只画点
