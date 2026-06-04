import common from '@ohos.app.ability.common';
import { promptAction, router } from '@kit.ArkUI';
import { serializeZhihuContentTarget, ZhihuCommentableTarget } from '../models/ZhihuContentModels';
import { DEFAULT_SESSION_SNAPSHOT, HomeFeedItem, SessionSnapshot, TextHighlightSegment } from '../models/ZhihuModels';
import { BrowsingHistoryRepository } from '../services/BrowsingHistoryRepository';
import { HotSearchItem, SearchService } from '../services/SearchService';
import { resolveZhihuContent } from '../services/ZhihuContentResolver';

interface SearchPageParams {
  query?: string;
}

@Entry
@Component
struct SearchPage {
  @StorageProp('topSafeAreaVp') private topSafeAreaVp: number = 0;
  @StorageProp('bottomSafeAreaVp') private bottomSafeAreaVp: number = 0;
  @StorageProp('sessionSnapshot') private sessionSnapshot: SessionSnapshot = DEFAULT_SESSION_SNAPSHOT;
  @State private queryInput: string = '';
  @State private searchQuery: string = '';
  @State private hotSearchItems: HotSearchItem[] = [];
  @State private hotSearchLoading: boolean = false;
  @State private hotSearchError: string = '';
  @State private resultItems: HomeFeedItem[] = [];
  @State private resultLoading: boolean = false;
  @State private resultLoadingMore: boolean = false;
  @State private resultError: string = '';
  @State private resultNextUrl: string = '';
  @State private hasSearched: boolean = false;

  aboutToAppear(): void {
    const rawParams = router.getParams();
    const emptyParams: SearchPageParams = {};
    const params: SearchPageParams = rawParams !== undefined && rawParams !== null
      ? rawParams as SearchPageParams
      : emptyParams;
    const initialQuery = typeof params.query === 'string' ? params.query.trim() : '';
    if (initialQuery.length > 0) {
      this.queryInput = initialQuery;
      this.submitSearch(initialQuery);
      return;
    }
    this.loadHotSearch();
  }

  private context(): common.Context {
    return getContext(this) as common.Context;
  }

  private showToast(message: string): void {
    promptAction.showToast({
      message,
      duration: 1800
    });
  }

  private async loadHotSearch(): Promise<void> {
    if (this.hotSearchLoading) {
      return;
    }
    this.hotSearchLoading = true;
    this.hotSearchError = '';
    try {
      this.hotSearchItems = await SearchService.loadHotSearch();
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.hotSearchError = `热搜加载失败：${message}`;
    } finally {
      this.hotSearchLoading = false;
    }
  }

  private async submitSearch(query?: string): Promise<void> {
    const nextQuery = (query ?? this.queryInput).trim();
    if (nextQuery.length === 0) {
      this.showToast('请输入搜索内容');
      return;
    }
    if (!this.sessionSnapshot.loggedIn) {
      this.showToast('登录后可使用知乎搜索');
    }
    this.queryInput = nextQuery;
    this.searchQuery = nextQuery;
    this.resultItems = [];
    this.resultNextUrl = '';
    this.resultError = '';
    this.hasSearched = true;
    this.resultLoading = true;
    try {
      const page = await SearchService.searchFirstPage(this.context(), nextQuery);
      this.resultItems = page.items;
      this.resultNextUrl = page.paging.nextUrl;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.resultError = `搜索失败：${message}`;
    } finally {
      this.resultLoading = false;
    }
  }

  private async loadMoreResults(): Promise<void> {
    if (this.resultLoadingMore || this.resultNextUrl.length === 0) {
      return;
    }
    this.resultLoadingMore = true;
    try {
      const page = await SearchService.searchNextPage(this.context(), this.resultNextUrl);
      const existed = new Set<string>(this.resultItems.map((item: HomeFeedItem) => item.id));
      const merged = [...this.resultItems];
      page.items.forEach((item: HomeFeedItem) => {
        if (!existed.has(item.id)) {
          existed.add(item.id);
          merged.push(item);
        }
      });
      this.resultItems = merged;
      this.resultNextUrl = page.paging.nextUrl;
      this.resultError = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.resultError = `继续加载失败：${message}`;
    } finally {
      this.resultLoadingMore = false;
    }
  }

  private clearSearch(): void {
    this.queryInput = '';
    this.searchQuery = '';
    this.resultItems = [];
    this.resultNextUrl = '';
    this.resultError = '';
    this.hasSearched = false;
    if (this.hotSearchItems.length === 0) {
      this.loadHotSearch();
    }
  }

  private openWebContent(title: string, url: string, recordHistory: boolean = false): void {
    if (url.length === 0) {
      return;
    }
    if (recordHistory) {
      BrowsingHistoryRepository.recordWeb(this.context(), title, url);
    }
    router.pushUrl({
      url: 'pages/WebContent',
      params: { title, url }
    });
  }

