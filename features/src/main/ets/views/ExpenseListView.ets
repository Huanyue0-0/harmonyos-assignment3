import { AppConstants, ExpenseItem, ReimbursementForm } from '@ohos/common';
import { ReimbursementViewModel } from '../viewmodel/ReimbursementViewModel';

/**
 * 费用类别选择标签。
 * 独立 @Component 使得 @Prop selected 能响应状态变化自动高亮。
 * 必须定义在文件顶层（ArkUI V1 不支持嵌套 @Component）。
 */
@Component
struct CategoryChip {
  private category: string = '';
  @Prop selected: boolean = false;
  private onClickCategory: (category: string) => void = () => {
  };

  build() {
    Text(this.category)
      .fontSize(AppConstants.FONT_SMALL)
      .fontColor(this.selected ? Color.White : AppConstants.COLOR_TEXT_SECONDARY)
      .backgroundColor(this.selected ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_CHIP_BG)
      .padding({
        left: AppConstants.SPACE_MD,
        right: AppConstants.SPACE_MD,
        top: AppConstants.SPACE_XS,
        bottom: AppConstants.SPACE_XS
      })
      .borderRadius(AppConstants.RADIUS_SM)
      .margin({ right: AppConstants.SPACE_SM, bottom: AppConstants.SPACE_XS })
      .onClick(() => {
        this.onClickCategory(this.category);
      })
  }
}

/**
 * 单条费用明细行。
 * 使用 @ObjectLink 订阅 @Observed 的 ExpenseItem，计算器回填或金额修改时只刷新本行。
 */
@Component
struct ExpenseRow {
  @ObjectLink item: ExpenseItem;
  @Prop isLandscape: boolean = false;
  onDelete: (id: string) => void = (id: string) => {
  };
  onCalc: (id: string) => void = (id: string) => {
  };
  onAmountChange: (id: string, text: string) => void = (id: string, text: string) => {
  };

  private rowWidth(): string {
    return this.isLandscape ? '48%' : '100%';
  }

  build() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Flex({ alignItems: ItemAlign.Center }) {
          Text(this.item.category)
            .fontSize(AppConstants.FONT_SMALL)
            .fontColor(AppConstants.COLOR_PRIMARY)
            .backgroundColor(AppConstants.COLOR_CHIP_BG)
            .padding({
              left: AppConstants.SPACE_SM,
              right: AppConstants.SPACE_SM,
              top: 2,
              bottom: 2
            })
            .borderRadius(AppConstants.RADIUS_SM)
          Text(this.item.date)
            .fontSize(AppConstants.FONT_SMALL)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            .margin({ left: AppConstants.SPACE_SM })
        }

        Text('删除')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_DANGER)
          .padding(AppConstants.SPACE_XS)
          .onClick(() => {
            this.onDelete(this.item.id);
          })
      }
      .width('100%')
      .margin({ bottom: AppConstants.SPACE_SM })

      Flex({ alignItems: ItemAlign.Center }) {
        Text('金额')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .margin({ right: AppConstants.SPACE_SM })
        TextInput({ text: this.item.amount, placeholder: '0.00' })
          .type(InputType.NUMBER_DECIMAL)
          .height(AppConstants.INPUT_HEIGHT)
          .fontSize(AppConstants.FONT_BODY)
          .backgroundColor(AppConstants.COLOR_CARD)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.onAmountChange(this.item.id, value);
          })
        Text('计算')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .padding({
            left: AppConstants.SPACE_SM,
            right: AppConstants.SPACE_SM,
            top: AppConstants.SPACE_SM,
            bottom: AppConstants.SPACE_SM
          })
          .margin({ left: AppConstants.SPACE_SM })
          .borderRadius(AppConstants.RADIUS_SM)
          .backgroundColor(AppConstants.COLOR_CHIP_BG)
          .onClick(() => {
            this.onCalc(this.item.id);
          })
      }
      .width('100%')

      if (this.item.remark.length > 0) {
        Text(`备注：${this.item.remark}`)
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .width('100%')
          .margin({ top: AppConstants.SPACE_XS })
      }
    }
    .width(this.rowWidth())
    .padding(AppConstants.SPACE_MD)
    .margin({ bottom: AppConstants.SPACE_SM })
    .backgroundColor(AppConstants.COLOR_BACKGROUND)
    .borderRadius(AppConstants.RADIUS_SM)
  }
}

/**
 * 费用明细视图（US1）。
 * - 添加行：类别选择、日期、金额、备注、计算器入口；
 * - 明细列表：动态删除、金额编辑、计算器回填；
 * - 底部实时合计。
 */
@Component
export struct ExpenseListView {
  @Consume('reimbursementForm') form: ReimbursementForm;
  @Link newItem: ExpenseItem;
  @Prop isLandscape: boolean = false;
  onAddItem: () => void = () => {
  };
  onDeleteItem: (id: string) => void = (id: string) => {
  };
  onRequestCalculator: (targetId: string) => void = (targetId: string) => {
  };
  /** field 为 'newItem' 时选择新增行日期，否则为目标明细 id */
  onPickItemDate: (field: string) => void = (field: string) => {
  };

  private totalText(): string {
    return ReimbursementViewModel.totalText(this.form);
  }

  /** 明细行金额直接写回模型（允许中间态如 "12."），合计自动忽略非法值 */
  private applyAmount(id: string, text: string): void {
    try {
      const target: ExpenseItem | null = this.form.findItemById(id);
      if (target === null) {
        return;
      }
      target.amount = text;
      this.form.items = this.form.replaceItem(target);
    } catch (error) {
      return;
    }
  }

