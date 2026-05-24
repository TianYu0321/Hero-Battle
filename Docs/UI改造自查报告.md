# 局内UI改造 — 自查报告

## 已修复的 Bug

### 🔴 严重

| # | 问题 | 影响 | 修复方式 |
|---|------|------|---------|
| 1 | **VBoxContainer 不支持 `panel` 样式覆盖** | PlayerInfoPanel、EnemyInfoPanel、TrainingPanel 的羊皮纸背景完全不显示 | 改用 `top_level=true` 的 Panel 作为背景层，每帧同步位置/大小/modulate/visible |
| 2 | **`_on_node_options_presented` 中 `remove_theme_color_override("font_color")` 破坏了木牌按钮的墨水色文字** | 4个选项按钮文字颜色丢失，可能显示为白色/看不清 | 移除了这行代码，按钮颜色由 `_apply_wood_button_style` 统一管理 |
| 3 | **伙伴 slot hover tween 没有保存到 meta** | `_kill_slot_tween` 永远找不到旧 tween，快速 hover 时可能产生多个冲突动画 | hover enter/exit 时都 `set_meta("hover_tween", tween)` |
| 4 | **PauseMenu / OutingPopup 弹窗动画没有 tween 管理** | 快速反复打开/关闭时，多个 tween 并行播放导致动画错乱 | 添加 `_kill_panel_tween()` / `_kill_popup_tween()`，启动新动画前 kill 旧 tween |
| 5 | **羊皮纸背景层不跟随父容器的 modulate 和 visible** | 敌人信息面板半透明时，背景仍然不透明；面板隐藏时背景仍然显示 | 在 sync 回调中加入 `bg.modulate = container.modulate` 和 `bg.visible = container.visible`，并连接 `visibility_changed` 信号 |

### 🟡 中等

| # | 问题 | 影响 | 修复方式 |
|---|------|------|---------|
| 6 | **HUD 信息项 Label 文字和前缀重复** | 木牌前缀已显示"层数"，Label 还显示"层数: 3/30"，变成"层数 层数: 3/30" | `_update_hud()` 中去掉前缀，只显示数值（"3 / 30"） |
| 7 | **菜单按钮尺寸不一致** | 代码中 BUTTON_ICON_SIZE=44，tscn 中 offset 定义的是 40×40 | 统一 BUTTON_ICON_SIZE 为 40 |
| 8 | **旧版 RunMainSettings 常量残留引用** | `CORNER_POPUP` 在新版中已删除，pause_menu / outing_popup 中引用会导致编译错误 | 改为 `CORNER_PARCHMENT` |

### 🟢 轻微（未修复，影响极小）

| # | 问题 | 影响 |
|---|------|------|
| 9 | 动态创建的飘字/商店空提示 Label 没有可爱字体覆盖 | 使用默认字体，视觉上略有差异 |
| 10 | EventTagLabel（事件透视标注）没有可爱字体覆盖 | 使用默认字体 |
| 11 | combat_confirm_panel 退出动画和 option_container 显示有一帧重叠 | 视觉上 option_container 在 combat_confirm_panel 淡出时就已经出现 |
| 12 | `_transition_ui_state` 隐藏模态面板时不隐藏 ui_modal_blocker，依赖 `_process` 安全检测修复 | 有一帧 ui_modal_blocker 异常可见，但下一帧自动修复 |

---

## 文件改动清单

```
修改：
  scripts/core/run_main_settings.gd     — 勇者木调配色 + 程序化纹理 + StyleBox工厂
  scenes/run_main/run_main.gd           — +370行：HUD木条、木牌、羊皮纸背景、按钮样式、动画
  scenes/run_main/run_main.tscn         — HudContainer改PanelContainer+HBoxContainer，MenuButton改40x40
  scenes/menu/pause_menu.gd             — 羊皮纸弹窗 + 木牌按钮 + tween管理
  scenes/outing/outing_popup.gd         — 羊皮纸弹窗 + 木牌按钮 + tween管理

新建：
  scripts/core/run_main_settings.gd.uid
  docs/UI美术资源需求.md
  docs/UI改造自查报告.md
```

---

## 建议测试项

1. **进入爬塔主场景**：检查 HUD 木条、木牌信息项、菜单铁盾按钮是否显示正常
2. **点击4个选项按钮**：检查木牌样式、图标、hover效果
3. **点击战斗进入预览**：检查 combat_confirm_panel 的入场/退出动画
4. **点击暂停菜单**：检查羊皮纸弹窗、入场/退出动画、按钮样式
5. **获得伙伴后**：检查伙伴CHAIN条的舞台木纹背景、hover效果、充能闪烁
6. **金币变化**：检查金币木牌的弹跳动画
7. **快速反复 hover 伙伴 slot**：检查动画是否冲突
8. **快速反复打开/关闭暂停菜单**：检查动画是否冲突
