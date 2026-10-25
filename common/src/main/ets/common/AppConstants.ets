/**
 * 差旅报销 - 全局常量定义。
 * 仅存放纯值常量，不依赖任何其他模块，避免循环引用。
 */
export class AppConstants {
  /** preferences 数据库名称 */
  static readonly STORE_NAME: string = 'reimbursement_store';
  /** 草稿存储键 */
  static readonly DRAFT_KEY: string = 'draft_form';

  /** 费用类型（固定枚举，不支持用户自定义） */
  static readonly EXPENSE_CATEGORIES: string[] = ['交通', '住宿', '餐饮', '通讯', '其他'];
  static readonly CATEGORY_TRANSPORT: string = '交通';

  /** 主题色与文本色 */
  static readonly COLOR_PRIMARY: string = '#2E6BE6';
  static readonly COLOR_PRIMARY_DARK: string = '#1F4FB8';
  static readonly COLOR_BACKGROUND: string = '#F2F4F8';
  static readonly COLOR_CARD: string = '#FFFFFF';
  static readonly COLOR_TEXT: string = '#1F2733';
  static readonly COLOR_TEXT_SECONDARY: string = '#7A869A';
  static readonly COLOR_BORDER: string = '#E3E8EF';
  static readonly COLOR_DANGER: string = '#E5442E';
  static readonly COLOR_SUCCESS: string = '#1F9D55';
  static readonly COLOR_MASK: string = '#66000000';
  static readonly COLOR_CHIP_BG: string = '#EEF2FA';

  /** 间距（vp） */
  static readonly SPACE_XS: number = 4;
  static readonly SPACE_SM: number = 8;
  static readonly SPACE_MD: number = 12;
  static readonly SPACE_LG: number = 16;
  static readonly SPACE_XL: number = 24;

  /** 圆角（vp） */
  static readonly RADIUS_SM: number = 8;
  static readonly RADIUS_MD: number = 12;
  static readonly RADIUS_LG: number = 18;

  /** 字号（fp） */
  static readonly FONT_TITLE: number = 20;
  static readonly FONT_SUBTITLE: number = 15;
  static readonly FONT_BODY: number = 14;
  static readonly FONT_SMALL: number = 12;

  /** 弹窗尺寸（vp） */
  static readonly POPUP_MAX_WIDTH: number = 520;
  static readonly CALC_MAX_WIDTH: number = 360;

  /** 输入框高度（vp） */
  static readonly INPUT_HEIGHT: number = 40;

  /** 诊断开关相关文案 */
  static readonly DIAGNOSTIC_ON_TEXT: string = '诊断：存储失败';
  static readonly DIAGNOSTIC_TOGGLE_TIP: string = '长按标题可切换存储故障诊断开关';
}
