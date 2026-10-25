import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DraftLoadResult, DraftStatus, ExpenseItem, OperationResult, ReimbursementForm } from '../model/ReimbursementModels';
import { AppConstants } from '../common/AppConstants';
import { ErrorUtil } from '../common/AppUtils';

const DOMAIN: number = 0x0001;
const TAG: string = 'DraftRepository';

/** 序列化用的中间结构（写入侧，字段必填） */
class ExpenseRawPayload {
  id: string = '';
  category: string = '';
  date: string = '';
  amount: string = '';
  remark: string = '';
}

class FormRawPayload {
  traveler: string = '';
  department: string = '';
  purpose: string = '';
  startDate: string = '';
  endDate: string = '';
  items: ExpenseRawPayload[] = [];
}

class DraftRawPayload {
  savedAt: number = 0;
  form: FormRawPayload = new FormRawPayload();
}

/** 反序列化用的中间结构（读取侧，字段可能缺失，必须逐个 typeof 校验） */
interface ExpenseRaw {
  id?: string;
  category?: string;
  date?: string;
  amount?: string;
  remark?: string;
}

interface FormRaw {
  traveler?: string;
  department?: string;
  purpose?: string;
  startDate?: string;
  endDate?: string;
  items?: ExpenseRaw[];
}

interface DraftRaw {
  savedAt?: number;
  form?: FormRaw;
}

/**
 * 草稿持久化：preferences + JSON 编解码。
 * - 保存后必须 flush()，否则进程退出后数据可能丢失；
 * - 读取区分 success / empty / error 三态；
 * - 解析结果先落到原始接口，再逐字段校验后构造领域对象，任何字段缺失或类型不符均返回 error。
 */
export class DraftRepository {
  /** 保存当前表单快照 */
  static async save(context: common.UIAbilityContext, form: ReimbursementForm | null): Promise<OperationResult> {
    try {
      if (form === null) {
        return OperationResult.fail('存储失败：没有可保存的表单');
      }
      const payload: string = DraftRepository.encode(form);
      const store: preferences.Preferences = await preferences.getPreferences(context, {
        name: AppConstants.STORE_NAME
      });
      await store.put(AppConstants.DRAFT_KEY, payload);
      await store.flush();
      hilog.info(DOMAIN, TAG, '%{public}s', '草稿保存成功');
      return OperationResult.ok('临时保存成功');
    } catch (error) {
      hilog.error(DOMAIN, TAG, '保存草稿失败: %{public}s', JSON.stringify(error));
      return OperationResult.fail(`存储失败：${ErrorUtil.message(error, '本地存储不可用')}`);
    }
  }

