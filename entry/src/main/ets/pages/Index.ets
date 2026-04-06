import { FeedMode, MigrationModule, MigrationPhase, SessionSnapshot, SettingHint } from '../models/ZhihuModels';
import { SessionStore } from '../services/SessionStore';
import { formatTimestamp } from '../utils/Time';

type MainTabKey = 'overview' | 'modules' | 'settings';

interface FeedModeOption {
  readonly key: FeedMode;
  readonly title: string;
  readonly summary: string;
}

interface MainTabOption {
  readonly key: MainTabKey;
  readonly title: string;
  readonly subtitle: string;
}

const FEED_MODE_OPTIONS: FeedModeOption[] = [
  { key: 'mixed', title: '混合流', summary: '保留 Android 默认推荐策略，适合作为 Lite MVP 的默认入口。' },
  { key: 'web', title: 'Web 流', summary: '优先迁移网页端 API 与签名链路，落地速度最快。' },
  { key: 'android', title: '安卓流', summary: '预留模拟 Android 端接口的扩展位，后续按需接入。' },
  { key: 'local', title: '本地流', summary: '留给本地爬取与排序引擎，建议在 MVP 完成后再迁。' }
];

const MAIN_TABS: MainTabOption[] = [
  { key: 'overview', title: '概览', subtitle: '当前状态' },
  { key: 'modules', title: '模块', subtitle: '迁移拆解' },
  { key: 'settings', title: '设置', subtitle: '工程约束' }
];

@Entry
@Component
struct Index {
  @State private selectedMainTab: MainTabKey = 'overview';
  @State private selectedFeedMode: FeedMode = 'mixed';
  @State private session: SessionSnapshot = SessionStore.snapshot();
  @State private generatedAt: string = formatTimestamp(new Date());

  private modules: MigrationModule[] = SessionStore.migrationModules();
  private phases: MigrationPhase[] = SessionStore.migrationPhases();
  private settingHints: SettingHint[] = SessionStore.settingHints();

  aboutToAppear(): void {
    this.refreshSnapshot();
  }

  private refreshSnapshot(): void {
    this.session = SessionStore.snapshot();
    this.selectedFeedMode = this.session.feedMode;
    this.generatedAt = formatTimestamp(new Date());
  }

  private selectFeedMode(mode: FeedMode): void {
    SessionStore.selectFeedMode(mode);
    this.refreshSnapshot();
  }

  private statusText(status: 'planned' | 'in-progress' | 'blocked'): string {
    if (status === 'in-progress') {
      return '进行中';
    }
    if (status === 'blocked') {
      return '暂缓';
    }
    return '已规划';
  }

  private statusTint(status: 'planned' | 'in-progress' | 'blocked'): string {
    if (status === 'in-progress') {
      return '#E6ECFDF3';
    }
    if (status === 'blocked') {
      return '#FFFCE8E6';
    }
    return '#E8EEF5FF';
  }

  private statusColor(status: 'planned' | 'in-progress' | 'blocked'): string {
    if (status === 'in-progress') {
      return '#0F9D58';
    }
    if (status === 'blocked') {
      return '#D93025';
    }
    return '#1856D6';
  }

  @Builder
  private BackgroundLayer(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('88%')
        .height(300)
        .margin({ left: 18, top: 6 })
        .backgroundColor('#364F87FF')
        .borderRadius(64)

      Column()
        .width('46%')
        .height(220)
        .margin({ left: 252, top: 36 })
        .backgroundColor('#286AD8FF')
        .borderRadius(52)

      Column()
        .width('58%')
        .height(180)
        .margin({ left: 22, top: 210 })
        .backgroundColor('#2CC4E8E8')
        .borderRadius(44)

      Column()
        .width('72%')
        .height(260)
        .margin({ left: 112, top: 460 })
        .backgroundColor('#14FFFFFF')
        .borderRadius(60)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private TopChrome(): void {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('Zhihu++')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text('NEXT')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0A59F7')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#E7F0FF')
            .borderRadius(16)
        }

