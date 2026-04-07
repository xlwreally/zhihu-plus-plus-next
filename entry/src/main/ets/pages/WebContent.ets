import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

interface WebContentParams {
  title?: string;
  url?: string;
}

@Entry
@Component
struct WebContent {
  @StorageProp('topSafeAreaVp') private topSafeAreaVp: number = 0;
  private readonly webController: webview.WebviewController = new webview.WebviewController();
  @State private pageTitle: string = '内容';
  @State private pageUrl: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as WebContentParams;
    this.pageTitle = typeof params.title === 'string' && params.title.length > 0 ? params.title : '内容';
    this.pageUrl = typeof params.url === 'string' ? params.url : '';
  }

  build() {
    Column() {
      Row() {
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
          .margin({ left: 12 })
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

      if (this.pageUrl.length > 0) {
        Web({ src: this.pageUrl, controller: this.webController })
          .width('100%')
          .layoutWeight(1)
      } else {
        Column({ space: 10 }) {
          Text('缺少内容地址')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('当前页面没有可打开的链接。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
