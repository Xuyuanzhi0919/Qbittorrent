import { ConnectionManager } from '../service/ConnectionManager';
import { QbittorrentService } from '../service/QbittorrentService';
import { ServerConfigPage } from './ServerConfigPage';
import { DashboardPage } from './DashboardPage';
import { TorrentListPage } from './TorrentListPage';
import { TorrentDetailPage } from './TorrentDetailPage';
import { AddTorrentPage } from './AddTorrentPage';
import { SettingsPage } from './SettingsPage';

// 全局服务实例 - 使用单例模式确保所有页面使用同一实例
export class AppService {
  private static connectionManager: ConnectionManager | null = null;
  private static service: QbittorrentService | null = null;

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
}

@Entry
@Component
struct Index {
  @State navPathStack: NavPathStack = new NavPathStack();
  @StorageLink('isConnected') @Watch('onConnectedChanged') isConnected: boolean = false;

  aboutToAppear(): void {
    // 初始化 AppStorage 中的连接状态
    AppStorage.setOrCreate('isConnected', false);
    this.initApp();
  }

  private async initApp(): Promise<void> {
    const connectionManager = AppService.getConnectionManager();
    const hasConfig: boolean = await connectionManager.loadSavedConfig();
    if (hasConfig) {
      const connected: boolean = await connectionManager.autoReconnect();
      this.isConnected = connected;
      if (connected) {
        this.navPathStack.replacePath({ name: 'Dashboard' });
      } else {
        this.navPathStack.replacePath({ name: 'ServerConfig' });
      }
    } else {
      this.navPathStack.replacePath({ name: 'ServerConfig' });
    }
  }

  private onConnectedChanged(): void {
    if (!this.isConnected && this.navPathStack.size() > 0) {
      this.navPathStack.clear();
      this.navPathStack.replacePath({ name: 'ServerConfig' });
    }
  }

  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === 'ServerConfig') {
      ServerConfigPage();
    } else if (name === 'Dashboard') {
      DashboardPage();
    } else if (name === 'TorrentList') {
      TorrentListPage();
    } else if (name === 'TorrentDetail') {
      TorrentDetailPage({ torrentHash: param as string });
    } else if (name === 'AddTorrent') {
      AddTorrentPage();
    } else if (name === 'Settings') {
      SettingsPage();
    }
  }

  build() {
    Navigation(this.navPathStack) {
    }
    .mode(NavigationMode.Stack)
    .navDestination(this.navDestinationBuilder)
    .titleMode(NavigationTitleMode.Mini)
    .backgroundColor($r('app.color.page_background'))
  }
}
