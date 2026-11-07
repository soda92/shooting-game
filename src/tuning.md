# 调参手册

## 对局

| 想改什么 | 位置 |
|---|---|
| AI 数量 | `scripts/game.gd` → `BOT_COUNT` |
| AI 难度倍率 | `scripts/meta.gd` → `bot_*_scale()` |
| 训练场靶子数量 / 血量 | `scripts/game.gd` → `_spawn_targets()`；`scripts/target.gd` → `max_health` |
| 武器箱数量 | `scripts/game.gd` → `LOOT_COUNT` |
| 医疗包数量 | `scripts/game.gd` → `MEDKIT_COUNT` |
| 瞄具数量 | `scripts/game.gd` → `SCOPE_COUNT` |
| 玩家出生避开房区的距离 | `scripts/game.gd` → `random_open_point(280.0, 40.0)` |
| 护甲 / 手雷数量 | `scripts/game.gd` → `ARMOR_COUNT` / `GRENADE_COUNT` |
| 护甲减伤比例 | `scripts/player.gd` → `take_damage()` 里的 `0.5` |
| 手雷引信 / 半径 / 伤害 | `scripts/grenade.gd` → `FUSE` / `RADIUS` / `_explode()` |
| 降落伞样式 | `scripts/parachutes.gd` → `LIST`（按皮肤索引选择） |

## 武器与瞄具

| 想改什么 | 位置 |
|---|---|
| 武器伤害 / 射速 / 弹匣 / 射程 | `scripts/weapons.gd` → `DEFS` |
| 爆头倍率 | `scripts/player.gd` 的 `2.0`；`scripts/bot.gd` 的 `1.8` |
| 瞄具 FOV / 镜圈类型 | `scripts/scopes.gd` → `fov` / `overlay` |
| 开镜灵敏度 | `scripts/player.gd` → `0.55` |
| AI 交战距离 | `scripts/bot.gd` → `RANGE`（默认 42） |
| AI 视野距离 | `scripts/bot.gd` → `SIGHT_RANGE`（默认 60） |
| AI 反应时间 | `scripts/bot.gd` → `_pick_target()` 里的 `0.45, 1.0` |
| AI 转向开火阈值 | `scripts/bot.gd` → `facing.dot(flat_dir) > 0.955` |
| AI 武器池 | `scripts/bot.gd` → `Weapons.ORDER` |
| AI 射击间隔 | `scripts/bot.gd` → `_shoot()` 里的 `1.8, 3.0` 倍率 |

## 玩家

| 想改什么 | 位置 |
|---|---|
| 移动 / 冲刺 / 瞄准速度 | `scripts/player.gd` 顶部 `WALK` / `SPRINT` / `AIM_WALK` |
| 跳跃 / 重力 | `scripts/player.gd` → `JUMP_V` / `GRAVITY` |
| 游泳速度 | `scripts/player.gd` → `SWIM_SPEED` |
| 视角灵敏度 | `scripts/player.gd` → `LOOK_SENS` |
| 医疗包回血量 / 携带上限 | `scripts/player.gd` → `MEDKIT_HEAL` / `MAX_MEDKITS` |
| 侦察镜时长 / 冷却 | `scripts/player.gd` → `SCAN_TIME` / `SCAN_CD` |
| 侦察范围 | `hud.gd`、`minimap.gd`、`player.gd` 里的 `110.0` |
| 切枪时间 | `scripts/player.gd` → `switch_weapon()` 里的 `0.4` |

## 安全区与地图

| 想改什么 | 位置 |
|---|---|
| 缩圈节奏 / 半径 / 伤害 | `scripts/zone.gd` → `PHASES` |
| 圈心随机偏移幅度 | `scripts/zone.gd` → `_prepare_next()` 里的 `0.9` |
| 岛的大小 / 地形精度 | `scripts/world.gd` → `WORLD_SIZE` / `RES` |
| 房区数量 | `scripts/world.gd` → `POI_COUNT` |
| 房区平整度 / 间距 | `scripts/world.gd` → `_is_flat(p, 9.0, 2.2)` / `140.0` |
| 城区位置 / 台地高度 | `scripts/world.gd` → `CITY_CENTER` / `CITY_PLATEAU` |
| 湖泊位置 / 半径 / 深度 | `scripts/world.gd` → `POND_CENTER` / `POND_RADIUS` / `POND_DEPTH` |
| 草地密度 / 视距 / 叶高 / 最大高度 | `scripts/grass.gd` → `PER_CHUNK` / `VIEW` / `_make_blade_mesh()` / `15.0` |

## UI 与触屏

| 想改什么 | 位置 |
|---|---|
| 摇杆 / 按钮位置和大小 | `scripts/touch_controls.gd` → `_layout()` |
| 按钮淡出透明度和时间 | `scripts/touch_controls.gd` → `_process()` 的 `0.35` / `2.5` |
| 小地图显示范围 | `scripts/minimap.gd` → `MAP_RANGE` |
| 击杀播报停留时间 | `scripts/hud.gd` → `add_feed()` 里的 `4.0` |
| 配件面板尺寸 | `scripts/hud.gd` → `_build()` 里 `_place(panel, ...)` |

## 音效

| 想改什么 | 位置 |
|---|---|
| 音量 | 调用处的 `volume_db` 参数（0 最响，-18 很轻） |
| 3D 衰减 / 距离低通 | `scripts/sfx.gd` → `max_distance` / `unit_size` / `attenuation_filter_*` |
| 环境音音量 | `scripts/sfx.gd` → `_start_ambience()` 的 `-25.0` / `-31.0` |
| 音效列表 | `scripts/sfx.gd` → `NAMES` |
| 枪声变体数量 | `scripts/sfx.gd` → `_pick_stream()` 的 `1..3` |
| 遮挡 / 回声触发距离 | `scripts/sfx.gd` → `_play_3d()` 里的 `38.0` / `2.5` |
| 鸟叫间隔 | `scripts/sfx.gd` → `_process()` 里的 `7.0, 19.0` |
