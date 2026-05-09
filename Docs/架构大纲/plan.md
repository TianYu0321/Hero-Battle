# 云端集群 Agent — MVP 设计深化 执行计划

## 项目概述
基于《开发规格书_赛马娘版Q宠大乐斗.md》v1.0，将 Phase 1 MVP 范围的设计从"概念级"深化到"可实施级"，输出 7 份详细设计文档 + 1 份全局依赖总图。

## 核心约束
- **不写代码**，只做开发拆分
- **不脑补**，所有不明确内容列为 `[待确认]`
- **MVP 范围严格冻结**：3主角、6伙伴、30回合、7种节点类型

## 关键发现：缺失输入
- **基准规格书《开发规格书_赛马娘版Q宠大乐斗.md》v1.0 未提供**
- 任务卡多次引用规格书章节（2.2、2.3、4.1-4.6、5.1-5.4、6.1等）
- 所有依赖规格书具体数值/设计的内容将标注为 `[待确认]`

## 执行阶段

### Stage 1: 核心子系统设计（5个并行任务）
5个子agent同时工作，各自产出完整的设计文档：

| 子agent | 产出文件 | 内容 |
|---------|---------|------|
| 架构师 | `01_module_breakdown.md` | 模块拆分表 + 架构DAG + AutoLoad清单 |
| 数据设计师 | `03_data_schema.md` | Phase 1 最小数据表集(12-15张)的完整Schema |
| 战斗设计师 | `04_battle_engine_design.md` | 战斗状态机 + 行动顺序 + 伤害管道 + 援助/连锁/必杀技/敌人AI |
| 养成设计师 | `05_run_loop_design.md` | 30回合状态机 + 节点池 + 锻炼/商店/救援 + 终局结算 |
| 技术规范师 | `07_technical_spec.md` | 命名规范 + 代码组织 + 错误处理 + 性能约束 |

### Stage 2: 接口与UI设计（2个并行任务，依赖Stage 1）
2个子agent并行，读取Stage 1产出完成：

| 子agent | 产出文件 | 依赖 |
|---------|---------|------|
| 接口设计师 | `02_interface_contracts.md` | Stage 1全部产出 |
| UI设计师 | `06_ui_flow_design.md` | Stage 1的模块拆分 + 状态机设计 |

### Stage 3: 全局汇总
由主agent整合所有产出，生成：
- `summary_dependency_graph.md` - 全局依赖总图

## 交付物清单
1. `01_module_breakdown.md` — 模块拆分与系统架构
2. `02_interface_contracts.md` — 接口契约与信号总线
3. `03_data_schema.md` — 数据表 Schema
4. `04_battle_engine_design.md` — 自动战斗引擎设计
5. `05_run_loop_design.md` — 30回合养成循环设计
6. `06_ui_flow_design.md` — UI流程与场景清单
7. `07_technical_spec.md` — 技术规范与开发约束
8. `summary_dependency_graph.md` — 全局依赖总图
