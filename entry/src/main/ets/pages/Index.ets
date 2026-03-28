import { ConnectionManager } from '../service/ConnectionManager';
import { QbittorrentService } from '../service/QbittorrentService';
import { ServerConfigPage } from './ServerConfigPage';
import { DashboardPage } from './DashboardPage';
import { TorrentListPage } from './TorrentListPage';
import { TorrentDetailPage } from './TorrentDetailPage';
import { AddTorrentPage } from './AddTorrentPage';
import { SettingsPage } from './SettingsPage';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../common/constants/AppConstants';

// Tab 项接口定义
interface TabItem {
  title: string;
  icon: Resource;
  activeIcon: Resource;
  index: number;
}

// 全局服务实例
export class AppService {
  private static connectionManager: ConnectionManager | null = null;
  private static service: QbittorrentService | null = null;
  private static navPathStack: NavPathStack | null = null;

  static getConnectionManager(): ConnectionManager {
    if (!AppService.connectionManager) {
      AppService.connectionManager = new ConnectionManager();
    }
    return AppService.connectionManager;
  }

  static getService(): QbittorrentService {
    if (!AppService.service) {
      AppService.service = new QbittorrentService(AppService.getConnectionManager());
    }
    return AppService.service;
  }

  static getNavPathStack(): NavPathStack {
    return AppService.navPathStack ?? new NavPathStack();
  }

  static setNavPathStack(stack: NavPathStack): void {
    AppService.navPathStack = stack;
  }
}

@Entry
@Component
struct Index {
  @State navPathStack: NavPathStack = new NavPathStack();
  @State currentTabIndex: number = 0;
  @StorageLink('isConnected') @Watch('onConnectedChanged') isConnected: boolean = false;
  @State isLoading: boolean = true;

  aboutToAppear(): void {
    AppStorage.setOrCreate('isConnected', false);
    AppService.setNavPathStack(this.navPathStack);
    this.initApp();
  }

  private async initApp(): Promise<void> {
    const connectionManager = AppService.getConnectionManager();
    const hasConfig: boolean = await connectionManager.loadSavedConfig();
    if (hasConfig) {
      const connected: boolean = await connectionManager.autoReconnect();
      this.isConnected = connected;
    }
    this.isLoading = false;
  }

  private onConnectedChanged(): void {
    if (!this.isConnected) {
      this.navPathStack.clear();
    }
  }

  @Builder
  tabBuilder(title: string, icon: Resource, activeIcon: Resource, isActive: boolean) {
    Column({ space: 4 }) {
      SymbolGlyph(isActive ? activeIcon : icon)
        .fontSize(24)
        .fontColor([isActive ? $r('app.color.accent_color') : $r('app.color.text_secondary')])
        .animation({
          duration: 200,
          curve: Curve.EaseInOut
        })
      Text(title)
        .fontSize(11)
        .fontWeight(isActive ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(isActive ? $r('app.color.accent_color') : $r('app.color.text_secondary'))
        .animation({
          duration: 200,
          curve: Curve.EaseInOut
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.tab_bar_background'))
  }

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === 'ServerConfig') {
      ServerConfigPage()
    } else if (name === 'TorrentDetail') {
      TorrentDetailPage({ torrentHash: param as string })
    } else if (name === 'AddTorrent') {
      AddTorrentPage()
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 主内容区域
      Navigation(this.navPathStack) {
        if (this.isLoading) {
          Column() {
            Column({ space: 16 }) {
              LoadingProgress()
                .width(48)
                .height(48)
                .color($r('app.color.accent_color'))
              Column({ space: 4 }) {
                Text('qBittorrent')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text('远程管理客户端')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.page_background'))
        } else if (!this.isConnected) {
          ServerConfigPage()
        } else {
          Column() {
            // Tab 内容
            Stack() {
              if (this.currentTabIndex === 0) {
                DashboardPage()
              } else if (this.currentTabIndex === 1) {
                TorrentListPage()
              } else if (this.currentTabIndex === 2) {
                SettingsPage()
              }
            }
            .width('100%')
            .layoutWeight(1)

            // 自定义底部导航栏
            this.customTabBar()
          }
          .width('100%')
          .height('100%')
        }
      }
      .mode(NavigationMode.Stack)
      .navDestination(this.navDestinationBuilder)
      .titleMode(NavigationTitleMode.Mini)
      .backgroundColor($r('app.color.page_background'))
      .hideTitleBar(!this.isConnected)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  customTabBar() {
    Row() {
      ForEach([
        { title: '首页', icon: $r('sys.symbol.house'), activeIcon: $r('sys.symbol.house_fill'), index: 0 },
        { title: '下载', icon: $r('sys.symbol.arrow_down'), activeIcon: $r('sys.symbol.arrow_down'), index: 1 },
        { title: '我的', icon: $r('sys.symbol.person'), activeIcon: $r('sys.symbol.person_fill'), index: 2 }
      ] as TabItem[], (item: TabItem) => {
        Column({ space: 4 }) {
          Stack({ alignContent: Alignment.Center }) {
            // 选中指示器
            if (this.currentTabIndex === item.index) {
              Column()
                .width(32)
                .height(3)
                .backgroundColor($r('app.color.accent_color'))
                .borderRadius(2)
                .margin({ bottom: 4 })
            }

            Column({ space: 4 }) {
              SymbolGlyph(this.currentTabIndex === item.index ? item.activeIcon : item.icon)
                .fontSize(24)
                .fontColor([this.currentTabIndex === item.index ?
                  $r('app.color.accent_color') : $r('app.color.text_secondary')])
              Text(item.title)
                .fontSize(11)
                .fontWeight(this.currentTabIndex === item.index ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.currentTabIndex === item.index ?
                  $r('app.color.accent_color') : $r('app.color.text_secondary'))
            }
          }
          .layoutWeight(1)
          .height('100%')
          .onClick(() => {
            this.currentTabIndex = item.index;
          })
        }
        .layoutWeight(1)
        .height('100%')
      })
    }
    .width('100%')
    .height(56)
    .backgroundColor($r('app.color.tab_bar_background'))
    .shadow({
      radius: 20,
      color: $r('app.color.shadow_color'),
      offsetX: 0,
      offsetY: -2
    })
  }
}
