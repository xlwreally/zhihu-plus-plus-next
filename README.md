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

## 已预埋的迁移点

- `services/ZhihuApi.ts`
  - 预留了鸿蒙网络层入口，后续把 Android 里的 `AccountData.fetch*()`、Header 组装、Cookie 刷新搬进来。
- `services/SessionStore.ts`
  - 先用内存态保存会话与推荐模式，后续替换成真实 Preferences/RDB。
- `utils/SnakeCase.ts`
  - 对齐 Android 版 `snake_case -> camelCase` 的 JSON 转换逻辑。
- `pages/Index.ets`
  - 当前是迁移控制台页面，用来承接后续首页、设置页和模块状态展示。

## 建议的下一步

1. 用 DevEco Studio 打开 `D:\code\DevecostudioProjects\zhihu-plus-plus-next`
2. 让 IDE 自动补齐签名配置和 `local.properties`
3. 先把真实的 Preferences 持久化接入 `PreferenceStore.ts`
4. 再把 Android 版 `AccountData.kt` 拆成：
   - `ZhihuSessionRepository`
   - `ZhihuCookieStore`
   - `ZhihuApi`
   - `ZhihuSignerBridge`
5. 然后实现首批页面：
   - 登录
   - 首页推荐/热榜
   - 问题/回答/文章阅读

## API 版本

当前骨架使用：

- `modelVersion`: `6.0.2`
- `targetSdkVersion`: `6.0.2(22)`
- `compatibleSdkVersion`: `6.0.2(22)`

这是按本机现有 HarmonyOS 工程模板对齐的版本配置。
