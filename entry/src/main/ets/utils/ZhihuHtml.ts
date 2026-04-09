function replaceBreaks(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<\/li>/gi, '\n');
}

function protocolizeUrl(url: string): string {
  if (url.startsWith('//')) {
    return `https:${url}`;
  }
  return url;
}

function firstImageCandidate(attributes: string): string {
  const candidates = [
    /(?:data-actualsrc|data-original|data-src|data-lazy-src|data-default-watermark-src|data-fullsrc)=["']([^"']+)["']/i,
    /(?:src)=["']([^"']+)["']/i
  ];
  for (const pattern of candidates) {
    const match = attributes.match(pattern);
    if (match !== null && typeof match[1] === 'string') {
      const candidate = protocolizeUrl(match[1].trim());
      if (candidate.length > 0
        && candidate !== 'about:blank'
        && !candidate.startsWith('data:image/gif;base64,R0lGOD')
        && !candidate.startsWith('data:image/svg+xml')) {
        return candidate;
      }
    }
  }
  return '';
}

export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function decodeHtmlEntities(text: string): string {
  return text
    .replace(/&nbsp;/gi, ' ')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, '\'')
    .replace(/&amp;/gi, '&');
}

export function stripHtmlToText(html: string): string {
  return decodeHtmlEntities(replaceBreaks(html).replace(/<[^>]+>/g, ''))
    .replace(/\r/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]+\n/g, '\n')
    .trim();
}

export function extractFirstImageUrl(html: string): string {
  const anchorMatch = html.match(/<(?:a|img)[^>]+(?:href|src)=["']([^"']+)["'][^>]*(?:comment_img|comment_gif|comment_sticker|src)/i);
  if (anchorMatch !== null && typeof anchorMatch[1] === 'string') {
    return protocolizeUrl(anchorMatch[1]);
  }
  return '';
}

