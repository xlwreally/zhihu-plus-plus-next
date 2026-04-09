import common from '@ohos.app.ability.common';
import { promptAction, router } from '@kit.ArkUI';
import {
  ArticlePageParams,
  CommentSortOrder,
  contentTargetDisplayTitle,
  parseZhihuContentTarget,
  rootContentTarget,
  serializeZhihuContentTarget,
  ZhihuCommentItem,
  ZhihuCommentTarget,
  ZhihuContentDetail,
  ZhihuContentTarget,
  ZhihuVoteState
} from '../models/ZhihuContentModels';
import { SessionSnapshot, DEFAULT_SESSION_SNAPSHOT } from '../models/ZhihuModels';
import { ZhihuRichWeb } from '../components/ZhihuRichWeb';
import { ArticleDetailService } from '../services/ArticleDetailService';
import { AppearanceThemeMode } from '../services/AppearanceSettingsRepository';
import { CommentService } from '../services/CommentService';
import { resolveZhihuContent } from '../services/ZhihuContentResolver';
import { buildArticleHtmlDocument, escapeHtml } from '../utils/ZhihuHtml';
import { formatTimestamp } from '../utils/Time';

const COMMENT_FOOTER_INDENT: number = 46;
const COMMENT_CHILD_INDENT: number = 44;
const COMMENT_CHILD_PREVIEW_LIMIT: number = 2;

function formatCounter(value: number, unit: string): string {
  if (value >= 10000) {
    return `${(value / 10000).toFixed(value >= 100000 ? 0 : 1)} 万${unit}`;
  }
  return `${value} ${unit}`;
}

function formatUnixTime(seconds: number): string {
  if (seconds <= 0) {
    return '';
  }
  return formatTimestamp(new Date(seconds * 1000));
}

function buildArticleSummaryHtml(detail: ZhihuContentDetail): string {
  const title = detail.target.kind === 'answer' && detail.questionTitle.length > 0 ? detail.questionTitle : detail.title;
  const summaryBadge = detail.target.kind === 'answer' ? '<div class="zhihu-summary-badge">回答详情</div>' : '';
  const avatarHtml = (detail.author?.avatarUrl ?? '').length > 0
    ? `<img class="zhihu-summary-avatar" data-zhihu-ignore-image-click="true" src="${escapeHtml(detail.author?.avatarUrl ?? '')}" alt="${escapeHtml(detail.author?.name ?? detail.title)}">`
    : `<div class="zhihu-summary-avatar zhihu-summary-avatar-fallback" data-zhihu-ignore-image-click="true">${escapeHtml((detail.author?.name ?? '知').slice(0, 1))}</div>`;
  const headlineHtml = (detail.author?.headline ?? '').length > 0
    ? `<p class="zhihu-summary-author-headline">${escapeHtml(detail.author?.headline ?? '')}</p>`
    : '';
  const metaItems: string[] = [
    `<span>${escapeHtml(formatCounter(detail.voteCount, detail.canVote ? '赞同' : '喜欢'))}</span>`,
    `<span>${escapeHtml(formatCounter(detail.commentCount, '评论'))}</span>`
  ];
  const timeText = formatUnixTime(detail.updatedTime || detail.createdTime || 0);
  if (timeText.length > 0) {
    metaItems.push(`<span>${escapeHtml(timeText)}</span>`);
  }
  if (detail.ipInfo.length > 0) {
    metaItems.push(`<span>${escapeHtml(detail.ipInfo)}</span>`);
  }

  return `<section class="zhihu-summary-card">
    <h1 class="zhihu-summary-title">${escapeHtml(title)}</h1>
    ${summaryBadge}
    <div class="zhihu-summary-author">
      ${avatarHtml}
      <div>
        <p class="zhihu-summary-author-name">${escapeHtml(detail.author?.name ?? detail.title)}</p>
        ${headlineHtml}
      </div>
    </div>
    <div class="zhihu-summary-meta">${metaItems.join('')}</div>
  </section>`;
}

function mergeComments(existing: ZhihuCommentItem[], incoming: ZhihuCommentItem[]): ZhihuCommentItem[] {
  const merged = [...existing];
  const ids = new Set<string>(existing.map((item: ZhihuCommentItem) => item.id));
  incoming.forEach((item: ZhihuCommentItem) => {
    if (!ids.has(item.id)) {
      merged.push(item);
    }
  });
  return merged;
}

