import common from '@ohos.app.ability.common';
import { webview } from '@kit.ArkWeb';
import { AppearanceThemeMode } from '../services/AppearanceSettingsRepository';
import { htmlToDataUrl } from '../utils/ZhihuHtml';
import {
  buildThemeScript,
  loadZhihuWebScripts,
  resolveZhihuThemeMode,
  ZhihuRichWebEvent,
  ZhihuWebScript,
  ZhihuWebBridgeHost
} from '../utils/ZhihuWebBridge';

@Component
export struct ZhihuRichWeb {
  @Prop @Watch('onHtmlChanged') html: string = '';
  @Prop @Watch('onSourceUrlChanged') sourceUrl: string = '';
  @Prop title: string = '';
  @Prop @Watch('onThemeModeChanged') themeMode: AppearanceThemeMode = 'system';
  @Prop heightCssPx: number = 320;
  @Prop fillHeight: boolean = false;

  onLinkTap?: (url: string, text: string) => void;
  onImageTap?: (url: string) => void;
  onContentHeightChange?: (heightPx: number) => void;

  private readonly controller: webview.WebviewController = new webview.WebviewController();
  private readonly bridgeHost: ZhihuWebBridgeHost = new ZhihuWebBridgeHost((event: ZhihuRichWebEvent) => {
    this.handleBridgeEvent(event);
  });
  private scripts: Array<ZhihuWebScript> = [];
  private contentLoaded: boolean = false;
  @State private pageUrl: string = 'about:blank';

  aboutToAppear(): void {
    this.scripts = loadZhihuWebScripts(this.context());
    this.updatePageUrl();
  }

  private context(): common.Context {
    return getContext(this) as common.Context;
  }

  private handleBridgeEvent(event: ZhihuRichWebEvent): void {
    if (event.type === 'link') {
      this.onLinkTap?.(event.url, event.text);
      return;
    }
    if (event.type === 'image') {
      this.onImageTap?.(event.url);
      return;
    }
    this.onContentHeightChange?.(event.height);
  }

  private updatePageUrl(): void {
    const html = this.html.trim();
    this.pageUrl = html.length > 0 ? htmlToDataUrl(html) : 'about:blank';
    this.contentLoaded = false;
  }

  private applyTheme(): void {
    if (!this.contentLoaded) {
      return;
    }
    const resolvedThemeMode = resolveZhihuThemeMode(this.context(), this.themeMode);
    this.controller.runJavaScript(buildThemeScript(resolvedThemeMode)).catch(() => {
    });
  }

  private onHtmlChanged(): void {
    this.updatePageUrl();
  }

  private onSourceUrlChanged(): void {
    this.updatePageUrl();
  }

  private onThemeModeChanged(): void {
    this.applyTheme();
  }

  build() {
    Web({ src: this.pageUrl, controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(true)
      .imageAccess(true)
      .mixedMode(MixedMode.Compatible)
      .overScrollMode(OverScrollMode.NEVER)
      .javaScriptProxy({
        object: this.bridgeHost,
        name: 'zhihuBridge',
        methodList: ['postMessage'],
        controller: this.controller
      })
      .runJavaScriptOnDocumentEnd(this.scripts.map((item: ZhihuWebScript): ScriptItem => {
        return {
          script: item.script,
          scriptRules: item.scriptRules
        };
      }))
      .onPageEnd(() => {
        this.contentLoaded = true;
        this.applyTheme();
      })
      .width('100%')
      .layoutWeight(this.fillHeight ? 1 : 0)
      .height(this.fillHeight ? '100%' : `${Math.max(1, Math.ceil(this.heightCssPx))}vp`)
  }
}
