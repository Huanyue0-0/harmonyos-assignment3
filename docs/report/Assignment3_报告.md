# 基于 Agent 的 HarmonyOS 差旅报销应用开发报告

**课程**：HarmonyOS 应用开发  
**作业**：Assignment 3 — 差旅报销小程序  
**技术栈**：HarmonyOS NEXT 6.0.1（API 21）· Stage 模型 · ArkTS/ArkUI · 状态管理 V1  
**工程根目录**：`/Users/annya/Documents/ustc/harmonyOS/assignment3`

---

## 第一章 设计思路

### 1.1 需求拆解

作业要求一个「单机差旅报销」应用，核心链路是：**录入基本信息 → 维护费用明细 → 计算金额 → 预览 → 提交 → 可临时保存**。围绕这条链路，我把需求拆成五个可独立验证的用户故事，并按优先级递增实现：

| 故事 | 内容 | 优先级 | 独立验收标准 |
|------|------|--------|--------------|
| US1 | 基本信息 + 费用明细动态增删 + 实时合计 | P1（MVP） | 填事由 → 加 3 条 → 删 1 条 → 合计正确 |
| US2 | 弹窗计算器计算并回填 | P2 | 100 ÷ 4 = 25 → 确定 → 金额框 25.00；5 ÷ 0 提示不崩溃 |
| US3 | 预览 + 提交校验 + 成功清空 | P3 | 缺事由提示且不清空；完整表单提交后清空 |
| US4 | 临时保存 / 历史加载 | P4 | 保存→改→加载→数据恢复；空/损坏/IO 异常均提示 |
| US5 | 横竖屏自适应 | P5 | 旋转后字段、按钮、弹窗完整可见 |

### 1.2 架构：三模块 + MVVM

作业硬性要求顶层 `common/`、`features/`、`products/` 三个可编译模块。我把 MVVM 的"分层"落在**模块边界**上，而不是单模块内的目录堆叠：

```text
products (entry HAP)        页面组装 + UIAbility
      │  依赖
      ├──────────────► features (HAR)        视图 + ViewModel 编排
      │                      │  依赖
      │                      ▼
      └──────────────► common  (HAR)         模型 + 服务 + 持久化
```

- **common（HAR）**：不依赖任何 UI，只放领域模型、常量、金额/计算/校验服务、preferences 仓储。这一层可以被单元测试直接覆盖，也是「金额、计算、JSON 必须 try/catch」这一评分点的唯一落点。
- **features（HAR）**：业务视图与编排。4 个视图组件 + 1 个 ViewModel。视图只负责采集与展示，一切"要不要加、能不能提交、失败说什么"都交给 ViewModel / Validator。
- **products（entry HAP）**：只做页面组装（`@Entry`、`@Provide`、路由式弹层）与 Ability 配置。它不含业务规则，换一个产品形态时可以整体替换。

这样拆的收益是：**改业务规则只动 common，改交互只动 features，改壳层只动 products**；代价是每个 HAR 都要独立构建配置与导出入口（barrel），文件数比单模块 MVVM 多，但这是作业目录要求在工程上的必然结果。

### 1.3 状态管理选型（V1，强制）

作业明确要求 `@Provide/@Consume`、`@Link`、`@State`，因此**不采用 V2**（V2 的 `@Provider/@Consumer` 在评分点上不成立）。V1 的关键约束是"只观测浅层"，所以我做了一次刻意的观测粒度设计：

| 数据 | 装饰器 | 刷新机制 |
|------|--------|----------|
| 报销单整体（`ReimbursementForm`） | 页面 `@Provide('reimbursementForm')` | 属性赋值（`form.purpose = ...`）触发订阅者刷新 |
| 基本信息 / 明细区读取表单 | 子组件 `@Consume('reimbursementForm')` | 同上，跨模块共享同一实例 |
| 预览弹窗 | `@Link form: ReimbursementForm` | 双向绑定同一实例，只读展示，关闭不丢数据 |
| 新增行草稿 | 页面 `@State newItem` + 子组件 `@Link` | 添加成功后整体替换为新的草稿对象 |
| 单条明细 | `@Observed ExpenseItem` + 行组件 `@ObjectLink` | 计算器回填/改金额时**只刷新目标行** |
| 计算器内部 | `@State expression / display / errorText / justEvaluated` | 组件局部状态，关闭即销毁 |