  private openNativeArticle(target: ZhihuCommentableTarget, fallbackTitle: string, fallbackUrl: string): void {
    BrowsingHistoryRepository.recordContent(this.context(), target, fallbackTitle, fallbackUrl);
    router.pushUrl({
      url: 'pages/Article',
      params: {
        target: serializeZhihuContentTarget(target),
        fallbackTitle,
        fallbackUrl
      }
    });
  }

  private openResultItem(item: HomeFeedItem): void {
    if (item.nativeTarget !== undefined) {
      this.openNativeArticle(item.nativeTarget, item.title, item.targetUrl);
      return;
    }
    const resolved = resolveZhihuContent(item.targetUrl);
    if (resolved !== undefined) {
      this.openNativeArticle(resolved, item.title, item.targetUrl);
      return;
    }
    this.openWebContent(item.title, item.targetUrl, true);
  }

  private handleScrollEdge(side: Edge): void {
    if (side === Edge.Bottom && this.hasSearched && this.resultItems.length > 0 && this.resultNextUrl.length > 0) {
      this.loadMoreResults();
    }
  }

  @Builder
  private HighlightText(
    text: string,
    segments: TextHighlightSegment[] | undefined,
    fontSize: number,
    lineHeight: number,
    normalColor: ResourceColor,
    highlightedColor: ResourceColor,
    normalWeight: FontWeight,
    highlightedWeight: FontWeight,
    maxLines: number
  ): void {
    Text() {
      if (segments !== undefined && segments.length > 0) {
        ForEach(segments, (segment: TextHighlightSegment, index: number) => {
          Span(segment.text)
            .fontColor(segment.highlighted ? highlightedColor : normalColor)
            .fontWeight(segment.highlighted ? highlightedWeight : normalWeight)
        }, (segment: TextHighlightSegment, index: number) => `${index}:${segment.highlighted ? 'h' : 'n'}:${segment.text}`)
      } else {
        Span(text)
          .fontColor(normalColor)
          .fontWeight(normalWeight)
      }
    }
    .fontSize(fontSize)
    .lineHeight(lineHeight)
    .maxLines(maxLines)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private SearchTopBar(): void {
    Row({ space: 10 }) {
      Text('返回')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.action_text'))
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor($r('app.color.action_background'))
        .borderRadius(18)
        .onClick(() => {
          router.back();
        })

      Row({ space: 8 }) {
        Text('⌕')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width(18)
          .textAlign(TextAlign.Center)

        TextInput({ text: this.queryInput, placeholder: '搜索内容' })
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor('#00000000')
          .padding({ left: 0, right: 0 })
          .onChange((value: string) => {
            this.queryInput = value;
          })

        if (this.queryInput.length > 0) {
          Text('清除')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 6, right: 6, top: 6, bottom: 6 })
            .onClick(() => {
              this.clearSearch();
            })
        }
      }
      .layoutWeight(1)
      .height(42)
      .padding({ left: 14, right: 10 })
      .backgroundColor($r('app.color.card_background'))
      .border({ width: 1, color: $r('app.color.card_border') })
      .borderRadius(22)

      Text('搜索')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.queryInput.trim().length > 0 ? $r('app.color.action_text') : $r('app.color.text_tertiary'))
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor(this.queryInput.trim().length > 0 ? $r('app.color.action_background') : $r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.card_border') })
        .borderRadius(18)
        .enabled(this.queryInput.trim().length > 0 && !this.resultLoading)
        .onClick(() => {
          this.submitSearch();
        })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({ left: 16, right: 16, top: this.topSafeAreaVp + 12, bottom: 12 })
    .backgroundColor($r('app.color.glass_top_bar_background'))
    .border({
      width: {
        bottom: 1
      },
      color: $r('app.color.glass_top_bar_border')
    })
    .backdropBlur(28)
  }

  @Builder
  private HotSearchList(): void {
    Column({ space: 10 }) {
      Row() {
        Text('热搜')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text(this.hotSearchLoading ? '刷新中' : '刷新')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hotSearchLoading ? $r('app.color.text_tertiary') : $r('app.color.action_text'))
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(16)
          .enabled(!this.hotSearchLoading)
          .onClick(() => {
            this.loadHotSearch();
          })
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 4 })

      if (this.hotSearchError.length > 0) {
        Text(this.hotSearchError)
          .fontSize(13)
          .fontColor($r('app.color.error_text'))
          .padding({ left: 18, right: 18, top: 0, bottom: 8 })
      }

