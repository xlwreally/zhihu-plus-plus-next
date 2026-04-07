import { ZhihuCommentableTarget } from '../models/ZhihuContentModels';

function trimQueryAndHash(url: string): string {
  const hashIndex = url.indexOf('#');
  const queryIndex = url.indexOf('?');
  let endIndex = url.length;
  if (hashIndex >= 0) {
    endIndex = Math.min(endIndex, hashIndex);
  }
  if (queryIndex >= 0) {
    endIndex = Math.min(endIndex, queryIndex);
  }
  return url.slice(0, endIndex);
}

export function resolveZhihuContent(url: string): ZhihuCommentableTarget | undefined {
  const normalized = trimQueryAndHash(url.trim());
  if (normalized.length === 0) {
    return undefined;
  }

  let match = normalized.match(/^https?:\/\/(?:www\.)?zhihu\.com\/question\/(\d+)\/answer\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'answer',
      id: match[2],
      questionId: match[1]
    };
  }

  match = normalized.match(/^https?:\/\/(?:www\.)?zhihu\.com\/answer\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'answer',
      id: match[1]
    };
  }

  match = normalized.match(/^https?:\/\/zhuanlan\.zhihu\.com\/p\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'article',
      id: match[1]
    };
  }

  match = normalized.match(/^https?:\/\/(?:www\.)?zhihu\.com\/question\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'question',
      id: match[1]
    };
  }

  match = normalized.match(/^https?:\/\/(?:www\.)?zhihu\.com\/pin\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'pin',
      id: match[1]
    };
  }

  match = normalized.match(/^zhihu:\/\/answers\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'answer',
      id: match[1]
    };
  }

  match = normalized.match(/^zhihu:\/\/articles\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'article',
      id: match[1]
    };
  }

  match = normalized.match(/^zhihu:\/\/questions\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'question',
      id: match[1]
    };
  }

  match = normalized.match(/^zhihu:\/\/pin\/(\d+)$/i);
  if (match !== null) {
    return {
      kind: 'pin',
      id: match[1]
    };
  }

  return undefined;
}
