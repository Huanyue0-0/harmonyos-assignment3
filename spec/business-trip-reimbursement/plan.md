# 实施计划：差旅报销小程序（Assignment 3）

**输入**：功能规格 `spec/business-trip-reimbursement/spec.md`

## Summary

交付一个可编译、可运行的 HarmonyOS NEXT 6.0.1（API 21）差旅报销单页应用。采用作业强制的三模块结构：`products`（entry HAP，页面组装与 Ability）、`features`（HAR，业务视图、计算器/预览弹窗、ViewModel 编排）、`common`（HAR，领域模型、金额/计算服务、校验、本地草稿持久化）。

页面以 `List` 渲染完整表单，`Flex` 负责行内/响应式排版，根节点 `RelativeContainer` 负责计算器与预览弹窗的定位；表单状态由 `@Provide/@Consume` 跨模块共享，预览弹窗用 `@Link` 绑定，计算器内部状态用 `@State`。所有金额转换、运算、JSON 编解码、明细增删均包裹异常处理，所有可空访问使用 `?.`/`??`/`??=`。

## Technical Context

**Language/Version**：ArkTS / ArkUI 声明式范式，HarmonyOS 6.0.1（API 21），Stage 模型  
**Primary Dependencies**：`@kit.ArkUI`（mediaquery、promptAction via UIContext）、`@kit.ArkData`（preferences）、`@kit.AbilityKit`（Context/UIAbility）、`@kit.ArkTS`（util）、`@kit.PerformanceAnalysisKit`（hilog）；构建使用 hvigor（DevEco Studio 6.0.1 内置）  
**State Management**：状态管理 V1（作业显式要求 `@Provide/@Consume`、`@Link`、`@State`，因此不采用 V2；该偏离已由需求强制）  
**Storage**：`@ohos.data.preferences`（键值型，key `draft_form`，值为 JSON 字符串 + `savedAt`）  
**Testing**：`devecocli build` 编译校验 + `arkts_check` 静态语法检查 + 人工 UI 验证（当前无设备，截图由用户补齐）  
**Target Platform**：HarmonyOS 手机，竖屏/横屏自适应  
**Project Type**：mobile-app，多模块（1 个 HAP + 2 个 HAR）  
**Performance Goals**：列表 50 条明细内滚动流畅（目标 60fps）；启动到可交互 < 2s  
**Constraints**：纯离线、无权限申请、无网络；金额保留两位小数；所有异常必须被捕获并中文提示；严禁 `any`/`ESObject`/未类型化对象字面量  
**Scale/Scope**：单用户、单页面、单份草稿，约 16 个 ArkTS 源文件

## Project Structure

### Documentation (this feature)

```text
/Users/annya/Documents/ustc/harmonyOS/assignment3/spec/business-trip-reimbursement/
├── spec.md              # 功能规格（已完成）
├── plan.md              # 本文件
└── tasks.md             # Phase 3 生成
```

### Source Code (repository root)

```text
/Users/annya/Documents/ustc/harmonyOS/assignment3/
├── AppScope/
│   ├── app.json5
│   └── resources/base/{element/string.json, media/*}
├── common/                                  # HAR：领域与基础设施
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── oh-package.json5
│   ├── Index.ets                            # 统一导出（barrel）
│   └── src/main/
│       ├── module.json5                     # type: har
│       ├── ets/
│       │   ├── model/ReimbursementModels.ets   # ReimbursementForm / ExpenseItem / DraftRecord / OperationResult
│       │   ├── common/AppConstants.ets         # 存储键、费用类型、尺寸/颜色常量
│       │   ├── service/AmountUtil.ets          # 金额解析/格式化/合计（try/catch）
│       │   ├── service/CalculatorEngine.ets    # 表达式求值（优先级、除零/非法表达式）
│       │   ├── service/FormValidator.ets       # 必填/金额/日期区间校验
│       │   └── data/DraftRepository.ets        # preferences 读写 + JSON 编解码 + 校验
│       └── resources/base/element/string.json
├── features/                                # HAR：业务视图与编排
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── oh-package.json5                     # 依赖 @ohos/common
│   ├── Index.ets
│   └── src/main/
│       ├── module.json5                     # type: har
│       ├── ets/
│       │   ├── viewmodel/ReimbursementViewModel.ets  # 增删改、合计、校验、存取编排
│       │   ├── views/BasicInfoView.ets               # 基本信息（Flex 响应式）
│       │   ├── views/ExpenseListView.ets             # 添加行 + 明细列表（Flex 行内）
│       │   ├── views/CalculatorPopup.ets             # 计算器弹窗（@State 局部状态）
│       │   └── views/PreviewPopup.ets                # 预览弹窗（@Link 表单）
│       └── resources/base/element/string.json
├── products/                                # entry HAP：产品组装
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── oh-package.json5                     # 依赖 @ohos/common、@ohos/features
│   └── src/main/
│       ├── module.json5                     # type: entry, orientation: auto_rotation
│       ├── ets/
│       │   ├── productsability/ProductsAbility.ets
│       │   └── pages/Index.ets              # @Entry：@Provide 表单、List、Relative 弹窗层
│       └── resources/base/
│           ├── element/{string,color,float}.json
│           ├── media/*                      # 复用 DevEco 模板图标资源
│           └── profile/main_pages.json
├── hvigor/
│   └── hvigor-config.json5
├── screenshots/
│   └── README.md                            # 截图清单与命名（待用户补图）
├── docs/
│   ├── trace/skill-trace.log                # Agent 技能调用 Trace
│   ├── trace/summary.md                     # Trace 摘要
│   ├── audit/code_audit_report.json         # 四维审计 JSON
│   ├── audit/fix-list.md                    # 人工修复缺陷清单
│   └── report/Assignment3_报告.md / .docx    # 作业报告
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5
└── README.md
```

