# Bug #002: config_manager.gd 遗漏 `_pvp_opponent_configs` 类变量声明

**发现时间**: 2026-05-09  
**发现方式**: Godot 编译报错  
**错误信息**: `Identifier "_pvp_opponent_configs" not declared in the current scope.`  
**错误位置**: `res://autoload/config_manager.gd` (在 `_load_all_configs()` 方法中)

---

## 问题描述

在 `_load_all_configs()` 方法中，代码直接对 `_pvp_opponent_configs` 进行赋值操作：
```gdscript
_pvp_opponent_configs = _load_json("pvp_opponent_templates")
```

但 `_pvp_opponent_configs` 从未在类级别声明为成员变量。GDScript 中，如果在方法中首次使用一个标识符进行赋值，它会尝试创建局部变量。但此处上下文表明它应该是一个类级别的配置缓存字典。

## 根因分析

Phase 2 Task A（PVP 系统）在 `config_manager.gd` 中新增了对 `pvp_opponent_templates.json` 的加载逻辑，但遗漏了在类变量声明区添加对应的字段。

## 修复措施

在 `config_manager.gd` 的类变量声明区补充：
```gdscript
var _pvp_opponent_configs: Dictionary = {}
```

## 修复后验证

Godot 编译通过，`_load_all_configs()` 成功加载 PVP 对手模板配置。

---

## 预防措施

- **新增 ConfigManager 配置加载前**，先在类变量声明区确认是否已添加对应字段
- 参考 Bug #001 的同类预防措施
