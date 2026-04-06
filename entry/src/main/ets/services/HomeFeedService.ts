import common from '@ohos.app.ability.common';
import { HomeFeedItem, HomeFeedPage } from '../models/ZhihuModels';
import { ZhihuApi } from './ZhihuApi';

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
    return typeof value === 'number' ? value : 0;
  }

  private static objectValue(value: JsonValue | undefined): JsonObject {
    return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as JsonObject : {};
  }

  private static arrayValue(value: JsonValue | undefined): JsonValue[] {
    return Array.isArray(value) ? value : [];
  }

  private static joinDetails(base: string, actionText: string): string {
    return actionText.length > 0 ? `${base} · ${actionText}` : base;
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

    if (targetType === 'answer') {
      const title = this.stringValue(question.title) || this.stringValue(question.name);
      return {
        id: `answer:${this.numberValue(target.id)}`,
        type: 'answer',
        title,
        summary: this.stringValue(target.excerpt),
        details: this.joinDetails(`回答 · ${this.numberValue(target.voteup_count)} 赞同 · ${this.numberValue(target.comment_count)} 评论`, actionText),
        authorName: this.stringValue(author.name),
        authorHeadline: this.stringValue(author.headline),
        authorAvatarUrl: this.stringValue(author.avatar_url),
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.stringValue(target.url),
        actionText
      };
    }

    if (targetType === 'article') {
      return {
        id: `article:${this.numberValue(target.id)}`,
        type: 'article',
        title: this.stringValue(target.title),
        summary: this.stringValue(target.excerpt),
        details: this.joinDetails(`文章 · ${this.numberValue(target.voteup_count)} 赞同 · ${this.numberValue(target.comment_count)} 评论`, actionText),
        authorName: this.stringValue(author.name),
        authorHeadline: this.stringValue(author.headline),
        authorAvatarUrl: this.stringValue(author.avatar_url),
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.stringValue(target.url),
        actionText
      };
    }

    if (targetType === 'question') {
      return {
        id: `question:${this.numberValue(target.id)}`,
        type: 'question',
        title: this.stringValue(target.title) || this.stringValue(target.name),
        summary: this.stringValue(target.excerpt),
        details: this.joinDetails(`问题 · ${this.numberValue(target.follower_count)} 关注 · ${this.numberValue(target.answer_count)} 回答`, actionText),
        authorName: '',
        authorHeadline: '',
        authorAvatarUrl: '',
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.stringValue(target.url),
        actionText
      };
    }

    if (targetType === 'pin') {
      const authorName = this.stringValue(author.name);
      return {
        id: `pin:${this.numberValue(target.id)}`,
        type: 'pin',
        title: authorName.length > 0 ? `${authorName}的想法` : '想法',
        summary: this.stringValue(target.excerpt_title),
        details: this.joinDetails(`想法 · ${this.numberValue(target.like_count)} 赞 · ${this.numberValue(target.comment_count)} 评论`, actionText),
        authorName,
        authorHeadline: this.stringValue(author.headline),
        authorAvatarUrl: this.stringValue(author.avatar_url),
        thumbnailUrl: this.pickThumbnail(target, rawFeed),
        targetUrl: this.stringValue(target.url),
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

  static async loadFirstPage(context: common.Context): Promise<HomeFeedPage> {
    const payload = await ZhihuApi.getJson(context, this.INITIAL_URL, { signed: true });
    if (payload === null) {
      throw new Error('主页内容为空');
    }
    return this.mapPage(payload as JsonObject);
  }

  static async loadNextPage(context: common.Context, nextUrl: string): Promise<HomeFeedPage> {
    const payload = await ZhihuApi.getJson(context, nextUrl, { signed: true });
    if (payload === null) {
      throw new Error('主页内容为空');
    }
    return this.mapPage(payload as JsonObject);
  }
}
