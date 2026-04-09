# PRD: HarmonyOS WebView Body Renderer Migration

## Context

The target HarmonyOS app already renders Zhihu answer/article/question/pin bodies through a simplified path:

- `ArticleDetailService.ts` maps API payloads into `ZhihuContentDetail.htmlContent`
- `Article.ets` builds `webDataUrl = htmlToDataUrl(buildArticleHtmlDocument(...))`
- `Article.ets` renders the result with `Web({ src: this.webDataUrl, controller: ... })`

The source Android app `zhihu-plus-plus` uses a richer WebView carrier with these behaviors:

- HTML injection with base URL semantics
- image/link click interception
- footnote script injection
- content-height reporting and outer-scroll sync
- normal/dark mode switching

Phase 1 migrates only the WebView-based body rendering path into the HarmonyOS target.

## Goal

Upgrade the HarmonyOS article/question body renderer so it preserves the source project's WebView carrier behaviors needed for content fidelity and interaction, while keeping the existing unified `Article` page architecture.

## Non-goals

- No Markdown/Compose fallback equivalent in phase 1
- No dedicated `Question` page in phase 1
- No export, AI summary, collection management, or answer-to-answer navigation parity
- No full theme-system parity beyond normal/dark body styling

## RALPLAN-DR Summary

### Principles

1. Preserve body-rendering behavior before expanding page architecture.
2. Reuse the target app's current unified `Article` page instead of introducing new routes in phase 1.
3. Isolate Web carrier mechanics into reusable modules so the `Article` page does not become the permanent dumping ground.
4. Prefer behavior parity for body interaction over UI parity for the surrounding page chrome.
5. Keep phase 1 reversible and testable with explicit manual verification checkpoints.

### Decision Drivers

1. The target project already has a working unified article/question page, so route churn is avoidable.
2. The migration priority is body fidelity and interaction, not full source-app architecture parity.
3. ArkWeb capability risk is concentrated in JS bridge, URL interception, and height sync, so the plan should localize that risk.

### Viable Options

#### Option A: Incremental enhancement of the existing `Article` page with a reusable ArkWeb carrier layer

Pros:
- Smallest diff against the current HarmonyOS architecture
- Reuses existing `ArticleDetailService.ts`, `ZhihuHtml.ts`, and `Article.ets`
- Fastest path to first working migration
- Keeps question bodies and answer bodies on one target page, matching current app behavior

Cons:
- Still depends on the existing `Article` page's mixed responsibilities
- Requires careful extraction so page code does not become more tangled

#### Option B: Introduce a new dedicated rich-content Web component plus a dedicated question detail page now

Pros:
- Closer long-term structural parity with the Android source
- Cleaner separation between question-body and answer-body flows

Cons:
- Larger scope and route churn in phase 1
- Higher regression risk in existing target navigation
- Delays delivery of the body-rendering behaviors the user actually wants first

### Chosen Option

Option A, with one constraint: do not bolt everything directly into `Article.ets`. Add a reusable ArkWeb carrier layer and shared content-builder helpers, then integrate them into the existing `Article` page.

### Why This Option Wins

It is the narrowest plan that satisfies the user’s explicit phase-1 constraints. It preserves the existing HarmonyOS app’s route model, avoids premature page proliferation, and concentrates the migration work around the exact behavior gap: the Web carrier.

## Product Scope

### In scope for phase 1

- Body HTML loading for answer/article/question/pin content
- Base URL preservation for relative content behavior
- Click interception for images and links
- Footnote script injection
- Content-height reporting from Web content to ArkTS
- Outer-scroll synchronization using reported content height
- Normal/dark mode body styling
- Reusable carrier modules that can be used by the existing `Article` page

### Explicitly deferred

- Alternate non-Web body rendering
- Question-page answer list parity with the Android source
- Complex in-body media affordances beyond click interception
- Advanced per-theme typography/custom font controls

## Target Design

### Target Architecture

Keep the current content flow:

`ArticleDetailService.ts -> ZhihuContentDetail.htmlContent -> builder/helpers -> reusable ArkWeb carrier -> Article.ets`

Add these reusable layers:

1. `ZhihuHtml.ts` expansion or split helper for richer document assembly
2. A new reusable ArkWeb carrier component/module
3. JS assets for click listening, footnote handling, and height reporting
4. A small interaction bridge that translates Web events into HarmonyOS page actions

