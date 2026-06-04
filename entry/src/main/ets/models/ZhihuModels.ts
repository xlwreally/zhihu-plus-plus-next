import { ZhihuCommentableTarget } from './ZhihuContentModels';

export interface ZhihuAccountProfile {
  readonly id: string;
  readonly name: string;
  readonly headline: string;
  readonly avatarUrl: string;
  readonly urlToken: string;
  readonly userType: string;
}

export interface ZhihuSessionData {
  readonly login: boolean;
  readonly username: string;
  readonly cookies: Record<string, string>;
  readonly userAgent: string;
  readonly self?: ZhihuAccountProfile;
}

export interface SessionSnapshot {
  readonly accountName: string;
  readonly avatarUrl: string;
  readonly loggedIn: boolean;
  readonly cookieCount: number;
  readonly hasSigningBridge: boolean;
}

export interface TextHighlightSegment {
  readonly text: string;
  readonly highlighted: boolean;
}

export interface HomeFeedItem {
  readonly id: string;
  readonly type: 'answer' | 'article' | 'question' | 'pin';
  readonly title: string;
  readonly summary: string;
  readonly details: string;
  readonly authorName: string;
  readonly authorHeadline: string;
  readonly authorAvatarUrl: string;
  readonly thumbnailUrl: string;
  readonly targetUrl: string;
  readonly nativeTarget?: ZhihuCommentableTarget;
  readonly actionText: string;
  readonly titleHighlightSegments?: TextHighlightSegment[];
  readonly summaryHighlightSegments?: TextHighlightSegment[];
}

export interface HomeFeedPaging {
  readonly isEnd: boolean;
  readonly nextUrl: string;
}

export interface HomeFeedPage {
  readonly items: HomeFeedItem[];
  readonly paging: HomeFeedPaging;
}

export const DEFAULT_USER_AGENT: string =
  'Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/9.1.0.0 Safari/540.0';

export const DEFAULT_SESSION_SNAPSHOT: SessionSnapshot = {
  accountName: '未登录',
  avatarUrl: '',
  loggedIn: false,
  cookieCount: 0,
  hasSigningBridge: true
};

export function createDefaultSessionData(): ZhihuSessionData {
  return {
    login: false,
    username: '',
    cookies: {},
    userAgent: DEFAULT_USER_AGENT
  };
}
