# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HarmonyOS (鸿蒙) ArkTS 应用，bundleName `com.movie.qbittorrent`，对外显示名称 **TorrentPilot**。基于 Stage 模型，目标 SDK HarmonyOS 6.0.2(22)，设备类型 phone。

## Build & Development

构建工具 **Hvigor**，包管理器 **OHPM**，需在 DevEco Studio 中构建和运行。

- **构建**: DevEco Studio Build 菜单，或 `hvigorw assembleHap`
- **依赖安装**: `ohpm install`
- **代码检查**: `code-linter`（规则见 `code-linter.json5`：`@performance/recommended`、`@typescript-eslint/recommended` 以及多项 `@security` 规则）
- **测试框架**: `@ohos/hypium`；单元测试 `entry/src/test/`，仪器测试 `entry/src/ohosTest/`

## Coding Conventions

- ArkTS：显式类型，优先 `const`，不用 `any`/`unknown`；JSON 解析固定用 `Record<string, Object>`
- 缩进：`.ets` 和 `.json5` 均为 2 空格
- 命名：页面、组件、模型用 PascalCase（`TorrentDetailPage.ets`、`ProgressBar.ets`）
- 提交信息：Conventional Commits 风格，前缀 `feat:`、`fix:`、`chore:`、`test:`，简短祈使句

## Architecture

### Layered Structure

```
pages/           → UI 层：页面和用户交互
components/      → 可复用 UI 组件
service/         → 业务逻辑层
  AppService           → 纯静态注册中心，定义在 Index.ets，管理 NavPathStack、Tab 栏显隐、Service 实例
  ConnectionManager    → 认证与连接状态（SID cookie 会话），含自动重连
  QbittorrentService   → 高层 API 封装（种子操作、传输统计、轮询）
network/         → 网络层
  HttpClient           → HTTP 客户端单例，管理 baseUrl 和 SID cookie
  QbittorrentApi       → qBittorrent REST API 封装；constructor(useSharedClient=true) — false 时创建独立实例（仅用于连接验证）
  QbiApiPaths          → API 端点常量
model/           → 数据模型，均提供静态 fromJson(json) 工厂方法
store/           → 持久化（PreferencesStore — 服务器配置、记住密码、轮询间隔）
common/          → AppConstants（LOG_DOMAIN/TAG、HTTP_TIMEOUT=15s、DEFAULT_POLLING_INTERVAL=5s）、FormatUtils
mock/            → Demo 模式数据生成器 DemoDataProvider
```

### Key Architectural Patterns

- **AppService 静态注册中心**: 定义在 `Index.ets`，纯静态类，提供 `ConnectionManager`、`QbittorrentService`、`NavPathStack` 全局访问点
- **Service 单例**: `HttpClient`、`PreferencesStore` 使用 `static getInstance()`；`ConnectionManager` 由 `AppService` 懒加载持有
- **PreferencesStore 初始化**: 必须在 `EntryAbility.onCreate()` 中调用 `PreferencesStore.getInstance().init(context)`；其他调用者通过 `waitForInit()` 等待（轮询最多 5 秒）
- **状态管理**: 全局状态 `AppStorage` + `@StorageLink`；页面级状态 `@State`
- **导航**: 仅 `pages/Index` 注册于 `main_pages.json`；子页面通过 `AppService.pushPage()` 压入 `NavPathStack`，命名路由见下表
- **Tab 导航**: `HdsTabs`（`@kit.UIDesignKit`）隐藏内置 bar，自定义悬浮胶囊 Tab 栏，`AppStorage('currentTabIndex')` 控制；再次点击当前 Tab（下载列表）触发回顶信号
- **API 响应封装**: `ApiResult<T>` 统一包装，含 `success`、`data`、`error`、`statusCode`
- **认证流程**: `postForLogin` 从响应头提取 SID cookie，后续请求附带 `Cookie: SID=xxx`；403 表示 SID 失效；自动重连要求已保存密码（空密码跳过）
- **多 hash 格式**: 批量操作（pause/resume/delete/reannounce/setCategory）的 hashes 参数以 `|` 分隔；`removeCategories` 例外，用 `\n` 分隔
- **Tracker 过滤**: `getTorrentTrackers` 过滤掉 `tier < 0 && status === 0` 的内部条目
- **Demo 模式**: `AppStorage('guestMode')` 为 true 时 `DemoDataProvider` 生成模拟数据
- **断开连接**: `disconnect()` 保留已保存配置；`disconnectAndClear()` 同时清除持久化配置
- **沉浸式布局**: `EntryAbility` 设置 `setWindowLayoutFullScreen(true)` + 透明背景，状态栏颜色跟随深色模式切换（`onConfigurationChange` 触发）
- **底部 Sheet 与 Tab 栏**: 任意 bottom sheet 打开时，`onAnySheetChanged()` 将 `showRootTabBar` 置 false 隐藏 Tab 栏；关闭时恢复
- **下载完成通知**: `QbittorrentService` 在每次全量轮询（无 filter/hashes 参数）时调用 `checkAndNotifyCompletions`，通过 `@kit.NotificationKit` 推送；权限申请在 `EntryAbility.onWindowStageCreate` 中发起

