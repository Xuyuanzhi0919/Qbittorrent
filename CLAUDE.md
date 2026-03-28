# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HarmonyOS (鸿蒙) ArkTS 应用项目，bundleName 为 `com.movie.qbittorrent`。基于 Stage 模型开发，目标 SDK 版本为 HarmonyOS 6.0.2(22)，设备类型为 phone。

## Build & Development

本项目使用 **Hvigor** 作为构建工具，**OHPM** 作为包管理器。需要在 DevEco Studio 中进行构建和运行。

- **构建**: 通过 DevEco Studio 的 Build 菜单，或命令行 `hvigorw assembleHap`
- **依赖安装**: `ohpm install`
- **代码检查**: `code-linter`（规则定义在 `code-linter.json5`，包含 `@performance/recommended` 和 `@typescript-eslint/recommended` 规则集，以及多项 `@security` 安全规则）
- **测试**: 测试框架使用 `@ohos/hypium`，测试文件位于：
  - 单元测试: `entry/src/test/`
  - 仪器测试: `entry/src/ohosTest/`

## Architecture

```
AppScope/              # 应用级配置和资源（app.json5、图标、字符串）
entry/                 # 主模块（entry HAP）
  src/main/
    ets/
      entryability/    # UIAbility 入口
      entrybackupability/  # 备份扩展能力
      pages/           # 页面（Index.ets 为首页）
    resources/         # 模块资源（字符串、颜色、图片、配置）
    module.json5       # 模块配置（abilities、extensionAbilities、页面路由）
hvigor/                # Hvigor 构建配置
oh-package.json5       # OHPM 依赖声明
build-profile.json5    # 构建配置（SDK 版本、签名、构建模式）
code-linter.json5      # 代码检查规则
```

## Key Conventions

- 使用 **ArkTS** 语言（`.ets` 文件），基于 TypeScript 扩展
- UI 使用声明式范式：`@Entry`、`@Component`、`@State` 等装饰器
- 页面路由通过 `entry/src/main/resources/base/profile/main_pages.json` 配置
- 日志使用 `hilog`，domain 为 `0x0000`，tag 为 `testTag`
- Release 构建启用代码混淆（属性名、顶层名、文件名、导出名）
- API 类型为 Stage 模式（`apiType: "stageMode"`）

## HarmonyOS Development Notes

- Kit 导入方式：`import { ... } from '@kit.xxx'`（如 `@kit.AbilityKit`、`@kit.ArkUI`、`@kit.PerformanceAnalysisKit`）
- 颜色模式支持：应用默认不设置颜色模式（`COLOR_MODE_NOT_SET`），在 `resources/dark/` 下提供暗色资源
- 项目的 `arkts-syntax-assistant` skill 可辅助 ArkTS 语法、迁移和优化问题
