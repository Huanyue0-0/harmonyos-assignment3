/**
 * 通用工具：日期处理、唯一 ID 生成、异常信息提取。
 * 所有工具方法均不抛出新异常（除显式声明的场景），保证调用方不会因工具方法崩溃。
 */
export class DateUtil {
  /** 返回今天的 YYYY-MM-DD 文本 */
  static todayText(): string {
    return DateUtil.format(new Date());
  }

  /** Date -> YYYY-MM-DD */
  static format(date: Date): string {
    try {
      const year: number = date.getFullYear();
      const month: string = DateUtil.pad2(date.getMonth() + 1);
      const day: string = DateUtil.pad2(date.getDate());
      return `${year}-${month}-${day}`;
    } catch (error) {
      return '';
    }
  }

  /** 数字补零到两位 */
  static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  /** 仅校验 YYYY-MM-DD 的字符结构，不做日期合法性判断 */
  static hasDateShape(text: string): boolean {
    if (text.length !== 10) {
      return false;
    }
    if (text.charAt(4) !== '-' || text.charAt(7) !== '-') {
      return false;
    }
    for (let i = 0; i < text.length; i++) {
      if (i === 4 || i === 7) {
        continue;
      }
      const ch: string = text.charAt(i);
      if (ch < '0' || ch > '9') {
        return false;
      }
    }
    return true;
  }

  /** 校验日期文本是否合法（含 2 月 30 日这类非法日期） */
  static isValid(text: string): boolean {
    try {
      return DateUtil.toDate(text) !== null;
    } catch (error) {
      return false;
    }
  }

  /** YYYY-MM-DD -> Date，非法返回 null */
  static toDate(text: string): Date | null {
    try {
      if (!DateUtil.hasDateShape(text)) {
        return null;
      }
      const year: number = Number(text.substring(0, 4));
      const month: number = Number(text.substring(5, 7));
      const day: number = Number(text.substring(8, 10));
      if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)) {
        return null;
      }
      const date: Date = new Date(year, month - 1, day);
      if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
        return null;
      }
      return date;
    } catch (error) {
      return null;
    }
  }

  /** 把文本解析为 Date，失败时回退到今天 */
  static toDateOrToday(text: string): Date {
    const parsed: Date | null = DateUtil.toDate(text);
    return parsed === null ? new Date() : parsed;
  }
}

export class IdUtil {
  private static counter: number = 0;

  /** 生成形如 item_1700000000000_3 的唯一 ID */
  static nextId(prefix: string): string {
    IdUtil.counter += 1;
    return `${prefix}_${Date.now()}_${IdUtil.counter}`;
  }
}

export class ErrorUtil {
  /** 从未知异常对象中提取可读信息，失败时返回 fallback */
  static message(error: Object, fallback: string): string {
    try {
      const err = error as Error;
      const text: string | undefined = err?.message;
      if (text !== undefined && text !== null && text.length > 0) {
        return text;
      }
    } catch (ignored) {
      return fallback;
    }
    return fallback;
  }
}