### Likely File and Module Changes

- Update: `entry/src/main/ets/pages/Article.ets`
- Update: `entry/src/main/ets/utils/ZhihuHtml.ts`
- Update: `entry/src/main/ets/services/ArticleDetailService.ts`
- Add: `entry/src/main/ets/components/ZhihuRichWeb.ets`
- Add: `entry/src/main/ets/utils/ZhihuWebBridge.ts`
- Add: `entry/src/main/resources/base/rawfile/click-listener.js`
- Add: `entry/src/main/resources/base/rawfile/footnotes.js`
- Add: `entry/src/main/resources/base/rawfile/content-height.js`

If `rawfile/` is not the correct final resource location for ArkWeb script loading in this repo, adjust the asset container during implementation, but keep the scripts externalized rather than embedding long JS strings inline.

## Implementation Plan

### Step 0: Capability gate for ArkWeb carrier behavior

- Verify, inside the target HarmonyOS module, the exact hooks available for:
- JS/script injection
- Web-to-ArkTS event callback or equivalent bridge
- URL interception
- post-load height reporting
- page/container scroll ownership
- Record the exact ArkWeb API surface chosen before broad integration starts
- If one of these hooks is missing or materially weaker than expected, stop broad integration and adapt the carrier design first instead of spreading assumptions across page code
- Decide and document one scroll-owner model before integration:
- either the page owns scroll and the Web content reports height into a sized container
- or the Web owns scroll and the surrounding page avoids nested-scroll expectations
- Do not leave mixed scroll ownership implicit in `Article.ets`

### Step 1: Extract a reusable HarmonyOS rich-web carrier

- Create a reusable `ZhihuRichWeb` component around `@kit.ArkWeb`
- Define inputs:
- `html`
- `sourceUrl`
- `title`
- `themeMode`
- callbacks for link/image/body events
- Ensure the component is reusable by the current `Article` page without introducing new routing

### Step 2: Upgrade HTML document assembly

- Refactor `ZhihuHtml.ts` so it can generate a richer document shell
- Preserve base URL semantics explicitly
- Add stable hooks/ids/classes needed by:
- footnotes script
- click interception
- height reporting
- light/dark mode toggling

### Step 3: Add JS carrier assets

- Port and trim the source behavior into three focused scripts:
- click listener
- footnotes
- content-height reporter
- Keep scripts phase-1 minimal:
- no custom font system
- no Compose fallback support
- no advanced source-app-only features

### Step 4: Add interaction bridge

- Implement a small ArkTS bridge module that:
- injects/loads the JS assets into the Web content
- receives events from Web content
- routes image clicks and link clicks back to HarmonyOS page logic
- Use this bridge to keep `Article.ets` orchestration thin
- Constrain the bridge:
- only enable it for app-generated Zhihu content documents
- validate event payload shape and action type before acting on it
- do not expose a broad generic command surface to arbitrary loaded pages

### Step 5: Integrate into `Article.ets`

- Replace direct `Web({ src: this.webDataUrl })` body rendering with the reusable carrier
- Preserve existing summary/header/comment actions
- Keep existing question/answer/article/pin loading behavior intact
- For `target.kind === 'question'`, reuse the same carrier path with upgraded body behaviors
- If the page-owned-scroll model is chosen, refactor the page layout so summary/body scroll ownership is explicit instead of relying on the current fixed `layoutWeight(1)` Web region

### Step 6: Dark/light body mode support

- Map existing HarmonyOS theme state/resources into a simple two-state body style
- Do not port the source project’s full theme system
- Keep styles local to body rendering

## Risks

1. ArkWeb bridge capability mismatch
   - The target platform may expose different JS-bridge or page-event hooks than Android WebView.
   - Mitigation: implement the carrier behind a single module boundary and validate bridge behavior in Step 0 before broad page integration.

2. Height-sync instability
   - Reported content height may change after image load or after script-based DOM mutation.
   - Mitigation: report height multiple times, including post-load and post-image-load checkpoints.

3. Link interception regressions
   - Internal Zhihu links, external links, and image links may require different treatment.
   - Mitigation: define explicit routing categories and test each one manually.