      if (this.hotSearchLoading && this.hotSearchItems.length === 0) {
        Text('正在加载知乎热搜...')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 18, right: 18, top: 20, bottom: 20 })
      } else if (this.hotSearchItems.length === 0) {
        Text('请输入搜索内容')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 18, right: 18, top: 20, bottom: 20 })
      } else {
        ForEach(this.hotSearchItems, (item: HotSearchItem, index: number) => {
          Row({ space: 12 }) {
            Text(`${index + 1}`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(index < 3 ? $r('app.color.error_text') : $r('app.color.text_tertiary'))
              .width(28)
              .textAlign(TextAlign.Center)

            Text(item.query)
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (item.hotShow.length > 0) {
              Text(item.hotShow)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 18, right: 18, top: 12, bottom: 12 })
          .backgroundColor($r('app.color.card_background'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(12)
          .margin({ left: 16, right: 16, bottom: 2 })
          .onClick(() => {
            this.submitSearch(item.query);
          })
        }, (item: HotSearchItem) => item.query)
      }
    }
    .width('100%')
  }

  @Builder
  private ResultCard(item: HomeFeedItem): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        if (item.authorAvatarUrl.length > 0) {
          Image(item.authorAvatarUrl)
            .width(36)
            .height(36)
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
            .clip(true)
        } else {
          Column() {
            Text(item.authorName.length > 0 ? item.authorName.slice(0, 1) : '知')
              .fontSize(13)
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

        Column({ space: 2 }) {
          Text(item.authorName.length > 0 ? item.authorName : '知乎搜索')
            .fontSize(13)
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
        Column({ space: 8 }) {
          this.HighlightText(
            item.title,
            item.titleHighlightSegments,
            17,
            24,
            $r('app.color.text_primary'),
            $r('app.color.action_text'),
            FontWeight.Bold,
            FontWeight.Bold,
            3
          )

          if (item.summary.length > 0) {
            this.HighlightText(
              item.summary,
              item.summaryHighlightSegments,
              13,
              20,
              $r('app.color.text_secondary'),
              $r('app.color.action_text'),
              FontWeight.Regular,
              FontWeight.Medium,
              3
            )
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
            .width(92)
            .height(92)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
        }
      }
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(16)
    .margin({ left: 16, right: 16, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
    .clip(true)
    .shadow({
      radius: 10,
      color: '#10000000',
      offsetX: 0,
      offsetY: 3
    })
    .onClick(() => {
      this.openResultItem(item);
    })
  }

  @Builder
  private ResultsList(): void {
    Column() {
      Row() {
        Text(`搜索：${this.searchQuery}`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text('刷新')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.resultLoading ? $r('app.color.text_tertiary') : $r('app.color.action_text'))
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(16)
          .enabled(!this.resultLoading)
          .onClick(() => {
            this.submitSearch(this.searchQuery);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 18, top: 16, bottom: 12 })

      if (this.resultLoading && this.resultItems.length === 0) {
        Column({ space: 10 }) {
          Text('正在搜索...')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('正在从知乎搜索接口拉取内容')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding({ top: 96 })
      } else if (this.resultError.length > 0 && this.resultItems.length === 0) {
        Column({ space: 12 }) {
          Text(this.resultError)
            .fontSize(15)
            .fontColor($r('app.color.error_text'))
            .textAlign(TextAlign.Center)

          Text('重新搜索')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_text'))
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .backgroundColor($r('app.color.action_background'))
            .borderRadius(18)
            .onClick(() => {
              this.submitSearch(this.searchQuery);
            })
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding({ top: 96, left: 24, right: 24 })
      } else if (this.resultItems.length === 0) {
        Text('暂无搜索结果')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 96 })
      } else {
        ForEach(this.resultItems, (item: HomeFeedItem) => {
          this.ResultCard(item);
        }, (item: HomeFeedItem) => item.id)

        if (this.resultError.length > 0) {
          Text(this.resultError)
            .fontSize(12)
            .fontColor($r('app.color.error_text'))
            .padding({ left: 18, right: 18, top: 0, bottom: 10 })
        }

        Text(this.resultNextUrl.length === 0 ? '已经到底了' : (this.resultLoadingMore ? '正在加载更多...' : '加载更多'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(
            this.resultNextUrl.length === 0 || this.resultLoadingMore
              ? $r('app.color.text_tertiary')
              : $r('app.color.action_text')
          )
          .padding({ left: 18, right: 18, top: 12, bottom: 12 })
          .margin({ top: 4, bottom: 20 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .enabled(this.resultNextUrl.length > 0 && !this.resultLoadingMore)
          .onClick(() => {
            this.loadMoreResults();
          })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      this.SearchTopBar();

      Scroll() {
        Column() {
          if (this.hasSearched) {
            this.ResultsList();
          } else {
            this.HotSearchList();
          }

          Column()
            .width('100%')
            .height(this.bottomSafeAreaVp + 24)
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .onScrollEdge((side: Edge) => {
        this.handleScrollEdge(side);
      })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
