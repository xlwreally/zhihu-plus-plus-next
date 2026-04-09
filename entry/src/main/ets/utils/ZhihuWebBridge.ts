import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';
import { AppearanceThemeMode } from '../services/AppearanceSettingsRepository';

export interface ZhihuWebScript {
  readonly script: string;
  readonly scriptRules: Array<string>;
}

export type ZhihuRichWebEvent =
  | {
    readonly type: 'link';
    readonly url: string;
    readonly text: string;
  }
  | {
    readonly type: 'image';
    readonly url: string;
  }
  | {
    readonly type: 'height';
    readonly height: number;
  };

const RAWFILE_SCRIPT_PATHS: string[] = [
  'zhihu_web/click-listener.js',
  'zhihu_web/footnotes.js',
  'zhihu_web/content-height.js'
];

const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });

function stringValue(value: Object | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}

function numberValue(value: Object | undefined): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function scriptItem(context: common.Context, path: string): ZhihuWebScript {
  const content = context.resourceManager.getRawFileContentSync(path);
  return {
    script: decoder.decodeWithStream(content),
    scriptRules: ['*']
  };
}

export function loadZhihuWebScripts(context: common.Context): ZhihuWebScript[] {
  const scripts: ZhihuWebScript[] = [];
  RAWFILE_SCRIPT_PATHS.forEach((path: string) => {
    try {
      scripts.push(scriptItem(context, path));
    } catch (_) {
    }
  });
  return scripts;
}

export function normalizeZhihuThemeMode(themeMode: AppearanceThemeMode): 'light' | 'dark' | 'system' {
  if (themeMode === 'light' || themeMode === 'dark') {
    return themeMode;
  }
  return 'system';
}

export function buildThemeScript(themeMode: AppearanceThemeMode): string {
  const normalized = normalizeZhihuThemeMode(themeMode);
  if (normalized === 'system') {
    return `
      (function () {
        document.documentElement.removeAttribute('data-ark-theme');
      })();
    `;
  }
  return `
    (function () {
      document.documentElement.setAttribute('data-ark-theme', '${normalized}');
    })();
  `;
}

export class ZhihuWebBridgeHost {
  constructor(private readonly onEvent: (event: ZhihuRichWebEvent) => void) {
  }

  postMessage(payload: string): void {
    const event = parseBridgeEvent(payload);
    if (event !== undefined) {
      this.onEvent(event);
    }
  }
}

function parseBridgeEvent(payload: string): ZhihuRichWebEvent | undefined {
  if (payload.length === 0) {
    return undefined;
  }

  try {
    const parsed = JSON.parse(payload) as Record<string, Object>;
    const type = stringValue(parsed.type);
    if (type === 'link') {
      const url = stringValue(parsed.url);
      if (url.length === 0) {
        return undefined;
      }
      return {
        type: 'link',
        url,
        text: stringValue(parsed.text)
      };
    }
    if (type === 'image') {
      const url = stringValue(parsed.url);
      if (url.length === 0) {
        return undefined;
      }
      return {
        type: 'image',
        url
      };
    }
    if (type === 'height') {
      const height = numberValue(parsed.height);
      if (!Number.isFinite(height) || height <= 0 || height > 200000) {
        return undefined;
      }
      return {
        type: 'height',
        height
      };
    }
  } catch (_) {
    return undefined;
  }
  return undefined;
}
