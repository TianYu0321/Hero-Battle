# Hero Character Sprite Prompts

本文档用于处理 `assets/characters/hero/saber` 下的角色素材，并以 `assets/characters/hero/shinobi` 的动作规格作为基准。目标是得到可直接用于 Godot 的透明 PNG 角色动作图，同时保留刀光、魔法光、粒子、冲击波等战斗特效。

## 基准规格

- 美术方向：日式 RPG 勇者冒险，Q 版二头身到三头身，清晰赛璐璐上色，干净轮廓线，高可读性。
- 画面用途：2D 游戏角色动作素材，透明背景 PNG，不包含 UI、文字、水印、地面、场景背景。
- 角色定位：Saber，银白长发，白银铠甲，金色纹饰，蓝色宝石，金色长剑，英气但可爱。
- 视角方向：与 shinobi 一致，角色整体偏侧向，适合横版战斗展示。
- 普通动作尺寸：`600x480`。
- 宽幅技能尺寸：`skill1_01-3` 使用 `1000x480`。
- 安全边距：角色和特效不要贴边，剑尖、披风、刀光不可被裁切。

## 现有图片修图提示词

用于图生图或 AI 修图，输入为 saber 目录下现有图片。

```text
Edit this image into a clean 2D JRPG chibi hero battle sprite for a Godot game.
Remove the green-screen background, baked checkerboard background, scenic background, ground, shadows, and any rectangular backdrop.
Preserve the original character design, pose, sword, armor, white hair, cape, golden slash trails, holy light beams, glow, particles, and magic effects.
Keep all combat VFX attached to the character and do not simplify the effects.
Output a transparent-background PNG sprite, crisp cel-shaded anime style, clean alpha edges, no green spill, no checkerboard pattern, no text, no watermark.
Keep the full character and all effects inside the canvas without cropping.
```

## Saber 统一角色提示词

作为每个动作提示词的公共前缀。

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
```

## 动作提示词

### idle / `saber_idle_01.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Idle ready stance, side-facing battle pose, sword held calmly in front, cape and long hair resting naturally, confident blue eyes, no attack effects, centered composition, full body inside a 600x480 canvas.
```

### attack / `saber_attack_01.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Fast forward sword slash, dynamic side-facing pose, golden crescent slash trail following the sword, hair and cape swept by motion, bright particles around the blade, full body and slash effect inside a 600x480 canvas.
```

### hit / `saber_hit_01.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Damaged recoil pose, small impact sparks near armor, sword pulled close defensively, expression briefly pained but still brave, cape and hair disturbed by the hit, no blood, full body inside a 600x480 canvas.
```

### skill1 start / `saber_skill1_01-1.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Skill startup pose, sword drawn upward with a golden magic circle and small holy runes, controlled bright glow around the blade, hair and cape lifting slightly, full body and effect inside a 600x480 canvas.
```

### skill1 slash / `saber_skill1_01-2.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Advancing sword technique, powerful diagonal slash with layered blue and gold blade trails, cape streaming backward, bright particles following the sword path, full body and effect inside a 600x480 canvas.
```

### skill1 wide slash / `saber_skill1_01-3.png` / `1000x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Wide dash-slash finisher, character placed slightly left of center, long horizontal blue-gold crescent slash sweeping across the canvas, strong motion line readability, full character and full slash arc inside a 1000x480 canvas.
```

### skill2 charge / `saber_skill2_01.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Ultimate skill charge, sword raised vertically, compact holy light beam descending onto the blade, golden aura bursting at the feet, radiant particles, preserve the bright beam and aura but keep everything inside a 600x480 canvas.
```

### skill2 release / `saber_skill2_02.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Ultimate skill release, stronger holy sword light and golden explosion aura, larger but readable magic burst, blue-white core light with golden edges, full body visible, no cropped beam, full effect inside a 600x480 canvas.
```

### victory / `saber_victory_01.png` / `600x480`

```text
JRPG brave hero chibi battle sprite, silver-white long-haired Saber knight, white and silver plate armor with gold trim, small blue gemstone accents, golden longsword, heroic but cute expression, clean anime cel shading, crisp dark outline, high readability for a 2D game, transparent-background PNG, no scenery, no ground, no UI, no text, no watermark.
Victory pose, calm smile, sword planted or held upright, cape resting gracefully, subtle golden sparkle particles only, no scenic background, no ground, full body inside a 600x480 canvas.
```

## 负面提示词

```text
background, green screen in final image, checkerboard pattern, scenic landscape, floor, ground, shadow blob, UI frame, text, watermark, logo, cropped sword, cropped hair, cropped VFX, missing slash trail, missing particles, extra weapon, extra limb, realistic photo style, 3D render, low-resolution blur, muddy outline, dark fantasy horror tone.
```

## 当前素材处理建议

- `idle`、`attack`、`hit`、`skill1_01-1`、`skill1_01-2`、`skill1_01-3` 可以优先使用本地抠图输出。
- `skill2_01`、`skill2_02` 的源图包含烘焙黑白棋盘背景，本地规则可以减轻但难以无损清理，推荐使用上面的 `skill2` 提示词重新生成或 AI 修图。
- `victory` 的源图包含完整场景背景，不是绿幕素材，推荐用 `victory` 提示词重新生成透明 PNG。
- `shinobi` 现有图只需要做 alpha 边缘清理和少量去绿边，不建议改变角色姿态或特效。