function copyComment(
  item: ZhihuCommentItem,
  childComments: ZhihuCommentItem[],
  liked?: boolean,
  likeCount?: number,
  childCommentCount?: number
): ZhihuCommentItem {
  return {
    id: item.id,
    contentHtml: item.contentHtml,
    contentText: item.contentText,
    previewImageUrl: item.previewImageUrl,
    createdTime: item.createdTime,
    liked: liked ?? item.liked,
    likeCount: likeCount ?? item.likeCount,
    childCommentCount: childCommentCount ?? item.childCommentCount,
    childComments,
    author: item.author,
    replyToAuthor: item.replyToAuthor,
    authorTag: item.authorTag,
    ipInfo: item.ipInfo
  };
}

function prependCommentPreview(existing: ZhihuCommentItem[], incoming: ZhihuCommentItem): ZhihuCommentItem[] {
  const filtered = existing.filter((item: ZhihuCommentItem) => item.id !== incoming.id);
  return [incoming, ...filtered].slice(0, COMMENT_CHILD_PREVIEW_LIMIT);
}

function appendReplyPreview(comments: ZhihuCommentItem[], parentId: string, reply: ZhihuCommentItem): ZhihuCommentItem[] {
  let changed = false;
  const next = comments.map((item: ZhihuCommentItem): ZhihuCommentItem => {
    const childComments = appendReplyPreview(item.childComments, parentId, reply);
    if (item.id !== parentId) {
      if (childComments === item.childComments) {
        return item;
      }
      changed = true;
      return copyComment(item, childComments);
    }
    changed = true;
    return copyComment(
      item,
      prependCommentPreview(item.childComments, reply),
      undefined,
      undefined,
      item.childCommentCount + 1
    );
  });
  return changed ? next : comments;
}

function copyDetail(
  detail: ZhihuContentDetail,
  voteCount?: number,
  voteState?: ZhihuVoteState,
  commentCount?: number
): ZhihuContentDetail {
  return {
    target: detail.target,
    title: detail.title,
    browserUrl: detail.browserUrl,
    author: detail.author,
    excerpt: detail.excerpt,
    htmlContent: detail.htmlContent,
    commentCount: commentCount ?? detail.commentCount,
    voteCount: voteCount ?? detail.voteCount,
    voteState: voteState ?? detail.voteState,
    createdTime: detail.createdTime,
    updatedTime: detail.updatedTime,
    ipInfo: detail.ipInfo,
    questionId: detail.questionId,
    questionTitle: detail.questionTitle,
    canComment: detail.canComment,
    canVote: detail.canVote,
    supportsDownvote: detail.supportsDownvote
  };
}

function updateCommentLike(comments: ZhihuCommentItem[], commentId: string, liked: boolean): ZhihuCommentItem[] {
  return comments.map((item: ZhihuCommentItem): ZhihuCommentItem => {
    const childComments = updateCommentLike(item.childComments, commentId, liked);
    if (item.id !== commentId) {
      if (childComments === item.childComments) {
        return item;
      }
      return copyComment(item, childComments);
    }
    return copyComment(item, childComments, liked, liked ? item.likeCount + 1 : Math.max(0, item.likeCount - 1));
  });
}

@Entry
@Component
struct Article {
  @StorageProp('topSafeAreaVp') private topSafeAreaVp: number = 0;
  @StorageProp('bottomSafeAreaVp') private bottomSafeAreaVp: number = 0;
  @StorageProp('themeMode') private themeMode: AppearanceThemeMode = 'system';
  @StorageProp('sessionSnapshot') private sessionSnapshot: SessionSnapshot = DEFAULT_SESSION_SNAPSHOT;
  @State private target?: ZhihuContentTarget = undefined;
  @State private fallbackTitle: string = '';
  @State private fallbackUrl: string = '';
  @State private detail?: ZhihuContentDetail = undefined;
  @State private pageTitle: string = '内容详情';
  @State private articleLoading: boolean = true;
  @State private articleError: string = '';
  @State private showRootCommentSheet: boolean = false;
  @State private rootComments: ZhihuCommentItem[] = [];
  @State private rootCommentSortOrder: CommentSortOrder = 'score';
  @State private rootCommentLoading: boolean = false;
  @State private rootCommentLoadingMore: boolean = false;
  @State private rootCommentError: string = '';
  @State private rootCommentNextUrl: string = '';
  @State private rootCommentEnd: boolean = false;
  @State private rootCommentDraft: string = '';
  @State private rootSubmitting: boolean = false;
  @State private rootReplyTo?: ZhihuCommentItem = undefined;
  @State private showChildCommentSheet: boolean = false;
  @State private childTarget?: ZhihuCommentTarget = undefined;
  @State private childComments: ZhihuCommentItem[] = [];
  @State private childCommentLoading: boolean = false;
  @State private childCommentLoadingMore: boolean = false;
  @State private childCommentError: string = '';
  @State private childCommentNextUrl: string = '';
  @State private childCommentEnd: boolean = false;
  @State private childCommentDraft: string = '';
  @State private childSubmitting: boolean = false;
  @State private childReplyTo?: ZhihuCommentItem = undefined;
  @State private activeChildComment?: ZhihuCommentItem = undefined;
  @State private commentRenderVersion: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as ArticlePageParams;
    this.target = parseZhihuContentTarget(params.target);
    this.fallbackTitle = typeof params.fallbackTitle === 'string' ? params.fallbackTitle : '';
    this.fallbackUrl = typeof params.fallbackUrl === 'string' ? params.fallbackUrl : '';
    const rootTargetValue = this.target !== undefined ? rootContentTarget(this.target) : undefined;
    this.pageTitle = rootTargetValue !== undefined ? contentTargetDisplayTitle(rootTargetValue) : '内容详情';
    this.loadArticle();
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