  /** 读取最近一次草稿 */
  static async load(context: common.UIAbilityContext): Promise<DraftLoadResult> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, {
        name: AppConstants.STORE_NAME
      });
      const raw: preferences.ValueType = await store.get(AppConstants.DRAFT_KEY, '');
      if (typeof raw !== 'string') {
        return new DraftLoadResult(DraftStatus.EMPTY, '暂无历史数据', null, 0);
      }
      const text: string = raw as string;
      if (text.trim().length === 0) {
        return new DraftLoadResult(DraftStatus.EMPTY, '暂无历史数据', null, 0);
      }
      return DraftRepository.decode(text);
    } catch (error) {
      hilog.error(DOMAIN, TAG, '读取草稿失败: %{public}s', JSON.stringify(error));
      return new DraftLoadResult(DraftStatus.ERROR, `读取失败：${ErrorUtil.message(error, '本地存储不可用')}`, null, 0);
    }
  }

  /** 序列化为 JSON 字符串，失败抛错 */
  static encode(form: ReimbursementForm): string {
    try {
      const items: ExpenseRawPayload[] = [];
      const source: ExpenseItem[] = form.items ?? [];
      for (let i = 0; i < source.length; i++) {
        const item: ExpenseItem | undefined = source[i];
        if (item === undefined || item === null) {
          continue;
        }
        const raw: ExpenseRawPayload = new ExpenseRawPayload();
        raw.id = item.id ?? '';
        raw.category = item.category ?? '';
        raw.date = item.date ?? '';
        raw.amount = item.amount ?? '';
        raw.remark = item.remark ?? '';
        items.push(raw);
      }
      const formRaw: FormRawPayload = new FormRawPayload();
      formRaw.traveler = form.traveler ?? '';
      formRaw.department = form.department ?? '';
      formRaw.purpose = form.purpose ?? '';
      formRaw.startDate = form.startDate ?? '';
      formRaw.endDate = form.endDate ?? '';
      formRaw.items = items;

      const payload: DraftRawPayload = new DraftRawPayload();
      payload.savedAt = Date.now();
      payload.form = formRaw;
      return JSON.stringify(payload);
    } catch (error) {
      throw new Error(ErrorUtil.message(error, '草稿数据无法序列化'));
    }
  }

  /** 反序列化并逐字段校验 */
  static decode(text: string): DraftLoadResult {
    let parsed: DraftRaw | null = null;
    try {
      parsed = JSON.parse(text) as DraftRaw;
    } catch (error) {
      hilog.error(DOMAIN, TAG, '草稿 JSON 解析失败: %{public}s', JSON.stringify(error));
      return new DraftLoadResult(DraftStatus.ERROR, '历史数据已损坏（JSON 解析失败），已保留当前表单', null, 0);
    }
    try {
      if (parsed === null || parsed === undefined) {
        return new DraftLoadResult(DraftStatus.ERROR, '历史数据已损坏（内容为空）', null, 0);
      }
      const draft: DraftRaw = parsed as DraftRaw;
      const rawForm: FormRaw | null | undefined = draft.form;
      if (rawForm === undefined || rawForm === null) {
        return new DraftLoadResult(DraftStatus.ERROR, '历史数据已损坏（缺少表单内容）', null, 0);
      }
      const traveler: string | undefined = rawForm.traveler;
      const department: string | undefined = rawForm.department;
      const purpose: string | undefined = rawForm.purpose;
      const startDate: string | undefined = rawForm.startDate;
      const endDate: string | undefined = rawForm.endDate;
      if (typeof traveler !== 'string' || typeof department !== 'string' || typeof purpose !== 'string'
        || typeof startDate !== 'string' || typeof endDate !== 'string') {
        return new DraftLoadResult(DraftStatus.ERROR, '历史数据已损坏（基本信息字段类型不符）', null, 0);
      }
      const rawItems: ExpenseRaw[] | null | undefined = rawForm.items;
      if (rawItems === undefined || rawItems === null || !Array.isArray(rawItems)) {
        return new DraftLoadResult(DraftStatus.ERROR, '历史数据已损坏（费用明细格式不符）', null, 0);
      }
      const items: ExpenseItem[] = [];
      for (let i = 0; i < rawItems.length; i++) {
        const rawItem: ExpenseRaw | null | undefined = rawItems[i];
        if (rawItem === undefined || rawItem === null) {
          return new DraftLoadResult(DraftStatus.ERROR, `历史数据已损坏（第 ${i + 1} 条明细为空）`, null, 0);
        }
        const id: string | undefined = rawItem.id;
        const category: string | undefined = rawItem.category;
        const date: string | undefined = rawItem.date;
        const amount: string | undefined = rawItem.amount;
        const remark: string | undefined = rawItem.remark;
        if (typeof id !== 'string' || typeof category !== 'string' || typeof date !== 'string'
          || typeof amount !== 'string' || typeof remark !== 'string') {
          return new DraftLoadResult(DraftStatus.ERROR, `历史数据已损坏（第 ${i + 1} 条明细字段类型不符）`, null, 0);
        }
        items.push(new ExpenseItem(id, category, date, amount, remark));
      }
      const savedAtRaw: number | undefined = draft.savedAt;
      const savedAt: number = typeof savedAtRaw === 'number' && Number.isFinite(savedAtRaw) ? savedAtRaw : 0;
      const form: ReimbursementForm = new ReimbursementForm(traveler, department, purpose, startDate, endDate, items);
      return new DraftLoadResult(DraftStatus.SUCCESS, '历史数据加载成功', form, savedAt);
    } catch (error) {
      hilog.error(DOMAIN, TAG, '草稿重建失败: %{public}s', JSON.stringify(error));
      return new DraftLoadResult(DraftStatus.ERROR, `历史数据已损坏：${ErrorUtil.message(error, '无法还原')}`, null, 0);
    }
  }
}
