# zhihu-plus-plus-next

`zhihu-plus-plus-next` 是基于 [`zhihu-plus-plus`](https://github.com/zly2006/zhihu-plus-plus) 适配的 HarmonyOS NEXT 独立工程。

## 来源与许可

- 本仓库基于上游项目 [`zly2006/zhihu-plus-plus`](https://github.com/zly2006/zhihu-plus-plus) 二次开发。
- 当前 HarmonyOS NEXT 适配工作由 `xlwreally` 于 `2026-04-06` 起在上游项目基础上进行。
- 上游项目许可证为 `GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later)`，本仓库沿用同一许可证发布。
- 原项目的版权声明和许可证声明应继续保留；本仓库新增修改部分的版权归各自贡献者所有。
- 本仓库与知乎官方无关联。

## 目标

- 使用 Stage Model + ArkTS + 单 `entry` HAP
- 保留知乎协议层、数据模型和迁移边界
- 不尝试复用 Android Compose / Activity / Room / WebView 实现
- 先按 Lite MVP 迁移，再补导出、TTS、本地推荐、AI 过滤

## 当前结构

```text
zhihu-plus-plus-next/
├─ AppScope/
├─ entry/
│  └─ src/main/
│     ├─ ets/
│     │  ├─ entryability/
│     │  ├─ entrybackupability/
│     │  ├─ models/
│     │  ├─ pages/
│     │  ├─ services/
│     │  └─ utils/
│     └─ resources/
├─ zhihu-plus-plus/        # Android 原仓库（Git 子模块）
└─ hvigor/
```

## Android 原仓库子模块

当前工程已将 `zhihu-plus-plus` 作为 Git 子模块挂载到项目根目录：

```bash
git submodule update --init --recursive
```

如果是首次克隆当前仓库，建议直接使用：

```bash
git clone --recurse-submodules https://github.com/xlwreally/zhihu-plus-plus-next.git
```

## 当前状态

- 已落地一版极简应用壳，底部保留 4 个一级入口：
  - `主页`
  - `关注`
  - `日报`
  - `历史`
- 当前默认优先接入的是 `日报` 页面，其余 3 个入口先保留占位。
- `pages/Index.ets`
  - 当前不再是迁移控制台，而是实际页面壳。
  - 页面已适配深色模式资源。
  - 底部导航已做沉浸式处理，底部手势区不再额外留白。
- `services/ZhihuApi.ts`
  - 已作为 Harmony 网络层基础封装使用。
- `services/DailyService.ts`
  - 已接入知乎日报真实接口：
    - `https://news-at.zhihu.com/api/4/stories/latest`
    - `https://news-at.zhihu.com/api/4/stories/before/{date}`
- `resources/base/element/color.json`
- `resources/dark/element/color.json`
  - 当前页面颜色通过资源分层适配浅色/深色模式。

## 当前日报页能力

- 首次进入页面自动拉取最新日报
- 支持继续加载更早日期内容
- 按日期分组显示日报卡片
- 日报卡片宽度、圆角、行高已做统一
- 支持错误提示与重试

## 当前限制

- 日报列表暂未接入详情页跳转
- 日报卡片暂未接入封面图
- `主页 / 关注 / 历史` 仍是占位入口
- `ZhihuApi.ts` 当前仍有一个 ArkTS 编译警告待清理，但不影响构建

## 建议的下一步

1. 用 DevEco Studio 打开 `D:\code\DevecostudioProjects\zhihu-plus-plus-next`
2. 让 IDE 自动补齐签名配置和 `local.properties`
3. 先给日报页补上详情跳转与封面图
4. 再把 Android 版 `AccountData.kt` 拆成：
   - `ZhihuSessionRepository`
   - `ZhihuCookieStore`
   - `ZhihuApi`
   - `ZhihuSignerBridge`
5. 然后实现剩余一级入口：
   - 主页推荐流
   - 关注流
   - 历史记录
   - 登录与账号设置

## 本地预览构建

当前页面可直接使用 DevEco Studio 的预览构建命令验证：

```bash
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p module=entry@default -p product=default -p pageType=page -p compileResInc=true -p requiredDeviceType=phone -p previewMode=true -p buildRoot=.preview PreviewBuild --watch --analyze=normal --parallel --incremental --daemon
```

## API 版本

当前骨架使用：

- `modelVersion`: `6.0.2`
- `targetSdkVersion`: `6.0.2(22)`
- `compatibleSdkVersion`: `6.0.2(22)`

这是按本机现有 HarmonyOS 工程模板对齐的版本配置。
