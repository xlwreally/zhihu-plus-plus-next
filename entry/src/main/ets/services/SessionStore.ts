import { FeedMode, MigrationModule, MigrationPhase, SessionSnapshot, SettingHint } from '../models/ZhihuModels';
import { preferenceStore } from './PreferenceStore';

const MIGRATION_MODULES: MigrationModule[] = [
  {
    name: '认证与 Cookie',
    status: 'planned',
    summary: '迁移 Android 版 AccountData、Cookie 持久化和登录态恢复。',
    sourceArea: 'app/src/main/java/.../data/AccountData.kt'
  },
  {
    name: '知乎接口层',
    status: 'planned',
    summary: '接管 Ktor 请求、Header 组装和 snake_case 转 camelCase。',
    sourceArea: 'app/src/main/java/.../data + util/Utils.kt'
  },
  {
    name: '阅读 Web 壳',
    status: 'planned',
    summary: '用鸿蒙 Web 组件重建文章/回答阅读和导出前渲染外壳。',
    sourceArea: 'app/src/main/java/.../ui/components/WebviewComp.kt'
  },
  {
    name: '本地存储',
    status: 'planned',
    summary: '用 Preferences 与关系型数据库替代 SharedPreferences 和 Room。',
    sourceArea: 'app/src/main/java/.../viewmodel/filter + viewmodel/local'
  },
  {
    name: '本地推荐与过滤',
    status: 'blocked',
    summary: '依赖爬取缓存、排序策略和可选的 AI/embedding 能力，建议在 Lite MVP 之后补。',
    sourceArea: 'app/src/main/java/.../viewmodel/local + nlp'
  }
];

const MIGRATION_PHASES: MigrationPhase[] = [
  {
    title: 'Phase 1',
    goal: '先打通 Lite MVP',
    modules: ['认证与 Cookie', '知乎接口层', '首页信息流', '问题/回答/文章阅读']
  },
  {
    title: 'Phase 2',
    goal: '补齐常用能力',
    modules: ['评论', '收藏夹', '历史记录', '分享与链接跳转']
  },
  {
    title: 'Phase 3',
    goal: '再迁重功能',
    modules: ['TTS', '图片/PDF/Markdown 导出', '本地推荐', 'AI 过滤']
  }
];

const SETTING_HINTS: SettingHint[] = [
  {
    title: '工程模型',
    value: 'Stage Model + ArkTS + 单 entry HAP'
  },
  {
    title: '目标 API',
    value: 'HarmonyOS 6.0.2(22)'
  },
  {
    title: '迁移策略',
    value: '保协议与数据模型，重写页面层和平台层'
  }
];

export class SessionStore {
  static snapshot(): SessionSnapshot {
    return preferenceStore.snapshot();
  }

  static selectFeedMode(feedMode: FeedMode): SessionSnapshot {
    return preferenceStore.updateFeedMode(feedMode);
  }

  static setCapability(
    capability: 'hasSigningBridge' | 'hasWebReadingShell' | 'hasPersistentStorage',
    enabled: boolean
  ): SessionSnapshot {
    return preferenceStore.markCapability(capability, enabled);
  }

  static reset(): SessionSnapshot {
    return preferenceStore.reset();
  }

  static migrationModules(): MigrationModule[] {
    return MIGRATION_MODULES;
  }

  static migrationPhases(): MigrationPhase[] {
    return MIGRATION_PHASES;
  }

  static settingHints(): SettingHint[] {
    return SETTING_HINTS;
  }
}
