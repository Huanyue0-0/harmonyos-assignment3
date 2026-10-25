import {
  AmountUtil,
  DraftLoadResult,
  DraftStatus,
  ErrorUtil,
  ExpenseItem,
  FormValidator,
  OperationResult,
  ReimbursementForm,
  DraftRepository
} from '@ohos/common';
import { common } from '@kit.AbilityKit';

/**
 * 报销单业务编排（ViewModel）。
 * 视图层只负责采集输入与展示，所有增删改、合计、校验、存取编排集中在此。
 * 约定：对 form 的修改都保持同一实例引用，仅替换 items 数组引用，以适配状态管理 V1 的观测规则。
 */
export class ReimbursementViewModel {
  /** 新增一条明细：校验金额 > 0 后再入库；失败返回原因且不追加 */
  static addItem(form: ReimbursementForm | null, draft: ExpenseItem | null): OperationResult {
    try {
      if (form === null) {
        return OperationResult.fail('表单数据缺失，请重新打开页面');
      }
      if (draft === null) {
        return OperationResult.fail('新增明细数据缺失');
      }
      const amountText: string = draft.amount?.trim() ?? '';
      if (amountText.length === 0) {
        return OperationResult.fail('请填写费用金额', 'items.amount');
      }
      let amount: number = 0;
      try {
        amount = AmountUtil.parse(amountText);
      } catch (error) {
        return OperationResult.fail(`金额不合法：${ErrorUtil.message(error, '请输入数字')}`, 'items.amount');
      }
      if (amount <= 0) {
        return OperationResult.fail('金额必须大于 0', 'items.amount');
      }
      if (!draft.date || draft.date.length === 0) {
        return OperationResult.fail('请选择费用发生日期', 'items.date');
      }
      const category: string = draft.category?.trim() ?? '';
      if (category.length === 0) {
        return OperationResult.fail('请选择费用类型', 'items.category');
      }
      const item: ExpenseItem = new ExpenseItem(draft.id, category, draft.date,
        AmountUtil.format(amount), draft.remark ?? '');
      form.items = form.appendItem(item);
      return OperationResult.ok('已添加 1 条费用明细');
    } catch (error) {
      return OperationResult.fail(`添加明细失败：${ErrorUtil.message(error, '未知错误')}`, 'items');
    }
  }

  /** 删除指定明细 */
  static removeItem(form: ReimbursementForm | null, id: string): OperationResult {
    try {
      if (form === null) {
        return OperationResult.fail('表单数据缺失');
      }
      const items: ExpenseItem[] = form.items ?? [];
      if (items.length === 0) {
        return OperationResult.fail('当前没有可删除的明细');
      }
      const target: ExpenseItem | null = form.findItemById(id);
      if (target === null) {
        return OperationResult.fail('未找到要删除的明细');
      }
      form.items = form.removeItemById(id);
      return OperationResult.ok('已删除 1 条明细');
    } catch (error) {
      return OperationResult.fail(`删除明细失败：${ErrorUtil.message(error, '未知错误')}`, 'items');
    }
  }

  /**
   * 回填/修改指定明细金额。
   * 先就地更新目标对象（@Observed 通知行组件），再替换数组引用（通知列表与合计）。
   */
  static updateItemAmount(form: ReimbursementForm | null, id: string, amountText: string): OperationResult {
    try {
      if (form === null) {
        return OperationResult.fail('表单数据缺失');
      }
      const target: ExpenseItem | null = form.findItemById(id);
      if (target === null) {
        return OperationResult.fail('未找到目标明细，无法回填金额');
      }
      const trimmed: string = amountText?.trim() ?? '';
      if (trimmed.length === 0) {
        return OperationResult.fail('金额不能为空');
      }
      let amount: number = 0;
      try {
        amount = AmountUtil.parse(trimmed);
      } catch (error) {
        return OperationResult.fail(`金额不合法：${ErrorUtil.message(error, '请输入数字')}`);
      }
      if (amount <= 0) {
        return OperationResult.fail('金额必须大于 0');
      }
      target.amount = AmountUtil.format(amount);
      form.items = form.replaceItem(target);
      return OperationResult.ok('金额已更新');
    } catch (error) {
      return OperationResult.fail(`更新金额失败：${ErrorUtil.message(error, '未知错误')}`);
    }
  }

  /** 合计金额（元） */
  static total(form: ReimbursementForm | null): number {
    try {
      if (form === null) {
        return 0;
      }
      return AmountUtil.sumItems(form.items ?? []);
    } catch (error) {
      return 0;
    }
  }

  /** 合计金额展示文本（两位小数） */
  static totalText(form: ReimbursementForm | null): string {
    try {
      return AmountUtil.format(ReimbursementViewModel.total(form));
    } catch (error) {
      return '0.00';
    }
  }

  /** 提交前校验：事由 → 明细数 → 金额 → 日期 */
  static validate(form: ReimbursementForm | null): OperationResult {
    return FormValidator.validate(form);
  }

  /** 保存草稿 */
  static async saveDraft(context: common.UIAbilityContext,
    form: ReimbursementForm | null): Promise<OperationResult> {
    try {
      return await DraftRepository.save(context, form);
    } catch (error) {
      return OperationResult.fail(`存储失败：${ErrorUtil.message(error, '本地存储不可用')}`);
    }
  }

  /** 加载草稿（三态） */
  static async loadDraft(context: common.UIAbilityContext): Promise<DraftLoadResult> {
    try {
      return await DraftRepository.load(context);
    } catch (error) {
      return new DraftLoadResult(DraftStatus.ERROR, `读取失败：${ErrorUtil.message(error, '本地存储不可用')}`, null, 0);
    }
  }

  /** 重置表单为初始空状态（保留实例引用） */
  static reset(form: ReimbursementForm | null): void {
    try {
      form?.reset();
    } catch (error) {
      return;
    }
  }
}
