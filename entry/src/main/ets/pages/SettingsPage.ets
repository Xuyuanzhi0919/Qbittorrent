import { ConnectionManager } from '../service/ConnectionManager';
import { QbittorrentService } from '../service/QbittorrentService';
import { PreferencesStore } from '../store/PreferencesStore';
import { AppConstants } from '../common/constants/AppConstants';
import { AppService } from './Index';
import { DemoDataProvider } from '../mock/DemoDataProvider';

@Component
export struct SettingsPage {
  private connectionManager: ConnectionManager = AppService.getConnectionManager();
  private service: QbittorrentService = AppService.getService();
  @StorageLink('isConnected') isConnected: boolean = false;
  @StorageLink('guestMode') guestMode: boolean = false;
  @StorageLink('rootTabBarReserveHeight') rootTabBarReserveHeight: number = 0;
@State serverUrl: string = '';
  @State serverUsername: string = '';
  @State pollingInterval: number = AppConstants.DEFAULT_POLLING_INTERVAL;
  @State isDisconnecting: boolean = false;
  @State actionMessage: string = '';
  @State showDisconnectConfirm: boolean = false;
  private actionMessageTimer: number = -1;

  async aboutToAppear(): Promise<void> {
    if (this.guestMode) {
      this.serverUrl = DemoDataProvider.getServerUrl();
      this.serverUsername = DemoDataProvider.getUsername();
    } else {
      const config = this.connectionManager.serverConfig;
      if (config !== null) {
        this.serverUrl = config.url;
        this.serverUsername = config.username;
      } else {
        this.serverUrl = '';
        this.serverUsername = '';
      }
    }
    const store: PreferencesStore = PreferencesStore.getInstance();
    this.pollingInterval = await store.loadPollingInterval();
  }

  aboutToDisappear(): void {
    if (this.actionMessageTimer !== -1) {
      clearTimeout(this.actionMessageTimer);
      this.actionMessageTimer = -1;
    }
  }

  private async handleDisconnect(): Promise<void> {
    if (this.isDisconnecting) {
      return;
    }
    this.isDisconnecting = true;
    try {
      this.service.stopPolling();
      await this.connectionManager.disconnect();
      this.isConnected = false;
    } finally {
      this.isDisconnecting = false;
      this.showDisconnectConfirm = false;
    }
  }

  private exitGuestMode(): void {
    this.guestMode = false;
    this.showDisconnectConfirm = false;
    AppStorage.setOrCreate('currentTabIndex', 0);
    AppService.getNavPathStack().clear();
  }

  private async savePollingInterval(interval: number): Promise<void> {
    this.pollingInterval = interval;
    const store: PreferencesStore = PreferencesStore.getInstance();
    await store.savePollingInterval(interval);
    this.showActionMessage(`已切换为 ${Math.floor(interval / 1000)} 秒刷新`);
  }

  private openServerConfig(): void {
    AppService.pushPage('ServerConfig');
  }

  private getPollingLabel(): string {
    return `${Math.floor(this.pollingInterval / 1000)} 秒同步`;
  }

  private getServerSummaryText(): string {
    const url: string = this.serverUrl.trim();
    const username: string = this.serverUsername.trim();
    if (url.length === 0 && username.length === 0) {
      return this.guestMode ? '演示节点 · demo.operator' : '尚未配置服务器';
    }
    if (url.length === 0) {
      return username;
    }
    if (username.length === 0) {
      return url;
    }
    return `${url} · ${username}`;
  }

  private getServerAddressText(): string {
    if (this.serverUrl.trim().length > 0) {
      return this.serverUrl;
    }
    return this.guestMode ? DemoDataProvider.getServerUrl() : '未配置';
  }

  private getAccountText(): string {
    if (this.serverUsername.trim().length > 0) {
      return this.serverUsername;
    }
    return this.guestMode ? DemoDataProvider.getUsername() : '未配置';
  }

  private showActionMessage(message: string): void {
    this.actionMessage = message;
    if (this.actionMessageTimer !== -1) {
      clearTimeout(this.actionMessageTimer);
    }
    this.actionMessageTimer = setTimeout(() => {
      this.actionMessage = '';
      this.actionMessageTimer = -1;
    }, 2200);
  }

