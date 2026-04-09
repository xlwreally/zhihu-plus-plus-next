## Deep Interview Transcript Summary

- Interview ID: `analyze-question-body-rendering-zhihu-plus-plus-20260409T060108Z`
- Profile: `standard`
- Context Type: `brownfield`
- Final Ambiguity: `0.05`
- Threshold: `0.20`
- Result: `ready for planning / implementation handoff`

## Task

分析子项目 `zhihu-plus-plus` 是怎么渲染问题正文的，并为迁移到用户自己的项目澄清第一期边界。

## Brownfield Facts Collected

- `Question` 是单独的导航目标，不是 `Article`。
- `QuestionScreen` 是问题详情页入口，负责问题正文和答案列表。
- 问题正文来自 `DataHolder.Question.detail`，字段类型是 `String`，内容是 HTML。
- 问题正文默认用 `WebviewComp -> CustomWebView.loadZhihu()` 渲染。
- 问题正文存在备用渲染链：`htmlToMdAst(...) -> MdAst.Render(...)`。
- 问题页下方答案列表不是完整正文，而是基于 feed 的摘要卡片。
- 点进答案后由 `ArticleScreen` + `ArticleViewModel` 渲染完整回答正文。
- 回答正文也有双通道：默认 WebView，备用 Markdown/Compose。
- WebView 承载层包含：
- HTML 注入和 `baseURL`
- 点击监听
- 链接跳转拦截
- 图片点击处理
- 脚注脚本
- 内容高度上报
- 外层滚动同步
- 普通/黑暗主题切换

## Rounds

### Round 1

- Question:
  你这次要我分析的“问题正文”，是只聚焦 `QuestionScreen` 顶部那段 `questionData.detail` 的渲染链，还是要把“该页下方答案列表如何渲染，以及点进答案后 `ArticleScreen` 的正文链路”也一起串起来？
- Answer:
  完整分析整个渲染方式，特别是正文。
- Effect:
  Scope expanded from question body only to full question-page rendering plus answer-detail rendering.

### Round 2

- Question:
  这次“完整分析”里，是否要把 WebView 注入脚本、图片/链接点击处理、主题样式、懒加载高度上报等承载层机制也一并展开？
- Answer:
  全部机制，因为准备迁移进自己的项目。
- Effect:
  Analysis must include rendering infrastructure, not only data-flow.

### Round 3

- Question:
  迁移目标是尽量行为等价，还是只保留正文显示效果和关键交互？
- Answer:
  先实现 WebView 方式。
- Effect:
  Migration strategy became phased: WebView first.

### Round 4

- Question:
  第一阶段是否要求保留 `HTML 注入 + baseURL`、`主题样式切换`、`图片/链接点击拦截`、`脚注脚本`、`内容高度上报/外层滚动同步`？
- Answer:
  除了主题样式其他都保留，主题切换只支持黑暗模式和普通模式切换。
- Effect:
  Phase-1 required mechanisms clarified.

### Round 5

- Question:
  第一阶段是否明确不迁移 `htmlToMdAst(...) -> Compose` 的备用渲染链？
- Answer:
  明确列为非目标。
- Effect:
  Non-goals and decision boundaries became explicit.

## Pressure Pass

- Earlier assumption challenged:
  “完整分析整个渲染方式” 可能只意味着“把所有页面都讲一遍”。
- Follow-up pressure:
  明确追问是否也要覆盖承载层机制，以及迁移时是否要尽量行为等价。
- What changed:
  需求从“源码讲解”收敛成“面向迁移的 WebView 方案拆解”，并明确第一期只做 WebView，不带 Markdown/Compose fallback。

## Final Clarified Direction

- 完整分析三条链路：
- `QuestionScreen` 的问题正文
- 问题页中的答案摘要列表
- `ArticleScreen` 的回答正文
- 重点放在正文和承载机制。
- 迁移第一期只做 WebView 方案。
- 必保留：
- HTML 注入 + `baseURL`
- 图片/链接点击拦截
- 脚注脚本
- 内容高度上报 / 外层滚动同步
- 主题先简化为普通 / 黑暗两态。
- 明确非目标：
- `htmlToMdAst(...) -> Compose` fallback
- 复刻原项目完整主题体系

