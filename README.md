# 差旅报销小程序（Assignment 3）

HarmonyOS NEXT 6.0.1（API 21）· Stage 模型 · ArkTS/ArkUI 声明式开发 · 状态管理 V1

一个面向企业员工的**单机差旅报销**迷你应用：录入出差基本信息、动态增删费用明细、用弹窗计算器算钱、预览整单、提交清空，并支持本地临时保存/加载。全中文界面，任何异常输入或存储故障都给出可理解的中文提示且不崩溃。

---

## 一、功能清单

| 模块 | 能力 | 关键实现 |
|------|------|----------|
| 基本信息 | 出差人、部门、出差事由（必填）、起止日期（系统日期选择器） | `BasicInfoView` + `UIContext.showDatePickerDialog` |
| 费用明细 | 动态新增/删除；类别（交通/住宿/餐饮/通讯/其他）、日期、金额、备注 | `ExpenseListView` + `ReimbursementViewModel.addItem/removeItem` |
| 实时合计 | 明细底部实时汇总，保留两位小数 | `AmountUtil.sumItems`（先转「分」整数累加，规避浮点误差） |
| 弹窗计算器 | `+ − × ÷`、小数点、清除、退格、求值、结果回填 | `CalculatorPopup` + 自研 `CalculatorEngine`（不用 `eval`/`Function`） |
| 预览 | 弹窗展示基本信息、全部明细、合计；关闭不丢数据 | `PreviewPopup`（`@Link` 双向绑定） |
| 提交 | 事由 → 明细数 → 金额 → 日期 四级校验；成功清空并提示 | `FormValidator` + 页面 `handleSubmit` |
| 临时保存/加载 | preferences 持久化，空/损坏/IO 异常中文提示且不覆盖当前表单 | `DraftRepository`（三态返回 + `flush()`） |
| 横竖屏 | 竖屏单列、横屏两列；弹窗始终完整可见 | `mediaquery` + `FlexWrap.Wrap` + 百分比宽度 |

### 异常处理一览

| 场景 | 提示文案 | 行为 |
|------|----------|------|
| 金额为空/非数字/≤0 | 「金额不能为空」「金额「x」不是合法数字」「金额必须大于 0」 | 拒绝添加/回填，表单不变 |
| 计算器除零 | 「除数不能为 0」 | 计算器保留原输入，可继续操作 |
| 计算器非法表达式 | 「表达式不完整，请检查运算符」等 | 同上，不崩溃 |
| 提交缺事由 | 「请填写出差事由」 | 表单保留 |
| 提交无明细 | 「请至少添加一条费用明细」 | 表单保留 |
| 结束日期早于开始日期 | 「结束日期不能早于开始日期」 | 表单保留 |
| 无历史草稿 | 「暂无历史数据」 | 表单保留 |
| 草稿 JSON 损坏 | 「历史数据已损坏（…）」 | 表单保留 |
| 存储 IO 失败 | 「存储失败：…」 | 表单保留 |

---

## 二、目录结构

```text
assignment3/
├── AppScope/                         # 应用级配置与图标
│   ├── app.json5
│   └── resources/base/{element,media}
├── common/                           # HAR：领域模型 / 常量 / 服务 / 持久化
│   ├── Index.ets                     # 统一导出（barrel）
│   ├── build-profile.json5  hvigorfile.ts  oh-package.json5
│   └── src/main/
│       ├── module.json5              # type: har
│       └── ets/
│           ├── model/ReimbursementModels.ets   # ExpenseItem / ReimbursementForm / DraftRecord / OperationResult / DraftLoadResult
│           ├── common/AppConstants.ets         # 存储键、费用类型、颜色、间距、文案
│           ├── common/AppUtils.ets             # DateUtil / IdUtil / ErrorUtil
│           ├── service/AmountUtil.ets          # 金额解析、格式化、合计（转「分」）
│           ├── service/CalculatorEngine.ets    # 表达式分词与求值
│           ├── service/FormValidator.ets       # 四级表单校验
│           └── data/DraftRepository.ets        # preferences + 强类型 JSON 编解码
├── features/                         # HAR：业务视图与编排（依赖 common）
│   ├── Index.ets
│   ├── build-profile.json5  hvigorfile.ts  oh-package.json5
│   └── src/main/
│       ├── module.json5              # type: har
│       └── ets/
│           ├── viewmodel/ReimbursementViewModel.ets
│           └── views/
│               ├── BasicInfoView.ets     # Flex 响应式基本信息
│               ├── ExpenseListView.ets   # 新增行 + 明细卡片 + 合计
│               ├── CalculatorPopup.ets   # Relative 定位的弹窗计算器
│               └── PreviewPopup.ets      # Relative 定位的预览弹窗
├── products/                         # entry HAP：页面组装与 Ability（依赖 common + features）
│   ├── build-profile.json5  hvigorfile.ts  oh-package.json5
│   └── src/main/
│       ├── module.json5              # type: entry, orientation: auto_rotation
│       ├── ets/
│       │   ├── productsability/ProductsAbility.ets
│       │   └── pages/Index.ets        # @Entry：@Provide 表单 / List / Relative 弹窗层
│       └── resources/base/{element,media,profile}
├── docs/
│   ├── trace/{skill-trace.log,summary.md}      # Agent 技能调用 Trace
│   ├── audit/{code_audit_report.json,fix-list.md}
│   └── report/Assignment3_报告.{md,docx}
├── screenshots/README.md             # 截图清单与拍摄步骤（图片待用户补齐）
├── scripts/
│   ├── package.sh                    # 交付打包脚本（调用 zip_project.py）
│   ├── zip_project.py                # 用 zipfile 归档，保证中文文件名 UTF-8 不乱码
│   └── md_to_docx.py                 # Markdown 报告转 Word
├── hvigor/hvigor-config.json5
├── build-profile.json5  hvigorfile.ts  oh-package.json5
└── README.md
```

