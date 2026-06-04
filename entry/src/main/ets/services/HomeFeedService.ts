import { ZhihuCommentableTarget } from '../models/ZhihuContentModels';
import common from '@ohos.app.ability.common';
import { HomeFeedItem, HomeFeedPage, TextHighlightSegment } from '../models/ZhihuModels';
import { ZhihuApi } from './ZhihuApi';
import { decodeHtmlEntities, stripHtmlToText } from '../utils/ZhihuHtml';

type JsonValue = string | number | boolean | null | JsonObject | JsonValue[];

interface JsonObject {
  [key: string]: JsonValue;
}

export class HomeFeedService {
  private static readonly INITIAL_URL: string = 'https://api.zhihu.com/topstory/recommend?include=data[*].content,excerpt,headline';

  private static stringValue(value: JsonValue | undefined): string {
    return typeof value === 'string' ? value : '';
  }

  private static numberValue(value: JsonValue | undefined): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private static idValue(value: JsonValue | undefined): string {
    if (typeof value === 'number') {
      return `${value}`;
    }
    if (typeof value === 'string') {
      return value;
    }
    return '';
  }

  private static objectValue(value: JsonValue | undefined): JsonObject {
    return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as JsonObject : {};
  }

  private static arrayValue(value: JsonValue | undefined): JsonValue[] {
    return Array.isArray(value) ? value : [];
  }

  private static firstString(value: JsonValue | undefined): string {
    if (typeof value === 'string') {
      return value;
    }
    if (Array.isArray(value)) {
      const found = value.find((item: JsonValue) => typeof item === 'string');
      return typeof found === 'string' ? found : '';
    }
    return '';
  }

  private static highlightValue(rawSearchItem: JsonObject, key: string): string {
    const highlight = this.objectValue(rawSearchItem.highlight);
    return this.firstString(highlight[key]);
  }

  private static parseHighlightSegments(html: string): TextHighlightSegment[] {
    const segments: TextHighlightSegment[] = [];
    const pattern = /<em>(.*?)<\/em>/gi;
    let lastIndex = 0;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      const before = html.slice(lastIndex, match.index);
      if (before.length > 0) {
        const text = stripHtmlToText(before);
        if (text.length > 0) {
          segments.push({ text, highlighted: false });
        }
      }
      const highlightedText = decodeHtmlEntities(match[1].replace(/<[^>]+>/g, ''));
      if (highlightedText.length > 0) {
        segments.push({ text: highlightedText, highlighted: true });
      }
      lastIndex = match.index + match[0].length;
      match = pattern.exec(html);
    }

