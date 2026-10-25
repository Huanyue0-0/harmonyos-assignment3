import { AmountUtil, AppConstants, ExpenseItem, ReimbursementForm } from '@ohos/common';

/**
 * 预览弹窗（US3）。
 * - 数据来源：@Link 双向绑定页面表单，关闭后表单数据不丢失；
 * - 布局：Root 为 RelativeContainer，遮罩铺满、卡片以 __container__ 为锚点居中；
 * - 长列表使用 Scroll，横竖屏均完整可见。
 */
@Component
export struct PreviewPopup {
  @Link form: ReimbursementForm;
  @Prop isLandscape: boolean = false;
  onClose: () => void = () => {
  };
  onSubmit: () => void = () => {
  };

  private totalText(): string {
    try {
      return AmountUtil.format(AmountUtil.sumItems(this.form.items ?? []));
    } catch (error) {
      return '0.00';
    }
  }

  private textOrPlaceholder(value: string): string {
    const text: string = value?.trim() ?? '';
    return text.length === 0 ? '—' : text;
  }

  @Builder
  infoLine(label: string, value: string) {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
      Text(label)
        .fontSize(AppConstants.FONT_SMALL)
        .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
        .width(80)
      Text(value)
        .fontSize(AppConstants.FONT_BODY)
        .fontColor(AppConstants.COLOR_TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.isLandscape ? '48%' : '100%')
    .padding({ top: AppConstants.SPACE_XS, bottom: AppConstants.SPACE_XS })
  }

  @Builder
  itemCard(item: ExpenseItem, index: number) {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text(`第 ${index + 1} 条 · ${item.category}`)
          .fontSize(AppConstants.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppConstants.COLOR_TEXT)
        Text(`¥ ${item.amount.length > 0 ? item.amount : '0.00'}`)
          .fontSize(AppConstants.FONT_BODY)
          .fontColor(AppConstants.COLOR_PRIMARY)
      }
      .width('100%')

      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text(`日期：${item.date.length > 0 ? item.date : '—'}`)
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
        Text(item.remark.length > 0 ? `备注：${item.remark}` : '无备注')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .margin({ left: AppConstants.SPACE_SM })
      }
      .width('100%')
      .margin({ top: AppConstants.SPACE_XS })
    }
    .width('100%')
    .padding(AppConstants.SPACE_MD)
    .margin({ bottom: AppConstants.SPACE_SM })
    .backgroundColor(AppConstants.COLOR_BACKGROUND)
    .borderRadius(AppConstants.RADIUS_SM)
  }

  build() {
    RelativeContainer() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppConstants.COLOR_MASK)
        .onClick(() => {
          this.onClose();
        })

      Column() {
        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          Text('报销单预览')
            .fontSize(AppConstants.FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_TEXT)
          Text('关闭')
            .fontSize(AppConstants.FONT_SMALL)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            .padding(AppConstants.SPACE_XS)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .margin({ bottom: AppConstants.SPACE_MD })

        Scroll() {
          Column() {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              this.infoLine('出差人', this.textOrPlaceholder(this.form.traveler))
              this.infoLine('部门', this.textOrPlaceholder(this.form.department))
              this.infoLine('出差事由', this.textOrPlaceholder(this.form.purpose))
              this.infoLine('开始日期', this.textOrPlaceholder(this.form.startDate))
              this.infoLine('结束日期', this.textOrPlaceholder(this.form.endDate))
            }
            .width('100%')

            Divider()
              .color(AppConstants.COLOR_BORDER)
              .margin({ top: AppConstants.SPACE_SM, bottom: AppConstants.SPACE_MD })

            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              Text('费用明细')
                .fontSize(AppConstants.FONT_SUBTITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_TEXT)
              Text(`共 ${this.form.items.length} 条`)
                .fontSize(AppConstants.FONT_SMALL)
                .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .margin({ bottom: AppConstants.SPACE_SM })

            if (this.form.items.length === 0) {
              Text('暂无费用明细')
                .fontSize(AppConstants.FONT_BODY)
                .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(AppConstants.SPACE_LG)
            } else {
              ForEach(this.form.items, (item: ExpenseItem, index: number) => {
                this.itemCard(item, index)
              }, (item: ExpenseItem) => item.id)
            }

            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              Text('合计')
                .fontSize(AppConstants.FONT_SUBTITLE)
                .fontWeight(FontWeight.Bold)
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
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)

        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          Text('关闭预览')
            .fontSize(AppConstants.FONT_BODY)
            .fontColor(AppConstants.COLOR_TEXT)
            .padding(AppConstants.SPACE_MD)
            .borderRadius(AppConstants.RADIUS_SM)
            .backgroundColor(AppConstants.COLOR_BACKGROUND)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .margin({ right: AppConstants.SPACE_SM })
            .onClick(() => {
              this.onClose();
            })
          Text('提交报销单')
            .fontSize(AppConstants.FONT_BODY)
            .fontColor(Color.White)
            .padding(AppConstants.SPACE_MD)
            .borderRadius(AppConstants.RADIUS_SM)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.onSubmit();
            })
        }
        .width('100%')
        .margin({ top: AppConstants.SPACE_MD })
      }
      .id('previewCard')
      .width(this.isLandscape ? '78%' : '94%')
      .constraintSize({ maxWidth: AppConstants.POPUP_MAX_WIDTH, maxHeight: '88%' })
      .padding(AppConstants.SPACE_LG)
      .backgroundColor(AppConstants.COLOR_CARD)
      .borderRadius(AppConstants.RADIUS_LG)
      .alignRules({
        center: { anchor: '__container__', align: VerticalAlign.Center },
        middle: { anchor: '__container__', align: HorizontalAlign.Center }
      })
    }
    .width('100%')
    .height('100%')
  }
}
