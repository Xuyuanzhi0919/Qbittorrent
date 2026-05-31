# Repository Guidelines

## Project Structure & Module Organization

This is a HarmonyOS ArkTS application. The app module is `entry/`; global metadata and shared resources are under `AppScope/`. Main ArkTS source is in `entry/src/main/ets/`:

- `pages/` contains UI pages such as `DashboardPage.ets`, `TorrentListPage.ets`, and `ServerConfigPage.ets`.
- `components/` holds reusable ArkUI components.
- `service/`, `network/`, `store/`, and `model/` contain logic, API access, persistence, and typed data.
- `common/constants/` and `common/utils/` contain shared constants and formatting helpers.

Resources are in `entry/src/main/resources/`, including `base/` and `dark/` element definitions. Local tests are in `entry/src/test/`; device/emulator tests are in `entry/src/ohosTest/`.

## Build, Test, and Development Commands

Use DevEco Studio or the HarmonyOS Hvigor toolchain.

- `ohpm install`: install project dependencies from `oh-package.json5`.
- Open the project in DevEco Studio and run `entry`: builds and deploys the HAP.
- Run unit tests from DevEco Studio using `entry/src/test/`: executes Hypium local tests.
- Run instrumented tests from DevEco Studio using `entry/src/ohosTest/`: executes device/emulator tests.
- Run code inspection with `code-linter.json5` when available.

## Coding Style & Naming Conventions

Write ArkTS with explicit, stable types. Prefer `const`, avoid `any`/`unknown`, and define interfaces or classes for structured data. Avoid dynamic TypeScript patterns such as object shape mutation, index signatures, or broad structural typing.

Use 2-space indentation in `.ets` and `.json5`. Name pages, components, and models in PascalCase (`TorrentDetailPage.ets`, `ProgressBar.ets`). Name constants files by domain (`QbiApiPaths.ets`) and keep shared values under `common/constants/`.

## Testing Guidelines

Use Hypium tests for ArkTS behavior. Put fast local tests in `entry/src/test/` and device-dependent tests in `entry/src/ohosTest/ets/test/`. Name files with `.test.ets`, matching `LocalUnit.test.ets` and `Ability.test.ets`. Add or update tests when changing services, network parsing, formatting utilities, or stateful page behavior.

## Commit & Pull Request Guidelines

Recent history uses short Conventional Commit-style messages, for example `feat: rebuild dashboard and fix torrent control API`. Prefer `feat:`, `fix:`, `chore:`, or `test:` plus a concise imperative summary.

Pull requests should describe the user-visible change, list affected modules, mention test coverage, and include screenshots or recordings for UI changes. Link issues when applicable and call out API path, permission, or resource changes.

## Security & Configuration Tips

Do not commit secrets, real qBittorrent credentials, or local SDK paths from `local.properties`. Keep network endpoints configurable through the existing server configuration flow, and follow `code-linter.json5` security rules for cryptography and unsafe APIs.

## HarmonyOS AI Skill Notes

Reference: <https://github.com/DengShiyingA/harmonyos-ai-skill>. Use these notes as a compact project-local subset of that HarmonyOS knowledge pack.

- Treat this as a Stage-model HarmonyOS NEXT app. Prefer `UIAbility`, `module.json5`, resource qualifiers, and ArkUI declarative components over Android, React, Vue, or web-style assumptions.
- Keep ArkTS strict: avoid `any` and `unknown`, avoid dynamic object shape mutation, use explicit classes/interfaces for structured data, and use `Record<K, V>` only for true dictionary data.
- Keep `build()` pure and declarative. Do network calls, timers, subscriptions, and persistence reads in lifecycle methods such as `aboutToAppear()` and clean them up in `aboutToDisappear()`.
- Use ArkUI state intentionally: `@State` for local mutable UI state, `@Prop`/callbacks for child inputs, and shared storage only where cross-page state is already established in the project.
- Use resources instead of hard-coded colors for UI surfaces. Every new color used by pages or components should have matching `base` and `dark` resource values.
- For permissions and system APIs, update `entry/src/main/module.json5` and keep listener lifecycle paired: `on(...)` in appear/start paths, `off(...)` in disappear/stop paths.
- Prefer `Navigation`/project routing helpers already present in the app; do not introduce a second routing pattern.
- For list-heavy UI, prefer stable render keys, lazy rendering patterns where available, and avoid expensive work inside item builders.
- Use HarmonyOS APIs and kits directly when possible. For HTTP/network logic, follow the existing service/network layer instead of calling APIs directly from pages.
- Validate changes with DevEco Studio or Hvigor when available. If local CLI tools are unavailable, at least run static checks such as JSON parsing and `git diff --check`, then call out the compile gap.
