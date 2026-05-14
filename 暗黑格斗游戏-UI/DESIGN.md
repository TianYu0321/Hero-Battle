---
version: alpha
name: Dark Fighting Game UI
---

## Overview
暗黑格斗游戏 PVP 对战大厅 UI，包含顶部 HUD（双角色血条、能量条、名字、回合/VS 装饰）、中段对战舞台（风格化 SVG 角色立绘 + 中央信息卡 + 浮动暴击数字）和底部战斗日志面板（实时记录 + 操作按钮）。整体采用暗黑霓虹（红/蓝/暗金）配色，带噪点纹理、网格透视地面与角标装饰。

## Colors
- `bg-0`: oklch(0.10 0.025 290) — 最深层背景
- `bg-1`: oklch(0.14 0.04 295) — 面板背景
- `bg-2`: oklch(0.18 0.06 300) — 高亮背景
- `ink-0`: oklch(0.94 0.015 280) — 主文字
- `ink-1`: oklch(0.74 0.03 280) — 次要文字
- `ink-2`: oklch(0.52 0.04 285) — 辅助/标签文字
- `line`: oklch(0.32 0.04 290) — 边框
- `line-soft`: oklch(0.24 0.03 290) — 弱边框
- `red`: oklch(0.66 0.22 25) — 红方主题
- `red-bright`: oklch(0.74 0.21 30) — 红方高亮
- `red-deep`: oklch(0.32 0.14 22) — 红方深色
- `blue`: oklch(0.74 0.16 230) — 蓝方主题
- `blue-bright`: oklch(0.82 0.16 225) — 蓝方高亮
- `blue-deep`: oklch(0.30 0.10 240) — 蓝方深色
- `gold`: oklch(0.82 0.16 78) — 暗金强调
- `gold-dim`: oklch(0.55 0.12 75) — 暗金弱色
- `crit`: oklch(0.88 0.18 70) — 暴击伤害色

## Typography
- 展示/标题：Cinzel（权重 600、800），中文回退 Noto Serif SC
- 数字/数据：Oxanium（权重 500、700、800），中文回退 Noto Sans SC
- 中文正文：Noto Sans SC（权重 400、500、700、900）
- 西文回退：system-ui, sans-serif

## Rounded
- 极少圆角：偏切割多边形（clip-path）设计
- 仅徽标/头像内部元素使用 2px 或 50% 圆角

## Spacing
- 页面内边距：26px（桌面端）/ 12px（移动端）
- 组件间基准 gap：8–14px
- 血条高度：22px / 能量条：6px
- 日志行高：1.5
