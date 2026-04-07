import common from '@ohos.app.ability.common';
import { promptAction, router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import {
  ArticlePageParams,
  CommentSortOrder,
  contentTargetDisplayTitle,
  parseZhihuContentTarget,
  rootContentTarget,
  ZhihuCommentItem,
  ZhihuCommentTarget,
  ZhihuContentDetail,
  ZhihuContentTarget,
  ZhihuVoteState
} from '../models/ZhihuContentModels';
import { SessionSnapshot, DEFAULT_SESSION_SNAPSHOT } from '../models/ZhihuModels';
import { ArticleDetailService } from '../services/ArticleDetailService';
import { CommentService } from '../services/CommentService';
import { buildArticleHtmlDocument, htmlToDataUrl } from '../utils/ZhihuHtml';
import { formatTimestamp } from '../utils/Time';

const ROOT_SHEET_HEIGHT: number = 620;
const CHILD_SHEET_HEIGHT: number = 560;

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

function copyComment(item: ZhihuCommentItem, childComments: ZhihuCommentItem[], liked?: boolean, likeCount?: number): ZhihuCommentItem {
  return {
    id: item.id,
    contentHtml: item.contentHtml,
    contentText: item.contentText,
    previewImageUrl: item.previewImageUrl,
    createdTime: item.createdTime,
    liked: liked ?? item.liked,
    likeCount: likeCount ?? item.likeCount,
    childCommentCount: item.childCommentCount,
    childComments,
    author: item.author,
    replyToAuthor: item.replyToAuthor,
    authorTag: item.authorTag,
    ipInfo: item.ipInfo
  };
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
  @StorageProp('sessionSnapshot') private sessionSnapshot: SessionSnapshot = DEFAULT_SESSION_SNAPSHOT;
  private readonly contentWebController: webview.WebviewController = new webview.WebviewController();
  @State private target?: ZhihuContentTarget = undefined;
  @State private fallbackTitle: string = '';
  @State private fallbackUrl: string = '';
  @State private detail?: ZhihuContentDetail = undefined;
  @State private pageTitle: string = '内容详情';
  @State private articleLoading: boolean = true;
  @State private articleError: string = '';
  @State private webDataUrl: string = '';
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
      this.webDataUrl = htmlToDataUrl(buildArticleHtmlDocument(detail.title, detail.htmlContent, detail.browserUrl));
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
      if (fromChildSheet) {
        this.childComments = updateCommentLike(this.childComments, commentId, nextLiked);
      } else {
        this.rootComments = updateCommentLike(this.rootComments, commentId, nextLiked);
      }
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
        this.ArticleSummary()
        Web({ src: this.webDataUrl, controller: this.contentWebController })
          .layoutWeight(1)
          .width('100%')
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
    Column({ space: 8 }) {
      if (replyTo !== undefined) {
        Row({ space: 8 }) {
          Text(`回复 ${replyTo.author.name}`)
            .fontSize(12)
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
      }

      Row({ space: 10 }) {
        TextInput({
          text: draft,
          placeholder: replyTo !== undefined ? `回复 ${replyTo.author.name}` : '写下你的评论'
        })
          .layoutWeight(1)
          .height(40)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .borderRadius(18)
          .border({ width: 1, color: $r('app.color.card_border') })
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            onDraftChange(value);
          })

        Text(submitting ? '发送中' : '发送')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(submitting ? $r('app.color.text_tertiary') : $r('app.color.action_text'))
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(18)
          .enabled(!submitting && draft.trim().length > 0)
          .onClick(() => {
            onSubmit();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: this.bottomSafeAreaVp + 10 })
    .backgroundColor($r('app.color.page_background'))
    .border({
      width: {
        top: 1
      },
      color: $r('app.color.card_border')
    })
  }

  @Builder
  private CommentCard(comment: ZhihuCommentItem, fromChildSheet: boolean, compact: boolean = false): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        if (comment.author.avatarUrl.length > 0) {
          Image(comment.author.avatarUrl)
            .width(compact ? 30 : 38)
            .height(compact ? 30 : 38)
            .objectFit(ImageFit.Cover)
            .borderRadius(compact ? 15 : 19)
        } else {
          Column() {
            Text(comment.author.name.slice(0, 1))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.action_text'))
          }
          .width(compact ? 30 : 38)
          .height(compact ? 30 : 38)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(compact ? 15 : 19)
        }

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(comment.author.name)
              .fontSize(compact ? 13 : 14)
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
            .fontSize(compact ? 13 : 14)
            .lineHeight(compact ? 20 : 22)
            .fontColor($r('app.color.text_primary'))

          if (comment.previewImageUrl.length > 0) {
            Image(comment.previewImageUrl)
              .width(132)
              .height(100)
              .objectFit(ImageFit.Cover)
              .borderRadius(12)
          }

          Row({ space: 10 }) {
            Text(formatUnixTime(comment.createdTime))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))

            if (comment.ipInfo.length > 0) {
              Text(comment.ipInfo)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
            }

            Text(comment.liked ? `已赞 ${comment.likeCount}` : `点赞 ${comment.likeCount}`)
              .fontSize(11)
              .fontColor(comment.liked ? $r('app.color.action_text') : $r('app.color.text_secondary'))
              .onClick(() => {
                this.toggleCommentLike(comment.id, comment.liked, fromChildSheet);
              })

            Text('回复')
              .fontSize(11)
              .fontColor($r('app.color.action_text'))
              .onClick(() => {
                if (fromChildSheet) {
                  this.childReplyTo = comment;
                } else {
                  this.rootReplyTo = comment;
                }
              })

            if (!fromChildSheet && comment.childCommentCount > 0 && !compact) {
              Text(`查看回复 ${comment.childCommentCount}`)
                .fontSize(11)
                .fontColor($r('app.color.action_text'))
                .onClick(() => {
                  this.openChildComments(comment);
                })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (!fromChildSheet && !compact && comment.childComments.length > 0) {
        Column({ space: 10 }) {
          ForEach(comment.childComments.slice(0, 2), (item: ZhihuCommentItem) => {
            this.CommentCard(item, false, true);
          }, (item: ZhihuCommentItem) => item.id)
        }
        .width('100%')
        .padding({ left: 12 })
        .border({
          width: {
            left: 2
          },
          color: $r('app.color.card_border')
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.card_border') })
  }

  @Builder
  private RootCommentSheet(): void {
    Column() {
      Row() {
        Text('评论')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.rootCommentSortOrder === 'score' ? '按热度' : '按时间')
          .fontSize(12)
          .fontColor($r('app.color.action_text'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.action_background'))
          .borderRadius(14)
          .onClick(() => {
            this.rootCommentSortOrder = this.rootCommentSortOrder === 'score' ? 'time' : 'score';
            this.ensureRootComments(true);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.rootCommentLoading && this.rootComments.length === 0) {
            Text('正在加载评论...')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .padding({ top: 12 })
          } else if (this.rootCommentError.length > 0 && this.rootComments.length === 0) {
            Text(this.rootCommentError)
              .fontSize(13)
              .fontColor($r('app.color.error_text'))
          } else if (this.rootComments.length === 0) {
            Text('还没有评论，抢先说点什么。')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          } else {
            ForEach(this.rootComments, (item: ZhihuCommentItem) => {
              this.CommentCard(item, false);
            }, (item: ZhihuCommentItem) => item.id)
          }

          if (this.rootComments.length > 0) {
            Text(this.rootCommentEnd ? '没有更多评论了' : (this.rootCommentLoadingMore ? '正在加载更多...' : '加载更多评论'))
              .fontSize(13)
              .fontColor(
                this.rootCommentEnd || this.rootCommentLoadingMore
                  ? $r('app.color.text_tertiary')
                  : $r('app.color.action_text')
              )
              .padding({ left: 12, right: 12, top: 10, bottom: 14 })
              .enabled(!this.rootCommentEnd && !this.rootCommentLoadingMore)
              .onClick(() => {
                this.loadMoreRootComments();
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
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
      Row({ space: 10 }) {
        Text('回复')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        if (this.childTarget !== undefined) {
          Text(`#${this.childTarget.commentId}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.childCommentLoading && this.childComments.length === 0) {
            Text('正在加载回复...')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .padding({ top: 12 })
          } else if (this.childCommentError.length > 0 && this.childComments.length === 0) {
            Text(this.childCommentError)
              .fontSize(13)
              .fontColor($r('app.color.error_text'))
          } else if (this.childComments.length === 0) {
            Text('暂时还没有回复。')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          } else {
            ForEach(this.childComments, (item: ZhihuCommentItem) => {
              this.CommentCard(item, true);
            }, (item: ZhihuCommentItem) => item.id)
          }

          if (this.childComments.length > 0) {
            Text(this.childCommentEnd ? '没有更多回复了' : (this.childCommentLoadingMore ? '正在加载更多...' : '加载更多回复'))
              .fontSize(13)
              .fontColor(
                this.childCommentEnd || this.childCommentLoadingMore
                  ? $r('app.color.text_tertiary')
                  : $r('app.color.action_text')
              )
              .padding({ left: 12, right: 12, top: 10, bottom: 14 })
              .enabled(!this.childCommentEnd && !this.childCommentLoadingMore)
              .onClick(() => {
                this.loadMoreChildComments();
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
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
      detents: [ROOT_SHEET_HEIGHT],
      backgroundColor: $r('app.color.page_background'),
      onDisappear: () => {
        this.showRootCommentSheet = false;
        this.rootReplyTo = undefined;
      }
    })
    .bindSheet($$this.showChildCommentSheet, this.ChildCommentSheet(), {
      showClose: false,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      detents: [CHILD_SHEET_HEIGHT],
      backgroundColor: $r('app.color.page_background'),
      onDisappear: () => {
        this.showChildCommentSheet = false;
        this.childReplyTo = undefined;
      }
    })
  }
}
