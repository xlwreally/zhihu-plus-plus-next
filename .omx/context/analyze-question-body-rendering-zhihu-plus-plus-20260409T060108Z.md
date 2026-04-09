Task statement
- 分析子项目 `zhihu-plus-plus` 是怎么渲染“问题正文”的。

Desired outcome
- 给出问题详情页正文的实际渲染链路，并区分问题页与答案页的差异。

Stated solution
- 使用 `deep-interview` 模式，先做 brownfield 代码事实收集，再收紧分析边界。

Probable intent hypothesis
- 用户很可能想定位“问题详情页正文”到底走 `WebView` 还是 Compose 富文本，以及涉及哪些页面/服务/数据模型。

Known facts / evidence
- 子项目路径是 `zhihu-plus-plus/`。
- `zhihu-plus-plus/AGENTS.md` 指向 `zhihu-plus-plus/CLAUDE.md`，要求导航前检查 `NavDestination.kt`。
- `NavDestination.Question(questionId, title)` 是单独的页面目标。
- `ui/ZhihuMain.kt` 为 `Question` route 挂载 `QuestionScreen(question, innerPadding)`。
- `ui/QuestionScreen.kt` 在 `LaunchedEffect(question.questionId)` 中调用 `DataHolder.getContentDetail(context, question)` 获取问题详情。
- `data/DataHolder.kt` 的问题详情 API 为 `/api/v4/questions/{id}?include=...detail...`，并将响应解析成 `DataHolder.Question`，正文字段是 `detail: String`。
- `QuestionScreen.kt` 将 `questionData.detail` 赋给本地状态 `questionContent`。
- `QuestionScreen.kt` 渲染正文时分两条分支：
- 默认 `articleUseWebview=true` 时，调用 `WebviewComp { it.loadZhihu("https://www.zhihu.com/question/{id}", Jsoup.parse(questionContent)) }`
- 否则走 `htmlToMdAst(questionContent)`，再通过 `MdAst.Render()` 以 Compose 渲染。
- `ui/components/WebviewComp.kt` 中 `CustomWebView.loadZhihu()` 使用 `loadDataWithBaseURL(...)` 拼出 HTML 文档，正文直接取 `document.body().html()`。
- `WebviewComp` 页面加载完成后会注入点击监听、脚注脚本、主题样式和内容高度上报脚本。

Constraints
- 当前任务是分析，不做实现修改。
- 需要区分“问题正文”与“回答正文”，不能误把 `ArticleScreen` 当成问题正文页。

Unknowns / open questions
- 用户要的“问题正文”是仅限 `QuestionScreen` 顶部的 `questionData.detail`，还是也想顺带覆盖该页下方答案列表的渲染链。
- 用户希望最终产出偏“调用链总结”还是“逐文件源码讲解”。

Decision-boundary unknowns
- 是否把答案卡片点击后的 `ArticleScreen` 渲染链纳入本轮分析。

Likely codebase touchpoints
- `zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/NavDestination.kt`
- `zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/ZhihuMain.kt`
- `zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/QuestionScreen.kt`
- `zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/data/DataHolder.kt`
- `zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/ui/components/WebviewComp.kt`
- `zhihu-plus-plus/app/src/main/java/com/github/zly2006/zhihu/markdown/MdAst.kt`