        Text('按 HarmonyOS NEXT 的 Stage 模型重建页面层，用蓝白主调、悬浮材质和超圆角卡片重做信息架构。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#334155')
      }
      .alignItems(HorizontalAlign.Start)

      Row({ space: 10 }) {
        Text(`预览 ${this.generatedAt}`)
          .fontSize(12)
          .fontColor('#1856D6')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#EDF4FF')
          .borderRadius(16)

        Text('高级材质')
          .fontSize(12)
          .fontColor('#0E7490')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#E8FBFF')
          .borderRadius(16)

        Text('Lite MVP')
          .fontSize(12)
          .fontColor('#0F9D58')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#EAF9F0')
          .borderRadius(16)
      }

      Row({ space: 8 }) {
        ForEach(MAIN_TABS, (item: MainTabOption) => {
          Column({ space: 4 }) {
            Text(item.title)
              .fontSize(15)
              .fontWeight(this.selectedMainTab === item.key ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.selectedMainTab === item.key ? '#0A59F7' : '#475569')
            Text(item.subtitle)
              .fontSize(11)
              .fontColor(this.selectedMainTab === item.key ? '#1856D6' : '#94A3B8')
          }
          .width('31%')
          .padding({ top: 12, bottom: 12 })
          .backgroundColor(this.selectedMainTab === item.key ? '#F7FBFF' : '#00FFFFFF')
          .borderRadius(22)
          .onClick(() => {
            this.selectedMainTab = item.key;
          })
        }, (item: MainTabOption) => item.key)
      }
      .padding(8)
      .backgroundColor('#A8FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .border({
        width: 1,
        color: '#5FFFFFFF'
      })
      .borderRadius(28)
      .shadow({
        radius: 20,
        color: '#12003D9C',
        offsetX: 0,
        offsetY: 10
      })
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 26, bottom: 18 })
    .margin({ left: 16, right: 16, top: 14 })
    .backgroundColor('#B8FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({
      width: 1,
      color: '#78FFFFFF'
    })
    .borderRadius(34)
    .shadow({
      radius: 28,
      color: '#180044B8',
      offsetX: 0,
      offsetY: 14
    })
  }

  @Builder
  private HeroPanel(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 18 }) {
        Text('迁移不是兼容层，而是重新设计一套更适合鸿蒙的前台结构。')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .lineHeight(34)
          .fontColor('#F8FBFF')

        Text('保留知乎协议、账号模型与过滤规则；重写导航、阅读页、系统交互与材质表达。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#DCEBFF')

        Row({ space: 12 }) {
          this.GlassTag('Stage 模型')
          this.GlassTag('ArkTS')
          this.GlassTag('蓝白悬浮')
        }

        Row({ space: 12 }) {
          this.HeroMetric('登录层', '待迁')
          this.HeroMetric('阅读壳', '预留')
          this.HeroMetric('签名桥', '待接')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding(22)
      .width('100%')
      .backgroundColor('#284F87FF')
      .borderRadius(34)

      Column()
        .width('62%')
        .height(96)
        .margin({ left: 128, top: 22 })
        .backgroundColor('#24FFFFFF')
        .borderRadius(28)

      Column()
        .width('36%')
        .height(76)
        .margin({ left: 20, top: 142 })
        .backgroundColor('#2C6CEAF8')
        .borderRadius(24)
    }
    .margin({ left: 16, right: 16, top: 12, bottom: 14 })
  }

  @Builder
  private GlassTag(title: string): void {
    Text(title)
      .fontSize(12)
      .fontColor('#F8FBFF')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#18FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({
        width: 1,
        color: '#34FFFFFF'
      })
      .borderRadius(16)
  }

  @Builder
  private HeroMetric(label: string, value: string): void {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text(label)
        .fontSize(11)
        .fontColor('#CFE2FF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10, left: 12, right: 12 })
    .backgroundColor('#16FFFFFF')
    .borderRadius(18)
  }

  @Builder
  private SessionBoard(): void {
    Column({ space: 16 }) {
      this.SectionLabel('会话与能力', '把账号态、Cookie、推荐模式和平台能力拆成可替换的独立层。')

      Row({ space: 10 }) {
        this.StatusMetric('账号', this.session.accountName)
        this.StatusMetric('Cookie', `${this.session.cookieCount}`)
        this.StatusMetric('模式', this.session.feedMode.toUpperCase())
      }

      Row({ space: 10 }) {
        this.CapabilityPill('签名桥', this.session.hasSigningBridge)
        this.CapabilityPill('Web 阅读壳', this.session.hasWebReadingShell)
        this.CapabilityPill('持久化', this.session.hasPersistentStorage)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor('#B8FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({
      width: 1,
      color: '#6FFFFFFF'
    })
    .borderRadius(30)
    .shadow({
      radius: 18,
      color: '#140050B5',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  private SectionLabel(title: string, summary: string): void {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(summary)
        .fontSize(13)
        .lineHeight(21)
        .fontColor('#475569')
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private StatusMetric(label: string, value: string): void {
    Column({ space: 5 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(label)
        .fontSize(11)
        .fontColor('#64748B')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor('#F8FBFF')
    .borderRadius(22)
  }

  @Builder
  private CapabilityPill(title: string, enabled: boolean): void {
    Text(`${title} ${enabled ? '已预留' : '未接入'}`)
      .fontSize(12)
      .fontColor(enabled ? '#0F9D58' : '#9A3412')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(enabled ? '#EAF9F0' : '#FFF1E7')
      .borderRadius(16)
  }

  @Builder
  private FeedModeBoard(): void {
    Column({ space: 14 }) {
      this.SectionLabel('推荐流模式', '用鸿蒙风格的胶囊分层重做切换区，后续把内存态替换成真实 Preferences。')

      ForEach(FEED_MODE_OPTIONS, (item: FeedModeOption) => {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(item.title)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text(item.summary)
              .fontSize(13)
              .lineHeight(20)
              .fontColor('#475569')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.selectedFeedMode === item.key ? '当前模式' : '切换')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedFeedMode === item.key ? '#0A59F7' : '#475569')
            .padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .backgroundColor(this.selectedFeedMode === item.key ? '#EAF2FF' : '#F4F7FB')
            .borderRadius(18)
        }
        .padding(16)
        .backgroundColor(this.selectedFeedMode === item.key ? '#F8FBFF' : '#FCFDFF')
        .border({
          width: 1,
          color: this.selectedFeedMode === item.key ? '#CFE0FF' : '#EEF2F7'
        })
        .borderRadius(24)
        .onClick(() => {
          this.selectFeedMode(item.key);
        })
      }, (item: FeedModeOption) => item.key)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor('#CCFFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({
      width: 1,
      color: '#82FFFFFF'
    })
    .borderRadius(30)
  }

  @Builder
  private DirectionBoard(): void {
    Column({ space: 12 }) {
      this.SectionLabel('材质与规范', '设计方向基于 HarmonyOS 官方设计理念中的蓝白色彩、舒适圆角、悬浮与轻拟物表达。')

      Row({ space: 10 }) {
        this.DirectionTile('蓝白主调', '纯净、克制，适合信息型应用。', '#EEF5FF')
        this.DirectionTile('悬浮层级', '通过模糊和阴影建立前后景。', '#EFFCFD')
      }

      Row({ space: 10 }) {
        this.DirectionTile('舒适圆角', '卡片和导航都使用更柔和的超圆角。', '#F8F3FF')
        this.DirectionTile('轻拟物', '少量体积感，不做 Android 式平铺。', '#FFF7ED')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .margin({ left: 16, right: 16, bottom: 28 })
    .backgroundColor('#B8FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({
      width: 1,
      color: '#82FFFFFF'
    })
    .borderRadius(30)
  }

  @Builder
  private DirectionTile(title: string, summary: string, surface: string): void {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(summary)
        .fontSize(12)
        .lineHeight(19)
        .fontColor('#475569')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(surface)
    .borderRadius(22)
  }

  @Builder
  private ModuleBoard(item: MigrationModule): void {
    Column({ space: 12 }) {
      Row() {
        Text(item.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)

        Text(this.statusText(item.status))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(item.status))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(this.statusTint(item.status))
          .borderRadius(18)
      }

      Text(item.summary)
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#334155')

      Text(item.sourceArea)
        .fontSize(12)
        .lineHeight(18)
        .fontColor('#64748B')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#F8FBFF')
        .borderRadius(18)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor('#CCFFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({
      width: 1,
      color: '#84FFFFFF'
    })
    .borderRadius(28)
  }

  @Builder
  private PhaseBoard(phase: MigrationPhase): void {
    Column({ space: 12 }) {
      Text(phase.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text(phase.goal)
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#334155')

      ForEach(phase.modules, (moduleName: string) => {
        Text(moduleName)
          .fontSize(13)
          .fontColor('#1E293B')
          .padding({ left: 12, right: 12, top: 9, bottom: 9 })
          .backgroundColor('#F5F9FF')
          .borderRadius(16)
      }, (moduleName: string) => moduleName)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor('#B8FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({
      width: 1,
      color: '#78FFFFFF'
    })
    .borderRadius(28)
  }

  @Builder
  private SettingBoard(item: SettingHint): void {
    Column({ space: 8 }) {
      Text(item.title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(item.value)
        .fontSize(13)
        .lineHeight(21)
        .fontColor('#475569')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor('#CCFFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({
      width: 1,
      color: '#84FFFFFF'
    })
    .borderRadius(26)
  }

  @Builder
  private OverviewSection(): void {
    Column() {
      this.HeroPanel()
      this.SessionBoard()
      this.FeedModeBoard()
      this.DirectionBoard()
    }
  }

  @Builder
  private ModulesSection(): void {
    Column() {
      this.SectionHeader('迁移模块', '先拆协议和状态，再逐步替换页面与平台能力。')
      ForEach(this.modules, (item: MigrationModule) => {
        this.ModuleBoard(item)
      }, (item: MigrationModule) => item.name)

      this.SectionHeader('迁移节奏', '按 Lite MVP 到重功能的顺序推进，避免把难点一次性堆满。')
      ForEach(this.phases, (item: MigrationPhase) => {
        this.PhaseBoard(item)
      }, (item: MigrationPhase) => item.title)
    }
  }

  @Builder
  private SettingsSection(): void {
    Column() {
      this.SectionHeader('工程设置', '这些卡片描述当前鸿蒙工程的约束与建议，不再使用默认表单式布局。')
      ForEach(this.settingHints, (item: SettingHint) => {
        this.SettingBoard(item)
      }, (item: SettingHint) => item.title)

      this.SettingBoard({
        title: '下一步建议',
        value: '优先把 Preferences 持久化接入 SessionStore，再把 AccountData、Cookie、zse96 签名桥和 Web 阅读壳迁进来。'
      })
    }
  }

  @Builder
  private SectionHeader(title: string, summary: string): void {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(summary)
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#475569')
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 8, bottom: 14 })
  }

  @Builder
  private ActiveContent(): void {
    if (this.selectedMainTab === 'overview') {
      this.OverviewSection()
    } else if (this.selectedMainTab === 'modules') {
      this.ModulesSection()
    } else {
      this.SettingsSection()
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.BackgroundLayer()

      Scroll() {
        Column() {
          Column()
            .height(208)
            .width('100%')

          this.ActiveContent()

          Column()
            .height(34)
            .width('100%')
        }
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      this.TopChrome()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EEF3F8')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