  private async loadArticle(): Promise<void> {
    const currentTarget = this.target;
    if (currentTarget === undefined) {
      this.articleLoading = false;
      this.articleError = '缺少内容目标';
      return;
    }
    const rootTargetValue = rootContentTarget(currentTarget);
    this.articleLoading = true;
    this.articleError = '';
    try {
      const detail = await ArticleDetailService.loadDetail(this.context(), rootTargetValue);
      this.detail = detail;
      this.pageTitle = detail.title;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.articleError = `详情加载失败：${message}`;
    } finally {
      this.articleLoading = false;
    }
  }

  private async toggleVote(nextState: ZhihuVoteState): Promise<void> {
    const detail = this.detail;
    if (detail === undefined) {
      return;
    }
    try {
      const result = await ArticleDetailService.toggleVote(this.context(), detail, nextState);
      this.detail = copyDetail(detail, result.voteCount, result.voteState);
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.showToast(`投票失败：${message}`);
    }
  }

  private openWebVersion(): void {
    const detail = this.detail;
    const url = detail?.browserUrl ?? this.fallbackUrl;
    const title = detail?.title ?? this.fallbackTitle;
    if (url.length === 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/WebContent',
      params: { title, url }
    });
  }

  private openImage(url: string): void {
    if (url.trim().length === 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/WebContent',
      params: {
        title: '图片',
        url
      }
    });
  }

  private openBodyLink(url: string, text: string): void {
    const normalized = url.trim();
    if (normalized.length === 0) {
      return;
    }

    const zhihuTarget = resolveZhihuContent(normalized);
    if (zhihuTarget !== undefined) {
      router.pushUrl({
        url: 'pages/Article',
        params: {
          target: serializeZhihuContentTarget(zhihuTarget),
          fallbackTitle: text,
          fallbackUrl: normalized
        }
      });
      return;
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      router.pushUrl({
        url: 'pages/WebContent',
        params: {
          title: text.length > 0 ? text : '网页',
          url: normalized
        }
      });
      return;
    }

    this.showToast('暂不支持打开该链接');
  }

  private async ensureRootComments(forceReload: boolean = false): Promise<void> {
    const detail = this.detail;
    if (detail === undefined) {
      return;
    }
    if (forceReload) {
      this.rootComments = [];
      this.rootCommentNextUrl = '';
      this.rootCommentEnd = false;
      this.rootCommentError = '';
    }
    if (this.rootCommentLoading || (this.rootComments.length > 0 && !forceReload)) {
      return;
    }
    this.rootCommentLoading = true;
    try {
      const page = await CommentService.loadRootComments(this.context(), detail.target, this.rootCommentSortOrder);
      this.rootComments = page.items;
      this.rootCommentNextUrl = page.nextUrl;
      this.rootCommentEnd = page.isEnd;
      this.rootCommentError = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.rootCommentError = `评论加载失败：${message}`;
    } finally {
      this.rootCommentLoading = false;
    }
  }

  private async loadMoreRootComments(): Promise<void> {
    const detail = this.detail;
    if (detail === undefined || this.rootCommentLoadingMore || this.rootCommentEnd || this.rootCommentNextUrl.length === 0) {
      return;
    }
    this.rootCommentLoadingMore = true;
    try {
      const page = await CommentService.loadRootComments(
        this.context(),
        detail.target,
        this.rootCommentSortOrder,
        this.rootCommentNextUrl
      );
      this.rootComments = mergeComments(this.rootComments, page.items);
      this.rootCommentNextUrl = page.nextUrl;
      this.rootCommentEnd = page.isEnd;
      this.rootCommentError = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.rootCommentError = `评论继续加载失败：${message}`;
    } finally {
      this.rootCommentLoadingMore = false;
    }
  }

  private async loadChildComments(forceReload: boolean = false): Promise<void> {
    const target = this.childTarget;
    if (target === undefined) {
      return;
    }
    if (forceReload) {
      this.childComments = [];
      this.childCommentNextUrl = '';
      this.childCommentEnd = false;
      this.childCommentError = '';
    }
    if (this.childCommentLoading || (this.childComments.length > 0 && !forceReload)) {
      return;
    }
    this.childCommentLoading = true;
    try {
      const page = await CommentService.loadChildComments(this.context(), target);
      this.childComments = page.items;
      this.childCommentNextUrl = page.nextUrl;
      this.childCommentEnd = page.isEnd;
      this.childCommentError = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.childCommentError = `回复加载失败：${message}`;
    } finally {
      this.childCommentLoading = false;
    }
  }

  private async loadMoreChildComments(): Promise<void> {
    const target = this.childTarget;
    if (target === undefined || this.childCommentLoadingMore || this.childCommentEnd || this.childCommentNextUrl.length === 0) {
      return;
    }
    this.childCommentLoadingMore = true;
    try {
      const page = await CommentService.loadChildComments(this.context(), target, this.childCommentNextUrl);
      this.childComments = mergeComments(this.childComments, page.items);
      this.childCommentNextUrl = page.nextUrl;
      this.childCommentEnd = page.isEnd;
      this.childCommentError = '';
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.childCommentError = `回复继续加载失败：${message}`;
    } finally {
      this.childCommentLoadingMore = false;
    }
  }

  private async submitRootComment(): Promise<void> {
    const detail = this.detail;
    if (detail === undefined || this.rootSubmitting) {
      return;
    }
    this.rootSubmitting = true;
    try {
      const created = await CommentService.submitComment(
        this.context(),
        detail.target,
        this.rootCommentDraft,
        this.rootReplyTo?.id
      );
      this.rootComments = [created, ...this.rootComments];
      this.rootCommentDraft = '';
      this.rootReplyTo = undefined;
      this.detail = copyDetail(detail, undefined, undefined, detail.commentCount + 1);
      this.showToast('评论已发送');
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.showToast(`发送失败：${message}`);
    } finally {
      this.rootSubmitting = false;
    }
  }

  private async submitChildComment(): Promise<void> {
    const target = this.childTarget;
    if (target === undefined || this.childSubmitting) {
      return;
    }
    this.childSubmitting = true;
    try {
      const created = await CommentService.submitComment(
        this.context(),
        target.article,
        this.childCommentDraft,
        this.childReplyTo?.id ?? target.commentId
      );
      this.childComments = [created, ...this.childComments];
      this.rootComments = appendReplyPreview(this.rootComments, target.commentId, created);
      if (this.activeChildComment !== undefined && this.activeChildComment.id === target.commentId) {
        this.activeChildComment = copyComment(
          this.activeChildComment,
          prependCommentPreview(this.activeChildComment.childComments, created),
          undefined,
          undefined,
          this.activeChildComment.childCommentCount + 1
        );
      }
      this.childCommentDraft = '';
      this.childReplyTo = undefined;
      this.showToast('回复已发送');
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.showToast(`发送失败：${message}`);
    } finally {
      this.childSubmitting = false;
    }
  }

  private async toggleCommentLike(commentId: string, liked: boolean, fromChildSheet: boolean): Promise<void> {
    try {
      const nextLiked = await CommentService.toggleLikeComment(this.context(), commentId, liked);
      this.rootComments = updateCommentLike(this.rootComments, commentId, nextLiked);
      this.childComments = updateCommentLike(this.childComments, commentId, nextLiked);
      if (this.activeChildComment !== undefined && this.activeChildComment.id === commentId) {
        this.activeChildComment = copyComment(
          this.activeChildComment,
          this.activeChildComment.childComments,
          nextLiked,
          nextLiked ? this.activeChildComment.likeCount + 1 : Math.max(0, this.activeChildComment.likeCount - 1)
        );
      }
      this.commentRenderVersion += 1;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      this.showToast(`操作失败：${message}`);
    }
  }

  private openChildComments(comment: ZhihuCommentItem): void {
    const detail = this.detail;
    if (detail === undefined) {
      return;
    }
    this.childTarget = {
      kind: 'comment',
      commentId: comment.id,
      article: detail.target
    };
    this.childComments = [];
    this.childCommentNextUrl = '';
    this.childCommentEnd = false;
    this.childCommentError = '';
    this.childCommentDraft = '';
    this.childReplyTo = undefined;
    this.activeChildComment = comment;
    this.showChildCommentSheet = true;
    this.loadChildComments(true);
  }

  private openComments(): void {
    this.showRootCommentSheet = true;
    this.ensureRootComments();
  }

  @Builder
  private HeaderBar(): void {
    Row({ space: 12 }) {
      Text('返回')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.action_text'))
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.action_background'))
        .borderRadius(16)
        .onClick(() => {
          router.back();
        })

      Text(this.pageTitle)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: this.topSafeAreaVp + 16, bottom: 12 })
    .backgroundColor($r('app.color.glass_top_bar_background'))
    .border({
      width: {
        bottom: 1
      },
      color: $r('app.color.glass_top_bar_border')
    })
    .backdropBlur(24)
  }

  @Builder
  private ArticleSummary(): void {
    if (this.detail !== undefined) {
      Column({ space: 14 }) {
        Column({ space: 6 }) {
          Text(this.detail?.target.kind === 'answer' && (this.detail?.questionTitle.length ?? 0) > 0
            ? this.detail?.questionTitle ?? ''
            : this.detail?.title ?? '')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .lineHeight(34)
            .fontColor($r('app.color.text_primary'))

          if (this.detail?.target.kind === 'answer') {
            Text('回答详情')
              .fontSize(12)
              .fontColor($r('app.color.action_text'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Row({ space: 12 }) {
          if ((this.detail?.author?.avatarUrl ?? '').length > 0) {
            Image(this.detail?.author?.avatarUrl ?? '')
              .width(44)
              .height(44)
              .objectFit(ImageFit.Cover)
              .borderRadius(22)
          } else {
            Column() {
              Text(this.detail?.author?.name.slice(0, 1) ?? '知')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.action_text'))
            }
            .width(44)
            .height(44)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor($r('app.color.action_background'))
            .borderRadius(22)
          }

          Column({ space: 2 }) {
            Text(this.detail?.author?.name ?? this.pageTitle)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            if ((this.detail?.author?.headline ?? '').length > 0) {
              Text(this.detail?.author?.headline ?? '')
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Row({ space: 10 }) {
          Text(formatCounter(this.detail?.voteCount ?? 0, this.detail?.canVote === true ? '赞同' : '喜欢'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          Text(formatCounter(this.detail?.commentCount ?? 0, '评论'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          if (formatUnixTime(this.detail?.updatedTime || this.detail?.createdTime || 0).length > 0) {
            Text(formatUnixTime(this.detail?.updatedTime || this.detail?.createdTime || 0))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }

          if ((this.detail?.ipInfo ?? '').length > 0) {
            Text(this.detail?.ipInfo ?? '')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 8, bottom: 16 })
    }
  }

  @Builder
  private ArticleBody(): void {
    if (this.articleLoading) {
      Column({ space: 10 }) {
        Text('正在加载详情...')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('正在同步知乎内容与评论入口')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 60, left: 24, right: 24 })
    } else if (this.articleError.length > 0 || this.detail === undefined) {
      Column({ space: 12 }) {
        Text(this.articleError.length > 0 ? this.articleError : '内容不存在')
          .fontSize(15)
          .fontColor($r('app.color.error_text'))
          .textAlign(TextAlign.Center)

        Text('重新加载')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action_text'))
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .onClick(() => {
            this.loadArticle();
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 60, left: 24, right: 24 })
    } else {
      Column() {
        ZhihuRichWeb({
          html: buildArticleHtmlDocument(
            this.detail.title,
            `${buildArticleSummaryHtml(this.detail)}${this.detail.htmlContent}`,
            this.detail.browserUrl
          ),
          sourceUrl: this.detail.browserUrl,
          title: this.detail.title,
          themeMode: this.themeMode,
          fillHeight: true,
          onLinkTap: (url: string, text: string) => {
            this.openBodyLink(url, text);
          },
          onImageTap: (url: string) => {
            this.openImage(url);
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  @Builder
  private ActionBar(): void {
    if (this.detail !== undefined) {
      Row({ space: 10 }) {
        if (this.detail?.canVote === true) {
          Text(this.detail?.voteState === 'up' ? '取消赞同' : '赞同')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.detail?.voteState === 'up' ? $r('app.color.action_text') : $r('app.color.text_primary'))
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor(this.detail?.voteState === 'up' ? $r('app.color.action_background') : $r('app.color.card_background'))
            .border({
              width: 1,
              color: this.detail?.voteState === 'up' ? $r('app.color.action_text') : $r('app.color.card_border')
            })
            .borderRadius(18)
            .onClick(() => {
              this.toggleVote(this.detail?.voteState === 'up' ? 'neutral' : 'up');
            })
        }

        if (this.detail?.canVote === true && this.detail?.supportsDownvote === true) {
          Text(this.detail?.voteState === 'down' ? '取消反对' : '反对')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.detail?.voteState === 'down' ? $r('app.color.text_primary') : $r('app.color.text_primary'))
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor(this.detail?.voteState === 'down' ? $r('app.color.tab_selected_background') : $r('app.color.card_background'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(18)
            .onClick(() => {
              this.toggleVote(this.detail?.voteState === 'down' ? 'neutral' : 'down');
            })
        }

        Text(`评论 ${this.detail?.commentCount ?? 0}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.card_background'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .onClick(() => {
            this.openComments();
          })

        Text('网页')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.card_background'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .onClick(() => {
            this.openWebVersion();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: this.bottomSafeAreaVp + 10 })
      .backgroundColor($r('app.color.tab_bar_background'))
      .border({
        width: {
          top: 1
        },
        color: $r('app.color.tab_bar_border')
      })
      .backdropBlur(24)
    }
  }

  @Builder
  private CommentInputBar(
    draft: string,
    replyTo: ZhihuCommentItem | undefined,
    submitting: boolean,
    onDraftChange: (value: string) => void,
    onClearReply: () => void,
    onSubmit: () => void
  ): void {
    Column({ space: 0 }) {
      if (replyTo !== undefined) {
        Row({ space: 8 }) {
          Text(`回复 ${replyTo.author.name}`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_text'))
            .layoutWeight(1)

          Text('取消')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              onClearReply();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor($r('app.color.action_background'))
        .borderRadius(14)
      }

      Row({ space: 10 }) {
        TextInput({
          text: draft,
          placeholder: replyTo !== undefined ? `回复 ${replyTo.author.name}...` : '写下你的评论...'
        })
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .borderRadius(22)
          .border({ width: 1, color: $r('app.color.card_border') })
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            onDraftChange(value);
          })

        Text(submitting ? '发送中' : '发送')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(
            submitting || draft.trim().length === 0
              ? $r('app.color.text_tertiary')
              : $r('app.color.action_text')
          )
          .padding({ left: 16, right: 16, top: 11, bottom: 11 })
          .backgroundColor(
            draft.trim().length === 0
              ? $r('app.color.page_background')
              : $r('app.color.action_background')
          )
          .borderRadius(20)
          .border({ width: 1, color: $r('app.color.card_border') })
          .enabled(!submitting && draft.trim().length > 0)
          .onClick(() => {
            onSubmit();
          })
      }
      .width('100%')
      .margin({ top: replyTo !== undefined ? 10 : 0 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: this.bottomSafeAreaVp + 10 })
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: {
        top: 1
      },
      color: $r('app.color.card_border')
    })
  }

  @Builder
  private SortChip(label: string, selected: boolean, onClick: () => void): void {
    Text(label)
      .fontSize(12)
      .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(selected ? $r('app.color.action_text') : $r('app.color.text_secondary'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(selected ? $r('app.color.action_background') : $r('app.color.card_background'))
      .borderRadius(16)
      .border({
        width: 1,
        color: selected ? $r('app.color.action_background') : $r('app.color.card_border')
      })
      .onClick(() => {
        onClick();
      })
  }

  @Builder
  private CommentSheetStatus(message: string, error: boolean = false): void {
    Column({ space: 8 }) {
      Text(message)
        .fontSize(14)
        .textAlign(TextAlign.Center)
        .fontColor(error ? $r('app.color.error_text') : $r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 28, right: 28, top: 36, bottom: 36 })
  }

  @Builder
  private CommentListLoadMore(label: string, enabled: boolean, onClick: () => void): void {
    Row() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? $r('app.color.action_text') : $r('app.color.text_tertiary'))
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.page_background'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.card_border') })
    .enabled(enabled)
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  private CommentCard(
    comment: ZhihuCommentItem,
    fromChildSheet: boolean,
    compact: boolean = false,
    showReplyThreadEntry: boolean = true
  ): void {
    Column({ space: compact ? 8 : 10 }) {
      Row({ space: 10 }) {
        if (comment.author.avatarUrl.length > 0) {
          Image(comment.author.avatarUrl)
            .width(compact ? 30 : 36)
            .height(compact ? 30 : 36)
            .objectFit(ImageFit.Cover)
            .borderRadius(compact ? 15 : 18)
        } else {
          Column() {
            Text(comment.author.name.slice(0, 1))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.action_text'))
          }
          .width(compact ? 30 : 36)
          .height(compact ? 30 : 36)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(compact ? 15 : 18)
        }

        Column({ space: compact ? 4 : 6 }) {
          Row({ space: 6 }) {
            Text(comment.author.name)
              .fontSize(compact ? 13 : 15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            if (comment.authorTag.length > 0) {
              Text(comment.authorTag)
                .fontSize(11)
                .fontColor($r('app.color.action_text'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor($r('app.color.action_background'))
                .borderRadius(10)
            }

            if (comment.replyToAuthor !== undefined) {
              Text(`回复 ${comment.replyToAuthor.name}`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(comment.contentText)
            .width('100%')
            .fontSize(compact ? 13 : 15)
            .lineHeight(compact ? 20 : 23)
            .fontColor($r('app.color.text_primary'))

          if (comment.previewImageUrl.length > 0) {
            Image(comment.previewImageUrl)
              .width(compact ? 128 : 180)
              .height(compact ? 96 : 120)
              .objectFit(ImageFit.Cover)
              .borderRadius(12)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        Row({ space: 8 }) {
          Text(formatUnixTime(comment.createdTime))
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)

          if (comment.ipInfo.length > 0) {
            Text(comment.ipInfo)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Row({ space: 12 }) {
          Row({ space: 4 }) {
            Image($r('app.media.comment_action'))
              .width(16)
              .height(16)

            if (!fromChildSheet && comment.childCommentCount > 0) {
              Text(`${comment.childCommentCount}`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          .onClick(() => {
            if (fromChildSheet) {
              this.childReplyTo = comment;
            } else {
              this.openChildComments(comment);
            }
          })
          .alignItems(VerticalAlign.Center)

          Row({ space: 4 }) {
            Image(comment.liked ? $r('app.media.thumb_up_filled') : $r('app.media.thumb_up_outline'))
              .width(16)
              .height(16)

            Text(`${comment.likeCount}`)
              .fontSize(12)
              .fontColor(comment.liked ? $r('app.color.action_text') : $r('app.color.text_secondary'))
          }
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          .onClick(() => {
            this.toggleCommentLike(comment.id, comment.liked, fromChildSheet);
          })
          .alignItems(VerticalAlign.Center)
        }
        .constraintSize({
          minWidth: 84
        })
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: compact ? 40 : COMMENT_FOOTER_INDENT })
      .alignItems(VerticalAlign.Center)

      if (!fromChildSheet && !compact && comment.childComments.length > 0) {
        Column() {
          Column({ space: 10 }) {
            ForEach(comment.childComments.slice(0, COMMENT_CHILD_PREVIEW_LIMIT), (item: ZhihuCommentItem) => {
              this.CommentCard(item, false, true);
            }, (item: ZhihuCommentItem) => `${item.id}:${this.commentRenderVersion}`)
          }
          .width('100%')
          .padding({ left: 10 })
          .border({ width: { left: 2 }, color: $r('app.color.card_border') })
        }
        .width('100%')
        .padding({ left: COMMENT_CHILD_INDENT })
      }

      if (!fromChildSheet && !compact && showReplyThreadEntry && comment.childCommentCount > 0) {
        Row() {
          Row({ space: 6 }) {
            Text(`查看 ${comment.childCommentCount} 条子评论`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
          }
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.page_background'))
          .borderRadius(16)
          .border({ width: 1, color: $r('app.color.card_border') })
          .onClick(() => {
            this.openChildComments(comment);
          })
        }
        .width('100%')
        .padding({ left: COMMENT_CHILD_INDENT })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: compact ? 0 : 8, bottom: compact ? 0 : 8 })
  }

  @Builder
  private RootCommentSheet(): void {
    Column() {
      Column({ space: 12 }) {
        Text('评论')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(`${this.detail?.commentCount ?? 0} 条评论`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))

        Row({ space: 10 }) {
          if (this.rootCommentSortOrder === 'score') {
            this.SortChip('最热', true, () => {
              if (this.rootCommentSortOrder !== 'score') {
                this.rootCommentSortOrder = 'score';
                this.ensureRootComments(true);
              }
            })
          } else {
            this.SortChip('最热', false, () => {
              if (this.rootCommentSortOrder !== 'score') {
                this.rootCommentSortOrder = 'score';
                this.ensureRootComments(true);
              }
            })
          }

          if (this.rootCommentSortOrder === 'time') {
            this.SortChip('最新', true, () => {
              if (this.rootCommentSortOrder !== 'time') {
                this.rootCommentSortOrder = 'time';
                this.ensureRootComments(true);
              }
            })
          } else {
            this.SortChip('最新', false, () => {
              if (this.rootCommentSortOrder !== 'time') {
                this.rootCommentSortOrder = 'time';
                this.ensureRootComments(true);
              }
            })
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 18, bottom: 14 })

      Scroll() {
        Column({ space: 16 }) {
          if (this.rootCommentLoading && this.rootComments.length === 0) {
            this.CommentSheetStatus('正在加载评论...')
          } else if (this.rootCommentError.length > 0 && this.rootComments.length === 0) {
            this.CommentSheetStatus(this.rootCommentError, true)
          } else if (this.rootComments.length === 0) {
            this.CommentSheetStatus('还没有评论，抢先说点什么。')
          } else {
            ForEach(this.rootComments, (item: ZhihuCommentItem) => {
              this.CommentCard(item, false);
            }, (item: ZhihuCommentItem) => `${item.id}:${this.commentRenderVersion}`)
          }

          if (this.rootComments.length > 0) {
            this.CommentListLoadMore(
              this.rootCommentEnd ? '没有更多评论了' : (this.rootCommentLoadingMore ? '正在加载更多...' : '加载更多评论'),
              !this.rootCommentEnd && !this.rootCommentLoadingMore,
              () => {
                this.loadMoreRootComments();
              }
            )
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      this.CommentInputBar(
        this.rootCommentDraft,
        this.rootReplyTo,
        this.rootSubmitting,
        (value: string) => {
          this.rootCommentDraft = value;
        },
        () => {
          this.rootReplyTo = undefined;
        },
        () => {
          this.submitRootComment();
        }
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private ChildCommentSheet(): void {
    Column() {
      Column({ space: 6 }) {
        Text('回复')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(`${this.activeChildComment?.childCommentCount ?? this.childComments.length} 条回复`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 18, bottom: 14 })

      Scroll() {
        Column({ space: 16 }) {
          if (this.activeChildComment !== undefined) {
            Column({ space: 12 }) {
              Text('原评论')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))

              this.CommentCard(this.activeChildComment, true, false, false)
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 14 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(18)
            .border({ width: 1, color: $r('app.color.card_border') })
          }

          if (this.childCommentLoading && this.childComments.length === 0) {
            this.CommentSheetStatus('正在加载回复...')
          } else if (this.childCommentError.length > 0 && this.childComments.length === 0) {
            this.CommentSheetStatus(this.childCommentError, true)
          } else if (this.childComments.length === 0) {
            this.CommentSheetStatus('暂时还没有回复。')
          } else {
            ForEach(this.childComments, (item: ZhihuCommentItem) => {
              this.CommentCard(item, true);
            }, (item: ZhihuCommentItem) => `${item.id}:${this.commentRenderVersion}`)
          }

          if (this.childComments.length > 0) {
            this.CommentListLoadMore(
              this.childCommentEnd ? '没有更多回复了' : (this.childCommentLoadingMore ? '正在加载更多...' : '加载更多回复'),
              !this.childCommentEnd && !this.childCommentLoadingMore,
              () => {
                this.loadMoreChildComments();
              }
            )
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      this.CommentInputBar(
        this.childCommentDraft,
        this.childReplyTo,
        this.childSubmitting,
        (value: string) => {
          this.childCommentDraft = value;
        },
        () => {
          this.childReplyTo = undefined;
        },
        () => {
          this.submitChildComment();
        }
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column() {
        this.HeaderBar()
        this.ArticleBody()
        this.ActionBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .bindSheet($$this.showRootCommentSheet, this.RootCommentSheet(), {
        showClose: false,
        dragBar: true,
        preferType: SheetType.BOTTOM,
        detents: [SheetSize.LARGE],
        backgroundColor: $r('app.color.page_background'),
        onDisappear: () => {
          this.showRootCommentSheet = false;
          this.rootReplyTo = undefined;
        }
      })

      Column()
        .width(1)
        .height(1)
        .bindSheet($$this.showChildCommentSheet, this.ChildCommentSheet(), {
          showClose: false,
          dragBar: true,
          preferType: SheetType.BOTTOM,
          detents: [SheetSize.LARGE],
          backgroundColor: $r('app.color.page_background'),
          onDisappear: () => {
            this.showChildCommentSheet = false;
            this.childReplyTo = undefined;
            this.activeChildComment = undefined;
          }
        })
    }
    .width('100%')
    .height('100%')
  }
}
