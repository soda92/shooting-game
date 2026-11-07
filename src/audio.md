# 音效系统

音效全部在 `assets/audio/`，16-bit 单声道 44.1kHz WAV。占位素材由 `tools/gen_sfx.py` 合成。

## 替换与新增

- **替换**：直接覆盖同名 `.wav`，不用改代码
- **新增**：文件放进 `assets/audio/`，再把名字加进 `scripts/sfx.gd` 的 `NAMES`
- 短音效用 `.wav`；长音频/背景音乐用 `.ogg`（导入时可勾选循环）

## 播放 API

```gdscript
Sfx.play("hit", -6.0)                    # 2D：自己的枪声、UI 反馈
Sfx.play_at("shot_rifle", pos, -7.0)     # 3D：AI 枪声、死亡，带距离衰减
```

音量单位是 dB：`0` 最响，`-6` 约一半，`-18` 很轻。

## 混音结构

- 两条总线：`SFX`（2D）和 `World`（3D）
- `World` 上挂 `AudioEffectReverb`，枪声有空间尾音
- `Master` 上挂 `AudioEffectLimiter`，多声部叠加不爆音
- 3D 音效开启距离低通（`attenuation_filter_cutoff_hz = 7000`），远处枪声会变闷
- 每次播放随机 ±3% 音高、±1 dB 音量，避免机械重复
- 脚步有 3 个变体随机切换
- 一条 5 秒风声环境音循环

## 继续提升

真实素材的关键是**分层**：

- 击发瞬态（transient）
- 枪身（body）
- 尾音（tail）

再叠加距离低通和混响，质感会明显不同。也可以按距离切换近/远样本。

## 素材来源

- Kenney（CC0，可直接商用）：<https://kenney.nl/assets?q=audio>
- Freesound（CC0 / CC-BY，注意署名）：<https://freesound.org>
- Sonniss GDC 音频包（免费商用）：<https://sonniss.com/gameaudiogdc>
