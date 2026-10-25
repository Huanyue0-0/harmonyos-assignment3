import { ExpenseItem } from '../model/ReimbursementModels';
import { ErrorUtil } from '../common/AppUtils';

/**
 * 金额工具：解析、格式化、合计。
 * 规则：
 * - 输入金额一律以字符串原文保存，需要参与运算时解析；
 * - 先转「分」再求和，避免浮点累加误差；
 * - 所有方法内部 try/catch，非法值抛出带中文消息的 Error。
 */
export class AmountUtil {
  /**
   * 归一化输入：去空白、全角数字转半角、忽略千分位逗号、全角小数点转半角。
   */
  static normalize(text: string): string {
    try {
      if (!text) {
        return '';
      }
      let result: string = '';
      for (let i = 0; i < text.length; i++) {
        const code: number = text.charCodeAt(i);
        const ch: string = text.charAt(i);
        if (code === 0x3000 || code === 0x20 || code === 0x09) {
          continue;
        }
        if (code >= 0xFF10 && code <= 0xFF19) {
          result += String.fromCharCode(code - 0xFF10 + 0x30);
          continue;
        }
        if (ch === '．' || ch === '。') {
          result += '.';
          continue;
        }
        if (ch === ',' || ch === '，') {
          continue;
        }
        result += ch;
      }
      return result;
    } catch (error) {
      return '';
    }
  }

  /** 判断归一化后的文本是否为合法数字（允许一个前导正负号与一个小数点） */
  static isNumeric(text: string): boolean {
    try {
      if (text.length === 0) {
        return false;
      }
      let start: number = 0;
      const first: string = text.charAt(0);
      if (first === '-' || first === '+') {
        start = 1;
      }
      let dotCount: number = 0;
      let digitCount: number = 0;
      for (let i = start; i < text.length; i++) {
        const ch: string = text.charAt(i);
        if (ch === '.') {
          dotCount += 1;
          if (dotCount > 1) {
            return false;
          }
          continue;
        }
        if (ch < '0' || ch > '9') {
          return false;
        }
        digitCount += 1;
      }
      return digitCount > 0;
    } catch (error) {
      return false;
    }
  }

  /** 解析金额文本为数字，失败抛出中文 Error */
  static parse(text: string): number {
    try {
      const normalized: string = AmountUtil.normalize(text);
      if (normalized.length === 0) {
        throw new Error('金额不能为空');
      }
      if (!AmountUtil.isNumeric(normalized)) {
        throw new Error(`金额「${text.trim()}」不是合法数字`);
      }
      const value: number = Number(normalized);
      if (Number.isNaN(value)) {
        throw new Error('金额不是合法数字');
      }
      if (!Number.isFinite(value)) {
        throw new Error('金额超出可表示范围');
      }
      return value;
    } catch (error) {
      throw new Error(ErrorUtil.message(error, '金额格式不正确'));
    }
  }

  /** 解析为「分」（整数），用于避免浮点累加误差 */
  static toCents(text: string): number {
    const value: number = AmountUtil.parse(text);
    return Math.round(value * 100);
  }

  /** 保留两位小数格式化，非法值抛错 */
  static format(value: number): string {
    try {
      if (Number.isNaN(value)) {
        throw new Error('金额不是合法数字');
      }
      if (!Number.isFinite(value)) {
        throw new Error('金额超出可表示范围');
      }
      return value.toFixed(2);
    } catch (error) {
      throw new Error(ErrorUtil.message(error, '金额格式化失败'));
    }
  }

  /** 紧凑格式化：最多保留 6 位小数并去掉多余的 0，用于计算器显示 */
  static formatCompact(value: number): string {
    try {
      if (Number.isNaN(value)) {
        throw new Error('计算结果不是合法数字');
      }
      if (!Number.isFinite(value)) {
        throw new Error('计算结果超出可表示范围');
      }
      const rounded: number = Math.round(value * 1000000) / 1000000;
      return `${rounded}`;
    } catch (error) {
      throw new Error(ErrorUtil.message(error, '计算结果无法显示'));
    }
  }

  /**
   * 计算明细合计：逐条 try/catch，非法金额按 0 计入（由表单校验单独报错）。
   * 整个过程以「分」为单位累加，最后再折算为元。
   */
  static sumItems(items: ExpenseItem[]): number {
    let cents: number = 0;
    const list: ExpenseItem[] = items ?? [];
    for (let i = 0; i < list.length; i++) {
      const item: ExpenseItem | undefined = list[i];
      try {
        const amountText: string = item?.amount ?? '';
        if (amountText.length === 0) {
          continue;
        }
        cents += Math.round(AmountUtil.parse(amountText) * 100);
      } catch (error) {
        cents += 0;
      }
    }
    return cents / 100;
  }

  /** 合计金额的展示文本（两位小数），异常时返回 0.00 */
  static sumText(items: ExpenseItem[]): string {
    try {
      return AmountUtil.format(AmountUtil.sumItems(items));
    } catch (error) {
      return '0.00';
    }
  }
}
