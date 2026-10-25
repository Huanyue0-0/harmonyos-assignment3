import { AppConstants, ReimbursementForm } from '@ohos/common';

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

  @Builder
  dateRow(label: string, value: string, field: string) {
    Column() {
      this.fieldLabel(label, false)
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text(value.length > 0 ? value : '请选择日期')
          .fontSize(AppConstants.FONT_BODY)
          .fontColor(value.length > 0 ? AppConstants.COLOR_TEXT : AppConstants.COLOR_TEXT_SECONDARY)
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
        this.onPickDate(field);
      })
    }
    .width(this.fieldWidth())
    .margin({ bottom: AppConstants.SPACE_MD })
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

        this.dateRow('开始日期', this.form.startDate, 'startDate')
        this.dateRow('结束日期', this.form.endDate, 'endDate')
      }
      .width('100%')
    }
    .width('100%')
    .padding(AppConstants.SPACE_LG)
    .backgroundColor(AppConstants.COLOR_CARD)
    .borderRadius(AppConstants.RADIUS_MD)
  }
}