export function htmlToDataUrl(html: string): string {
  return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`;
}

export function normalizeRichContentHtml(html: string): string {
  if (html.trim().length === 0) {
    return html;
  }

  const normalizedLinks = html.replace(
    /\b(src|href|poster)=["']\/\/([^"']+)["']/gi,
    (_match: string, attribute: string, path: string): string => {
      return `${attribute}="https://${path}"`;
    }
  );

  return normalizedLinks.replace(/<img\b([^>]*)>/gi, (match: string, attributes: string): string => {
    const normalizedSrc = firstImageCandidate(attributes);
    let nextAttributes = attributes
      .replace(/\sloading=["'][^"']*["']/gi, '')
      .replace(/\ssrc=["'][^"']*["']/gi, '');
    if (normalizedSrc.length > 0) {
      nextAttributes += ` src="${escapeHtml(normalizedSrc)}"`;
    }
    return `<img${nextAttributes}>`;
  });
}

export function paragraphizeText(text: string): string {
  if (text.trim().length === 0) {
    return '';
  }
  return text
    .split(/\n{2,}/)
    .map((paragraph: string) => `<p>${escapeHtml(paragraph).replace(/\n/g, '<br/>')}</p>`)
    .join('');
}

export function buildArticleHtmlDocument(
  title: string,
  contentHtml: string,
  sourceUrl: string,
  initialThemeMode: 'light' | 'dark' = 'light'
): string {
  const safeTitle = escapeHtml(title);
  const safeSourceUrl = escapeHtml(sourceUrl);
  const safeThemeMode = initialThemeMode === 'dark' ? 'dark' : 'light';
  return `<!DOCTYPE html>
<html lang="zh-CN" data-ark-theme="${safeThemeMode}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <base href="${safeSourceUrl}">
    <title>${safeTitle}</title>
    <style>
      :root {
        color-scheme: light dark;
        --page-bg: #f5f7fb;
        --card-bg: #ffffff;
        --text-primary: #111827;
        --text-secondary: #475467;
        --border: #e5ecf3;
        --link: #1d4ed8;
        --blockquote-bg: #f8fafc;
        --code-bg: #eff4fb;
        --target-ring: rgba(29, 78, 216, 0.16);
        --accent-soft: rgba(29, 78, 216, 0.10);
      }
      * {
        box-sizing: border-box;
      }
      html {
        background: var(--page-bg);
      }
      body {
        margin: 0;
        padding: 0;
        background: var(--page-bg);
        color: var(--text-primary);
        font-family: "Noto Serif SC", "Source Han Serif SC", serif;
        line-height: 1.72;
      }
      #zhihu-body-root {
        background: var(--card-bg);
        margin: 0;
        padding: 18px 18px 24px;
        min-height: 0;
        overflow: hidden;
      }
      .zhihu-summary-card {
        margin-bottom: 18px;
        padding-bottom: 18px;
        border-bottom: 1px solid var(--border);
      }
      .zhihu-summary-title {
        margin: 0;
        font-size: 28px;
        line-height: 1.35;
        font-weight: 700;
      }
      .zhihu-summary-badge {
        display: inline-flex;
        margin-top: 8px;
        padding: 2px 10px;
        border-radius: 999px;
        background: var(--accent-soft);
        color: var(--link);
        font-size: 12px;
      }
      .zhihu-summary-author {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-top: 18px;
      }
      .zhihu-summary-avatar {
        width: 44px;
        height: 44px;
        border-radius: 999px;
        object-fit: cover;
        flex: 0 0 auto;
      }
      .zhihu-summary-avatar-fallback {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        background: var(--accent-soft);
        color: var(--link);
        font-weight: 700;
      }
      .zhihu-summary-author-name {
        margin: 0;
        font-size: 15px;
        font-weight: 600;
      }
      .zhihu-summary-author-headline {
        margin: 2px 0 0;
        font-size: 12px;
        line-height: 1.5;
        color: var(--text-secondary);
      }
      .zhihu-summary-meta {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-top: 16px;
        font-size: 12px;
        color: var(--text-secondary);
      }
      #zhihu-body-content {
        display: block;
        margin: 0;
        padding: 0;
      }
      #zhihu-body-content > :first-child {
        margin-top: 0;
      }
      #zhihu-body-content > :last-child {
        margin-bottom: 0;
      }
      #zhihu-body-sentinel {
        display: block;
        width: 100%;
        height: 1px;
        margin: 0;
        padding: 0;
        opacity: 0;
        pointer-events: none;
      }
      #zhihu-body-root > :first-child {
        margin-top: 0;
      }
      #zhihu-body-root > :last-child {
        margin-bottom: 0;
      }
      img, video {
        max-width: 100%;
        height: auto;
        border-radius: 14px;
      }
      img.zhihu-emoji {
        width: 1.35em;
        height: 1.35em;
        max-width: none;
        display: inline-block;
        margin: 0 0.04em;
        vertical-align: -0.24em;
        border-radius: 0;
      }
      pre, code {
        white-space: pre-wrap;
        word-break: break-word;
      }
      blockquote {
        margin: 16px 0;
        padding: 10px 14px;
        border-left: 3px solid var(--border);
        background: var(--blockquote-bg);
        color: var(--text-secondary);
      }
      pre {
        overflow-x: auto;
        padding: 12px 14px;
        border-radius: 14px;
        background: var(--blockquote-bg);
      }
      a {
        color: var(--link);
        text-decoration: none;
      }
      code {
        padding: 0.08em 0.28em;
        border-radius: 6px;
        background: var(--code-bg);
      }
      pre code {
        padding: 0;
        border-radius: 0;
        background: transparent;
      }
      table {
        width: 100%;
        border-collapse: collapse;
      }
      th, td {
        border: 1px solid var(--border);
        padding: 8px;
      }
      .zhihu-footnote-target {
        animation: zhihu-footnote-flash 1.25s ease;
        box-shadow: 0 0 0 10px var(--target-ring);
      }
      @keyframes zhihu-footnote-flash {
        0% {
          box-shadow: 0 0 0 0 var(--target-ring);
        }
        100% {
          box-shadow: 0 0 0 10px rgba(0, 0, 0, 0);
        }
      }
      html[data-ark-theme="dark"] {
        --page-bg: #0f141a;
        --card-bg: #18212b;
        --text-primary: #f3f7fd;
        --text-secondary: #a4b0bf;
        --border: #243242;
        --link: #a9c7ff;
        --blockquote-bg: #111a22;
        --code-bg: #111a22;
        --target-ring: rgba(169, 199, 255, 0.2);
        --accent-soft: rgba(169, 199, 255, 0.14);
      }
      html[data-ark-theme="light"] {
        --page-bg: #f5f7fb;
        --card-bg: #ffffff;
        --text-primary: #111827;
        --text-secondary: #475467;
        --border: #e5ecf3;
        --link: #1d4ed8;
        --blockquote-bg: #f8fafc;
        --code-bg: #eff4fb;
        --target-ring: rgba(29, 78, 216, 0.16);
        --accent-soft: rgba(29, 78, 216, 0.10);
      }
      @media (prefers-color-scheme: dark) {
        html:not([data-ark-theme]) {
          --page-bg: #0f141a;
          --card-bg: #18212b;
          --text-primary: #f3f7fd;
          --text-secondary: #a4b0bf;
          --border: #243242;
          --link: #a9c7ff;
          --blockquote-bg: #111a22;
          --code-bg: #111a22;
          --target-ring: rgba(169, 199, 255, 0.2);
          --accent-soft: rgba(169, 199, 255, 0.14);
        }
      }
    </style>
  </head>
  <body data-source-url="${safeSourceUrl}">
    <article id="zhihu-body-root" data-zhihu-body="true"><div id="zhihu-body-content">${contentHtml}</div><div id="zhihu-body-sentinel" aria-hidden="true"></div></article>
  </body>
</html>`;
}
