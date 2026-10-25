import { mediaquery } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AppConstants,
  DateUtil,
  DraftStatus,
  ErrorUtil,
  ExpenseItem,
  ReimbursementForm
} from '@ohos/common';
import {
  BasicInfoView,
  CalculatorPopup,
  ExpenseListView,
  PreviewPopup,
  ReimbursementViewModel
} from '@ohos/features';

const DOMAIN: number = 0x0001;
const TAG: string = 'ReimbursementIndex';

/**
 * 差旅报销主页面。
 * 布局：根 RelativeContainer + List 表单 + Relative 全尺寸弹窗层；
 * 状态：@Provide 共享表单（V1），@State 管理弹窗/方向/诊断开关，明细金额通过 @Observed + @ObjectLink 刷新。
 */
@Entry
@Component
struct Index {
  @Provide('reimbursementForm') form: ReimbursementForm = ReimbursementForm.createEmpty();
  @State newItem: ExpenseItem = ExpenseItem.createDraft();
  @State showCalculator: boolean = false;
  @State calcTargetId: string = '';
  @State showPreview: boolean = false;
  @State isLandscape: boolean = false;
  @State forceStorageError: boolean = false;
  @State lastSavedAt: number = 0;
  private landscapeListener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    this.registerLandscapeListener();
  }

  aboutToDisappear(): void {
    try {
      this.landscapeListener?.off('change');
    } catch (error) {
      hilog.error(DOMAIN, TAG, '注销方向监听失败: %{public}s', JSON.stringify(error));
    }
    this.landscapeListener = null;
  }

  /** 注册横竖屏监听（mediaquery 生命周期管理） */
  private registerLandscapeListener(): void {
    try {
      const listener: mediaquery.MediaQueryListener =
        this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)');
      this.landscapeListener = listener;
      this.isLandscape = listener.matches;
      listener.on('change', (result: mediaquery.MediaQueryResult) => {
        this.isLandscape = result.matches;
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '注册方向监听失败: %{public}s', JSON.stringify(error));
    }
  }

  /** 统一 Toast：通过 UIContext 获取 PromptAction，避免全局导入 */
  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Toast 调用失败: %{public}s', JSON.stringify(error));
    }
  }

  private abilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private savedAtText(): string {
    if (this.lastSavedAt <= 0) {
      return '尚未临时保存';
    }
    try {
      const date: Date = new Date(this.lastSavedAt);
      const hour: string = DateUtil.pad2(date.getHours());
      const minute: string = DateUtil.pad2(date.getMinutes());
      return `上次保存 ${DateUtil.format(date)} ${hour}:${minute}`;
    } catch (error) {
      return '尚未临时保存';
    }
  }

  /** 长按标题切换「存储失败」诊断开关 */
  private toggleDiagnostic(): void {
    this.forceStorageError = !this.forceStorageError;
    this.showToast(this.forceStorageError ? '已开启存储失败诊断（下一次保存/加载将失败）' : '已关闭存储失败诊断');
  }

  /** 打开系统日期选择器并回填 */
  private openDatePicker(field: string): void {
    try {
      let currentText: string = '';
      if (field === 'startDate') {
        currentText = this.form.startDate;
      } else if (field === 'endDate') {
        currentText = this.form.endDate;
      } else if (field === 'newItem') {
        currentText = this.newItem.date;
      }
      const selected: Date = DateUtil.toDateOrToday(currentText);
      const startLimit: Date = new Date(2000, 0, 1);
      const endLimit: Date = new Date(2100, 11, 31);
      this.getUIContext().showDatePickerDialog({
        start: startLimit,
        end: endLimit,
        selected: selected,
        onDateAccept: (value: Date) => {
          this.applyDate(field, DateUtil.format(value));
        }
      });
    } catch (error) {
      this.showToast(`打开日期选择器失败：${ErrorUtil.message(error, '请重试')}`);
    }
  }

  /** 日期回填：基本信息字段 / 新增行草稿 / 指定明细 */
  private applyDate(field: string, text: string): void {
    try {
      if (field === 'startDate') {
        this.form.startDate = text;
        return;
      }
      if (field === 'endDate') {
        this.form.endDate = text;
        return;
      }
      if (field === 'newItem') {
        this.newItem.date = text;
        return;
      }
      const target: ExpenseItem | null = this.form.findItemById(field);
      if (target === null) {
        this.showToast('未找到要修改日期的明细');
        return;
      }
      target.date = text;
      this.form.items = this.form.replaceItem(target);
    } catch (error) {
      this.showToast(`日期回填失败：${ErrorUtil.message(error, '请重试')}`);
    }
  }

  private handleAddItem(): void {
    try {
      const result = ReimbursementViewModel.addItem(this.form, this.newItem);
      this.showToast(result.message);
      if (result.success) {
        this.newItem = ExpenseItem.createDraft();
      }
    } catch (error) {
      this.showToast(`添加明细失败：${ErrorUtil.message(error, '未知错误')}`);
    }
  }

  private handleDeleteItem(id: string): void {
    try {
      const result = ReimbursementViewModel.removeItem(this.form, id);
      this.showToast(result.message);
    } catch (error) {
      this.showToast(`删除明细失败：${ErrorUtil.message(error, '未知错误')}`);
    }
  }

  private openCalculator(targetId: string): void {
    this.calcTargetId = targetId;
    this.showCalculator = true;
  }

  private calculatorSeed(): string {
    if (this.calcTargetId.length === 0) {
      return this.newItem.amount ?? '';
    }
    const target: ExpenseItem | null = this.form.findItemById(this.calcTargetId);
    return target?.amount ?? '';
  }

  /** 计算器确定：回填新增行或指定明细 */
  private applyCalculatorResult(value: string): void {
    try {
      if (this.calcTargetId.length === 0) {
        this.newItem.amount = value;
        this.showCalculator = false;
        this.showToast(`已回填金额 ${value}`);
        return;
      }
      const result = ReimbursementViewModel.updateItemAmount(this.form, this.calcTargetId, value);
      if (!result.success) {
        this.showToast(result.message);
        return;
      }
      this.showCalculator = false;
      this.showToast(`已回填金额 ${value}`);
    } catch (error) {
      this.showToast(`回填失败：${ErrorUtil.message(error, '未知错误')}`);
    }
  }

  /** 提交：校验 → 成功清空，失败保留表单 */
  private handleSubmit(): void {
    try {
      const result = ReimbursementViewModel.validate(this.form);
      if (!result.success) {
        this.showToast(result.message);
        return;
      }
      ReimbursementViewModel.reset(this.form);
      this.newItem = ExpenseItem.createDraft();
      this.lastSavedAt = 0;
      this.showPreview = false;
      this.showToast('提交成功，表单已清空');
    } catch (error) {
      this.showToast(`提交失败：${ErrorUtil.message(error, '未知错误')}`);
    }
  }

  /** 临时保存（含诊断开关模拟失败） */
  private async handleSave(): Promise<void> {
    if (this.forceStorageError) {
      this.showToast('存储失败：本地存储不可用（诊断开关已开启）');
      return;
    }
    try {
      const result = await ReimbursementViewModel.saveDraft(this.abilityContext(), this.form);
      if (result.success) {
        this.lastSavedAt = Date.now();
        this.showToast('临时保存成功');
      } else {
        this.showToast(result.message);
      }
    } catch (error) {
      this.showToast(`存储失败：${ErrorUtil.message(error, '本地存储不可用')}`);
    }
  }

  /** 加载历史（空 / 损坏 / IO 异常均不覆盖当前表单） */
  private async handleLoad(): Promise<void> {
    if (this.forceStorageError) {
      this.showToast('存储失败：本地存储不可用（诊断开关已开启）');
      return;
    }
    try {
      const result = await ReimbursementViewModel.loadDraft(this.abilityContext());
      if (result.status === DraftStatus.SUCCESS && result.form !== null) {
        this.form.applyFrom(result.form);
        this.lastSavedAt = result.savedAt;
        this.showToast('已加载最近一次临时保存');
        return;
      }
      if (result.status === DraftStatus.EMPTY) {
        this.showToast('暂无历史数据');
        return;
      }
      this.showToast(result.message);
    } catch (error) {
      this.showToast(`读取失败：${ErrorUtil.message(error, '本地存储不可用')}`);
    }
  }

  private onActionClick(kind: string): void {
    if (kind === 'preview') {
      this.showPreview = true;
      return;
    }
    if (kind === 'submit') {
      this.handleSubmit();
      return;
    }
    if (kind === 'save') {
      this.handleSave();
      return;
    }
    this.handleLoad();
  }

  @Builder
  header() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Column() {
          Text('差旅报销单')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_TEXT)
          Text(this.isLandscape ? '横屏 · 两列布局' : '竖屏 · 单列布局')
            .fontSize(AppConstants.FONT_SMALL)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => {
          this.showToast(AppConstants.DIAGNOSTIC_TOGGLE_TIP);
        })
        .gesture(LongPressGesture({ repeat: false }).onAction((event: GestureEvent) => {
          this.toggleDiagnostic();
        }))

        if (this.forceStorageError) {
          Text(AppConstants.DIAGNOSTIC_ON_TEXT)
            .fontSize(AppConstants.FONT_SMALL)
            .fontColor(Color.White)
            .backgroundColor(AppConstants.COLOR_DANGER)
            .padding({
              left: AppConstants.SPACE_SM,
              right: AppConstants.SPACE_SM,
              top: 2,
              bottom: 2
            })
            .borderRadius(AppConstants.RADIUS_SM)
        }
      }
      .width('100%')

      Text(this.savedAtText())
        .fontSize(AppConstants.FONT_SMALL)
        .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
        .width('100%')
        .margin({ top: AppConstants.SPACE_XS })
    }
    .width('100%')
    .padding({ left: AppConstants.SPACE_LG, right: AppConstants.SPACE_LG, top: AppConstants.SPACE_MD })
  }

  @Builder
  actionButton(label: string, kind: string, primary: boolean) {
    Text(label)
      .fontSize(AppConstants.FONT_BODY)
      .fontColor(primary ? Color.White : AppConstants.COLOR_PRIMARY)
      .backgroundColor(primary ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_CARD)
      .textAlign(TextAlign.Center)
      .height(40)
      .width(this.isLandscape ? '24%' : '48%')
      .borderRadius(AppConstants.RADIUS_SM)
      .margin({ bottom: AppConstants.SPACE_SM })
      .onClick(() => {
        this.onActionClick(kind);
      })
  }

  @Builder
  actionBar() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      this.actionButton('预览', 'preview', false)
      this.actionButton('提交', 'submit', true)
      this.actionButton('临时保存', 'save', false)
      this.actionButton('加载历史', 'load', false)
    }
    .width('100%')
    .padding({ left: AppConstants.SPACE_LG, right: AppConstants.SPACE_LG, top: AppConstants.SPACE_SM })
    .backgroundColor(AppConstants.COLOR_BACKGROUND)
  }

  build() {
    RelativeContainer() {
      Column() {
        this.header()

        List({ space: AppConstants.SPACE_MD }) {
          ListItem() {
            BasicInfoView({
              isLandscape: this.isLandscape,
              onPickDate: (field: string) => {
                this.openDatePicker(field);
              }
            })
          }

          ListItem() {
            ExpenseListView({
              newItem: this.newItem,
              isLandscape: this.isLandscape,
              onAddItem: () => {
                this.handleAddItem();
              },
              onDeleteItem: (id: string) => {
                this.handleDeleteItem(id);
              },
              onRequestCalculator: (targetId: string) => {
                this.openCalculator(targetId);
              },
              onPickItemDate: (field: string) => {
                this.openDatePicker(field);
              }
            })
          }

          ListItem() {
            Column()
              .height(AppConstants.SPACE_XL)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: AppConstants.SPACE_LG, right: AppConstants.SPACE_LG, top: AppConstants.SPACE_MD })
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)

        this.actionBar()
      }
      .id('mainColumn')
      .width('100%')
      .height('100%')
      .backgroundColor(AppConstants.COLOR_BACKGROUND)
      .alignRules({
        top: { anchor: '__container__', align: VerticalAlign.Top },
        left: { anchor: '__container__', align: HorizontalAlign.Start },
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
        right: { anchor: '__container__', align: HorizontalAlign.End }
      })

      // ---------- 计算器弹窗层（Relative 定位） ----------
      if (this.showCalculator) {
        CalculatorPopup({
          initialValue: this.calculatorSeed(),
          isLandscape: this.isLandscape,
          onConfirm: (value: string) => {
            this.applyCalculatorResult(value);
          },
          onClose: () => {
            this.showCalculator = false;
          }
        })
      }

      // ---------- 预览弹窗层（Relative 定位） ----------
      if (this.showPreview) {
        PreviewPopup({
          form: this.form,
          isLandscape: this.isLandscape,
          onClose: () => {
            this.showPreview = false;
          },
          onSubmit: () => {
            this.handleSubmit();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppConstants.COLOR_BACKGROUND)
  }
}
