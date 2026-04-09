# Deep Interview Spec

## Metadata

- Slug: `analyze-question-body-rendering-zhihu-plus-plus`
- Profile: `standard`
- Rounds: `5`
- Final ambiguity: `0.05`
- Threshold: `0.20`
- Context type: `brownfield`
- Context snapshot: `.omx/context/analyze-question-body-rendering-zhihu-plus-plus-20260409T060108Z.md`
- Transcript: `.omx/interviews/analyze-question-body-rendering-zhihu-plus-plus-20260409T061122Z.md`

## Clarity Breakdown

| Dimension | Score |
| --- | --- |
| Intent Clarity | 0.97 |
| Outcome Clarity | 0.96 |
| Scope Clarity | 0.96 |
| Constraint Clarity | 0.94 |
| Success Criteria Clarity | 0.90 |
| Context Clarity | 0.97 |

Readiness gates:
- Non-goals: explicit
- Decision boundaries: explicit
- Pressure pass: complete

## Intent

用户要完整搞清楚 `zhihu-plus-plus` 中“问题正文”的渲染方式，不只是知道正文来自哪个接口字段，而是为了把这套机制迁移到自己的项目里。分析必须覆盖正文主链和承载层机制，尤其是 WebView 方案。

## Desired Outcome

产出一份足够指导迁移第一期实现的分析规格，明确：
- 问题正文的完整渲染链
- 问题页答案列表的渲染方式
- 点进答案后的正文渲染链
- WebView 承载层需要保留的机制
- 第一阶段明确不做的内容

## In Scope

- `Question` 路由是如何进入 `QuestionScreen`
- `QuestionScreen` 如何获取问题详情
- `DataHolder.Question.detail` 如何成为问题正文
- `QuestionScreen` 默认 WebView 正文渲染路径
- `QuestionScreen` 的备用 Markdown/Compose 路径，仅作为分析对象
- 问题页答案列表如何获取和显示摘要
- `ArticleScreen` / `ArticleViewModel` 如何获取回答正文
- `ArticleScreen` 默认 WebView 正文渲染路径
- `ArticleScreen` 的备用 Markdown/Compose 路径，仅作为分析对象
- `WebviewComp` / `CustomWebView` 的承载机制：
- HTML 注入
- `baseURL`
- 图片和链接点击拦截
- 脚注脚本
- 内容高度上报
- 外层滚动同步
- 普通 / 黑暗模式切换

## Out-of-Scope / Non-goals

- 第一阶段不迁移 `htmlToMdAst(...) -> MdAst.Render(...)` 的 Compose fallback
- 第一阶段不复刻原项目完整主题体系，只保留普通 / 黑暗模式切换
- 第一阶段不要求完整复刻问题页其余非正文功能
- 第一阶段不要求先实现导出、AI 摘要、收藏、回答切换等附加能力

## Decision Boundaries

OMX 可直接按以下边界继续规划或实现，无需再次确认：

- 第一阶段正文方案固定为 WebView
- 必须保留：
- HTML 注入 + `baseURL`
- 图片/链接点击拦截
- 脚注脚本
- 内容高度上报 / 外层滚动同步
- 主题能力只做普通 / 黑暗两态，不需要照搬原项目主题系统
- Markdown/Compose fallback 明确不是第一阶段目标

## Constraints

- 项目来源是 brownfield Android 子项目 `zhihu-plus-plus`
- 迁移目标偏行为迁移，不只是 UI 外观相似
- 正文相关分析必须区分：
- 问题正文
- 答案摘要列表
- 回答正文
- 不能把 `QuestionScreen` 和 `ArticleScreen` 混为同一正文页面

## Testable Acceptance Criteria

- 能明确指出问题正文入口文件和导航位置
- 能明确指出问题正文使用的数据字段和接口 include 字段
- 能明确指出问题正文默认走 WebView，备用走 Markdown/Compose
- 能明确指出答案列表只是摘要卡片，不是完整正文渲染
- 能明确指出回答正文在 `ArticleScreen` 中再次走 WebView 主链
- 能列出 WebView 承载层第一阶段必须保留的机制
- 能列出第一阶段明确不做的内容
- 文件级证据足够支持后续迁移规划

## Assumptions Exposed And Resolved

- Assumption:
  用户只想知道 `questionData.detail` 来自哪里。
  Resolution:
  错。用户要完整分析整个渲染方式，特别是正文。

- Assumption:
  用户只关心数据主链，不关心 WebView 承载层细节。
  Resolution:
  错。用户明确要求把承载层机制也展开，因为准备迁移。

- Assumption:
  迁移第一阶段需要保持原项目所有渲染路径。
  Resolution:
  错。第一阶段只做 WebView 主链，Markdown/Compose fallback 明确排除。

## Pressure-Pass Findings

- Revisiting earlier answer:
  “完整分析整个渲染方式”
- Pressure applied:
  追问迁移目标和第一阶段保留机制，而不是默认做全量等价迁移。
- Outcome:
  形成了更窄、更可执行的迁移边界：WebView first，保留关键承载层机制，删去 Compose fallback。

## Brownfield Evidence Vs Inference

