import { AmountUtil, AppConstants, CalculatorEngine, ErrorUtil } from '@ohos/common';

/**
 * 弹窗计算器（US2）。
 * - 局部状态：@State expression / display / errorText / justEvaluated；
 * - 布局：Root 为 RelativeContainer，遮罩铺满、卡片以 __container__ 为锚点居中；
 * - 求值：CalculatorEngine 自研分词求值，除零与非法表达式 try/catch 转中文提示。
 */
@Component
export struct CalculatorPopup {
  @Prop initialValue: string = '';
  @Prop isLandscape: boolean = false;
  @State expression: string = '';
  @State display: string = '0';
  @State errorText: string = '';
  @State justEvaluated: boolean = false;
  onConfirm: (value: string) => void = (value: string) => {
  };
  onClose: () => void = () => {
  };

  aboutToAppear(): void {
    try {
      const seed: string = this.initialValue?.trim() ?? '';
      if (seed.length > 0) {
        this.expression = seed;
        this.display = seed;
      }
    } catch (error) {
      this.expression = '';
      this.display = '0';
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (error) {
      return;
    }
  }

  private isOperatorChar(ch: string): boolean {
    return ch === '+' || ch === '-' || ch === '×' || ch === '÷';
  }

  private lastChar(): string {
    if (this.expression.length === 0) {
      return '';
    }
    return this.expression.charAt(this.expression.length - 1);
  }

  /** 当前正在输入的数字片段（最后一个运算符之后的部分） */
  private currentSegment(): string {
    let index: number = this.expression.length - 1;
    while (index >= 0) {
      const ch: string = this.expression.charAt(index);
      if (this.isOperatorChar(ch)) {
        break;
      }
      index -= 1;
    }
    return this.expression.substring(index + 1);
  }

  private pressDigit(digit: string): void {
    try {
      if (this.justEvaluated) {
        this.expression = '';
        this.justEvaluated = false;
      }
      this.errorText = '';
      this.expression = `${this.expression}${digit}`;
      this.display = this.expression;
    } catch (error) {
      this.errorText = ErrorUtil.message(error, '输入异常');
    }
  }

  private pressDot(): void {
    try {
      if (this.justEvaluated) {
        this.expression = '0';
        this.justEvaluated = false;
      }
      const segment: string = this.currentSegment();
      if (segment.indexOf('.') >= 0) {
        return;
      }
      if (this.expression.length === 0) {
        this.expression = '0.';
      } else if (this.isOperatorChar(this.lastChar())) {
        this.expression = `${this.expression}0.`;
      } else {
        this.expression = `${this.expression}.`;
      }
      this.errorText = '';
      this.display = this.expression;
    } catch (error) {
      this.errorText = ErrorUtil.message(error, '输入异常');
    }
  }

  private pressOperator(operator: string): void {
    try {
      this.errorText = '';
      if (this.expression.length === 0) {
        if (operator === '−') {
          this.expression = '−';
          this.display = this.expression;
        }
        return;
      }
      if (this.justEvaluated) {
        this.justEvaluated = false;
      }
      if (this.isOperatorChar(this.lastChar())) {
        // 连续运算符：覆盖上一个运算符
        this.expression = `${this.expression.substring(0, this.expression.length - 1)}${operator}`;
      } else {
        this.expression = `${this.expression}${operator}`;
      }
      this.display = this.expression;
    } catch (error) {
      this.errorText = ErrorUtil.message(error, '运算符处理失败');
    }
  }

  private pressBackspace(): void {
    try {
      this.justEvaluated = false;
      if (this.expression.length > 0) {
        this.expression = this.expression.substring(0, this.expression.length - 1);
      }
      this.errorText = '';
      this.display = this.expression.length === 0 ? '0' : this.expression;
    } catch (error) {
      this.errorText = ErrorUtil.message(error, '退格失败');
    }
  }

  private clearAll(): void {
    this.expression = '';
    this.display = '0';
    this.errorText = '';
    this.justEvaluated = false;
  }

  /** 求值：成功回显结果，失败保留原输入并提示 */
  private evaluate(): void {
    try {
      const value: number = CalculatorEngine.evaluate(this.expression);
      const text: string = AmountUtil.formatCompact(value);
      this.display = text;
      this.expression = text;
      this.justEvaluated = true;
      this.errorText = '';
    } catch (error) {
      const message: string = ErrorUtil.message(error, '表达式非法');
      this.errorText = message;
      this.showToast(message);
    }
  }

  /** 确定：必要时先求值，再把两位小数的结果回填 */
  private confirm(): void {
    try {
      let text: string = this.expression;
      if (!this.justEvaluated) {
        const value: number = CalculatorEngine.evaluate(this.expression);
        text = AmountUtil.formatCompact(value);
      }
      const amount: number = AmountUtil.parse(text);
      const formatted: string = AmountUtil.format(amount);
      this.onConfirm(formatted);
    } catch (error) {
      const message: string = ErrorUtil.message(error, '表达式非法，请检查输入');
      this.errorText = message;
      this.showToast(message);
    }
  }

  private onKey(label: string, kind: string): void {
    if (kind === 'num') {
      this.pressDigit(label);
      return;
    }
    if (kind === 'dot') {
      this.pressDot();
      return;
    }
    if (kind === 'op') {
      this.pressOperator(label);
      return;
    }
    if (kind === 'back') {
      this.pressBackspace();
      return;
    }
    if (kind === 'clear') {
      this.clearAll();
      return;
    }
    this.evaluate();
  }

  private buttonBgColor(kind: string): string {
    if (kind === 'equal') {
      return AppConstants.COLOR_PRIMARY;
    }
    if (kind === 'op') {
      return AppConstants.COLOR_CHIP_BG;
    }
    if (kind === 'clear' || kind === 'back') {
      return '#F3F0FF';
    }
    return AppConstants.COLOR_BACKGROUND;
  }

  private buttonTextColor(kind: string): string {
    if (kind === 'equal') {
      return '#FFFFFF';
    }
    if (kind === 'op') {
      return AppConstants.COLOR_PRIMARY;
    }
    if (kind === 'clear' || kind === 'back') {
      return AppConstants.COLOR_PRIMARY_DARK;
    }
    return AppConstants.COLOR_TEXT;
  }

  @Builder
  padButton(label: string, kind: string) {
    Column() {
      Text(label)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.buttonTextColor(kind))
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(this.isLandscape ? 40 : 46)
        .borderRadius(AppConstants.RADIUS_SM)
        .backgroundColor(this.buttonBgColor(kind))
    }
    .width('25%')
    .padding(4)
    .onClick(() => {
      this.onKey(label, kind);
    })
  }

