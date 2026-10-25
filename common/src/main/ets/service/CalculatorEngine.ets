import { ErrorUtil } from '../common/AppUtils';

/** 表达式中的单个 token：要么是数字，要么是运算符 */
class CalcToken {
  isNumber: boolean;
  numberValue: number;
  operator: string;

  constructor(isNumber: boolean, numberValue: number, operator: string) {
    this.isNumber = isNumber;
    this.numberValue = numberValue;
    this.operator = operator;
  }

  static number(value: number): CalcToken {
    return new CalcToken(true, value, '');
  }

  static op(operator: string): CalcToken {
    return new CalcToken(false, 0, operator);
  }
}

/**
 * 计算器表达式引擎。
 * 支持：+ - × ÷ . 与数字，一元负号（如 -3+5），连续运算符覆盖在 UI 层处理。
 * 禁止使用 eval / Function，全部自研分词与求值。
 * 除零、非法表达式抛出带中文消息的 Error。
 */
export class CalculatorEngine {
  /** 运算符归一化：× ÷ − 等符号统一成 * / - */
  static normalize(expression: string): string {
    try {
      if (!expression) {
        return '';
      }
      let result: string = '';
      for (let i = 0; i < expression.length; i++) {
        const ch: string = expression.charAt(i);
        if (ch === ' ' || ch === '\t' || ch === '\n') {
          continue;
        }
        if (ch === '×' || ch === 'x' || ch === 'X' || ch === '*') {
          result += '*';
          continue;
        }
        if (ch === '÷' || ch === '/') {
          result += '/';
          continue;
        }
        if (ch === '−' || ch === '－' || ch === '-') {
          result += '-';
          continue;
        }
        if (ch === '＋' || ch === '+') {
          result += '+';
          continue;
        }
        if (ch === '．' || ch === '。') {
          result += '.';
          continue;
        }
        const code: number = expression.charCodeAt(i);
        if (code >= 0xFF10 && code <= 0xFF19) {
          result += String.fromCharCode(code - 0xFF10 + 0x30);
          continue;
        }
        result += ch;
      }
      return result;
    } catch (error) {
      return '';
    }
  }

  /** 分词：把表达式拆成数字与运算符 token 序列 */
  private static tokenize(expression: string): CalcToken[] {
    const tokens: CalcToken[] = [];
    let index: number = 0;
    let expectOperand: boolean = true;
    while (index < expression.length) {
      const ch: string = expression.charAt(index);
      if (ch === '+' || ch === '-' || ch === '*' || ch === '/') {
        if (!expectOperand) {
          tokens.push(CalcToken.op(ch));
          expectOperand = true;
          index += 1;
          continue;
        }
        if (ch === '-') {
          // 一元负号：与紧随其后的数字合并为一个负数 token
          index += 1;
          const digits: string = CalculatorEngine.readDigits(expression, index);
          if (digits.length === 0) {
            throw new Error('运算符位置错误，请检查表达式');
          }
          index += digits.length;
          const negative: number = Number(`-${digits}`);
          if (Number.isNaN(negative)) {
            throw new Error('数字格式非法');
          }
          tokens.push(CalcToken.number(negative));
          expectOperand = false;
          continue;
        }
        throw new Error('运算符位置错误，请检查表达式');
      }
      if ((ch >= '0' && ch <= '9') || ch === '.') {
        const digits: string = CalculatorEngine.readDigits(expression, index);
        if (digits.length === 0 || digits === '.') {
          throw new Error('数字格式非法');
        }
        index += digits.length;
        const value: number = Number(digits);
        if (Number.isNaN(value)) {
          throw new Error('数字格式非法');
        }
        tokens.push(CalcToken.number(value));
        expectOperand = false;
        continue;
      }
      throw new Error('表达式包含不支持的字符');
    }
    if (expectOperand) {
      throw new Error('表达式不完整，请检查运算符');
    }
    if (tokens.length === 0) {
      throw new Error('表达式不能为空');
    }
    return tokens;
  }

  /** 读取连续的数字与最多一个小数点 */
  private static readDigits(expression: string, start: number): string {
    let digits: string = '';
    let dotCount: number = 0;
    let index: number = start;
    while (index < expression.length) {
      const ch: string = expression.charAt(index);
      if (ch >= '0' && ch <= '9') {
        digits += ch;
        index += 1;
        continue;
      }
      if (ch === '.') {
        dotCount += 1;
        if (dotCount > 1) {
          throw new Error('小数点过多，请检查表达式');
        }
        digits += ch;
        index += 1;
        continue;
      }
      break;
    }
    return digits;
  }

  /**
   * 求值：先乘除后加减。
   * @throws Error 空表达式 / 非法字符 / 运算符位置错误 / 除数为 0 / 结果溢出
   */
  static evaluate(expression: string): number {
    try {
      const normalized: string = CalculatorEngine.normalize(expression);
      if (normalized.length === 0) {
        throw new Error('表达式不能为空');
      }
      const tokens: CalcToken[] = CalculatorEngine.tokenize(normalized);

      const numbers: number[] = [];
      const operators: string[] = [];
      for (let i = 0; i < tokens.length; i++) {
        const token: CalcToken = tokens[i];
        if (token.isNumber) {
          numbers.push(token.numberValue);
        } else {
          operators.push(token.operator);
        }
      }
      if (numbers.length !== operators.length + 1) {
        throw new Error('表达式结构非法');
      }

      // 第一遍：处理乘除，把它们折叠成单个数字
      const foldedNumbers: number[] = [numbers[0]];
      const foldedOperators: string[] = [];
      let numberCursor: number = 1;
      for (let i = 0; i < operators.length; i++) {
        const operator: string = operators[i];
        const next: number = numbers[numberCursor];
        numberCursor += 1;
        if (operator === '*' || operator === '/') {
          const lastIndex: number = foldedNumbers.length - 1;
          const previous: number = foldedNumbers[lastIndex];
          if (operator === '/') {
            if (next === 0) {
              throw new Error('除数不能为 0');
            }
            foldedNumbers[lastIndex] = previous / next;
          } else {
            foldedNumbers[lastIndex] = previous * next;
          }
        } else {
          foldedOperators.push(operator);
          foldedNumbers.push(next);
        }
      }

      // 第二遍：处理加减
      let result: number = foldedNumbers[0];
      for (let i = 0; i < foldedOperators.length; i++) {
        const operator: string = foldedOperators[i];
        const value: number = foldedNumbers[i + 1];
        if (operator === '+') {
          result += value;
        } else {
          result -= value;
        }
      }
      if (Number.isNaN(result)) {
        throw new Error('计算结果不是合法数字');
      }
      if (!Number.isFinite(result)) {
        throw new Error('计算结果超出可表示范围');
      }
      return result;
    } catch (error) {
      throw new Error(ErrorUtil.message(error, '表达式非法'));
    }
  }
}