  build() {
    Stack() {
      Circle()
        .width(228)
        .height(228)
        .fill($r('app.color.dashboard_decor_primary'))
        .opacity(0.9)
        .position({ x: 254, y: -76 })

      Circle()
        .width(172)
        .height(172)
        .fill($r('app.color.dashboard_decor_secondary'))
        .opacity(0.96)
        .position({ x: -52, y: 90 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.actionMessage.length > 0) {
            this.actionBanner()
          }
          this.headerSection()
          this.serverSummaryBar()
          this.connectionCard()
          this.refreshCard()
          this.aboutCard()
          this.disconnectButton()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 62, bottom: this.rootTabBarReserveHeight + 14 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      if (this.showDisconnectConfirm) {
        this.disconnectConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private actionBanner() {
    Row() {
      Text(this.actionMessage)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Text('关闭')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .onClick(() => {
          this.actionMessage = '';
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(16)
  }

  @Builder
  private headerSection() {
    Column({ space: 4 }) {
      Text('DOWNLOAD CENTER')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(1)
        .fontColor($r('app.color.text_secondary'))

      Text('设置中心')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private serverSummaryBar() {
    Row() {
      Column({ space: 4 }) {
        Text('当前服务节点')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))

        Text(this.getServerSummaryText())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(this.isConnected ? '已连接' : (this.guestMode ? '示例体验' : '未连接'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isConnected ? $r('app.color.success_color') : (this.guestMode ? $r('app.color.accent_color') : $r('app.color.error_color')))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.isConnected ? $r('app.color.dashboard_surface_success') : (this.guestMode ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_danger')))
          .borderRadius(999)

        Text(this.getPollingLabel())
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_color'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
  }

  @Builder
  private connectionCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text('连接与账户')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('当前服务节点与登录身份')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.isConnected ? '已连接' : (this.guestMode ? '示例体验' : '未连接'))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isConnected ? $r('app.color.success_color') : (this.guestMode ? $r('app.color.accent_color') : $r('app.color.error_color')))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.isConnected ? $r('app.color.dashboard_surface_success') : (this.guestMode ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_danger')))
          .border({
            width: 1,
            color: this.isConnected ? $r('app.color.success_color') : (this.guestMode ? $r('app.color.download_selected_border') : $r('app.color.download_warn_border'))
          })
          .borderRadius(999)
      }
      .width('100%')

      this.serverAddressRow()
      this.accountRow()
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
  }

  @Builder
  private refreshCard() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text('刷新间隔')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('控制队列与详情页的轮询频率')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 6 }) {
        Button('1 秒')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pollingInterval === 1000 ? $r('app.color.tab_active_fg') : $r('app.color.text_secondary'))
          .backgroundColor(this.pollingInterval === 1000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_surface_soft'))
          .border({
            width: 1,
            color: this.pollingInterval === 1000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_border')
          })
          .borderRadius(16)
          .onClick(() => this.savePollingInterval(1000))

        Button('2 秒')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pollingInterval === 2000 ? $r('app.color.tab_active_fg') : $r('app.color.text_secondary'))
          .backgroundColor(this.pollingInterval === 2000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_surface_soft'))
          .border({
            width: 1,
            color: this.pollingInterval === 2000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_border')
          })
          .borderRadius(16)
          .onClick(() => this.savePollingInterval(2000))

        Button('5 秒')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pollingInterval === 5000 ? $r('app.color.tab_active_fg') : $r('app.color.text_secondary'))
          .backgroundColor(this.pollingInterval === 5000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_surface_soft'))
          .border({
            width: 1,
            color: this.pollingInterval === 5000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_border')
          })
          .borderRadius(16)
          .onClick(() => this.savePollingInterval(5000))

        Button('10 秒')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pollingInterval === 10000 ? $r('app.color.tab_active_fg') : $r('app.color.text_secondary'))
          .backgroundColor(this.pollingInterval === 10000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_surface_soft'))
          .border({
            width: 1,
            color: this.pollingInterval === 10000 ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_border')
          })
          .borderRadius(16)
          .onClick(() => this.savePollingInterval(10000))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
  }

  @Builder
  private aboutCard() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text('关于应用')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('版本与基础信息')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.versionRow()
      this.apiRow()
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
  }

  @Builder
  private disconnectButton() {
    Button(this.guestMode ? '退出示例体验' : (this.isDisconnecting ? '断开中...' : '断开当前服务器'))
      .width('100%')
      .height(48)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.guestMode ? $r('app.color.accent_color') : $r('app.color.error_color'))
      .backgroundColor(this.guestMode ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_danger'))
      .border({
        width: 1,
        color: this.guestMode ? $r('app.color.download_selected_border') : $r('app.color.download_warn_border')
      })
      .borderRadius(18)
      .enabled(!this.isDisconnecting)
      .onClick(() => {
        if (this.guestMode) {
          this.exitGuestMode();
          return;
        }
        this.showDisconnectConfirm = true;
      })
  }

  @Builder
  private disconnectConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .onClick(() => {
          if (!this.isDisconnecting) {
            this.showDisconnectConfirm = false;
          }
        })

      Column({ space: 14 }) {
        Text('断开服务器')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('将断开当前 qBittorrent 连接，并返回服务器配置页。')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(999)
            .enabled(!this.isDisconnecting)
            .onClick(() => {
              this.showDisconnectConfirm = false;
            })

          Button(this.isDisconnecting ? '断开中...' : '确认断开')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.tab_active_fg'))
            .backgroundColor($r('app.color.error_color'))
            .borderRadius(999)
            .enabled(!this.isDisconnecting)
            .onClick(() => {
              this.handleDisconnect();
            })
        }
        .width('100%')
      }
      .width(286)
      .padding(18)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private serverAddressRow() {
    Row() {
      Column({ space: 4 }) {
        Text('服务器地址')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))

        Text(this.getServerAddressText())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('编辑')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.accent_color'))
        .onClick(() => this.openServerConfig())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(16)
  }

  @Builder
  private accountRow() {
    Row() {
      Column({ space: 4 }) {
        Text('登录账户')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))

        Text(this.getAccountText())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('切换')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.accent_color'))
        .onClick(() => this.openServerConfig())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(16)
  }

  @Builder
  private versionRow() {
    Row() {
      Text('当前版本')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))

      Blank()

      Text('v1.0.0')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(16)
  }

  @Builder
  private apiRow() {
    Row() {
      Text('WebUI API')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))

      Blank()

      Text('qBittorrent 5.x')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(16)
  }
}
