import { ExpenseItem, OperationResult, ReimbursementForm } from '../model/ReimbursementModels';
import { AmountUtil } from './AmountUtil';
import { DateUtil, ErrorUtil } from '../common/AppUtils';

/**
 * 表单校验。
 * 校验顺序（返回首个失败原因）：出差事由必填 → 至少一条明细 → 每条金额合法且 > 0 → 起止日期合法。
 */
export class FormValidator {
  static validate(form: ReimbursementForm | null): OperationResult {
    try {
      if (form === null) {
        return OperationResult.fail('表单数据缺失，请重新填写', 'form');
      }
      // 1. 出差事由必填
      const purpose: string = form.purpose?.trim() ?? '';
      if (purpose.length === 0) {
        return OperationResult.fail('请填写出差事由', 'purpose');
      }
      // 2. 至少一条明细
      const items: ExpenseItem[] = form.items ?? [];
      if (items.length === 0) {
        return OperationResult.fail('请至少添加一条费用明细', 'items');
      }
      // 3. 逐条金额合法且大于 0
      for (let i = 0; i < items.length; i++) {
        const item: ExpenseItem | undefined = items[i];
        if (item === undefined || item === null) {
          return OperationResult.fail(`第 ${i + 1} 条明细数据缺失`, `items.${i}`);
        }
        const amountText: string = item.amount?.trim() ?? '';
        if (amountText.length === 0) {
          return OperationResult.fail(`第 ${i + 1} 条明细未填写金额`, `items.${i}.amount`);
        }
        let amount: number = 0;
        try {
          amount = AmountUtil.parse(amountText);
        } catch (error) {
          return OperationResult.fail(`第 ${i + 1} 条明细金额不合法：${ErrorUtil.message(error, '格式错误')}`,
            `items.${i}.amount`);
        }
        if (amount <= 0) {
          return OperationResult.fail(`第 ${i + 1} 条明细金额必须大于 0`, `items.${i}.amount`);
        }
      }
      // 4. 起止日期合法
      const startDate: string = form.startDate ?? '';
      const endDate: string = form.endDate ?? '';
      if (!DateUtil.isValid(startDate)) {
        return OperationResult.fail('请选择合法的开始日期', 'startDate');
      }
      if (!DateUtil.isValid(endDate)) {
        return OperationResult.fail('请选择合法的结束日期', 'endDate');
      }
      if (endDate < startDate) {
        return OperationResult.fail('结束日期不能早于开始日期', 'endDate');
      }
      return OperationResult.ok('校验通过');
    } catch (error) {
      return OperationResult.fail(`表单校验失败：${ErrorUtil.message(error, '未知错误')}`, 'form');
    }
  }
}