其中最容易踩坑的是明细行：V1 的 `ForEach` 在 key 不变时**不会重建子组件**，因此"把数组元素换成一个新对象"并不会让行内容刷新。解决方案是让明细对象 `@Observed`、行组件 `@ObjectLink`，回填时**就地更新目标对象的字段**（触发 `@ObjectLink`），同时把 `form.items` 换成新数组（触发依赖数组的合计与条数刷新）。这一点在代码与审计报告（B-07）里都做了显式说明，避免后续维护者改回"新建对象"而引入不刷新缺陷。

### 1.4 布局策略

作业要求"页面用 `List`、行内用 `Flex`、弹窗用 `RelativeContainer`"，三者各司其职：

- **根 `RelativeContainer`**：页面唯一根容器，承载「主内容 Column + 计算器弹层 + 预览弹层」三个兄弟层。
- **`List`**：表单主体（基本信息卡、明细卡、底部留白）。滚动、边缘回弹交给 List 自身。
- **`Flex`**：所有行内排版。响应式的关键就是 `FlexWrap.Wrap` + 百分比宽度（横屏 48%/24%，竖屏 100%/48%）。
- **弹窗**：不用 `CustomDialog`，而是"全尺寸遮罩 + 居中卡片"。遮罩是 `100% × 100%` 的 Column，点击关闭；卡片用 `alignRules` 以 `__container__` 为锚点同时做垂直居中（`center`）与水平居中（`middle`）。这样弹窗天然占据整个页面坐标系，横竖屏切换时只需调整卡片宽度上限，不需要重算定位。

### 1.5 健壮性设计

作业的"异常场景 100% 有中文提示且不崩溃"是硬指标，我按"可能出错的四类操作"分别设防：

1. **金额**：字符串原文保存，解析时先归一化（全角数字、千分位逗号、全角小数点），再逐字符校验字符集，`NaN`/`Infinity` 显式拒绝；合计时**先转「分」做整数累加**，避免 `0.1 + 0.2` 类误差。
2. **计算**：自研 `CalculatorEngine`（ArkTS 禁止 `eval`），分词 + 两遍扫描（先乘除后加减），除零、尾随运算符、多小数点、非法字符都抛中文 `Error`，由 UI 捕获成 Toast 且**保留原输入**。
3. **JSON**：`JSON.parse` 只落到带可选字段的 `DraftRaw` 原始接口，随后逐字段 `typeof` 校验，任何缺失/类型不符返回 `error` 状态，页面**只在 success 时覆盖表单**。
4. **IO**：`preferences` 读写全程 `try/catch`，保存后强制 `await flush()`（官方 FAQ 明确：不 flush 可能只在内存里）。

---

## 第二章 核心模块说明

### 2.1 领域模型（`common/src/main/ets/model/ReimbursementModels.ets`）

```ts
@Observed
export class ExpenseItem {
  id: string; category: string; date: string; amount: string; remark: string;
  constructor(id, category, date, amount, remark) { /* ... */ }
  static createDraft(): ExpenseItem        // 新增行默认值：类别=交通，日期=今天
  copy(): ExpenseItem                      // 深拷贝
}

export class ReimbursementForm {
  traveler / department / purpose / startDate / endDate / items
  static createEmpty(): ReimbursementForm  // 空表单工厂（日期默认今天）
  copy() / applyFrom() / reset()           // 快照、整体覆盖（保持实例引用）、清空
  findItemById(id) / replaceItem(updated) / removeItemById(id) / appendItem(item)
}
```

设计要点：

- `ExpenseItem` 标注 `@Observed`，是明细行粒度刷新的前提；
- 所有"修改集合"的方法都**返回新数组**，由调用方赋值给 `form.items`——这是 V1 下通知列表/合计刷新的最小代价方案；
- `applyFrom` / `reset` 都**保持实例引用**，因为 `@Provide`/`@Consume`/`@Link` 绑定的是实例，整体替换对象会让绑定失效。

此外还有 `DraftRecord`（保存快照）、`OperationResult`（`success/message/field`）、`DraftLoadResult`（`status: DraftStatus + message + form + savedAt` 三态）。

### 2.2 金额服务（`AmountUtil`）

