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
import { hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { window, SymbolGlyphModifier } from '@kit.ArkUI';

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

  static pushPage(name: string, param?: Object): void {
    if (param === undefined) {
      AppService.getNavPathStack().pushPath({ name: name });
      return;
    }
    AppService.getNavPathStack().pushPath({ name: name, param: param });
  }
}

@Entry
@Component
struct Index {
  @State navPathStack: NavPathStack = new NavPathStack();
  @StorageLink('currentTabIndex') currentTabIndex: number = 0;
  @StorageLink('downloadTabScrollToTopToken') downloadTabScrollToTopToken: number = 0;
  @StorageLink('torrentListRefreshToken') torrentListRefreshToken: number = 0;
  @StorageLink('guestMode') guestMode: boolean = false;
  @StorageLink('isConnected') @Watch('onConnectedChanged') isConnected: boolean = false;
  @State isLoading: boolean = true;
  @State bottomAvoidHeight: number = 0;
  private hdsTabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    AppStorage.setOrCreate('isConnected', false);
    AppStorage.setOrCreate('currentTabIndex', 0);
    AppStorage.setOrCreate('downloadTabScrollToTopToken', 0);
    AppStorage.setOrCreate('torrentListRefreshToken', 0);
    AppStorage.setOrCreate('guestMode', false);
    AppStorage.setOrCreate('rootTabBarReserveHeight', 0);
    AppService.setNavPathStack(this.navPathStack);
    this.getBottomAvoidArea();
    this.initApp();
  }

  private async getBottomAvoidArea(): Promise<void> {
    try {
      const mainWindow: window.Window = window.findWindow('MainWindow') ??
        await window.getLastWindow(getContext(this));
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomAvoidHeight = avoidArea.bottomRect.height;
    } catch (err) {
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Failed to get bottom avoid area: ${JSON.stringify(err)}`);
      this.bottomAvoidHeight = 28;
    }
    AppStorage.setOrCreate('rootTabBarReserveHeight', this.bottomAvoidHeight + 86);
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
    if (!this.isConnected && !this.guestMode) {
      this.navPathStack.clear();
    }
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
    Navigation(this.navPathStack) {
      if (this.isLoading) {
        Column() {
          Column({ space: 16 }) {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('app.color.accent_color'))
            Column({ space: 4 }) {
              Text('TorrentPilot')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('远程下载控制台')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.page_background'))
      } else if (!this.isConnected && !this.guestMode) {
        ServerConfigPage()
      } else {
        HdsTabs({
          barPosition: BarPosition.End,
          index: this.currentTabIndex,
          controller: this.hdsTabsController
        }) {
          TabContent() {
            DashboardPage()
          }
          .tabBar(new BottomTabBarStyle(
            {
              normal: new SymbolGlyphModifier($r('sys.symbol.house')),
              selected: new SymbolGlyphModifier($r('sys.symbol.house_fill'))
            },
            '首页'
          ))

          TabContent() {
            TorrentListPage()
          }
          .tabBar(new BottomTabBarStyle(
            {
              normal: new SymbolGlyphModifier($r('sys.symbol.arrow_down_circle')),
              selected: new SymbolGlyphModifier($r('sys.symbol.arrow_down_circle'))
            },
            '下载'
          ))

          TabContent() {
            SettingsPage()
          }
          .tabBar(new BottomTabBarStyle(
            {
              normal: new SymbolGlyphModifier($r('sys.symbol.person')),
              selected: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
            },
            '我的'
          ))
        }
        .barOverlap(true)
        .scrollable(false)
        .animationDuration(0)
        .barFloatingStyle({
          barBottomMargin: this.bottomAvoidHeight + 6,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
        .width('100%')
        .height('100%')
      }
    }
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
    .titleMode(NavigationTitleMode.Mini)
    .backgroundColor($r('app.color.page_background'))
    .hideTitleBar(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }
}