  build() {
    Column() {
      Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
        Text('费用明细')
          .fontSize(AppConstants.FONT_SUBTITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT)
        Text(`共 ${this.form.items.length} 条`)
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      .margin({ bottom: AppConstants.SPACE_MD })

      // ---------- 新增行 ----------
      Column() {
        Text('新增一条费用')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .width('100%')
          .margin({ bottom: AppConstants.SPACE_SM })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(AppConstants.EXPENSE_CATEGORIES, (category: string) => {
            CategoryChip({
              category: category,
              selected: this.newItem.category === category,
              onClickCategory: (cat: string) => {
                this.newItem.category = cat;
              }
            })
          }, (category: string) => category)
        }
        .width('100%')
        .margin({ bottom: AppConstants.SPACE_SM })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          Flex({ alignItems: ItemAlign.Center }) {
            Text('发生日期')
              .fontSize(AppConstants.FONT_SMALL)
              .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            Text(this.newItem.date.length > 0 ? this.newItem.date : '请选择')
              .fontSize(AppConstants.FONT_SMALL)
              .fontColor(AppConstants.COLOR_PRIMARY)
              .margin({ left: AppConstants.SPACE_SM })
          }
          .width(this.isLandscape ? '48%' : '100%')
          .height(AppConstants.INPUT_HEIGHT)
          .padding({ left: AppConstants.SPACE_MD, right: AppConstants.SPACE_MD })
          .margin({ bottom: AppConstants.SPACE_SM })
          .backgroundColor(AppConstants.COLOR_CARD)
          .borderRadius(AppConstants.RADIUS_SM)
          .onClick(() => {
            this.onPickItemDate('newItem');
          })

          Flex({ alignItems: ItemAlign.Center }) {
            TextInput({ text: this.newItem.amount, placeholder: '金额（元）' })
              .type(InputType.NUMBER_DECIMAL)
              .height(AppConstants.INPUT_HEIGHT)
              .fontSize(AppConstants.FONT_BODY)
              .layoutWeight(1)
              .onChange((value: string) => {
                this.newItem.amount = value;
              })
            Text('计算')
              .fontSize(AppConstants.FONT_SMALL)
              .fontColor(AppConstants.COLOR_PRIMARY)
              .padding(AppConstants.SPACE_SM)
              .margin({ left: AppConstants.SPACE_SM })
              .borderRadius(AppConstants.RADIUS_SM)
              .backgroundColor(AppConstants.COLOR_CHIP_BG)
              .onClick(() => {
                this.onRequestCalculator('');
              })
          }
          .width(this.isLandscape ? '48%' : '100%')
          .margin({ bottom: AppConstants.SPACE_SM })
        }
        .width('100%')

        TextInput({ text: this.newItem.remark, placeholder: '备注（可选）' })
          .height(AppConstants.INPUT_HEIGHT)
          .fontSize(AppConstants.FONT_BODY)
          .margin({ bottom: AppConstants.SPACE_SM })
          .onChange((value: string) => {
            this.newItem.remark = value;
          })

        Flex({ justifyContent: FlexAlign.End }) {
          Text('添加到明细')
            .fontSize(AppConstants.FONT_BODY)
            .fontColor(Color.White)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
            .padding({
              left: AppConstants.SPACE_LG,
              right: AppConstants.SPACE_LG,
              top: AppConstants.SPACE_SM,
              bottom: AppConstants.SPACE_SM
            })
            .borderRadius(AppConstants.RADIUS_SM)
            .onClick(() => {
              this.onAddItem();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(AppConstants.SPACE_MD)
      .backgroundColor(AppConstants.COLOR_CARD)
      .borderRadius(AppConstants.RADIUS_MD)
      .margin({ bottom: AppConstants.SPACE_MD })

      // ---------- 明细列表 ----------
      if (this.form.items.length === 0) {
        Column() {
          Text('还没有费用明细')
            .fontSize(AppConstants.FONT_BODY)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          Text('填写金额后点击「添加到明细」')
            .fontSize(AppConstants.FONT_SMALL)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            .margin({ top: AppConstants.SPACE_XS })
        }
        .width('100%')
        .padding(AppConstants.SPACE_LG)
        .backgroundColor(AppConstants.COLOR_BACKGROUND)
        .borderRadius(AppConstants.RADIUS_SM)
      } else {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.form.items, (item: ExpenseItem) => {
            ExpenseRow({
              item: item,
              isLandscape: this.isLandscape,
              onDelete: (id: string) => {
                this.onDeleteItem(id);
              },
              onCalc: (id: string) => {
                this.onRequestCalculator(id);
              },
              onAmountChange: (id: string, text: string) => {
                this.applyAmount(id, text);
              }
            })
          }, (item: ExpenseItem) => item.id)
        }
        .width('100%')
      }

      // ---------- 合计 ----------
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text('费用合计')
          .fontSize(AppConstants.FONT_SUBTITLE)
          .fontColor(AppConstants.COLOR_TEXT)
        Text(`¥ ${this.totalText()}`)
          .fontSize(AppConstants.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
      }
      .width('100%')
      .padding(AppConstants.SPACE_MD)
      .margin({ top: AppConstants.SPACE_MD })
      .backgroundColor(AppConstants.COLOR_CHIP_BG)
      .borderRadius(AppConstants.RADIUS_SM)
    }
    .width('100%')
    .padding(AppConstants.SPACE_LG)
    .backgroundColor(AppConstants.COLOR_CARD)
    .borderRadius(AppConstants.RADIUS_MD)
  }
}