| 方法 | 语义 | 异常行为 |
|------|------|----------|
| `normalize(text)` | 全角→半角、去空白、去千分位 | 内部 try/catch，失败返回 `''` |
| `isNumeric(text)` | 允许一个前导正负号 + 一个小数点 | 返回 boolean |
| `parse(text)` | 文本 → number | 空/非法/NaN/Infinity 抛中文 `Error` |
| `toCents(text)` | 文本 → 整数分 | 同上 |
| `format(value)` | → `toFixed(2)` | 非有限值抛错 |
| `formatCompact(value)` | 最多 6 位小数、去尾零（计算器显示） | 同上 |
| `sumItems(items)` | 逐条解析后**以分为单位累加**，非法项计 0 | 不抛错（校验阶段单独报错） |
| `sumText(items)` | 合计的两位小数文本 | 异常兜底 `'0.00'` |

### 2.3 计算引擎（`CalculatorEngine`）

自研三段式：`normalize`（× ÷ − 归一为 `* / -`、全角数字转换）→ `tokenize`（数字 / 运算符 token，支持一元负号和"单个数字只能有一个小数点"）→ `evaluate`（第一遍折叠乘除、第二遍加减）。

```ts
evaluate('100÷4')  → 25
evaluate('−3+5')   → 2
evaluate('5÷0')    → throw new Error('除数不能为 0')
evaluate('1++2')   → throw new Error('运算符位置错误，请检查表达式')
evaluate('5÷')     → throw new Error('表达式不完整，请检查运算符')
```

### 2.4 校验器（`FormValidator`）

严格按作业要求的顺序，返回**首个**失败原因（带 `field` 定位，如 `items.2.amount`）：

1. 出差事由 `trim()` 后非空 → 否则「请填写出差事由」
2. 至少一条明细 → 否则「请至少添加一条费用明细」
3. 逐条金额可解析且 `> 0` → 否则「第 N 条明细金额必须大于 0」
4. 起止日期格式合法且 `end >= start` → 否则「结束日期不能早于开始日期」

### 2.5 持久化（`DraftRepository`）

```text
保存：encode(form) → JSON 字符串 → preferences.put('draft_form', json) → await flush()
读取：preferences.get('draft_form', '')
        ├─ 空串            → EMPTY  「暂无历史数据」
        ├─ JSON.parse 失败 → ERROR  「历史数据已损坏（JSON 解析失败），已保留当前表单」
        └─ 字段 typeof 不符→ ERROR  「历史数据已损坏（第 N 条明细字段类型不符）」
```

写入侧用 `DraftRawPayload`（字段必填）保证序列化结构稳定；读取侧用 `DraftRaw/FormRaw/ExpenseRaw`（字段全可选）配合逐个 `typeof` 校验重建领域对象——这是 ArkTS 禁用 `any` 与下标访问后的标准做法。

### 2.6 ViewModel（`ReimbursementViewModel`）

业务规则集中地，全部静态方法，返回 `OperationResult`/`DraftLoadResult`，不抛异常给视图：

| 方法 | 规则 |
|------|------|
| `addItem(form, draft)` | 金额必填 → 可解析 → `>0` → 日期/类别非空 → 入库（格式化为两位小数字符串）→ 返回「已添加 1 条费用明细」 |
| `removeItem(form, id)` | 必须存在该明细，否则提示「未找到要删除的明细」 |
| `updateItemAmount(form, id, text)` | 计算器回填用：校验 → **就地更新目标对象** → 替换数组引用 |
| `total` / `totalText` | 合计（元 / 两位小数文本） |
| `validate` | 转调 `FormValidator` |
| `saveDraft` / `loadDraft` | 转调 `DraftRepository`，兜底异常 |
| `reset` | 清空表单（保留实例） |

### 2.7 视图层