  build() {
    RelativeContainer() {
      // 遮罩层：拦截点击并关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppConstants.COLOR_MASK)
        .onClick(() => {
          this.onClose();
        })

      // 计算器卡片：以容器为锚点居中
      Column() {
        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          Text('计算器')
            .fontSize(AppConstants.FONT_SUBTITLE)
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
        .margin({ bottom: AppConstants.SPACE_SM })

        Text(this.display)
          .width('100%')
          .height(64)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: AppConstants.SPACE_SM, right: AppConstants.SPACE_SM })
          .backgroundColor(AppConstants.COLOR_BACKGROUND)
          .borderRadius(AppConstants.RADIUS_SM)
          .margin({ bottom: AppConstants.SPACE_XS })

        Text(this.errorText.length > 0 ? this.errorText : '支持 + − × ÷ 与小数')
          .width('100%')
          .fontSize(AppConstants.FONT_SMALL)
          .fontColor(this.errorText.length > 0 ? AppConstants.COLOR_DANGER : AppConstants.COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: AppConstants.SPACE_SM })

        Flex({ wrap: FlexWrap.Wrap }) {
          this.padButton('C', 'clear')
          this.padButton('⌫', 'back')
          this.padButton('÷', 'op')
          this.padButton('×', 'op')
          this.padButton('7', 'num')
          this.padButton('8', 'num')
          this.padButton('9', 'num')
          this.padButton('−', 'op')
          this.padButton('4', 'num')
          this.padButton('5', 'num')
          this.padButton('6', 'num')
          this.padButton('+', 'op')
          this.padButton('1', 'num')
          this.padButton('2', 'num')
          this.padButton('3', 'num')
          this.padButton('=', 'equal')
          this.padButton('0', 'num')
          this.padButton('.', 'dot')
          Column() {
            Text('确定')
              .fontSize(AppConstants.FONT_BODY)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(this.isLandscape ? 40 : 46)
              .borderRadius(AppConstants.RADIUS_SM)
              .backgroundColor(AppConstants.COLOR_SUCCESS)
          }
          .width('50%')
          .padding(4)
          .onClick(() => {
            this.confirm();
          })
        }
        .width('100%')
      }
      .id('calculatorCard')
      .width(this.isLandscape ? '56%' : '92%')
      .constraintSize({
        maxWidth: this.isLandscape ? 460 : AppConstants.CALC_MAX_WIDTH,
        maxHeight: '90%'
      })
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
