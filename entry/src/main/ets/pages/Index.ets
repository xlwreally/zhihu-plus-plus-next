import common from '@ohos.app.ability.common';
import { promptAction, router } from '@kit.ArkUI';
import { DailyService, DailyStoriesPage, DailyStory } from '../services/DailyService';
import { DEFAULT_SESSION_SNAPSHOT, HomeFeedItem, SessionSnapshot } from '../models/ZhihuModels';
import { HomeFeedService } from '../services/HomeFeedService';
import { LocalDebugSessionService } from '../services/LocalDebugSessionService';
import { ZhihuSessionRepository } from '../services/ZhihuSessionRepository';

type AppPortalKey = 'home' | 'follow' | 'daily' | 'history';

interface AppPortalOption {
  readonly key: AppPortalKey;
  readonly title: string;
}

interface DailySection {
  readonly date: string;
  readonly stories: DailyStory[];
}

const TOP_BAR_BASE_PADDING: number = 10;
const TOP_BAR_SCROLL_INSET: number = 68;
const BOTTOM_PORTAL_BAR_CONTENT_INSET: number = 84;
const BOTTOM_PORTAL_BAR_BASE_OFFSET: number = 8;
const SEARCH_PAGE_URL: string = 'https://www.zhihu.com/search?type=content&q=';

const APP_PORTAL_TABS: AppPortalOption[] = [
  { key: 'home', title: '主页' },
  { key: 'follow', title: '关注' },
  { key: 'daily', title: '日报' },
  { key: 'history', title: '历史' }
];

@Entry
@Component
struct Index {
  @StorageProp('topSafeAreaVp') private topSafeAreaVp: number = 0;
  @StorageProp('bottomSafeAreaVp') private bottomSafeAreaVp: number = 0;
  @StorageProp('sessionSnapshot') private sessionSnapshot: SessionSnapshot = DEFAULT_SESSION_SNAPSHOT;
  @State private selectedPortalTab: AppPortalKey = 'daily';
  @State private dailySections: DailySection[] = [];
  @State private dailyLoading: boolean = false;
  @State private dailyLoadingMore: boolean = false;
  @State private dailyError: string = '';
  @State private nextDailyDate: string = '';
  @State private homeItems: HomeFeedItem[] = [];
  @State private homeLoading: boolean = false;
  @State private homeLoadingMore: boolean = false;
  @State private homeError: string = '';
  @State private homeNextUrl: string = '';
  @State private homeHasLoaded: boolean = false;
  @State private showHomeAccountPanel: boolean = false;

  aboutToAppear(): void {
    ZhihuSessionRepository.load(this.context());
    this.applyLocalDebugSession();
    this.loadLatestDaily();
  }

  onPageShow(): void {
    if (this.selectedPortalTab === 'home' && this.sessionSnapshot.loggedIn && !this.homeHasLoaded) {
      this.loadHomeFirstPage();
    }
  }

  private context(): common.Context {
    return getContext(this) as common.Context;
  }

  private async applyLocalDebugSession(): Promise<void> {
    try {
      const applied = await LocalDebugSessionService.applyIfPresent(this.context());
      if (applied && this.selectedPortalTab === 'home' && !this.homeHasLoaded) {
        this.loadHomeFirstPage();
      }
    } catch (_) {
    }
  }

  private portalTitle(tab: AppPortalKey): string {
    if (tab === 'home') {
      return '知乎首页';
    }
    if (tab === 'daily') {
      return '知乎日报';
    }
    const selected = APP_PORTAL_TABS.find((item: AppPortalOption) => item.key === tab);
    if (selected !== undefined) {
      return selected.title;
    }
    return '知乎日报';
  }

  private topBarSubtitle(): string {
    if (this.selectedPortalTab === 'home') {
      if (!this.sessionSnapshot.loggedIn) {
        return '登录后查看真实推荐流';
      }
      if (this.homeLoading && !this.homeHasLoaded) {
        return '正在同步知乎推荐流';
      }
      return this.sessionSnapshot.accountName;
    }
    if (this.selectedPortalTab !== 'daily') {
      return this.portalPlaceholder(this.selectedPortalTab);
    }
    if (this.dailySections.length > 0) {
      return this.dateLabel(this.dailySections[0].date);
    }
    return '正在同步知乎日报';
  }