| 组件 | 关键实现 |
|------|----------|
| `BasicInfoView` | `@Consume` 表单；出差人/部门/事由（TextArea）/起止日期行；`FlexWrap.Wrap` + `fieldWidth()` 实现两列/单列；日期行点击回调页面弹系统日期选择器 |
| `ExpenseListView` | `@Link newItem` 新增行（类别 chip、日期、金额、备注、计算器入口）；明细卡片 `ForEach` + `ExpenseRow`（`@ObjectLink`）；删除、金额编辑、**实时合计**；空态引导文案 |
| `CalculatorPopup` | `@State` 四件套；`Flex` 5×4 按键网格（C/⌫/÷/×/7-9/−/4-6/+/1-3/=/0/./确定）；`RelativeContainer` 遮罩 + 居中卡片；求值/回填/错误提示 |
| `PreviewPopup` | `@Link form` 只读展示；`Scroll` 承载长列表；基本信息横屏两列；底部「关闭预览 / 提交报销单」 |
| `pages/Index.ets` | `@Provide` 表单 + 6 个 `@State`；`RelativeContainer` 根；`List` 组装；`mediaquery` 生命周期；Toast/日期选择器封装；提交/保存/加载编排；长按标题的诊断开关 |

### 2.8 页面关键代码（节选）

```ts
@Provide('reimbursementForm') form: ReimbursementForm = ReimbursementForm.createEmpty();
@State newItem: ExpenseItem = ExpenseItem.createDraft();
@State showCalculator: boolean = false;
@State calcTargetId: string = '';        // '' = 回填新增行，否则为目标明细 id
@State showPreview: boolean = false;
@State isLandscape: boolean = false;
@State forceStorageError: boolean = false;

aboutToAppear(): void {
  const listener = this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)');
  this.landscapeListener = listener;
  this.isLandscape = listener.matches;
  listener.on('change', (r: mediaquery.MediaQueryResult) => { this.isLandscape = r.matches; });
}

aboutToDisappear(): void {
  this.landscapeListener?.off('change');
  this.landscapeListener = null;
}
```

```ts
// 计算器回填：目标为新增行 / 指定明细
private applyCalculatorResult(value: string): void {
  if (this.calcTargetId.length === 0) {
    this.newItem.amount = value;
    this.showCalculator = false;
    return;
  }
  const result = ReimbursementViewModel.updateItemAmount(this.form, this.calcTargetId, value);
  if (!result.success) { this.showToast(result.message); return; }
  this.showCalculator = false;
}
```

---

## 第三章 运行截图说明

> **重要声明**：本次开发环境**无可用真机、也无可用模拟器**（DevEco Studio 6.0.1 的 `devecocli emulator` 需要 ≥ 6.1.0），因此**未生成任何截图**，也不使用伪造图片。以下为截图清单与拍摄步骤，图片由用户在 DevEco Studio 运行后补齐到 `screenshots/`。

| 序号 | 建议文件名 | 场景 | 拍摄步骤 | 验收要点 |
|------|------------|------|----------|----------|
| 1 | `01_main_portrait.png` | 主界面（竖屏） | 启动应用，填写出差人/部门/事由，添加 2 条明细 | 单列排布；合计两位小数；按钮行完整 |
| 2 | `02_calculator.png` | 计算器弹窗 | 点新增行「计算」→ 依次按 1 0 0 ÷ 4 = | 显示 25；遮罩覆盖全屏；卡片居中 |
| 3 | `03_calculator_fill.png` | 回填结果 | 接上一步点「确定」 | 金额框显示 25.00，其余明细不受影响 |
| 4 | `04_preview.png` | 预览弹窗 | 点底部「预览」 | 基本信息 + 全部明细 + 合计齐全 |
| 5 | `05_divide_by_zero.png` | 除零提示 | 打开计算器 → 5 ÷ 0 = | Toast「除数不能为 0」，弹窗仍可操作 |
| 6 | `06_validate_fail.png` | 校验失败 | 清空出差事由 → 点「提交」 | Toast「请填写出差事由」，表单数据保留 |
| 7 | `07_storage_fail.png` | 存储失败 | 长按标题开启诊断 → 点「临时保存」 | 红色徽标「诊断：存储失败」+ Toast 失败提示 |
| 8 | `08_main_landscape.png` | 主界面（横屏） | 旋转为横屏 | 基本信息两列、明细两列、按钮一行四个 |


---

## 第四章 Agent 开发补充

### 4.1 本次使用的 Agent 能力

