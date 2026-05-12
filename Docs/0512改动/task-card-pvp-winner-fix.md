# Bug修复任务卡：PVP胜负判定反转

---

## 根因

`pvp_director.gd` 第44行，胜负判定逻辑写反了：

```gdscript
# 错误代码：
var player_won: bool = (battle_result.winner == "enemy")
```

`battle_result.winner` 的语义：
- `"player"` = 玩家英雄获胜
- `"enemy"` = 敌人获胜

当前代码把两者完全颠倒：
- 玩家打赢AI → `winner == "player"` → `player_won = false`（误判为输）
- 玩家输给AI → `winner == "enemy"` → `player_won = true`（误判为赢）

## 修复

**文件：`scripts/systems/pvp_director.gd`**

第44行改为：

```gdscript
var player_won: bool = (battle_result.winner == "player")
```

---

## 验证

改完后测试：

1. **打赢PVP**：
   - `winner == "player"` → `player_won = true`
   - RunController 走胜利分支：`金币+150，全属性+15`
   - **不应有透视+5**

2. **打输PVP**：
   - `winner == "enemy"` → `player_won = false`
   - RunController 走失败分支：`金币+50，全属性+5，透视+5`
   - 走5层后消耗完毕，标注消失

---

## 文件修改清单

| # | 文件 | 修改内容 |
|:---:|:---|:---|
| 1 | `scripts/systems/pvp_director.gd` | 第44行：`== "enemy"` → `== "player"` |
