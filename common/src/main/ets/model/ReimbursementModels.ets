import { AppConstants } from '../common/AppConstants';
import { DateUtil, IdUtil } from '../common/AppUtils';

/**
 * 费用明细。使用 @Observed 以便视图层通过 @ObjectLink 订阅单条明细的字段变化，
 * 从而在计算器回填、金额修改时只刷新对应行。
 */
@Observed
export class ExpenseItem {
  id: string;
  category: string;
  date: string;
  amount: string;
  remark: string;

  constructor(id: string, category: string, date: string, amount: string, remark: string) {
    this.id = id;
    this.category = category;
    this.date = date;
    this.amount = amount;
    this.remark = remark;
  }

  /** 防御性初始化：确保所有字段不因外部赋值变为 null/undefined */
  sanitize(): void {
    this.category ??= '';
    this.date ??= '';
    this.amount ??= '';
    this.remark ??= '';
  }

  /** 新增行草稿的默认值：类别默认交通，日期默认今天 */
  static createDraft(): ExpenseItem {
    return new ExpenseItem(IdUtil.nextId('item'), AppConstants.CATEGORY_TRANSPORT, DateUtil.todayText(), '', '');
  }

  /** 深拷贝，避免草稿与正式明细共享同一对象 */
  copy(): ExpenseItem {
    return new ExpenseItem(this.id, this.category, this.date, this.amount, this.remark);
  }

  /** 用其他明细的字段覆盖当前对象（保持对象引用不变） */
  applyFrom(other: ExpenseItem | null): void {
    if (other === null) {
      return;
    }
    this.category ??= other.category;
    this.date ??= other.date;
    this.amount ??= other.amount;
    this.remark ??= other.remark;
  }
}

/** 报销单 */
@Observed
export class ReimbursementForm {
  traveler: string;
  department: string;
  purpose: string;
  startDate: string;
  endDate: string;
  items: ExpenseItem[];

  constructor(traveler: string, department: string, purpose: string, startDate: string, endDate: string,
    items: ExpenseItem[]) {
    this.traveler = traveler;
    this.department = department;
    this.purpose = purpose;
    this.startDate = startDate;
    this.endDate = endDate;
    this.items = items;
  }

  /** 防御性初始化：确保所有字段不因外部赋值变为 null/undefined */
  sanitize(): void {
    this.traveler ??= '';
    this.department ??= '';
    this.purpose ??= '';
    this.startDate ??= '';
    this.endDate ??= '';
    this.items ??= [];
  }

  /** 空表单工厂：起止日期默认今天，明细为空 */
  static createEmpty(): ReimbursementForm {
    const today: string = DateUtil.todayText();
    return new ReimbursementForm('', '', '', today, today, []);
  }

  /** 深拷贝（明细逐条拷贝） */
  copy(): ReimbursementForm {
    const copiedItems: ExpenseItem[] = [];
    const source: ExpenseItem[] = this.items ?? [];
    for (let i = 0; i < source.length; i++) {
      const item: ExpenseItem | undefined = source[i];
      if (item !== undefined && item !== null) {
        copiedItems.push(item.copy());
      }
    }
    return new ReimbursementForm(this.traveler, this.department, this.purpose, this.startDate, this.endDate,
      copiedItems);
  }

  /** 把另一个表单的内容整体覆盖到当前实例（保持引用不变，便于 @Provide/@Consume 继续生效） */
  applyFrom(other: ReimbursementForm | null): void {
    if (other === null) {
      return;
    }
    this.traveler = other.traveler ?? '';
    this.department = other.department ?? '';
    this.purpose = other.purpose ?? '';
    this.startDate = other.startDate ?? '';
    this.endDate = other.endDate ?? '';
    this.items = other.copy().items;
    this.sanitize();
  }

  /** 重置为初始空状态（保留当前实例引用） */
  reset(): void {
    const empty: ReimbursementForm = ReimbursementForm.createEmpty();
    this.traveler = empty.traveler;
    this.department = empty.department;
    this.purpose = empty.purpose;
    this.startDate = empty.startDate;
    this.endDate = empty.endDate;
    this.items = [];
    this.sanitize();
  }

  /** 按 id 查找明细，未找到返回 null */
  findItemById(id: string): ExpenseItem | null {
    const list: ExpenseItem[] = this.items ?? [];
    for (let i = 0; i < list.length; i++) {
      const item: ExpenseItem | undefined = list[i];
      if (item !== undefined && item !== null && item.id === id) {
        return item;
      }
    }
    return null;
  }

  /**
   * 按 id 替换明细，返回新数组（数组引用变化用于通知列表/合计刷新）。
   * 注意：新数组复用同一 ExpenseItem 实例，保证 @ObjectLink 订阅不失效。
   */
  replaceItem(updated: ExpenseItem | null): ExpenseItem[] {
    const list: ExpenseItem[] = this.items ?? [];
    const next: ExpenseItem[] = [];
    for (let i = 0; i < list.length; i++) {
      const item: ExpenseItem | undefined = list[i];
      if (item === undefined || item === null) {
        continue;
      }
      if (updated !== null && item.id === updated.id) {
        next.push(updated);
      } else {
        next.push(item);
      }
    }
    return next;
  }

  /** 按 id 删除明细，返回新数组 */
  removeItemById(id: string): ExpenseItem[] {
    const list: ExpenseItem[] = this.items ?? [];
    const next: ExpenseItem[] = [];
    for (let i = 0; i < list.length; i++) {
      const item: ExpenseItem | undefined = list[i];
      if (item === undefined || item === null) {
        continue;
      }
      if (item.id !== id) {
        next.push(item);
      }
    }
    return next;
  }

  /** 追加一条明细，返回新数组 */
  appendItem(item: ExpenseItem): ExpenseItem[] {
    const list: ExpenseItem[] = this.items ?? [];
    const next: ExpenseItem[] = list.slice();
    next.push(item);
    return next;
  }
}

/** 本地临时保存记录 */
export class DraftRecord {
  savedAt: number;
  form: ReimbursementForm;

  constructor(savedAt: number, form: ReimbursementForm) {
    this.savedAt = savedAt;
    this.form = form;
  }
}

/** 通用操作结果 */
export class OperationResult {
  success: boolean;
  message: string;
  /** 失败字段定位，例如 purpose / items.0.amount */
  field: string;

  constructor(success: boolean, message: string, field: string = '') {
    this.success = success;
    this.message = message;
    this.field = field;
  }

  static ok(message: string): OperationResult {
    return new OperationResult(true, message, '');
  }

  static fail(message: string, field: string = ''): OperationResult {
    return new OperationResult(false, message, field);
  }
}

/** 草稿加载状态 */
export enum DraftStatus {
  SUCCESS = 'success',
  EMPTY = 'empty',
  ERROR = 'error'
}

/** 草稿加载结果（三态） */
export class DraftLoadResult {
  status: DraftStatus;
  message: string;
  form: ReimbursementForm | null;
  savedAt: number;

  constructor(status: DraftStatus, message: string, form: ReimbursementForm | null, savedAt: number) {
    this.status = status;
    this.message = message;
    this.form = form;
    this.savedAt = savedAt;
  }

  isSuccess(): boolean {
    return this.status === DraftStatus.SUCCESS;
  }
}