| 环节 | 使用的技能/工具 | 实际作用 |
|------|-----------------|----------|
| 规范获取 | `deveco-cli` skill | 确认 `devecocli create/build/docs` 的用法、沙箱要求、构建产物路径 |
| ArkTS 规范 | `hmos-arkui-develop-skill`（**加载失败**：`DEVECO_HOME` 未配置）+ 内置 ArkTS 规则清单 | 约束装饰器代际、禁止语法、组件属性可用性 |
| 工程脚手架 | `devecocli create --app-name ReimbursementTmp --api-level 21` | 生成可编译的 Stage 骨架（避免手工臆造工程文件） |
| API 核对 | `devecocli docs search`（preferences flush / RelativeContainer alignRules / mediaquery 横竖屏）+ SDK `.d.ts` 检索 | 确保 `off('change')`、`onDateAccept`、`InputType.NUMBER_DECIMAL`、`getPreferences/put/flush` 等签名真实存在 |
| 静态检查 | `arkts_check`（两批共 16 个文件） | 拦截 `any`/对象字面量作类型/索引签名等严格模式问题 |
| 编译验证 | `devecocli build --build-mode debug` | 首轮即 `BUILD SUCCESSFUL`，后续两轮回归通过 |

完整逐条记录见 [`docs/trace/skill-trace.log`](../trace/skill-trace.log)，归纳见 [`docs/trace/summary.md`](../trace/summary.md)。

### 4.2 Agent 协作方式（可复用到下次作业）

1. **先规格后代码**：先把需求拆成 `spec.md`（用户故事 + 验收场景 + FR 编号）、`plan.md`（技术选型 + 契约）、`tasks.md`（可勾选任务），再让 Agent 按任务逐条实现。好处是每个决策都有出处，评审时能对上评分点。
2. **先骨架后业务**：强制 Agent 用 `devecocli create` 生成骨架，再由人确认三模块改造，避免 Agent"凭记忆写构建配置"。
3. **早编译、勤编译**：三轮 `devecocli build`。第一轮在"页面 + 视图 + 服务"全部就位后立刻跑，用来验证 `@Provide → @Link` 这类有争议的组合；第二轮修复废弃告警；第三轮做最终门禁。
4. **文档查询代替记忆**：涉及 API 签名（`off` 是否可省回调、`getHostContext` 是否可用）一律查本地文档或 `.d.ts`，而不是凭印象写。
5. **让 Agent 生成审计，但人要复核**：`code_audit_report.json` 由 Agent 按四维产出，人工逐条核对定位与证据（本次就发现并修正了 7 个真实问题，见 `fix-list.md`）。

### 4.3 交付物

| 交付物 | 路径 |
|--------|------|
| 源码工程 | 本仓库根目录（三模块） |
| 说明文档 | `README.md` |
| 开发报告 | `docs/report/Assignment3_报告.md` / `.docx` |
| Skill 调用 Trace | `docs/trace/skill-trace.log`、`docs/trace/summary.md` |
| 代码审计报告 | `docs/audit/code_audit_report.json` |
| 缺陷修复清单 | `docs/audit/fix-list.md` |
| 截图清单 | `screenshots/README.md` |
| 打包脚本 | `scripts/package.sh` |

---

## 第五章 问题与解决

### 5.1 已解决的技术问题

