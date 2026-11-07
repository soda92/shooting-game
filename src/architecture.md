# 项目结构

## 目录

```
project.godot          工程配置（Mobile 渲染器、横屏、ETC2/ASTC）
export_presets.cfg     Android 导出预设（arm64-v8a）
book.toml              mdBook 配置
src/                   本文档源文件
tools/gen_sfx.py       占位音效生成脚本
tools/import_real_sfx.py  真实录音裁切/归一化导入脚本
tools/make_anime_skin.py  Blender 二次元角色生成脚本
assets/
  audio/               音效 WAV
  models/              可选的真模型皮肤（.glb）
scenes/
  menu.tscn            开始界面（模式 / 难度 / 皮肤预览 / 设置）
  main.tscn            对局根场景：环境、太阳、地形、安全区、HUD、触屏
  player.tscn          玩家：碰撞体 + Visual + 过肩相机 + 枪口
  bot.tscn             AI：碰撞体 + Visual + 发现提示
  target.tscn          训练场靶子
  loot.tscn            武器箱
  medkit.tscn          医疗包
  armor.tscn           护甲
  grenade.tscn         投掷中的手雷
  grenade_pickup.tscn  手雷拾取
  scope.tscn           瞄具拾取物
scripts/
  menu.gd              开始界面与 3D 预览
  meta.gd              模式与难度配置
  input_state.gd       全局输入层（触屏 / 键盘 / 鼠标统一）
  player.gd            移动、跳伞、射击、换弹、槽位、瞄具、受伤
  bot.gd               索敌、进圈、走位、射击、死亡
  character_visual.gd  方块小人（士兵 / 二次元 / GLB 模型）
  skins.gd             皮肤配色表与模型清单
  scopes.gd            瞄具参数表
  weapons.gd           武器参数表
  world.gd             流式地形区块、城区、桥、房区、物资点
  grass.gd             玩家周围的分块草地（MultiMesh + 风摆 shader）
  zone.gd              缩圈与圈外伤害
  loot.gd              武器箱拾取
  medkit.gd            医疗包拾取
  armor_pickup.gd      护甲拾取
  grenade.gd           手雷投掷与爆炸
  grenade_pickup.gd    手雷拾取
  scope_pickup.gd      瞄具拾取
  minimap.gd           小地图（点击展开）
  map_overlay.gd       右侧地图：地形贴图、圈、POI、物资、玩家、缩放/平移
  target.gd            训练场靶子
  game.gd              开局生成、存活统计、胜负判定、训练场、观战
  hud.gd               血条、弹药、槽位、播报、配件面板、镜圈
  touch_controls.gd    虚拟摇杆、视角拖动、按钮
  sfx.gd               音效池（2D + 3D、遮挡、回声、脚步、环境音）
```

## 自动加载

| 名称 | 文件 | 作用 |
|---|---|---|
| `InputState` | `scripts/input_state.gd` | 汇总触屏/键盘/鼠标输入，提供 `move`、`look`、`fire`、`aim` 等状态和一次性事件 |
| `Sfx` | `scripts/sfx.gd` | 预加载音效、管理 2D/3D 播放器池、总线、混响与环境音 |
| `Meta` | `scripts/meta.gd` | 当前模式（大逃杀/训练场）与难度，向 AI 提供倍率 |

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
- 地形按 180m 区块流式生成，只保留玩家周围 7 × 7 块；每块独立三角网碰撞
- 树和城区盒子都用 `SurfaceTool` 按材质合并
- 草只保留玩家周围 7 × 7 个区块，跨区块时才重建 MultiMesh
- 音效使用固定大小的 2D / 3D / Echo 播放器池
- 小地图贴图只生成一次，之后每帧只画点