**Structure Decision**：选择 **MVVM** 分层，但按作业要求做“模块级边界”而非单模块目录堆叠。`products` 只做页面组装与 Ability；`features` 承载业务视图（views）与状态/事件编排（viewmodel）；`common` 承载模型（model）、服务（service）与持久化（data）。约 16 个 ArkTS 文件；相较单模块 MVVM 的 6–12 文件建议略多，原因是作业强制 `common/`、`features/`、`products/` 三个可编译模块，每个模块都需要独立的构建配置与导出入口，属于结构性必需而非过度拆分。遵循的是新工程 MVVM 分层，不迁移既有项目。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 3 个构建模块（common/features/products） | 作业“工程目录要求”明确列出这三个顶层目录，且要求可编译工程 | 单模块 + 顶层普通目录无法让 ArkTS 跨目录解析导入，且不符合目录评分项 |
| 状态管理 V1 而非 V2 | 作业强制 `@Provide/@Consume`、`@Link`、`@State` | 使用 V2 会直接不满足技术规范评分项 |
| 文件数 16 > MVVM 建议上限 12 | 三模块各自需要入口/构建文件，且计算器算法、校验、存储需独立可测单元 | 合并会破坏模块职责边界，降低可审计性 |

## Research & Decisions

### R1. 三模块依赖与构建配置

- **Decision**：`products` 为 entry HAP；`common`、`features` 为 HAR；`features` 依赖 `common`，`products` 同时依赖两者；根 `build-profile.json5` 注册三个模块并统一 `applyToProducts: ["default"]`。
- **Rationale**：与 DevEco 官方 “Flexible Layout” 多模块模板一致；HAR 通过 `file:` 依赖与 `useNormalizedOHMUrl: true` 正常解析 `@ohos/common` / `@ohos/features`。
- **Alternatives considered**：单 HAP + 顶层源码目录（跨模块相对导入不可用，不满足目录要求）；HSP 动态共享包（运行时共享，作业无动态加载需求，复杂度更高）。

### R2. 状态管理方案

- **Decision**：采用 V1；页面 `@Provide('reimbursementForm')` 持有 `ReimbursementForm` 实例，`BasicInfoView`/`ExpenseListView` 用 `@Consume` 读写；`PreviewPopup` 用 `@Link` 接收同一实例；`CalculatorPopup` 的表达式、显示、错误提示全部为自身 `@State`。
- **Rationale**：V1 对类实例的首层属性与数组赋值可观测；通过“替换数组/替换元素对象”而非深层原地修改来保证刷新，规避 V1 深层观测限制。
- **Alternatives considered**：V2 `@Provider/@Consumer/@Param`（作业不认可）；全局 `AppStorage`（不符合 `@Provide/@Consume` 评分点）。

### R3. 本地持久化

- **Decision**：使用 `preferences`，存储键 `draft_form`，值为 `{ "savedAt": number, "form": {...} }` 的 JSON 字符串；保存后 `flush()`；加载时严格校验字段并重建强类型模型。
- **Rationale**：轻量键值场景最合适；`flush()` 保证进程退出后仍可恢复（官方 FAQ 明确要求）；JSON 便于实现“序列化/解析 try/catch”评分点。
- **Alternatives considered**：`relationalStore`（单条草稿过重）；应用沙箱文件（需处理路径与清理，收益低）；`PersistentStorage`（无法体现 JSON 编解码异常）。

### R4. 计算器表达式求值

- **Decision**：自研 `CalculatorEngine`，分词后按“先乘除后加减”两遍扫描求值；支持一元负号、小数、连续运算符覆盖；除零与非法表达式抛出带中文消息的 `Error`，由 UI `try/catch` 转 Toast。
- **Rationale**：ArkTS 禁止 `eval`/`Function` 构造；自研引擎可精确控制异常语义并满足“捕获除零”评分点。
- **Alternatives considered**：逐键立即计算（无法回显完整表达式，退格语义差）；引入第三方表达式库（增加依赖与离线风险）。