### NavPathStack 命名路由

| 路由名 | 目标页面 | 参数 |
|--------|----------|------|
| `ServerConfig` | `ServerConfigPage` | 无 |
| `TorrentDetail` | `TorrentDetailPage` | `string`（torrentHash） |
| `AddTorrent` | `AddTorrentPage` | 无 |

### AppStorage Keys

| Key | Type | 用途 |
|-----|------|------|
| `isConnected` | boolean | 服务器连接状态 |
| `guestMode` | boolean | 演示模式开关 |
| `currentTabIndex` | number | 当前 Tab 索引（0=仪表盘, 1=种子列表, 2=设置） |
| `showRootTabBar` | boolean | Tab 栏显隐（进入详情页时隐藏，带 220ms 延迟恢复） |
| `torrentListRefreshToken` | number | 种子列表刷新信号（递增触发 `@Watch`） |
| `downloadTabScrollToTopToken` | number | 下载 Tab 回顶信号 |
| `rootTabBarReserveHeight` | number | Tab 栏占位高度（供子页面 padding 使用） |
| `navBlurLevel` | number | 导航栏模糊等级（≥1 使用 COMPONENT_THICK） |
| `navLowPowerMode` | boolean | 低功耗模式（减少动画和模糊效果） |

### Pages

- **Index.ets**: 主容器 + `AppService` 定义，管理初始化、连接状态、HdsTabs 切换和悬浮 Tab 栏
- **DashboardPage.ets**: 实时统计仪表盘（传输速度、连接数），轮询刷新
- **TorrentListPage.ets**: 种子列表，支持 `TorrentFilter`（ALL/DOWNLOADING/COMPLETED/PAUSED/ACTIVE/INACTIVE）筛选/排序/搜索/批量操作
- **TorrentDetailPage.ets**: 种子详情，多 Tab（信息/文件/Peers/Trackers）
- **AddTorrentPage.ets**: 添加种子（URL/磁力链接或 `.torrent` 文件，文件上传走 multipart POST）
- **ServerConfigPage.ets**: 服务器配置，含记住密码和演示模式入口
- **SettingsPage.ets**: 应用设置

## HarmonyOS Development Notes

- Kit 导入：`import { ... } from '@kit.xxx'`（AbilityKit、ArkUI、NetworkKit、PerformanceAnalysisKit、UIDesignKit、ArkData、LocalizationKit、NotificationKit）
- 日志：`hilog`，domain `0x0000`，tag `QbittorrentApp`
- Release 构建启用代码混淆（属性名、顶层名、文件名、导出名），规则见 `entry/obfuscation-rules.txt`
- 深色模式：应用默认 `COLOR_MODE_NOT_SET`，深色资源在 `resources/dark/`
- 项目的 `arkts-syntax-assistant` skill 可辅助 ArkTS 语法、迁移和优化问题
