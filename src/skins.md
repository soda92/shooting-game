# 皮肤与模型

## 配色皮肤

`scripts/skins.gd` 是一张配色表。每套皮肤包含：

- 士兵：`shirt` / `vest` / `pants` / `helmet` / `skin`
- 二次元：`hair` / `blouse` / `skirt` / `socks` / `shoe` / `skin` / `eye`

右上角「换肤」按钮会在所有皮肤之间循环，立即生效，重开也会保留。

当前包含：

- 6 套士兵配色（特战蓝 / 丛林 / 沙漠 / 都市 / 雪地 / 赤红）
- 2 套程序化二次元（樱粉 / 赛博青，大头、双马尾、裙子、过膝袜）
- 玩家默认「特战蓝」，AI 只从士兵配色里随机

加一套配色只需要往 `LIST` 里追加一个字典。

## 真模型皮肤（GLB / GLTF）

`character_visual.gd` 支持加载带骨骼的模型。

1. 把 `.glb`（或 `.gltf` + 贴图）放进 `assets/models/`
2. 在 `scripts/skins.gd` 的 `MODEL_MANIFEST` 里加上路径
3. 重开游戏，「换肤」里会多出一个以文件名命名的皮肤

> 导出包必须显式写进 `MODEL_MANIFEST`。目录扫描只在编辑器环境有效，因为 PCK 里没有原始 `.glb`。

加载器会自动：

- 按 AABB 缩放到 1.75m 并贴地
- 默认朝 Godot 的 -Z；反了就给皮肤加 `"model_yaw": 3.14159`
- 查找 `AnimationPlayer`，按名字匹配 `idle` / `run` / `walk` / `aim`
- 跑动时按速度调整动画播放倍率
- 没有动画的模型会保持 T-pose

## 内置的二次元模型

仓库里已经带了三个自己生成的二次元角色：

| 皮肤 | 文件 | 特征 |
|---|---|---|
| 二次元·樱 | `assets/models/anime_pink.glb` | 粉色双马尾、白衬衫、藏青短裙 |
| 二次元·青 | `assets/models/anime_cyan.glb` | 青色双马尾、深色上衣、粉色鞋 |
| 二次元·绯 | `assets/models/anime_crimson.glb` | 红色双马尾、白衬衫、暗红短裙 |

它们都由 `tools/make_anime_skin.py` 在 Blender 5.2 里程序化生成，带骨骼和 `Idle` / `Run` / `Aim` 三个动画。

重新生成或改样式：

```bash
blender -b -P tools/make_anime_skin.py
```

颜色、发型、服装尺寸都在脚本的 `VARIANTS` 和几何参数里，改完重新跑一次会覆盖三个 GLB。

## 二次元模型来源

1. **VRoid Studio**（免费）捏人 → 导出 `.vrm`
2. VRM 转 GLB：Blender + VRM Add-on，或 `vrm2glb`
3. Mixamo 下载 `idle` / `run`，在 Blender 里 Retarget 到 VRM 骨架
4. 一起导出 GLB → 放进 `assets/models/`

注意事项：

- VRM 的 MToon 材质 Godot 不认，会退化成 PBR，颜色偏灰；在 Blender 里转成 Principled BSDF 再导出
- 没有动画的模型会 T-pose
- **不要把你没有分发权的模型提交到仓库**

> 这条通道已用 Mixamo 的 `Soldier.glb` 实测：缩放、贴地、朝向、Idle 动画都正常，55–57 FPS。
