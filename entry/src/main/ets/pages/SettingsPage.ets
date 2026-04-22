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
  @State @Watch('onAnySheetChanged') showDisconnectConfirm: boolean = false;
  private actionMessageTimer: number = -1;
  private readonly pollingOptions: number[] = [1000, 2000, 5000, 10000];

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
    AppStorage.setOrCreate('showRootTabBar', true);
  }

  private onAnySheetChanged(): void {
    AppStorage.setOrCreate('showRootTabBar', !this.showDisconnectConfirm);
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
    return `${Math.floor(this.pollingInterval / 1000)} 秒`;
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

  private getStatusColor(): Resource {
    if (this.guestMode) {
      return $r('app.color.accent_color');
    }
    return this.isConnected ? $r('app.color.success_color') : $r('app.color.error_color');
  }

  private getStatusBgColor(): Resource {
    if (this.guestMode) {
      return $r('app.color.dashboard_surface_info');
    }
    return this.isConnected ? $r('app.color.dashboard_surface_success') : $r('app.color.dashboard_surface_danger');
  }

  private getStatusText(): string {
    if (this.guestMode) {
      return '示例体验';
    }
    return this.isConnected ? '已连接' : '未连接';
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          if (this.actionMessage.length > 0) {
            this.actionBanner()
          }

          this.headerSection()

          this.statusCard()

          this.sectionLabel('连接配置')
          this.connectionGroup()

          this.sectionLabel('轮询频率')
          this.pollingGroup()

          this.sectionLabel('关于')
          this.aboutGroup()

          this.disconnectArea()

          Blank().height(this.rootTabBarReserveHeight + 14)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 62 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
      .blur(this.showDisconnectConfirm ? 16 : 0)
      .animation({ duration: 220, curve: Curve.EaseOut })

      if (this.showDisconnectConfirm) {
        this.disconnectConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  actionBanner() {
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
    .border({ width: 1, color: $r('app.color.dashboard_border') })
    .borderRadius(16)
    .margin({ bottom: 12 })
  }

  @Builder
  headerSection() {
    Text('设置')
      .fontSize(28)
      .fontWeight(FontWeight.Bold)
      .letterSpacing(-0.5)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .margin({ bottom: 20 })
  }

  @Builder
  statusCard() {
    Row() {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Row()
            .width(8)
            .height(8)
            .backgroundColor(this.getStatusColor())
            .borderRadius(999)
          Text(this.getStatusText())
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getStatusColor())
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.getStatusBgColor())
        .borderRadius(999)

        Text(this.getServerAddressText())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.guestMode ? '演示模式' : (this.serverUsername.length > 0 ? `账户：${this.serverUsername}` : '未配置账户'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('管理连接')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(999)
        .onClick(() => {
          this.openServerConfig();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.dashboard_border') })
    .borderRadius(20)
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 20 })
  }

  @Builder
  sectionLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 8 })
  }

  @Builder
  connectionGroup() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('服务器地址')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Text(this.getServerAddressText())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.tab_inactive_fg')])
      }
      .width('100%')
      .padding({ left: 16, right: 14, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openServerConfig();
      })

      Divider()
        .color($r('app.color.dashboard_border_soft'))
        .margin({ left: 16 })

      Row() {
        Column({ space: 3 }) {
          Text('登录账户')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Text(this.getAccountText())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.tab_inactive_fg')])
      }
      .width('100%')
      .padding({ left: 16, right: 14, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openServerConfig();
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.dashboard_border') })
    .borderRadius(20)
    .clip(true)
    .margin({ bottom: 20 })
  }

  @Builder
  pollingGroup() {
    Column({ space: 12 }) {
      Row() {
        Text('数据刷新间隔')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(`当前 ${this.getPollingLabel()}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        ForEach(this.pollingOptions, (ms: number) => {
          Row() {
            Text(`${Math.floor(ms / 1000)}s`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.pollingInterval === ms ? $r('app.color.tab_active_fg') : $r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .height(38)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.pollingInterval === ms ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_surface_soft'))
          .border({
            width: 1,
            color: this.pollingInterval === ms ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_border')
          })
          .borderRadius(999)
          .onClick(() => {
            this.savePollingInterval(ms);
          })
        }, (ms: number) => ms.toString())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.dashboard_border') })
    .borderRadius(20)
    .margin({ bottom: 20 })
  }

  @Builder
  aboutGroup() {
    Column() {
      Row() {
        Text('应用版本')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('v1.0.0')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('app.color.dashboard_border_soft'))
        .margin({ left: 16 })

      Row() {
        Text('WebUI API')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('qBittorrent 5.x')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.dashboard_border') })
    .borderRadius(20)
    .clip(true)
    .margin({ bottom: 20 })
  }

  @Builder
  disconnectArea() {
    Row() {
      Text(this.guestMode ? '退出示例体验' : (this.isDisconnecting ? '断开中…' : '断开当前服务器'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.guestMode ? $r('app.color.accent_color') : $r('app.color.error_color'))
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.guestMode ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_danger'))
    .border({
      width: 1,
      color: this.guestMode ? $r('app.color.download_selected_border') : $r('app.color.download_warn_border')
    })
    .borderRadius(20)
    .onClick(() => {
      if (this.isDisconnecting) {
        return;
      }
      if (this.guestMode) {
        this.exitGuestMode();
        return;
      }
      this.showDisconnectConfirm = true;
    })
  }

  @Builder
  disconnectConfirmDialog() {
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

      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('断开服务器')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('将断开当前 qBittorrent 连接，并返回服务器配置页。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(999)
            .enabled(!this.isDisconnecting)
            .onClick(() => {
              this.showDisconnectConfirm = false;
            })

          Button(this.isDisconnecting ? '断开中…' : '确认断开')
            .layoutWeight(1)
            .height(44)
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
      .width(290)
      .padding(20)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }
}