    const after = html.slice(lastIndex);
    if (after.length > 0) {
      const text = stripHtmlToText(after);
      if (text.length > 0) {
        segments.push({ text, highlighted: false });
      }
    }
    return segments;
  }

  private static joinDetails(base: string, actionText: string): string {
    return actionText.length > 0 ? `${base} · ${actionText}` : base;
  }

  private static resolveTargetUrl(targetType: string, target: JsonObject, rawFeed: JsonObject): string {
    const originalUrl = this.stringValue(target.url);
    if (originalUrl.startsWith('https://www.zhihu.com/')
      || originalUrl.startsWith('https://zhuanlan.zhihu.com/')
      || originalUrl.startsWith('https://www.zhihu.com/pin/')) {
      return originalUrl;
    }

    const targetId = this.idValue(target.id);
    if (targetType === 'answer') {
      const questionId = this.idValue(this.objectValue(target.question).id);
      if (questionId.length > 0 && targetId.length > 0) {
        return `https://www.zhihu.com/question/${questionId}/answer/${targetId}`;
      }
    }
    if (targetType === 'article' && targetId.length > 0) {
      return `https://zhuanlan.zhihu.com/p/${targetId}`;
    }
    if (targetType === 'question' && targetId.length > 0) {
      return `https://www.zhihu.com/question/${targetId}`;
    }
    if (targetType === 'pin' && targetId.length > 0) {
      return `https://www.zhihu.com/pin/${targetId}`;
    }

    const rawId = this.stringValue(rawFeed.id);
    return rawId.length > 0 ? `https://www.zhihu.com/${rawId}` : originalUrl;
  }

  private static stableItemId(type: string, target: JsonObject, rawFeed: JsonObject): string {
    const targetId = this.idValue(target.id);
    if (targetId.length > 0) {
      return `${type}:${targetId}`;
    }
    const rawId = this.stringValue(rawFeed.id);
    if (rawId.length > 0) {
      return `${type}:${rawId}`;
    }
    const url = this.resolveTargetUrl(type, target, rawFeed);
    if (url.length > 0) {
      return `${type}:${url}`;
    }
    const title = this.stringValue(target.title) || this.stringValue(this.objectValue(target.question).title);
    return `${type}:${title}`;
  }

  private static pickThumbnail(target: JsonObject, fallback: JsonObject): string {
    const thumbnail = this.stringValue(target.thumbnail);
    if (thumbnail.length > 0) {
      return thumbnail;
    }
    const thumbnails = this.arrayValue(target.thumbnails);
    if (thumbnails.length > 0 && typeof thumbnails[0] === 'string') {
      return thumbnails[0];
    }
    const children = this.arrayValue(fallback.children);
    if (children.length > 0) {
      return this.stringValue(this.objectValue(children[0]).thumbnail);
    }
    return '';
  }

  private static mapTarget(target: JsonObject, rawFeed: JsonObject): HomeFeedItem | undefined {
    const targetType = this.stringValue(target.type);
    const actionText = this.stringValue(rawFeed.action_text) || this.stringValue(rawFeed.detail_text);
    const author = this.objectValue(target.author);
    const question = this.objectValue(target.question);
    let nativeTarget: ZhihuCommentableTarget | undefined;

    if (targetType === 'answer') {
      nativeTarget = {
        kind: 'answer',
        id: this.idValue(target.id),
        questionId: this.idValue(question.id),
        title: this.stringValue(question.title) || this.stringValue(question.name)
      };
      const title = this.stringValue(question.title) || this.stringValue(question.name);
      return {
        id: this.stableItemId('answer', target, rawFeed),
        type: 'answer',
        title,
        summary: this.stringValue(target.excerpt),
        details: this.joinDetails(`回答 · ${this.numberValue(target.voteup_count)} 赞同 · ${this.numberValue(target.comment_count)} 评论`, actionText),
        authorName: this.stringValue(author.name),
        authorHeadline: this.stringValue(author.headline),
        authorAvatarUrl: this.stringValue(author.avatar_url),
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.resolveTargetUrl('answer', target, rawFeed),
        nativeTarget,
        actionText
      };
    }

    if (targetType === 'article') {
      nativeTarget = {
        kind: 'article',
        id: this.idValue(target.id),
        title: this.stringValue(target.title)
      };
      return {
        id: this.stableItemId('article', target, rawFeed),
        type: 'article',
        title: this.stringValue(target.title),
        summary: this.stringValue(target.excerpt),
        details: this.joinDetails(`文章 · ${this.numberValue(target.voteup_count)} 赞同 · ${this.numberValue(target.comment_count)} 评论`, actionText),
        authorName: this.stringValue(author.name),
        authorHeadline: this.stringValue(author.headline),
        authorAvatarUrl: this.stringValue(author.avatar_url),
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.resolveTargetUrl('article', target, rawFeed),
        nativeTarget,
        actionText
      };
    }

    if (targetType === 'question') {
      nativeTarget = {
        kind: 'question',
        id: this.idValue(target.id),
        title: this.stringValue(target.title) || this.stringValue(target.name)
      };
      return {
        id: this.stableItemId('question', target, rawFeed),
        type: 'question',
        title: this.stringValue(target.title) || this.stringValue(target.name),
        summary: this.stringValue(target.excerpt),
        details: this.joinDetails(`问题 · ${this.numberValue(target.follower_count)} 关注 · ${this.numberValue(target.answer_count)} 回答`, actionText),
        authorName: '',
        authorHeadline: '',
        authorAvatarUrl: '',
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.resolveTargetUrl('question', target, rawFeed),
        nativeTarget,
        actionText
      };
    }

    if (targetType === 'pin') {
      const authorName = this.stringValue(author.name);
      nativeTarget = {
        kind: 'pin',
        id: this.idValue(target.id),
        title: authorName.length > 0 ? `${authorName}的想法` : '想法'
      };
      return {
        id: this.stableItemId('pin', target, rawFeed),
        type: 'pin',
        title: authorName.length > 0 ? `${authorName}的想法` : '想法',
        summary: this.stringValue(target.excerpt_title),
        details: this.joinDetails(`想法 · ${this.numberValue(target.like_count)} 赞 · ${this.numberValue(target.comment_count)} 评论`, actionText),
        authorName,
        authorHeadline: this.stringValue(author.headline),
        authorAvatarUrl: this.stringValue(author.avatar_url),
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.resolveTargetUrl('pin', target, rawFeed),
        nativeTarget,
        actionText
      };
    }

    return undefined;
  }

  private static mapRawFeed(rawFeed: JsonObject): HomeFeedItem[] {
    const type = this.stringValue(rawFeed.type);
    if (type === 'feed_group') {
      return this.arrayValue(rawFeed.list)
        .map((item: JsonValue) => this.objectValue(item))
        .flatMap((item: JsonObject) => this.mapRawFeed(item));
    }
    if (type === 'hot_list_feed') {
      const target = this.objectValue(rawFeed.target);
      const children = this.arrayValue(rawFeed.children);
      const childThumbnail = children.length > 0 ? this.stringValue(this.objectValue(children[0]).thumbnail) : '';
      const mapped = this.mapTarget(target, {
        ...rawFeed,
        action_text: this.stringValue(rawFeed.detail_text) || this.stringValue(rawFeed.detailText),
        children
      });
      if (mapped === undefined || mapped.title.length === 0 || mapped.targetUrl.length === 0) {
        return [];
      }
      return [{
        ...mapped,
        id: `hot:${mapped.id}`,
        authorName: '',
        authorHeadline: '',
        authorAvatarUrl: '',
        thumbnailUrl: childThumbnail.length > 0 ? childThumbnail : mapped.thumbnailUrl,
        actionText: mapped.actionText.length > 0 ? mapped.actionText : '热榜'
      }];
    }
    if (type === 'feed_advert' || type === 'zvideo' || type.length === 0) {
      return [];
    }

    const mapped = this.mapTarget(this.objectValue(rawFeed.target), rawFeed);
    if (mapped === undefined || mapped.title.length === 0 || mapped.targetUrl.length === 0) {
      return [];
    }
    return [mapped];
  }

  private static mapPage(payload: JsonObject): HomeFeedPage {
    const data = this.arrayValue(payload.data);
    const items = data
      .map((item: JsonValue) => this.objectValue(item))
      .flatMap((item: JsonObject) => this.mapRawFeed(item));
    const paging = this.objectValue(payload.paging);
    return {
      items,
      paging: {
        isEnd: paging.is_end === true,
        nextUrl: this.stringValue(paging.next)
      }
    };
  }

  static mapSearchPage(payload: Object): HomeFeedPage {
    const jsonPayload = payload as JsonObject;
    const data = this.arrayValue(jsonPayload.data);
    const items = data
      .map((item: JsonValue) => this.objectValue(item))
      .flatMap((item: JsonObject): HomeFeedItem[] => {
        if (this.stringValue(item.type) !== 'search_result') {
          return [];
        }
        const target = this.objectValue(item.object);
        const rawFeed: JsonObject = {
          id: this.idValue(item.id),
          target,
          action_text: '搜索结果'
        };
        const mapped = this.mapTarget(target, rawFeed);
        if (mapped === undefined || mapped.title.length === 0 || mapped.targetUrl.length === 0) {
          return [];
        }
        const titleHighlight = this.highlightValue(item, 'title');
        const summaryHighlight = this.highlightValue(item, 'description') || this.highlightValue(item, 'excerpt');
        const titleHighlightSegments = titleHighlight.length > 0 ? this.parseHighlightSegments(titleHighlight) : undefined;
        const summaryHighlightSegments = summaryHighlight.length > 0 ? this.parseHighlightSegments(summaryHighlight) : undefined;
        return [{
          ...mapped,
          id: `search:${mapped.id}`,
          title: titleHighlight.length > 0 ? stripHtmlToText(titleHighlight) : stripHtmlToText(mapped.title),
          summary: summaryHighlight.length > 0 ? stripHtmlToText(summaryHighlight) : stripHtmlToText(mapped.summary),
          titleHighlightSegments,
          summaryHighlightSegments,
          actionText: mapped.actionText.length > 0 ? mapped.actionText : '搜索结果'
        }];
      });
    const paging = this.objectValue(jsonPayload.paging);
    return {
      items,
      paging: {
        isEnd: paging.is_end === true,
        nextUrl: this.stringValue(paging.next)
      }
    };
  }

  static mapHotListPage(payload: Object): HomeFeedPage {
    return this.mapPage(payload as JsonObject);
  }

  static async loadFirstPage(context: common.Context): Promise<HomeFeedPage> {
    return this.loadSignedPage(context, this.INITIAL_URL);
  }

  static async loadNextPage(context: common.Context, nextUrl: string): Promise<HomeFeedPage> {
    return this.loadSignedPage(context, nextUrl);
  }

  static async loadSignedPage(context: common.Context, url: string): Promise<HomeFeedPage> {
    const payload = await ZhihuApi.getJson(context, url, { signed: true });
    if (payload === null) {
      throw new Error('主页内容为空');
    }
    return this.mapPage(payload as JsonObject);
  }
}
