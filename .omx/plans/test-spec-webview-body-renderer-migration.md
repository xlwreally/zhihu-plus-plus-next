# Test Spec: HarmonyOS WebView Body Renderer Migration

## Scope

This spec verifies phase-1 migration of the WebView-based body renderer from the Android source project into the HarmonyOS target project.

It covers:
- question body rendering
- answer body rendering
- image/link click interception
- footnote behavior
- content-height reporting and outer-scroll sync
- normal/dark body styling

It does not cover:
- Markdown/Compose fallback
- question answer-list parity beyond current target behavior
- export or AI-summary features

## Test Levels

### Capability Gate

Before broad integration, verify the chosen ArkWeb API surface can support:

1. Injecting or loading the required JS scripts into rendered content
2. Returning at least the required event classes back to ArkTS:
- image click
- link click
- content-height report
3. Intercepting URL loads before default navigation proceeds
4. Reacting after initial page/content load so the carrier can trigger footnote and height logic
5. Supporting the chosen scroll-owner model without ambiguous nested scrolling
6. Constraining the bridge/event surface to the minimum required interaction set

If any of these fail, broad page integration is blocked until the carrier design is adapted.

### Build / Static

1. HarmonyOS module build succeeds after the migration.
2. Newly added ArkTS modules have no diagnostics/type errors.
3. Resource references for JS assets resolve correctly.
4. Bridge/event types are defined in a narrow, explicit contract rather than generic command strings.

### Integration

1. `ArticleDetailService.ts` still returns valid `htmlContent` for:
- answer
- article
- question
- pin

2. `ZhihuRichWeb` integration receives:
- body HTML
- title
- source URL
- theme mode

3. Web event callbacks are wired from the carrier back into page logic.
4. Unexpected or malformed event payloads are ignored safely.

### Manual End-to-End

#### Case A: Question body render

- Open a question target in the HarmonyOS app
- Confirm the body appears in the Web carrier
- Confirm relative/link behavior still works under the configured source URL/base semantics

#### Case B: Answer body render

- Open an answer target in the HarmonyOS app
- Confirm the answer body appears in the Web carrier
- Confirm header and surrounding page actions still function

#### Case C: Image click interception

- Open content with at least one inline image
- Tap image
- Confirm the event is intercepted by app logic instead of silently doing nothing

#### Case D: Internal link interception

- Open content with an internal Zhihu link
- Tap link
- Confirm the app handles it with its intended internal navigation/opening behavior

#### Case E: External link interception

- Open content with an external link
- Tap link
- Confirm the app routes it via the intended external handling path

#### Case F: Footnote behavior

- Open content containing footnotes or equivalent annotated references
- Confirm the script-enhanced footnote behavior is active and readable

#### Case G: Height reporting and outer scroll

- Open long content with images
- Confirm the Web carrier height updates after initial render
- Confirm the page scroll remains usable and does not trap or double-scroll incorrectly
- Confirm late image loading does not leave the Web body clipped

#### Case G2: Scroll-owner consistency

- Exercise the page using the selected scroll-owner model
- Confirm there is only one user-visible primary scrolling behavior for body traversal
- Confirm header/body interaction does not jitter or fight for gesture ownership

#### Case H: Theme switching

- Verify normal mode body rendering
- Verify dark mode body rendering
- Confirm text, links, and block backgrounds remain legible in both modes

#### Case I: Bridge safety

- Trigger each supported interaction class and confirm it still works:
- image click
- link click
- height report
- If the API surface allows, simulate or log an unsupported event payload
- Confirm unsupported payloads are ignored without navigation or crash

## Acceptance Gate

The migration is ready for implementation completion review only if:

1. Build/static checks pass.
2. Question and answer bodies both render through the new carrier.
3. Image and link interception both work.
4. Footnote behavior works.
5. Height reporting prevents broken body clipping or unusable nested scrolling.
6. Normal/dark body styles are acceptable.
7. No Markdown fallback is introduced in phase 1.
8. Bridge/event handling remains narrow and does not accept unsupported commands.

## Evidence To Collect

- Step-0 capability notes describing the exact ArkWeb hooks selected
- Build output summary
- Before/after screenshots for:
- question body
- answer body
- dark mode
- Logs or screenshots showing link/image interception behavior
- Notes from manual verification of height-sync behavior
- Notes or logs showing the chosen scroll-owner model behaves consistently
- Notes or logs showing unsupported bridge payloads are ignored when testable
