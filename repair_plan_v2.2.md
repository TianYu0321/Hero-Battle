# 修复方案 v2.2 — 最优解耦设计

> 原则: 不选最快的，只选最好的。注重解耦、可维护、可扩展。

## 7个残留问题

| # | 问题 | 最优方案 | 解耦策略 |
|:--:|------|----------|----------|
| 1 | PVP惩罚残留 | 策略模式: IPVPPenaltyStrategy | 惩罚逻辑从PvpDirector完全抽离 |
| 2 | 终局Boss固定 | 配置驱动: FinalBossPool | Boss池从配置读取，RunController零硬编码 |
| 3 | 局外商店 | 完整MVC: OutgameShopSystem+UI | 与局内商店完全分离，独立生命周期 |
| 4 | 预计损失血量 | 计算器+观察者: DamagePredictor | 纯函数计算，无副作用，UI自动刷新 |
| 5 | 行动顺序改speed | 属性接口: IAttributeProvider | ActionOrder依赖接口而非具体属性 |
| 6 | Lv3/Lv5质变 | 事件驱动: SkillMilestoneSystem | 等级变更事件→自动触发技能升级 |
| 7 | 删除patch文件 | git rm | 无影响 |

## 依赖关系

```
P7(删除patch) ──→ 独立
P5(speed属性) ──→ 影响P4(预计血量) ──→ 影响P2(Boss随机)
P1(PVP惩罚) ──→ 独立
P3(局外商店) ──→ 独立
P6(Lv3/Lv5) ──→ 依赖P5(属性系统)
```

## Worker分配

- Worker A: P7+P1+P5 (基础设施+PVP+属性)
- Worker B: P2+P4+P6 (终局+Boss+质变)
- Worker C: P3 (局外商店)
