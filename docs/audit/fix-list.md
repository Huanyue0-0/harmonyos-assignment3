# 缺陷与修复清单（人工修复记录）

> 仅记录**本次开发中真实出现并已处理**的问题。四维审计结论见 [`code_audit_report.json`](./code_audit_report.json)。

## 一、已修复

| # | 现象 | 定位 | 根因 | 修复方式 | 验证 |
|---|------|------|------|----------|------|
| F-01 | 构建告警 `'getContext' has been deprecated` | `products/.../pages/Index.ets` 获取 Context 处 | 使用的是已废弃的全局 `getContext(this)` | 改为 `this.getUIContext().getHostContext() as common.UIAbilityContext` | 重新构建后该告警消失 |
| F-02 | 计算器弹窗在横屏下过宽、按键高度不随方向变化（T032 未闭环） | `CalculatorPopup.ets` 卡片与按键 | 初版只按竖屏给定固定宽度 92% / 按键 46vp，`isLandscape` 入参未被使用 | 卡片宽度改为 `isLandscape ? '56%' : '92%'`，`constraintSize` 的 maxWidth 改为 460/360，按键高度 40/46vp | 布局走查 + 构建通过 |
| F-03 | 预览弹窗横屏信息密度低、字段单列 | `PreviewPopup.ets` | 初版 5 条基本信息始终单列 | 卡片宽度 78%/94%；基本信息改用 `FlexWrap.Wrap`，`infoLine` 宽度 48%/100% | 布局走查 + 构建通过 |
| F-04 | `AppConstants` 存在未被引用的常量（`NO_DATE`、`POPUP_MAX_HEIGHT_RATIO`、`DIAGNOSTIC_OFF_TEXT`） | `common/.../AppConstants.ets` | 设计阶段预留，实现后无引用 | 删除冗余常量，保留实际使用的诊断文案 | `arkts_check` 通过 |
| F-05 | `module.json5` 仍保留模板 `EntryBackupAbility` 备份扩展与其 `backup_config.json` | `products/src/main/{module.json5,resources/base/profile}` | 由 `devecocli create` 模板带入，本应用无备份需求 | 删除 extensionAbilities 与 backup_config.json，ability 改名为 `ProductsAbility` | 构建通过（资源引用无误） |
| F-06 | `ReimbursementForm.applyFrom` 与 `ExpenseItem.applyFrom` 对非空类型做 `=== undefined` 判断 | `common/.../ReimbursementModels.ets` | 参数声明为不可空类型，运行期却可能为 null，类型判断与声明不一致 | 参数类型改为 `X | null`，仅判断 `=== null`，访问统一用 `?.`/`??` | `arkts_check` 通过 |
| F-07 | 根 `build-profile.json5` 中两个 HAR 模块带 `targets.applyToProducts` 写法引发冗余校验 | `build-profile.json5` | 与 hvigor 对 HAR 模块的声明约定不一致 | 改为 `{ name, srcPath }` 形式（products 仍保留 applyToProducts=default） | 构建通过 |

## 二、确认为「非缺陷 / 已接受」

| # | 现象 | 结论 | 说明 |
|---|------|------|------|
| A-01 | `WARN: Missing module info for local modules '@ohos/common,@ohos/features'`（仅首轮构建出现） | 接受（不影响构建） | 该提示由 hvigor 的 `checkModulesOutsideProjectWithoutModuleInfo` 触发：依赖名取 `oh-package.json5` 的 `name`（`@ohos/common`），而工程模块名是 `common`，二者不一致。**依赖安装到 `oh_modules/` 后，clean 重建不再出现该提示**（已实测 `devecocli build clean` + `devecocli build --build-mode debug`，exitCode=0 且无该告警）。保留 scoped 包名是为满足作业命名要求。 |
| A-02 | `WARN: Will skip sign 'hos_hap'. No signingConfigs profile ...` | 接受 | 命令行环境未配置签名材料，产出 unsigned HAP 仅用于编译验证；安装到设备需在 DevEco Studio 配置 Signing Configs。 |
| A-03 | 费用明细行使用 `ForEach + Flex` 而非嵌套 `List` | 有意设计 | 横屏需要两列换行网格，`List` 只能单列；页面级 `List` 已承担「表单列表 + 滚动」职责。已在审计报告 B-08 记录为 design deviation。 |
| A-04 | 计算器「连续运算符覆盖」与规格中「输入 1++2 求值报错」不完全一致 | 有意设计 | `tasks.md` T023 明确要求「连续运算符覆盖」（`1++` 覆盖为上一步的运算符），因此 UI 层不会产生 `1++2`；引擎本身仍会拒绝 `1++2`（若通过初始值注入），非法表达式（如 `5÷` 求值）仍会中文提示并保留原输入。 |
| A-05 | 明细金额在入库时被格式化为两位小数（如 `25` → `25.00`） | 有意设计 | 金额全程以字符串保存，入库时统一 `toFixed(2)` 只影响**展示与存储的可读性**，不改变数值；合计仍以「分」整数累加。 |

## 三、环境相关

| # | 现象 | 处置 |
|---|------|------|
| E-01 | `hmos-arkui-develop-skill` 加载失败：`DEVECO_HOME environment variable is not configured` | 未伪造加载成功；改用内置 ArkTS 严格模式规则，并在所有 CLI 调用前显式 `export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents` |
| E-02 | 系统未预装 `python-docx`（`ModuleNotFoundError: No module named 'docx'`） | 在临时目录创建 venv（`/var/folders/.../T/deveco/pyenv`）并 `pip install python-docx`，用于生成 `.docx` 报告 |
| E-03 | 无可用真机/模拟器（DevEco 6.0.1 的 `devecocli emulator` 需 ≥ 6.1.0） | 不生成伪造截图；`screenshots/README.md` 提供完整拍摄清单，README 与报告中标注「截图待补」 |
