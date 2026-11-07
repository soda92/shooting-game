# 音效系统

音效全部在 `assets/audio/`，短音效是 16-bit WAV，环境音是立体声 WAV。
占位素材由 `tools/gen_sfx.py` 合成；**真实素材**直接覆盖同名文件即可。

## API

```gdscript
Sfx.play("hit", -6.0)                        # 2D：自己的枪声、UI 反馈
Sfx.play_at("shot_rifle", pos, -7.0)         # 3D：AI 枪声、爆炸、鸟
Sfx.footstep("grass", -18.0)                 # 2D：玩家脚步
Sfx.footstep_at(pos, "concrete", -15.0)      # 3D：敌人脚步
```

音量单位是 dB：`0` 最响，`-6` 约一半，`-18` 很轻。

## 现在的声音结构

### 枪声：五层叠加

每把枪有 3 个随机变体（`shot_rifle_1..3` 等），`Sfx` 每次随机选一个：

| 层 | 作用 |
|---|---|
| crack | 2–5ms 高频瞬态，枪口爆裂感 |
| body | 带低通扫频的噪声，枪身厚度 |
| thump | 100→60Hz 正弦下扫，胸腔冲击 |
| tail | 低通噪声尾音 + 4 个早期反射 |
| action | 50ms 后的枪机/抛壳咔哒声 |

这比“一枪一个样本 + 随机音高”自然得多，因为真实枪声的随机性主要来自**音色**，不是音高。

### 空间感

- 3D 音效使用 `AudioStreamPlayer3D`，距离衰减 + 低通（`attenuation_filter_*`）
- **遮挡**：从相机到声源打一条射线；被地形/建筑挡住时降低 6dB，并把低通降到 1.3kHz
- **远距离回声**：超过 38m 的枪声/爆炸会延迟 `距离 / 230` 秒再播一次低通副本，走 `Echo` 总线（大厅混响），模拟山体/建筑反射
- `World` 总线：EQ 低切 + 户外混响（room 0.68，wet 0.15）
- `Echo` 总线：更长、更湿的混响（wet 0.55）

### 脚步与表面

玩家和 AI 都会按脚下表面选择样本：

- `grass`：草叶摩擦 + 两次轻响
- `sand`：更闷的低频沙地
- `concrete`：城区/桥面，短促硬质
- `water`：涉水/游泳的溅水声

AI 的脚步从 3D 位置播放，55m 内有效，是判断敌人方位的重要线索。

### 环境音

- 立体声 `ambient_wind`（12s 无缝循环）与 `ambient_surf`（10s 循环）
- 每 7–19 秒在相机周围随机播一声 3D 鸟叫
- 风/海浪在生成时做了首尾交叉淡化，循环点没有爆音

### 混音

- `SFX` 总线：EQ 低切 + 3.2kHz 轻微提升
- `World` 总线：低切 + 混响
- `Master` 总线：`AudioEffectCompressor`（2.4:1）→ `AudioEffectLimiter`
- 动态范围：近处枪声 -2dB，远处枪声 -7dB，脚步 -15 到 -18dB

## 想让音效更真实：优先级

1. **换真实素材**（提升最大）。合成器很难做出真实枪声的复杂瞬态和房间信息。
   - Kenney（CC0）：<https://kenney.nl/assets?q=audio>
   - Freesound（CC0 / CC-BY，注意署名）：<https://freesound.org>
   - Sonniss GDC 音频包（免费商用）：<https://sonniss.com/gameaudiogdc>
   - 直接覆盖 `assets/audio/shot_rifle_1.wav` 等同名文件，代码不用改。
2. **每个声音做 3–5 个变体**，随机轮播；人耳对重复极其敏感。
3. **分层**：瞬态、主体、尾音、机械声分开录/合成，再按距离和空间混合。
4. **空间化**：3D 衰减、低通、遮挡、混响/回声；声音的“位置”比音色更能骗过耳朵。
5. **材质化**：脚步、命中、弹壳落地按表面/材质区分。
6. **混音**：压缩 + 限制器，保证多声部不爆音；用 EQ 给枪声留出中高频空间。

## 素材命名

新增声音时，把文件名加进 `scripts/sfx.gd` 的 `NAMES`，然后在对应脚本调用
`Sfx.play(...)` 或 `Sfx.play_at(...)`。枪声按 `shot_<weapon>_<1..3>` 命名会自动
被变体选择器使用；脚步按 `footstep_<surface>_<1..3>` 命名。
