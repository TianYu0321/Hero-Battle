# Bug #003: event_bus.gd 中 `node_selected` 信号重复声明

**发现时间**: 2026-05-09  
**发现方式**: 代码审查（Phase 1 遗留架构缺口排查）  
**错误位置**: `res://autoload/event_bus.gd` 第22行和第91行

---

## 问题描述

在 `event_bus.gd` 中，`node_selected` 信号被声明了两次：

- **第1处**（养成循环信号区，第22行）: `signal node_selected(node_index: int)`
- **第2处**（UI控制信号区，第91行）: `signal node_selected(node_index: int)`

这两处声明的签名完全一致，会导致 Godot 编译报错 `Signal "node_selected" has the same name as a previously declared signal.`。

这与 Bug #001（`archive_saved` 重复声明）属于同一类问题，是在不同开发阶段分块添加信号时未做全局查重导致的。

## 根因分析

Phase 1 开发时，`node_selected` 作为 UI 交互信号被添加在 UI 控制信号区（第91行附近）。后续在整理养成循环信号时，又将其归入养成循环生命周期信号区（第22行附近），但未删除原有的声明。

## 修复措施

**删除**第91行（UI控制信号区）的重复声明，**保留**第22行（养成循环信号区）的声明。理由：`node_selected` 是养成循环核心信号（RunController → UI），归类在养成循环信号区更合理。

```gdscript
# 删除以下行（原第91行）:
signal node_selected(node_index: int)
```

## 修复后验证

```bash
grep -n "node_selected" autoload/event_bus.gd
# 输出: 22:signal node_selected(node_index: int)
# 仅出现一次
```

---

## 预防措施

- 参考 Bug #001 的预防措施：新增 EventBus 信号前，务必先全文搜索确认是否已存在