**模块依赖**：`products` →（`features` → `common`）+ `common`；两个 HAR 通过 `file:` 本地依赖与 `useNormalizedOHMUrl: true` 解析为 `@ohos/common`、`@ohos/features`。

---

## 三、技术要点

1. **状态管理 V1（作业强制）**
   - 页面 `@Provide('reimbursementForm') form: ReimbursementForm`，子视图 `@Consume('reimbursementForm')` 读写同一实例；
   - 预览弹窗 `@Link form`；计算器内部 `@State expression/display/errorText/justEvaluated`；
   - 明细对象 `ExpenseItem` 标注 `@Observed`，明细行用 `@ObjectLink` 订阅，计算器回填时只刷新目标行。

2. **布局三件套（作业强制）**
   - 页面根 `RelativeContainer`，表单主体由 `List` 承载；
   - 行内排版全部使用 `Flex`（含 `FlexWrap.Wrap` 的两列响应式）；
   - 计算器与预览弹窗均为「全尺寸遮罩 + 居中卡片」，卡片以 `__container__` 为锚点用 `alignRules` 居中，不使用 `CustomDialog`。

3. **安全与健壮性**
   - 金额、计算、JSON 编解码、明细增删全部 `try/catch`；
   - 可空访问统一 `?.` / `??`；无 `any`/`unknown`/`ESObject`、无对象字面量作类型、无索引签名、无 `eval`；
   - 金额以字符串原文保存，合计前转「分」做整数累加，展示统一 `toFixed(2)`。

4. **持久化**
   - preferences：库名 `reimbursement_store`，键 `draft_form`，写入后必须 `flush()`；
   - 读取先 `JSON.parse` 到 `DraftRaw` 原始接口，再逐字段 `typeof` 校验后构造领域对象，失败返回 `error` 状态，**不覆盖当前表单**。

---

## 四、构建与运行

### 环境

- DevEco Studio 6.0.1（内置 hvigor、ohpm、SDK `6.0.1(21)`）
- macOS：`export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents`

### 命令行构建

```bash
cd /Users/annya/Documents/ustc/harmonyOS/assignment3
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents

# 编译（产物：products/build/default/outputs/default/products-default-unsigned.hap）
devecocli build --build-mode debug
```

### 在 DevEco Studio 中运行

1. `File → Open` 打开本工程根目录；
2. 等待 Sync 完成（会自动 `ohpm install` 三个模块）；
3. 连接真机或启动模拟器，选择 `products` 模块，点击 Run；
4. 若无签名配置，先在 `Project Structure → Signing Configs` 勾选自动签名。

> 说明：命令行构建产出的是 **未签名 HAP**（`signingConfigs` 为空），仅用于编译验证；安装到设备需在 DevEco Studio 中配置签名。

---

## 五、诊断开关（演示「存储失败」）

- **操作**：长按页面标题「差旅报销单」切换诊断开关；
- **开启后**：标题右侧出现红色徽标「诊断：存储失败」，此时点击「临时保存」或「加载历史」会直接给出中文失败提示，且**不会写入/读取真实存储**，当前表单不受影响；
- **再次长按**关闭开关，恢复正常读写；
- 该开关仅用于截图与演示异常分支，不参与正常业务。

---

## 六、截图清单（待补齐）

截图目录：`screenshots/`，命名与拍摄步骤见 [`screenshots/README.md`](screenshots/README.md)。

当前构建环境**无可用真机/模拟器**（DevEco 6.0.1 的 `devecocli emulator` 需 ≥ 6.1.0），因此本仓库只提供截图清单与拍摄步骤，**不包含伪造截图**。请按清单在 DevEco Studio 运行后补图。

---

## 七、已知说明

- **首次构建**（`oh_modules/` 尚未生成时）hvigor 会提示 `Missing module info for local modules '@ohos/common,@ohos/features'`。这是 hvigor 对「本地模块包名（`@ohos/common`）与模块名（`common`）不一致」的提示；依赖安装到 `oh_modules/` 后，**后续构建不再出现该提示**，且依赖解析、编译、产物均正常。保留 scoped 包名是为满足作业的模块命名要求。
- 命令行产物为**未签名 HAP**（`signingConfigs` 为空），仅用于编译验证；安装到设备需在 DevEco Studio 中配置签名。
- 交付 ZIP 包名使用占位符 `Assignment3_TeamX_StudentID1_StudentID2.zip`，提交前请替换为真实团队号与学号。
- 交付物：`docs/report/Assignment3_报告.md` / `.docx`、`docs/audit/code_audit_report.json`、`docs/trace/skill-trace.log`。
