# User Instruction Memory

This file records user instructions, preferences, and teachings for reference in future interactions.

## Entries

[Current Build Status]
- Date: 2026-11-09
- The current `main` branch is an apktool project (`MiaoMiaoAssistant/`) targeting `3.0.1` (versionCode 52); the old Gradle `AndroidStudio/` tree only exists at tag `v3.0.0` and was removed from `main`.
- Do not run Gradle commands against `main`. On Windows, build through `scripts/build-wsl.ps1`; the smali tree contains case-only path collisions that cannot be checked out safely on NTFS.
- The `3.0.1` source fixes the accessibility settings activity package, removes unused `INTERNET`/`RECEIVE_BOOT_COMPLETED` permissions, sets `allowBackup=false`, and keeps the existing `miao_config` preference schema.
- Verified: commit `69297a3` builds `3.0.1` (versionCode 52) with apktool 2.10.0. The Debug APK passes v2/v3 signature verification and `zipalign -c -v 4`; SHA-256 is `D219FE0D19CB3783D1DF8E4C59A66B7F561D3168A60E74F2056781B448DE66EC`.
- Upgrade evidence: 2.5.0 is versionCode 50 with signer SHA-256 `31b4fdeda7978308fa185d9df78f52e9789c2d085feab2ae188db3d04f89369c`; the default debug signer is `865d3872a44e1500a1ee6fdf28e5aa3780763670d20029b91b0298b3ce9ff627`.
- In-place upgrade requires the original release keystore. `scripts/check-upgrade.ps1` checks package, strict versionCode increase, and signer; `scripts/build-wsl.ps1 -LegacyApk ...` enforces it after signing.
- Upgrade gate evidence: 2.5.0 against Debug `3.0.1` returns `UPGRADE_COMPATIBLE=false` with `signer_mismatch_use_original_release_keystore`; a Debug-resigned 2.5.0 control returns `true`.
- Settings evidence: 2.5.0 and 3.0.1 both use `miao_config`; the relevant T0/k smali is byte-identical after line-ending normalization, and startup has no `clear()` or `deleteSharedPreferences()`. Same-signature upgrade preserves prefs; a debug-signed build cannot replace 2.5.0.

[Project Knowledge Summary]
- Date: 2026-09-29
- Context: Discovered by Agent while restoring UI of the decompiled 喵喵助手 2.3.3 into the Compose codebase
- Category: Build Methods | Workflow & Collaboration
- Instructions:
  - Verification commands for this Android project: `./gradlew :app:compileDebugKotlin` and `./gradlew :app:testDebugUnitTest --tests "com.miaomiao.assistant.core.TextEngineTest"`, run with `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64` and `--console=plain --no-daemon` under `/workspace/MiaoMiaoAssistant`.
- [Superseded 2026-11-09] The Gradle commands above apply only to tag `v3.0.0`, not to `main`; use the apktool build scripts for current `main`.
  - No deployable web port exists for this project; UI work is verified by compilation + unit tests only.
  - UI restore workflow: engine semantics and layout structure come from decompiled 2.3.3 sources under `/tmp/opencode/decompiled/sources/...`; verify with compile + tests (no device preview available).
  - Glass blur is implemented natively (user reversed the earlier "remove glass" decision): page主体 recorded into `androidx.compose.ui.graphics.layer.GraphicsLayer` via `layer.record(...)` + drawn via `drawLayer(DrawScope, layer)`; glass panels blur it with `RenderEffect.createBlurEffect` (API 31+, lower versions degrade to unblurred) applied in `Modifier.graphicsLayer { renderEffect = ... }`.
  - Key API notes for compose-ui 1.7.3: `MaskFilter` no longer exists (use RenderEffect instead); `rememberGraphicsLayer` returns `androidx.compose.ui.graphics.layer.GraphicsLayer` (public `record(size: IntSize, density, layoutDirection) { DrawScope }` and `layer.drawLayer(DrawScope)` extension in `androidx.compose.ui.graphics.layer`); no opt-in annotations needed (GraphicsLayer API is stable in 1.7).