  private portalPlaceholder(tab: AppPortalKey): string {
    if (tab === 'home') {
      return '主页推荐流待加载';
    }
    if (tab === 'follow') {
      return '关注入口待迁移';
    }
    return '历史入口待迁移';
  }

  private dateLabel(date: string): string {
    if (date.length === 8) {
      return `${date.slice(4, 6)} 月 ${date.slice(6, 8)} 日`;
    }
    return date;
  }

  private openLoginPage(): void {
    router.pushUrl({
      url: 'pages/Login'
    });
  }

  private openWebContent(title: string, url: string): void {
    if (url.length === 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/WebContent',
      params: { title, url }
    });
  }

  private openSearchPage(): void {
    this.openWebContent('搜索', SEARCH_PAGE_URL);
  }

  private openSelfPage(): void {
    const data = ZhihuSessionRepository.load(this.context());
    const urlToken = data.self?.urlToken ?? '';
    if (urlToken.length === 0) {
      return;
    }
    this.showHomeAccountPanel = false;
    this.openWebContent(data.self?.name ?? '我的主页', `https://www.zhihu.com/people/${urlToken}`);
  }

  private refreshHomeFromPanel(): void {
    this.showHomeAccountPanel = false;
    this.homeItems = [];
    this.homeError = '';
    this.homeNextUrl = '';
    this.homeHasLoaded = false;
    this.loadHomeFirstPage();
  }

  private openProjectRepository(): void {
    this.showHomeAccountPanel = false;
    this.openWebContent('知乎++ 项目地址', 'https://github.com/zly2006/zhihu-plus-plus');
  }

  private showPendingSettingToast(message: string): void {
    promptAction.showToast({
      message,
      duration: 1800
    });
  }

  private logout(): void {
    ZhihuSessionRepository.clear(this.context());
    this.showHomeAccountPanel = false;
    this.homeItems = [];
    this.homeError = '';
    this.homeNextUrl = '';
    this.homeHasLoaded = false;
  }

  private async loadHomeFirstPage(): Promise<void> {
    if (this.homeLoading || !this.sessionSnapshot.loggedIn) {
      return;
    }
    this.homeLoading = true;
    this.homeError = '';
    try {
      const page = await HomeFeedService.loadFirstPage(this.context());
      this.homeItems = page.items;
      this.homeNextUrl = page.paging.nextUrl;
      this.homeHasLoaded = true;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.homeError = `主页加载失败：${message}`;
    } finally {
      this.homeLoading = false;
    }
  }

  private async loadMoreHome(): Promise<void> {
    if (this.homeLoadingMore || this.homeNextUrl.length === 0) {
      return;
    }
    this.homeLoadingMore = true;
    try {
      const page = await HomeFeedService.loadNextPage(this.context(), this.homeNextUrl);
      const existed = new Set<string>(this.homeItems.map((item: HomeFeedItem) => item.id));
      const merged = [...this.homeItems];
      page.items.forEach((item: HomeFeedItem) => {
        if (!existed.has(item.id)) {
          merged.push(item);
        }
      });
      this.homeItems = merged;
      this.homeNextUrl = page.paging.nextUrl;
      this.homeError = '';
      this.homeHasLoaded = true;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.homeError = `主页继续加载失败：${message}`;
    } finally {
      this.homeLoadingMore = false;
    }
  }

  private async loadLatestDaily(): Promise<void> {
    if (this.dailyLoading) {
      return;
    }

    this.dailyLoading = true;
    this.dailyError = '';
    try {
      const page: DailyStoriesPage = await DailyService.loadLatest();
      this.dailySections = [page];
      this.nextDailyDate = page.date;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.dailyError = `日报加载失败：${message}`;
    } finally {
      this.dailyLoading = false;
    }
  }

  private async loadMoreDaily(): Promise<void> {
    if (this.dailyLoadingMore || this.nextDailyDate.length === 0) {
      return;
    }

    this.dailyLoadingMore = true;
    try {
      const page: DailyStoriesPage = await DailyService.loadBefore(this.nextDailyDate);
      this.dailySections = [...this.dailySections, page];
      this.nextDailyDate = page.date;
      this.dailyError = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.dailyError = `日报继续加载失败：${message}`;
    } finally {
      this.dailyLoadingMore = false;
    }
  }

  private handleContentScrollEdge(side: Edge): void {
    if (side !== Edge.Bottom) {
      return;
    }
    if (this.selectedPortalTab === 'home' && this.homeHasLoaded && this.homeNextUrl.length > 0) {
      this.loadMoreHome();
      return;
    }
    if (this.selectedPortalTab === 'daily' && this.dailySections.length > 0 && this.nextDailyDate.length > 0) {
      this.loadMoreDaily();
    }
  }

  private topBarScrollInset(): number {
    return this.topSafeAreaVp + TOP_BAR_SCROLL_INSET;
  }

  @Builder
  private TopBar(): void {
    if (this.selectedPortalTab === 'home') {
      Stack() {
        Stack() {
          Row() {
            Column()
              .width(196)
              .height(48)
              .borderRadius(24)
              .backgroundColor('#01FFFFFF')
              .shadow({
                radius: 34,
                color: '#55A8D8FF',
                offsetX: -10,
                offsetY: 8
              })

            Blank()
              .layoutWeight(1)

            Column()
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor('#01FFFFFF')
              .shadow({
                radius: 26,
                color: '#40FFFFFF',
                offsetX: 6,
                offsetY: -4
              })
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 3, bottom: 3 })

          Row({ space: 12 }) {
            Row({ space: 10 }) {
              Text('⌕')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
                .width(16)
                .textAlign(TextAlign.Center)

              Text('搜索')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .height(46)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#66FFFFFF')
            .backgroundBlurStyle(BlurStyle.Thick)
            .border({
              width: 1,
              color: '#4DFFFFFF'
            })
            .borderRadius(27)
            .shadow({
              radius: 18,
              color: '#1A2E6B9A',
              offsetX: 0,
              offsetY: 8
            })
            .onClick(() => {
              this.openSearchPage();
            })

            Stack({ alignContent: Alignment.TopEnd }) {
              if (this.sessionSnapshot.avatarUrl.length > 0) {
                Image(this.sessionSnapshot.avatarUrl)
                  .width(36)
                  .height(36)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(18)
                  .clip(true)
              } else {
                Column() {
                  Text(this.sessionSnapshot.loggedIn ? this.sessionSnapshot.accountName.slice(0, 1) : '我')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.action_text'))
                }
                .width(36)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor($r('app.color.action_background'))
                .borderRadius(18)
              }

              if (this.sessionSnapshot.loggedIn) {
                Column()
                  .width(8)
                  .height(8)
                  .backgroundColor('#FF5A5F')
                  .borderRadius(4)
                  .margin({ top: 1, right: 1 })
              }
            }
            .width(46)
            .height(46)
            .padding(5)
            .backgroundColor('#73FFFFFF')
            .backgroundBlurStyle(BlurStyle.Thick)
            .border({
              width: 1,
              color: '#52FFFFFF'
            })
            .borderRadius(23)
            .shadow({
              radius: 18,
              color: '#16000000',
              offsetX: 0,
              offsetY: 8
            })
            .onClick(() => {
              this.showHomeAccountPanel = !this.showHomeAccountPanel;
            })
          }
          .alignItems(VerticalAlign.Center)
          .width('100%')
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      }
      .backgroundColor('#99FFFFFF')
      .backdropBlur(36)
      .padding({ left: 16, right: 16, top: TOP_BAR_BASE_PADDING + this.topSafeAreaVp, bottom: 6 })
      .width('100%')
    } else {
      Stack() {
        Column({ space: 2 }) {
          Text(this.portalTitle(this.selectedPortalTab))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text(this.topBarSubtitle())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      }
      .backgroundColor('#96FFFFFF')
      .backdropBlur(32)
      .padding({ left: 16, right: 16, top: TOP_BAR_BASE_PADDING + this.topSafeAreaVp, bottom: 10 })
      .width('100%')
    }
  }

  @Builder
  private HomeAccountSheet(): void {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 6 }) {
          Text('账号与设置')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text(this.sessionSnapshot.loggedIn ? '主页入口、账号信息与常用设置' : '登录后可同步主页推荐流与账号信息')
            .fontSize(13)
            .lineHeight(18)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 14 }) {
          Row({ space: 12 }) {
            if (this.sessionSnapshot.avatarUrl.length > 0) {
              Image(this.sessionSnapshot.avatarUrl)
                .width(54)
                .height(54)
                .objectFit(ImageFit.Cover)
                .borderRadius(27)
                .clip(true)
            } else {
              Column() {
                Text(this.sessionSnapshot.loggedIn ? this.sessionSnapshot.accountName.slice(0, 1) : '我')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.action_text'))
              }
              .width(54)
              .height(54)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor($r('app.color.action_background'))
              .borderRadius(27)
            }

            Column({ space: 4 }) {
              Text(this.sessionSnapshot.accountName)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text(this.sessionSnapshot.loggedIn ? `已保存 ${this.sessionSnapshot.cookieCount} 个登录 Cookie` : '尚未登录知乎账号')
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Row({ space: 10 }) {
            Text(this.sessionSnapshot.loggedIn ? '我的主页' : '登录知乎')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.action_text'))
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor($r('app.color.action_background'))
              .borderRadius(18)
              .onClick(() => {
                if (this.sessionSnapshot.loggedIn) {
                  this.openSelfPage();
                } else {
                  this.showHomeAccountPanel = false;
                  this.openLoginPage();
                }
              })

            Text('刷新主页')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor($r('app.color.card_background'))
              .border({
                width: 1,
                color: $r('app.color.card_border')
              })
              .borderRadius(18)
              .onClick(() => {
                this.refreshHomeFromPanel();
              })

            if (this.sessionSnapshot.loggedIn) {
              Text('退出登录')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.error_text'))
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .backgroundColor('#FFF7F7')
                .border({
                  width: 1,
                  color: '#F4D4D6'
                })
                .borderRadius(18)
                .onClick(() => {
                  this.logout();
                })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFFFF')
        .borderRadius(24)
        .border({
          width: 1,
          color: '#EEF2F7'
        })

        Column({ space: 12 }) {
          Text('快捷入口')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 4 })

          Column({ space: 2 }) {
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('外观与阅读体验')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))

                Text('主题、字体与界面细节正在迁移')
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text('待迁移')
                .fontSize(12)
                .fontColor($r('app.color.action_text'))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .backgroundColor('#FFFFFFFF')
            .borderRadius(20)
            .onClick(() => {
              this.showPendingSettingToast('外观设置页还在迁移中');
            })

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('推荐系统与内容过滤')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))

                Text('推荐模式、过滤规则与屏蔽能力正在迁移')
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text('待迁移')
                .fontSize(12)
                .fontColor($r('app.color.action_text'))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .backgroundColor('#FFFFFFFF')
            .borderRadius(20)
            .onClick(() => {
              this.showPendingSettingToast('推荐与过滤设置页还在迁移中');
            })

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('系统与更新')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))

                Text('项目地址、更新策略与关于信息')
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text('打开')
                .fontSize(12)
                .fontColor($r('app.color.action_text'))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .backgroundColor('#FFFFFFFF')
            .borderRadius(20)
            .onClick(() => {
              this.openProjectRepository();
            })
          }
          .width('100%')
          .padding(6)
          .backgroundColor('#F7F9FC')
          .borderRadius(24)
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('当前阶段先复用子项目的交互结构，具体设置子页会在后续逐步迁移。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 4, right: 4, bottom: this.bottomSafeAreaVp + 12 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .backgroundColor('#F5F7FB')
  }

  @Builder
  private DailySectionHeader(section: DailySection): void {
    Row() {
      Column()
        .layoutWeight(1)
        .height(1)
        .backgroundColor($r('app.color.card_border'))

      Text(this.dateLabel(section.date))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.action_text'))
        .margin({ left: 16, right: 16 })

      Column()
        .layoutWeight(1)
        .height(1)
        .backgroundColor($r('app.color.card_border'))
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 20, top: 8, bottom: 10 })
  }

  @Builder
  private DailyStoryCard(item: DailyStory): void {
    Row({ space: 12 }) {
      if (item.image !== undefined && item.image.length > 0) {
        Image(item.image)
          .width(104)
          .height(92)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
      }

      Column({ space: 12 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 6 }) {
          Column()
            .width(6)
            .height(6)
            .backgroundColor($r('app.color.text_secondary'))
            .borderRadius(3)

          Text(item.hint)
            .fontSize(12)
            .lineHeight(16)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      .layoutWeight(1)
      .constraintSize({
        minHeight: item.image !== undefined && item.image.length > 0 ? 92 : 100
      })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding(12)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.card_border')
    })
    .borderRadius(12)
    .clip(true)
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      this.openWebContent(item.title, item.url);
    })
  }

  @Builder
  private HomeFeedCard(item: HomeFeedItem): void {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        if (item.authorAvatarUrl.length > 0) {
          Image(item.authorAvatarUrl)
            .width(42)
            .height(42)
            .objectFit(ImageFit.Cover)
            .borderRadius(21)
            .clip(true)
        } else {
          Column() {
            Text(item.authorName.length > 0 ? item.authorName.slice(0, 1) : '知')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.action_text'))
          }
          .width(42)
          .height(42)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(21)
        }

        Column({ space: 2 }) {
          Text(item.authorName.length > 0 ? item.authorName : '知乎推荐')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))

          Text(item.authorHeadline.length > 0 ? item.authorHeadline : item.actionText)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }

      Row({ space: 12 }) {
        Column({ space: 10 }) {
          Text(item.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .lineHeight(26)
            .fontColor($r('app.color.text_primary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (item.summary.length > 0) {
            Text(item.summary)
              .fontSize(13)
              .lineHeight(20)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Text(item.details)
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (item.thumbnailUrl.length > 0) {
          Image(item.thumbnailUrl)
            .width(104)
            .height(104)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
        }
      }
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(16)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.card_border')
    })
    .borderRadius(18)
    .clip(true)
    .shadow({
      radius: 12,
      color: '#10000000',
      offsetX: 0,
      offsetY: 3
    })
    .onClick(() => {
      this.openWebContent(item.title, item.targetUrl);
    })
  }

  @Builder
  private HomePage(): void {
    if (!this.sessionSnapshot.loggedIn) {
      Column({ space: 14 }) {
        Text('需要先登录知乎')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('主页推荐流依赖登录 Cookie 和签名请求。')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))

        Text('去登录')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action_text'))
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .onClick(() => {
            this.openLoginPage();
          })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 120, left: 30, right: 30 })
    } else if (this.homeLoading && !this.homeHasLoaded) {
      Column({ space: 10 }) {
        Text('正在加载主页...')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('正在从知乎推荐接口拉取首页内容')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 120 })
    } else if (this.homeError.length > 0 && !this.homeHasLoaded) {
      Column({ space: 12 }) {
        Text(this.homeError)
          .fontSize(15)
          .fontColor($r('app.color.error_text'))

        Text('重新加载')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action_text'))
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .onClick(() => {
            this.loadHomeFirstPage();
          })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 120 })
    } else {
      Column() {
        ForEach(this.homeItems, (item: HomeFeedItem) => {
          this.HomeFeedCard(item);
        }, (item: HomeFeedItem) => item.id)

        if (this.homeError.length > 0) {
          Text(this.homeError)
            .fontSize(12)
            .fontColor($r('app.color.error_text'))
            .padding({ left: 18, right: 18, top: 0, bottom: 10 })
        }

        Text(this.homeNextUrl.length === 0 ? '已经到底了' : (this.homeLoadingMore ? '正在加载更多...' : '加载更多'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(
            this.homeNextUrl.length === 0 || this.homeLoadingMore
              ? $r('app.color.text_tertiary')
              : $r('app.color.action_text')
          )
          .padding({ left: 18, right: 18, top: 12, bottom: 12 })
          .margin({ top: 4, bottom: 20 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .enabled(this.homeNextUrl.length > 0 && !this.homeLoadingMore)
          .onClick(() => {
            this.loadMoreHome();
          })
      }
    }
  }

  @Builder
  private DailyPage(): void {
    if (this.dailyLoading && this.dailySections.length === 0) {
      Column({ space: 10 }) {
        Text('正在加载日报...')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('正在从知乎日报接口拉取最新内容')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 120 })
    } else if (this.dailyError.length > 0 && this.dailySections.length === 0) {
      Column({ space: 12 }) {
        Text(this.dailyError)
          .fontSize(15)
          .fontColor($r('app.color.error_text'))

        Text('重试')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action_text'))
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .onClick(() => {
            this.loadLatestDaily();
          })
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 120 })
    } else {
      Column() {
        ForEach(this.dailySections, (section: DailySection, sectionIndex: number) => {
          Column() {
            this.DailySectionHeader(section)

            ForEach(section.stories, (story: DailyStory) => {
              this.DailyStoryCard(story)
            }, (story: DailyStory) => story.id)
          }
        }, (section: DailySection) => section.date)

        if (this.dailyError.length > 0) {
          Text(this.dailyError)
            .fontSize(12)
            .fontColor($r('app.color.error_text'))
            .padding({ left: 18, right: 18, top: 0, bottom: 10 })
        }

        Text(this.dailyLoadingMore ? '正在加载更多...' : '加载更多')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.dailyLoadingMore ? $r('app.color.text_tertiary') : $r('app.color.action_text'))
          .padding({ left: 18, right: 18, top: 12, bottom: 12 })
          .margin({ top: 4, bottom: 20 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .enabled(!this.dailyLoadingMore)
          .onClick(() => {
            this.loadMoreDaily();
          })
      }
    }
  }

  @Builder
  private PlaceholderPage(): void {
    Column({ space: 12 }) {
      Text(this.portalPlaceholder(this.selectedPortalTab))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text('当前先接入主页和日报，这个入口后续再迁。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: 120 })
  }

  @Builder
  private ContentArea(): void {
    if (this.selectedPortalTab === 'home') {
      this.HomePage();
    } else if (this.selectedPortalTab === 'daily') {
      this.DailyPage();
    } else {
      this.PlaceholderPage();
    }
  }

  @Builder
  private PortalTab(item: AppPortalOption): void {
    Column() {
      Text(item.title)
        .fontSize(14)
        .fontWeight(this.selectedPortalTab === item.key ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedPortalTab === item.key ? $r('app.color.tab_selected_text') : $r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
    .height(44)
    .backgroundColor(this.selectedPortalTab === item.key ? $r('app.color.tab_selected_background') : '#00000000')
    .backgroundBlurStyle(this.selectedPortalTab === item.key ? BlurStyle.Thick : BlurStyle.Thin)
    .border({
      width: this.selectedPortalTab === item.key ? 1 : 0,
      color: this.selectedPortalTab === item.key ? $r('app.color.tab_selected_border') : '#00000000'
    })
    .borderRadius(18)
    .onClick(() => {
      this.selectedPortalTab = item.key;
      this.showHomeAccountPanel = false;
      if (item.key === 'home') {
        if (!this.sessionSnapshot.loggedIn) {
          this.openLoginPage();
        } else if (!this.homeHasLoaded) {
          this.loadHomeFirstPage();
        }
      } else if (item.key === 'daily' && this.dailySections.length === 0) {
        this.loadLatestDaily();
      }
    })
  }

  @Builder
  private BottomPortalBar(): void {
    Row({ space: 8 }) {
      ForEach(APP_PORTAL_TABS, (item: AppPortalOption) => {
        this.PortalTab(item)
      }, (item: AppPortalOption) => item.key)
    }
    .padding({ left: 10, right: 10, top: 10, bottom: 6 })
    .margin({ left: 16, right: 16, bottom: 0 })
    .backgroundColor($r('app.color.tab_bar_background'))
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({
      width: 1,
      color: $r('app.color.tab_bar_border')
    })
    .borderRadius(24)
    .shadow({
      radius: 18,
      color: '#10000000',
      offsetX: 0,
      offsetY: 8
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column() {
            Column()
              .width('100%')
              .height(this.topBarScrollInset())

            this.ContentArea()

            Column()
              .height(BOTTOM_PORTAL_BAR_CONTENT_INSET + this.bottomSafeAreaVp)
              .width('100%')
          }
        }
        .scrollBar(BarState.Off)
        .onScrollEdge((side: Edge) => {
          this.handleContentScrollEdge(side);
        })
        .width('100%')
        .layoutWeight(1)
        .height('100%')

        this.TopBar()
      }
      .width('100%')
      .height('100%')

      Column() {
        this.BottomPortalBar()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.End)
      .padding({ bottom: this.bottomSafeAreaVp + BOTTOM_PORTAL_BAR_BASE_OFFSET })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showHomeAccountPanel, this.HomeAccountSheet(), {
      showClose: false,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      detents: [540],
      backgroundColor: '#F5F7FB',
      onDisappear: () => {
        this.showHomeAccountPanel = false;
      }
    })
  }
}
