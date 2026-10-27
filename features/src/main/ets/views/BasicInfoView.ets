import { AppConstants, ReimbursementForm } from '@ohos/common';

/**
 * 日期选择行。
 * 独立 @Component 使得 @Prop value 能响应日期变化自动更新显示文本。
 * 必须定义在文件顶层（ArkUI V1 不支持嵌套 @Component）。
 */
@Component
struct DateRow {
  private label: string = '';
  @Prop value: string = '';
  private field: string = '';
  private fieldWidth: string = '100%';
  private onPickDate: (field: string) => void = () => {
  };

  build() {
    Column() {
      Flex({ alignItems: ItemAlign.Center }) {
        Text(this.label)
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .margin({ bottom: AppConstants.SPACE_XS })

      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text(this.value.length > 0 ? this.value : '请选择日期')
          .fontSize(AppConstants.FONT_BODY)
          .fontColor(this.value.length > 0 ? AppConstants.COLOR_TEXT : AppConstants.COLOR_TEXT_SECONDARY)
        Text('选择')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_PRIMARY)
      }
      .width('100%')
      .height(AppConstants.INPUT_HEIGHT)
      .padding({ left: AppConstants.SPACE_MD, right: AppConstants.SPACE_MD })
      .backgroundColor(AppConstants.COLOR_CHIP_BG)
      .borderRadius(AppConstants.RADIUS_SM)
      .onClick(() => {
        this.onPickDate(this.field);
      })
    }
    .width(this.fieldWidth)
    .margin({ bottom: AppConstants.SPACE_MD })
  }
}

/**
 * 基本信息视图（US1）。
 * 状态来源：@Consume 共享报销单；布局：Flex 换行实现竖屏单列 / 横屏两列。
 */
@Component
export struct BasicInfoView {
  @Consume('reimbursementForm') form: ReimbursementForm;
  @Prop isLandscape: boolean = false;
  /** 点击日期行时回调页面弹出系统日期选择器，field ∈ {startDate, endDate} */
  onPickDate: (field: string) => void = (field: string) => {
  };

  private fieldWidth(): string {
    return this.isLandscape ? '48%' : '100%';
  }

  @Builder
  fieldLabel(text: string, required: boolean) {
    Flex({ alignItems: ItemAlign.Center }) {
      Text(text)
        .fontSize(AppConstants.FONT_SMALL)
        .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
      if (required) {
        Text('*')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_DANGER)
          .margin({ left: 2 })
      }
    }
    .width('100%')
    .margin({ bottom: AppConstants.SPACE_XS })
  }

  build() {
    Column() {
      Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
        Text('基本信息')
          .fontSize(AppConstants.FONT_SUBTITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT)
        Text('出差事由为必填项')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_DANGER)
      }
      .width('100%')
      .margin({ bottom: AppConstants.SPACE_MD })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        Column() {
          this.fieldLabel('出差人', false)
          TextInput({ text: this.form.traveler, placeholder: '请输入出差人姓名' })
            .height(AppConstants.INPUT_HEIGHT)
            .fontSize(AppConstants.FONT_BODY)
            .backgroundColor(AppConstants.COLOR_CHIP_BG)
            .onChange((value: string) => {
              this.form.traveler = value;
            })
        }
        .width(this.fieldWidth())
        .margin({ bottom: AppConstants.SPACE_MD })

        Column() {
          this.fieldLabel('部门', false)
          TextInput({ text: this.form.department, placeholder: '请输入所属部门' })
            .height(AppConstants.INPUT_HEIGHT)
            .fontSize(AppConstants.FONT_BODY)
            .backgroundColor(AppConstants.COLOR_CHIP_BG)
            .onChange((value: string) => {
              this.form.department = value;
            })
        }
        .width(this.fieldWidth())
        .margin({ bottom: AppConstants.SPACE_MD })

        Column() {
          this.fieldLabel('出差事由', true)
          TextArea({ text: this.form.purpose, placeholder: '必填：请简要说明本次出差事由' })
            .height(84)
            .fontSize(AppConstants.FONT_BODY)
            .backgroundColor(AppConstants.COLOR_CHIP_BG)
            .onChange((value: string) => {
              this.form.purpose = value;
            })
        }
        .width('100%')
        .margin({ bottom: AppConstants.SPACE_MD })

        DateRow({
          label: '开始日期',
          value: this.form.startDate,
          field: 'startDate',
          fieldWidth: this.fieldWidth(),
          onPickDate: (f: string) => {
            this.onPickDate(f);
          }
        })
        DateRow({
          label: '结束日期',
          value: this.form.endDate,
          field: 'endDate',
          fieldWidth: this.fieldWidth(),
          onPickDate: (f: string) => {
            this.onPickDate(f);
          }
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppConstants.SPACE_LG)
    .backgroundColor(AppConstants.COLOR_CARD)
    .borderRadius(AppConstants.RADIUS_MD)
  }
}