### R5. 弹窗定位

- **Decision**：页面根节点为 `RelativeContainer`；表单 `List` 与两个弹窗层均为其子节点。弹窗层使用 `alignRules` 以 `__container__` 为锚点铺满并居中卡片，遮罩层拦截点击。
- **Rationale**：RelativeContainer 对“水平+垂直同时居中”需组合规则且易受 auto 尺寸影响；用全尺寸子层 + 内部居中列既满足“Relative 定位弹窗”的审计点，又保证横竖屏下稳定。
- **Alternatives considered**：`CustomDialog`/`bindPopup`（不满足 Relative 布局要求）；`Stack` 根节点（不满足 Relative 要求）。

### R6. 横竖屏适配

- **Decision**：`module.json5` 的 ability 配置 `"orientation": "auto_rotation"`；页面在 `aboutToAppear` 通过 `this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)')` 监听，`aboutToDisappear` 注销；`isLandscape` 通过 `@Prop` 下发给视图，控制 Flex 换行、字段宽度与弹窗最大宽度。
- **Rationale**：媒体查询是官方推荐的旋转监听方式，且能在不重建页面的情况下实时重排。
- **Alternatives considered**：仅依赖百分比宽度（横屏信息密度低、弹窗过宽）；`display.on('change')`（粒度偏设备级，页面内使用媒体查询更直接）。

### R7. 日期输入

- **Decision**：点击日期行调用 `this.getUIContext().showDatePickerDialog({ start, end, selected, onDateAccept })`，回填 `YYYY-MM-DD`。
- **Rationale**：系统组件交互一致、无需自造日历；`DatePickerDialog.show` 自 API 18 起废弃，UIContext 版本为推荐路径。
- **Alternatives considered**：纯文本输入（格式错误率高）；`CalendarPicker` 内联（占用表单空间）。

### R8. Toast 与日志

- **Decision**：提示统一走 `this.getUIContext().getPromptAction().showToast({ message, duration })`；关键异常用 `hilog.error` 记录，不向用户暴露堆栈。
- **Rationale**：避免 `promptAction` 全局导入歧义；通过 UIContext 获取实例在多模块下更稳定。
- **Alternatives considered**：`AlertDialog`（打断性强，不适合校验提示）；自绘 Toast（重复造轮子）。

### R9. JSON 解析的强类型化

- **Decision**：`JSON.parse(raw) as DraftRaw` 仅解析到“原始模型”，随后逐字段 `typeof` 校验并构造 `ReimbursementForm`/`ExpenseItem`；缺失或类型错误返回 `error` 状态并提示“历史数据已损坏”。
- **Rationale**：ArkTS 禁止 `any`/索引访问，必须先落到命名接口再校验；可同时覆盖“JSON 解析 try/catch”与“空安全”评分点。
- **Alternatives considered**：直接把 `JSON.parse` 结果断言为领域模型（运行期字段缺失会导致崩溃）；引入序列化库（依赖成本高）。

### R10. 验证与截图策略

- **Decision**：本阶段验证范围为 **build-only**：`arkts_check` + `devecocli build`；`screenshots/` 保留清单与占位说明，由用户在 DevEco Studio 连接设备后补图。
- **Rationale**：当前无已连接真机，且 devecocli 要求 DevEco ≥ 6.1.0 才能管理模拟器（本机 6.0.1）；强行 UI 验证不可行。
- **Alternatives considered**：升级 DevEco（用户未选择）；Previewer 截图（无法脚本化且非真机运行证据）。

## Data Model

### 实体与字段

| 实体 | 字段 | 类型 | 约束 |
|------|------|------|------|
| `ExpenseItem` | `id` | string | 非空，UUID |
| | `category` | string | 必填，取自固定枚举（交通/住宿/餐饮/通讯/其他） |
| | `date` | string | `YYYY-MM-DD` |
| | `amount` | string | 用户输入原文，提交时解析为 >0 的数字 |
| | `remark` | string | 可空（空串） |
| `ReimbursementForm` | `traveler` | string | 可空（作业未强制） |
| | `department` | string | 可空 |
| | `purpose` | string | **必填**，去除首尾空格后非空 |
| | `startDate` | string | `YYYY-MM-DD` |
| | `endDate` | string | `YYYY-MM-DD`，且 ≥ `startDate` |
| | `items` | `ExpenseItem[]` | 可为空；提交时至少 1 条 |
| `DraftRecord` | `savedAt` | number | 毫秒时间戳 |
| | `form` | `ReimbursementForm` | 保存时快照 |

### 派生与校验规则

