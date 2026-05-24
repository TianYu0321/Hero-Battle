# 局内UI美术资源需求文档
## 勇者奇幻风格 — 冒险者公会木牌 + 羊皮纸 + 蜡封

---

## 一、纹理类资源

### 1. 木纹背景板（HUD / 按钮 / 弹窗底板）
**用途**：顶部HUD木条、选项按钮木牌、弹窗底板、伙伴CHAIN条背景  
**尺寸**：512×512px（无缝平铺）  
**风格**：手绘、Q版2D、奇幻RPG  
**提示词**：
```
A seamless hand-painted wood plank texture, 
fantasy RPG style, warm brown tones (#4A3428 to #A17352), 
visible wood grain and knots, slightly weathered adventurer's guild feel, 
cartoon Q-version 2D style, tileable, 512x512px
```
**交付格式**：PNG，透明通道不需要（底图用）

---

### 2. 羊皮纸/卷轴纹理
**用途**：主角属性面板背景、弹窗内容区背景、训练面板背景  
**尺寸**：512×512px（无缝平铺）  
**风格**：手绘、 aged parchment、边缘烧焦  
**提示词**：
```
A hand-painted parchment paper texture, aged yellow-cream color (#F5E6C8), 
slightly burnt and curled edges, ink stains and subtle creases, 
fantasy adventure bulletin board feel, cartoon Q-version 2D style, 
tileable, 512x512px
```
**交付格式**：PNG

---

### 3. 深色木纹（标题栏 / 重型木牌）
**用途**：HUD顶部主横条、弹窗标题栏底板、重要按钮底板  
**尺寸**：256×256px（无缝平铺）  
**风格**：更深沉的棕木色、厚实感  
**提示词**：
```
A seamless dark wood plank texture, deep brown (#3E2723 to #5D4037), 
thick wooden board feel, heavy grain, iron nail holes, 
fantasy tavern counter style, cartoon Q-version 2D, tileable, 256x256px
```
**交付格式**：PNG

---

## 二、图标类资源

### 4. 勇者主题功能图标集（16个）
**用途**：替换当前所有 Emoji 占位图标  
**尺寸**：64×64px 每个  
**风格**：手绘、Q版、棕金色调  
**需求清单**：

| 编号 | 图标名 | 用途 | 提示词方向 |
|------|--------|------|-----------|
| 01 | 城堡/层数 | HUD层数木牌 | small castle tower, brown stone |
| 02 | 金币袋 | HUD金币木牌 | leather coin pouch, gold coins spilling |
| 03 | 红心/生命 | HUD生命木牌 | red heart with wooden frame |
| 04 | 肌肉/体魄 | 属性面板 | flexing arm, strength symbol |
| 05 | 交叉剑/力量 | 属性面板 | two crossed swords |
| 06 | 风/敏捷 | 属性面板 | swift wind lines, speed symbol |
| 07 | 靶心/技巧 | 属性面板 | arrow hitting bullseye |
| 08 | 水晶球/精神 | 属性面板 | glowing crystal ball, magic |
| 09 | 哑铃/训练 | 选项按钮 | wooden dumbbell, training gear |
| 10 | 长剑/战斗 | 选项按钮 | iron sword, combat ready |
| 11 | 床铺/休息 | 选项按钮 | simple bedroll, campfire nearby |
| 12 | 大门/外出 | 选项按钮 | wooden dungeon door, adventure awaits |
| 13 | 齿轮/设置 | 菜单按钮 | iron gear, mechanical |
| 14 | 卷轴/任务 | 弹窗装饰 | rolled parchment with red ribbon |
| 15 | 蜡封/印章 | 弹窗标题 | red wax seal with crown emblem |
| 16 | 星标/等级 | 头像框旁 | golden star badge, level up |

**通用提示词**：
```
A set of 16 hand-drawn fantasy RPG UI icons,
warm brown and gold color palette (#D4A574, #D4AF37),
cartoon Q-version 2D style, thick outlines,
64x64px each, transparent background, clean edges for game use
```
**交付格式**：PNG 序列帧或单图合批（带坐标清单）

---

### 5. 木牌装饰元素图集
**用途**：木牌的四角铁钉、顶部悬挂绳索、边缘装饰  
**尺寸**：64×64px 每个元素  
**需求清单**：

| 元素 | 描述 |
|------|------|
| 铁钉A | 圆形铁铆钉，俯视图 |
| 铁钉B | 方形铁钉头，带锈迹 |
| 绳索环 | 顶部悬挂用绳圈 |
| 木牌左角 | 不规则木片缺口（破损感） |
| 木牌右角 | 不规则木片缺口 |
| 蜡烛滴蜡 | 木牌边缘的蜡滴装饰 |

**提示词**：
```
A sprite sheet of wooden sign decorations,
including iron nails, rope hangers, corner brackets, wax drips,
fantasy RPG tavern/quest board style,
warm wood and iron colors, cartoon Q-version 2D,
transparent background, each element 64x64px
```
**交付格式**：PNG 精灵图（spritesheet）或独立文件

---

## 三、头像框类资源

### 6. 圆形木质肖像框
**用途**：主角属性面板头像、伙伴CHAIN条头像  
**尺寸**：256×256px（外框），内圆直径约 180px  
**风格**：厚重木框 + 四角铁钉  
**提示词**：
```
A circular wooden portrait frame,
thick bark texture with iron studs on four corners,
inner area transparent/cutout for character portrait,
fantasy wanted poster style, cartoon Q-version 2D,
256x256px, transparent background
```
**交付格式**：PNG（中心透明）

---

### 7. 方形木质肖像框（伙伴用）
**用途**：伙伴CHAIN条小头像框  
**尺寸**：128×128px  
**风格**：轻巧小木框，顶部有挂孔  
**提示词**：
```
A small square wooden picture frame,
light oak texture, tiny nail hole at top center for hanging,
inner area transparent for portrait,
cartoon Q-version 2D, 128x128px, transparent background
```
**交付格式**：PNG（中心透明）

---

## 四、背景氛围类（可选升级）

### 8. 卷轴展开装饰条
**用途**：弹窗顶部/底部的卷轴轴（木棒+两端圆头）  
**尺寸**：1024×64px（横向可拉伸）  
**提示词**：
```
A horizontal wooden scroll rod,
dark wood cylinder with round decorative ends,
fantasy spell scroll style, cartoon Q-version 2D,
1024x64px, transparent background, center area stretchable
```

---

## 五、交付规范

1. **命名规范**：`ui_{category}_{name}_{size}.png`
   - 例：`ui_texture_wood_light_512.png`
   - 例：`ui_icon_gold_64.png`
   - 例：`ui_frame_portrait_round_256.png`

2. **存放路径**：`assets/ui/adventurer_guild/`
   - `/textures/` — 纹理资源
   - `/icons/` — 图标资源
   - `/decorations/` — 装饰元素
   - `/frames/` — 头像框

3. **透明背景**：所有非纹理类资源需带透明通道（PNG）

4. **风格统一**：所有资源使用同一套棕-金-红配色，保持手绘Q版质感一致
