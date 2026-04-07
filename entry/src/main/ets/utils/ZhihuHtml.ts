function replaceBreaks(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<\/li>/gi, '\n');
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
    return anchorMatch[1];
  }
  return '';
}

export function htmlToDataUrl(html: string): string {
  return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`;
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

export function buildArticleHtmlDocument(title: string, contentHtml: string, sourceUrl: string): string {
  const safeTitle = escapeHtml(title);
  return `<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <base href="${escapeHtml(sourceUrl)}">
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
      }
      * {
        box-sizing: border-box;
      }
      body {
        margin: 0;
        padding: 0;
        background: var(--page-bg);
        color: var(--text-primary);
        font-family: "Noto Serif SC", "Source Han Serif SC", serif;
        line-height: 1.72;
      }
      article {
        background: var(--card-bg);
        margin: 0;
        padding: 18px 18px 96px;
        min-height: 100vh;
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
      a {
        color: var(--link);
        text-decoration: none;
      }
      table {
        width: 100%;
        border-collapse: collapse;
      }
      th, td {
        border: 1px solid var(--border);
        padding: 8px;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --page-bg: #0f141a;
          --card-bg: #18212b;
          --text-primary: #f3f7fd;
          --text-secondary: #a4b0bf;
          --border: #243242;
          --link: #a9c7ff;
          --blockquote-bg: #111a22;
        }
      }
    </style>
  </head>
  <body>
    <article>${contentHtml}</article>
  </body>
</html>`;
}