Evidence:
- `Question` 导航目标定义在 [NavDestination.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/NavDestination.kt#L141)
- `QuestionScreen` 挂载在 [ZhihuMain.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/ZhihuMain.kt#L360) 和 [ZhihuMain.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/ZhihuMain.kt#L362)
- 问题详情接口在 [DataHolder.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/data/DataHolder.kt#L65)
- 问题模型 `detail` 字段在 [DataHolder.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/data/DataHolder.kt#L377) 和 [DataHolder.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/data/DataHolder.kt#L390)
- `QuestionScreen` 读取详情与正文赋值在 [QuestionScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/QuestionScreen.kt#L104) 和 [QuestionScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/QuestionScreen.kt#L106)
- `QuestionScreen` 的 WebView / Markdown 分支在 [QuestionScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/QuestionScreen.kt#L162) 和 [QuestionScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/QuestionScreen.kt#L170)
- 问题页答案 feed URL 在 [QuestionFeedViewModel.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/viewmodel/feed/QuestionFeedViewModel.kt#L20)
- 答案卡片展示 `excerpt/detailsText` 在 [QuestionFeedViewModel.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/viewmodel/feed/QuestionFeedViewModel.kt#L31), [QuestionFeedViewModel.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/viewmodel/feed/QuestionFeedViewModel.kt#L35), [QuestionFeedViewModel.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/viewmodel/feed/QuestionFeedViewModel.kt#L36)
- `FeedCard` 用 `parseHtmlTextWithTheme` 渲染标题和摘要，在 [FeedCard.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/FeedCard.kt#L450), [FeedCard.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/FeedCard.kt#L467), [FeedCard.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/FeedCard.kt#L538), [FeedCard.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/FeedCard.kt#L574)
- 回答正文载入点在 [ArticleViewModel.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/viewmodel/ArticleViewModel.kt#L357)
- `ArticleScreen` 的 WebView / Markdown 分支在 [ArticleScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/ArticleScreen.kt#L1245), [ArticleScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/ArticleScreen.kt#L1266), [ArticleScreen.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/ArticleScreen.kt#L1275)
- `CustomWebView.loadZhihu` 在 [WebviewComp.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt#L367) 和 [WebviewComp.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt#L392)
- 点击/脚注/高度注入分别在 [WebviewComp.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt#L309), [WebviewComp.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt#L322), [WebviewComp.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt#L356)
- 链接拦截在 [WebviewComp.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt#L699)
- Markdown fallback 入口在 [MdAst.kt](D:/code/harmonyos/zhihu-plus-plus-next/zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/markdown/MdAst.kt#L442)

Inference:
- 如果用户只迁移第一阶段 WebView 主链，就能先覆盖“问题正文”和“回答正文”的核心显示能力；答案列表摘要属于独立卡片体系，可后续单独适配。

## Technical Context Findings

### 1. 问题正文

- 入口是 `QuestionScreen`
- 数据来自 `DataHolder.getContentDetail(context, question)`
- 正文字段是 `questionData.detail`
- 默认渲染方式是 `WebviewComp { it.loadZhihu(questionUrl, Jsoup.parse(questionContent)) }`

### 2. 问题页答案列表

- 数据来自 `QuestionFeedViewModel.initialUrl`
- 每条答案在问题页只渲染摘要卡片，不渲染完整 HTML 正文
- 关键显示字段是：
- `title`
- `excerpt`
- `detailsText`
- `FeedCard` 主要走 `parseHtmlTextWithTheme(...)` 做轻量文本显示

### 3. 回答正文

- 点击答案后进入 `ArticleScreen`
- `ArticleViewModel` 通过答案详情接口把 `answer.content` 放入 `viewModel.content`
- `ArticleScreen` 默认继续走 `WebviewComp -> loadZhihu(...)`
- `prepareContentDocument(...)` 在送入 WebView 前预处理正文 HTML

### 4. WebView 承载层

- `loadZhihu(...)` 使用 `loadDataWithBaseURL(...)`
- `baseURL` 是知乎内容 URL，因此相对资源、脚注、部分链接解析依赖它
- 页面加载完成后注入：
- 点击监听脚本
- 脚注脚本
- 主题样式
- 内容高度上报脚本
- `shouldOverrideUrlLoading(...)` 负责区分站内内容跳转和外部链接跳转
- `WebviewComp` 通过 `onContentHeightCallback` 把内容高度同步到 Compose 外层，以避免 WebView 自己滚动

## Full / Condensed Transcript

1. 用户先要求分析子项目如何渲染问题正文。
2. 范围被澄清为：完整分析整个渲染方式，特别是正文。
3. 用户要求展开全部承载机制，因为准备迁移到自己的项目。
4. 迁移策略被澄清为：第一阶段先实现 WebView 方式。
5. 第一阶段保留：
   HTML 注入 + baseURL、图片/链接点击拦截、脚注脚本、内容高度上报 / 外层滚动同步。
6. 主题只做普通 / 黑暗模式切换。
7. Markdown/Compose fallback 被明确列为非目标。

## Execution Bridge

### Recommended: `$ralplan`

- Input artifact:
  `.omx/specs/deep-interview-analyze-question-body-rendering-zhihu-plus-plus.md`
- Why:
  下一步最适合把“分析结果”转成“迁移设计和测试计划”，尤其是把 `WebView` 主链拆成可实施模块。
- Expected output:
  迁移 PRD、测试规范、阶段拆分。

### Alternative: `$autopilot`

- Best when:
  你已经确定马上开始迁移，而且允许直接进入实现。

### Alternative: `$ralph`

- Best when:
  你希望一个 owner 持续推进到可验证完成。

### Alternative: `$team`

- Best when:
  你要把问题正文、回答正文、WebView 承载层、点击/脚注/滚动同步拆成并行 lane。

### Refine further

- Not recommended right now.
- 当前规格已经足够进入规划或实现。