| # | 问题 | 现象 | 原因 | 解决方案 |
|---|------|------|------|----------|
| 1 | 明细金额回填后界面不刷新 | 计算器点确定后金额框仍显示旧值 | V1 `ForEach` 在 key 不变时不重建子组件，替换数组元素对象不会触发行刷新 | 明细对象 `@Observed` + 行组件 `@ObjectLink`；回填时**就地更新目标对象**再替换数组引用（只刷新目标行 + 合计） |
| 2 | `getContext` 废弃告警 | `ArkTS:WARN 'getContext' has been deprecated` | 使用了全局 API 获取 Context | 改为 `this.getUIContext().getHostContext()` |
| 3 | 横屏下弹窗过宽/按键过高 | 计算器卡片几乎贴边 | 初版只按竖屏给定宽高，`isLandscape` 入参未使用 | 卡片宽度 56%/92%、maxWidth 460/360、按键 40/46vp；预览卡片 78%/94% 且信息改两列 |
| 4 | hvigor 提示 `Missing module info for local modules` | 首轮构建（依赖未安装）有 WARN | 本地模块的 `oh-package.json5` 包名（`@ohos/common`）与模块名（`common`）不一致，hvigor 按包名匹配 modules 失败 | 依赖安装到 `oh_modules/` 后该提示自动消失；实测 `devecocli build clean` + `devecocli build --build-mode debug` 清洁重建 exitCode=0 且无该告警。保留 scoped 包名以满足作业命名要求 |
| 5 | 类型声明与运行期可空性不一致 | `applyFrom` 中对不可空参数做 `=== undefined` | 参数声明为不可空，运行期却可能是 `null` | 参数改为 `X \| null`，只判 `=== null`，访问统一 `?.`/`??` |
| 6 | 模板残留备份能力 | `module.json5` 有 `EntryBackupAbility` | `devecocli create` 模板带入 | 删除扩展与其 `backup_config.json`，ability 改名 `ProductsAbility` |
| 7 | 系统未装 `python-docx` | `ModuleNotFoundError: No module named 'docx'` | 系统 Python 受 PEP 668 保护，无法直接 pip 安装 | 新建 venv 安装 `python-docx` 后生成 `.docx`（脚本与命令见报告附录） |
| 8 | 首次打包把 `spec/`、`.hvigor/` 打进 ZIP | 942 个条目，混入规格目录与构建缓存 | `zip -x` 只匹配单个条目，`-x ".hvigor"` 不会排除其内容 | 改为对每个排除项同时排除 `dir`、`dir/*`、`*/dir`、`*/dir/*`；最终 73 个文件 |
| 9 | 解压后中文文件名乱码 | `Assignment3_报告.docx` 解压成 `Assignment3_???.docx` | macOS 自带 Info-ZIP 3.0 对非 ASCII 文件名不写 UTF-8 标志位，且不支持 `-UN=UTF8` | 新增 `scripts/zip_project.py` 用 Python `zipfile` 归档（自动置 UTF-8 flag），`package.sh` 改为调用它；实测 `flag_bits=0x800`，解压文件名正常 |

### 5.2 环境限制与遗留事项

| 事项 | 现状 | 建议 |
|------|------|------|
| 真机/模拟器验证 | 环境无设备，DevEco 6.0.1 不支持 `devecocli emulator`（需 ≥6.1.0） | 在 DevEco Studio 连接设备后按 `screenshots/README.md` 补齐 10 张截图，并手工回归 US1–US5 |
| 签名 | `signingConfigs` 为空，命令行产物为 unsigned HAP | 在 `Project Structure → Signing Configs` 勾选自动签名后再安装 |
| ZIP 命名 | 使用占位 `Assignment3_TeamX_StudentID1_StudentID2.zip` | 提交前替换为真实团队号与学号 |
| 明细行未用嵌套 List | 用 `ForEach + Flex` 支持横屏两列 | 已作为 design deviation 记入审计 B-08；若评分严格要求，可改为竖屏 List / 横屏 Flex 分支 |

### 5.3 验证结论

| 门禁 | 命令/工具 | 结果 |
|------|-----------|------|
| ArkTS 严格模式静态检查 | `arkts_check`（common 8 文件 + features/products 8 文件） | `No errors found`（两批） |
| 编译 | `devecocli build --build-mode debug` | `BUILD SUCCESSFUL`（exitCode=0），产物 `products-default-unsigned.hap` |
| 四维审计 | 人工 + 编译器 | 编译/语法/布局/业务 4/4 通过，0 项 fail |
| 运行时 UI | — | **未验证（无设备）**，需用户补测 |

---

## 附录：复现命令

```bash
cd /Users/annya/Documents/ustc/harmonyOS/assignment3
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents

# 编译（产物：products/build/default/outputs/default/products-default-unsigned.hap）
devecocli build --build-mode debug

# 生成 Word 报告（python-docx 装在临时 venv 中）
/var/folders/b1/sxv4c7fn2cx1pbjhq62ryp300000gp/T/deveco/pyenv/bin/python \
  scripts/md_to_docx.py docs/report/Assignment3_报告.md docs/report/Assignment3_报告.docx

# 打包交付物（zip_project.py 用 zipfile 写入 UTF-8 文件名，避免解压乱码）
bash scripts/package.sh
```

> 打包实现说明：macOS 自带 Info-ZIP 3.0 在写入中文文件名时不会设置 UTF-8 标志位，Windows 解压会出现乱码，因此 `package.sh` 调用 `scripts/zip_project.py`（Python `zipfile`）完成归档，并自动校验 13 个关键文件是否齐全。