- 合计金额 = 对所有 `items[].amount` 逐个 `try/catch` 解析后求和；解析失败按 0 计入并在提交校验中单独报错。
- 提交校验顺序：出差事由必填 → 至少一条明细 → 每条金额为 >0 的合法数字 → 起止日期合法；返回首个失败原因（含明细序号）。
- 保存前置：允许保存不完整草稿（这是“临时保存”的意义），仅要求可序列化。
- 加载后：所有字段回填；若条目金额无法解析，保留原文并在提交时提示。

### 状态转换

- `编辑中 → 临时保存`：写入 preferences，`savedAt` 更新，表单不变。
- `编辑中 → 预览`：只读快照视图，关闭后表单不变。
- `编辑中 → 提交成功`：清空为初始表单（保留 `newItem` 默认值），Toast 成功。
- `编辑中 → 提交失败`：表单不变，Toast 具体原因。
- `加载历史`：`success` 覆盖表单；`empty` 提示暂无；`error` 提示损坏/IO 失败，表单不变。

## Contracts & Interfaces

### 模块导出契约

- `common/Index.ets`
  - `export { ReimbursementForm, ExpenseItem, DraftRecord, OperationResult, DraftLoadResult, AmountResult }`
  - `export { AppConstants }`
  - `export { AmountUtil }`
  - `export { CalculatorEngine }`
  - `export { FormValidator }`
  - `export { DraftRepository }`
- `features/Index.ets`
  - `export { ReimbursementViewModel }`
  - `export { BasicInfoView, ExpenseListView, CalculatorPopup, PreviewPopup }`

### 服务接口契约

- `AmountUtil.parse(text: string): number`：去除空白与千分位后解析；空串/非法/`NaN`/`Infinity` 抛 `Error`。
- `AmountUtil.format(value: number): string`：保留两位小数；非有限值抛 `Error`。
- `AmountUtil.sumItems(items: ExpenseItem[]): number`：逐项 try/catch，非法项按 0。
- `CalculatorEngine.evaluate(expression: string): number`：空表达式/连续运算符/括号缺失/除零抛 `Error`；仅支持 `+ - × ÷ .` 与数字。
- `FormValidator.validate(form: ReimbursementForm): OperationResult`：返回 `{ success, message, field? }`。
- `DraftRepository.save(context: Context, form: ReimbursementForm): Promise<OperationResult>`。
- `DraftRepository.load(context: Context): Promise<DraftLoadResult>`，`status ∈ {success, empty, error}`。
- `ReimbursementViewModel.addItem(form, draftItem): OperationResult`：校验金额后追加并返回新数组。
- `ReimbursementViewModel.removeItem(form, id): OperationResult`。
- `ReimbursementViewModel.updateItemAmount(form, id, amountText): OperationResult`。
- `ReimbursementViewModel.total(form): number`。

### 组件属性契约（ArkUI）

- `BasicInfoView`
  - `@Consume('reimbursementForm') form: ReimbursementForm`
  - `@Prop isLandscape: boolean`
  - 回调：`onPickDate(field: string)`（由页面弹出日期选择器）
- `ExpenseListView`
  - `@Consume('reimbursementForm') form: ReimbursementForm`
  - `@Link newItem: ExpenseItem`
  - `@Prop isLandscape: boolean`
  - 回调：`onAddItem()`, `onDeleteItem(id: string)`, `onRequestCalculator(targetId: string)`（`''` 表示新增行）
- `CalculatorPopup`
  - `@State expression/display/error/justEvaluated`
  - 输入：`initialValue: string`, `visible: boolean`
  - 回调：`onConfirm(value: string)`, `onClose()`
- `PreviewPopup`
  - `@Link form: ReimbursementForm`
  - `@Prop isLandscape: boolean`
  - 回调：`onClose()`, `onSubmit()`
- 页面 `Index.ets`
  - `@Provide('reimbursementForm') form: ReimbursementForm`
  - `@State newItem: ExpenseItem`、`showCalculator`、`calcTargetId`、`showPreview`、`isLandscape`、`forceStorageError`

### 存储契约

- preferences 名称：`reimbursement_store`；键：`draft_form`。
- 值结构：`{"savedAt": number, "form": {"traveler": string, "department": string, "purpose": string, "startDate": string, "endDate": string, "items": [{"id": string, "category": string, "date": string, "amount": string, "remark": string}]}}`
- 读取到空值 → `empty`；JSON 解析失败/字段类型不符 → `error`；`flush` 抛错 → `error`。

### 审计报告契约（交付物）

- `docs/audit/code_audit_report.json` 顶层字段：`meta`、`compilationAudit`、`syntaxAudit`、`layoutAudit`、`businessAudit`、`summary`。
- 每个审计维度包含 `status: "pass" | "fail"`、`items[]`（`id`、`result`、`location`、`evidence`、`suggestion`）。
- `summary` 含四维通过数与总体结论，供报告第④章引用。