4. Page complexity creep
   - The existing `Article.ets` page already owns a lot of behavior.
   - Mitigation: push all new Web-carrier mechanics into reusable component/helper modules.

5. Bridge exposure / content-surface safety
   - A permissive JS bridge can become an execution surface for unexpected page content.
   - Mitigation: scope the bridge to app-generated documents, whitelist event types, and reject malformed payloads.

## Assumptions

- The current HarmonyOS target should keep using the unified `Article` page for question and answer bodies in phase 1.
- The destination app does not need a non-Web body fallback in phase 1.
- Theme behavior only needs normal/dark states for the content document shell.

## Acceptance Criteria

1. Question, answer, article, and pin bodies still load through the current content-detail path, but render through the upgraded rich-web carrier.
2. The rendered body preserves base URL behavior for relative links/resources.
3. Clicking an in-body image is intercepted and routed to target-app handling.
4. Clicking an in-body link is intercepted and routed according to internal vs external destination rules.
5. Footnote behavior is available inside the rendered body.
6. Body content reports height back to ArkTS and the surrounding page uses that height to avoid broken nested scrolling.
7. Normal and dark body styles both render correctly.
8. No Markdown/Compose fallback path is added in phase 1.
9. The carrier bridge only accepts the minimal whitelisted event set needed for phase 1 interactions.

## Verification Strategy

- Static verification:
- type/build validation for the HarmonyOS module
- targeted diagnostics for newly added ArkTS modules

- Manual verification:
- question body render
- answer body render
- image click handling
- internal link handling
- external link handling
- footnote behavior
- delayed image load height updates
- no trapped or double-scroll behavior under the chosen scroll-owner model
- light mode body
- dark mode body
- malformed or unexpected bridge payloads are ignored safely if the chosen ArkWeb API makes this testable

## ADR

### Decision

Implement phase-1 migration by enhancing the existing HarmonyOS `Article` page with a reusable ArkWeb carrier layer, not by adding a new dedicated question page or a non-Web fallback.

### Drivers

- Existing target architecture already unifies question and answer body rendering.
- User explicitly wants WebView-first migration.
- Carrier behavior is the true gap, not route architecture.

### Alternatives Considered

- Option A: Incremental enhancement with reusable carrier layer
- Option B: New dedicated question page + richer route split now

### Why Chosen

Option A preserves current target architecture, minimizes route churn, and delivers the requested behavior with the smallest reversible surface.

### Consequences

- Phase 1 ships faster and with narrower scope.
- `Article.ets` remains the integration point, so code hygiene depends on extracting new carrier logic cleanly.
- Dedicated question-page parity can still be added later if needed.
- The implementation must pass a concrete ArkWeb capability gate before the integration work fans out.
- The implementation must also lock down bridge scope so the carrier does not become a generic scripting surface.

### Follow-ups

- Evaluate whether answer-list parity needs separate work after body migration lands.
- Reassess whether Markdown/Compose fallback is worth adding after WebView behavior is stable.
- Consider a later split between carrier component and page-level orchestration if more content types arrive.

## Downstream Execution Guidance

### Available agent types roster

- `planner`
- `architect`
- `critic`
- `executor`
- `debugger`
- `verifier`
- `test-engineer`
- `designer`
- `writer`
- `explore`
- `security-reviewer`
- `code-reviewer`

### Suggested staffing for `ralph`

- Single owner: `executor`
- Reasoning: `high`
- Verification support:
- `verifier` after implementation
- `test-engineer` if the first verification pass reveals weak manual coverage

### Suggested staffing for `$team`

- Lane 1: `executor` (`high`) for reusable ArkWeb carrier and bridge
- Lane 2: `executor` (`medium` or `high`) for HTML builder and script assets
- Lane 3: `executor` (`medium`) for `Article.ets` integration and theme wiring
- Lane 4: `verifier` (`high`) for manual verification script/checklist and completion evidence

### Team launch hints

- `$team .omx/plans/prd-webview-body-renderer-migration.md`
- If using explicit tmux/runtime orchestration, keep one verification lane separate from implementation lanes.

### Team verification path

1. Validate bridge and event flow in isolation.
2. Validate body render in the integrated `Article` page.
3. Run link/image/footnote/height-sync manual checks.
4. Run final build validation.
5. Only then mark phase 1 complete.
