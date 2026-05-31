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
  @State isReconnecting: boolean = false;
  @State isClearingConfig: boolean = false;
  @State actionMessage: string = '';
  @State @Watch('onAnySheetChanged') showDisconnectConfirm: boolean = false;
  @State @Watch('onAnySheetChanged') showClearConfigConfirm: boolean = false;
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
    const anyOpen: boolean = this.showDisconnectConfirm || this.showClearConfigConfirm;
    AppStorage.setOrCreate('showRootTabBar', !anyOpen);
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

  private async handleReconnect(): Promise<void> {
    if (this.isReconnecting || this.guestMode) {
      return;
    }
    this.isReconnecting = true;
    try {
      let hasConfig: boolean = this.connectionManager.serverConfig !== null;
      if (!hasConfig) {
        hasConfig = await this.connectionManager.loadSavedConfig();
      }
      if (!hasConfig) {
        this.showActionMessage('未找到服务器配置');
        return;
      }
      const connected: boolean = await this.connectionManager.autoReconnect();
      this.isConnected = connected;
      if (connected) {
        const config = this.connectionManager.serverConfig;
        if (config !== null) {
          this.serverUrl = config.url;
          this.serverUsername = config.username;
        }
        this.showActionMessage('已重新连接服务器');
        return;
      }
      this.showActionMessage('重新连接失败，请检查密码或网络');
    } finally {
      this.isReconnecting = false;
    }
  }

  private async handleClearConfig(): Promise<void> {
    if (this.isClearingConfig || this.guestMode) {
      return;
    }
    this.isClearingConfig = true;
    try {
      this.service.stopPolling();
      await this.connectionManager.disconnectAndClear();
      this.serverUrl = '';
      this.serverUsername = '';
      this.isConnected = false;
      this.showClearConfigConfirm = false;
      AppStorage.setOrCreate('currentTabIndex', 0);
      AppService.getNavPathStack().clear();
    } finally {
      this.isClearingConfig = false;
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
      Column() {
        Row()
          .width('100%')
          .height(440)
          .linearGradient({
            angle: 180,
            colors: [[$r('app.color.page_gradient_top'), 0], [$r('app.color.page_gradient_mid'), 0.5], [$r('app.color.page_background'), 1]]
          })
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      Scroll() {
        Column({ space: 12 }) {
          if (this.actionMessage.length > 0) {
            this.actionBanner()
          }

          this.headerSection()

          this.statusCard()

          this.overviewGrid()

          this.sectionLabel('连接')
          this.connectionGroup()

          this.sectionLabel('偏好')
          this.pollingGroup()

          this.sectionLabel('应用')
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
      .backgroundColor(Color.Transparent)
      .blur(this.showDisconnectConfirm || this.showClearConfigConfirm ? 16 : 0)
      .animation({ duration: 220, curve: Curve.EaseOut })

      if (this.showDisconnectConfirm) {
        this.disconnectConfirmDialog()
      }
      if (this.showClearConfigConfirm) {
        this.clearConfigConfirmDialog()
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
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(20)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  headerSection() {
    Row() {
      Text('我的')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(-0.5)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Row({ space: 8 }) {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getStatusColor())
        Text(this.getStatusText())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(24)
      .border({ width: 1, color: $r('app.color.glass_border') })
      .borderRadius(999)
    }
    .width('100%')
    .height(46)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  statusCard() {
    Column({ space: 18 }) {
      Row({ space: 14 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(24)
            .fontColor([$r('app.color.accent_color')])
        }
        .width(54)
        .height(54)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .border({ width: 1, color: $r('app.color.download_selected_border') })
        .borderRadius(20)

        Column({ space: 5 }) {
          Text(this.guestMode ? '示例体验账户' : 'qBittorrent 账户')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.5)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.getAccountText())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('管理连接')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .border({ width: 1, color: $r('app.color.download_selected_border') })
          .borderRadius(999)
          .onClick(() => {
            this.openServerConfig();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('app.color.glass_border'))

      Column({ space: 6 }) {
        Text('当前服务器')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text(this.getServerAddressText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(24)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(28)
    .shadow({
      radius: 20,
      color: '#0F172A14',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  overviewGrid() {
    Row({ space: 10 }) {
      this.overviewTile(
        '连接状态',
        this.getStatusText(),
        $r('sys.symbol.link'),
        this.getStatusColor(),
        this.getStatusBgColor()
      )
      this.overviewTile(
        '刷新频率',
        this.getPollingLabel(),
        $r('sys.symbol.arrow_2_circlepath'),
        $r('app.color.accent_color'),
        $r('app.color.dashboard_surface_info')
      )
    }
    .width('100%')
  }

  @Builder
  overviewTile(label: string, value: string, icon: Resource, toneColor: Resource, surfaceColor: Resource) {
    Column({ space: 10 }) {
      Row() {
        SymbolGlyph(icon)
          .fontSize(16)
          .fontColor([toneColor])
        Blank()
        Circle()
          .width(8)
          .height(8)
          .fill(toneColor)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 4 }) {
        Text(value)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(label)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(surfaceColor)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(20)
  }

  @Builder
  sectionLabel(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 0 })
  }

  @Builder
  connectionGroup() {
    Column() {
      this.settingsRow('服务器地址', this.getServerAddressText(), $r('sys.symbol.link'), () => {
        this.openServerConfig();
      })

      Divider()
        .color($r('app.color.dashboard_border_soft'))
        .margin({ left: 52 })

      this.settingsRow('登录账户', this.getAccountText(), $r('sys.symbol.person'), () => {
        this.openServerConfig();
      })

      if (!this.guestMode) {
        Divider()
          .color($r('app.color.dashboard_border_soft'))
          .margin({ left: 52 })

        this.reconnectRow()

        Divider()
          .color($r('app.color.dashboard_border_soft'))
          .margin({ left: 52 })

        this.clearConfigRow()
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(22)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(24)
    .clip(true)
  }

  @Builder
  settingsRow(label: string, value: string, icon: Resource, action: () => void) {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph(icon)
          .fontSize(16)
          .fontColor([$r('app.color.accent_color')])
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.dashboard_surface_info'))
      .borderRadius(999)

      Column({ space: 3 }) {
        Text(label)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Text(value)
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
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  reconnectRow() {
    Row({ space: 12 }) {
      Row() {
        if (this.isReconnecting) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('app.color.accent_color'))
        } else {
          SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
            .fontSize(16)
            .fontColor([$r('app.color.accent_color')])
        }
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.dashboard_surface_info'))
      .borderRadius(999)

      Column({ space: 3 }) {
        Text(this.isReconnecting ? '正在重新连接' : '重新连接')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text('使用已保存的服务器配置恢复会话')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.isConnected ? '刷新' : '连接')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .border({ width: 1, color: $r('app.color.download_selected_border') })
        .borderRadius(999)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .enabled(!this.isReconnecting)
    .onClick(() => {
      this.handleReconnect();
    })
  }

  @Builder
  clearConfigRow() {
    Row({ space: 12 }) {
      Row() {
        if (this.isClearingConfig) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('app.color.error_color'))
        } else {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(16)
            .fontColor([$r('app.color.error_color')])
        }
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.dashboard_surface_danger'))
      .borderRadius(999)

      Column({ space: 3 }) {
        Text(this.isClearingConfig ? '正在清除配置' : '清除服务器配置')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text('清除已保存的地址、账户和密码')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
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
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .enabled(!this.isClearingConfig)
    .onClick(() => {
      this.showClearConfigConfirm = true;
    })
  }

  @Builder
  pollingGroup() {
    Column({ space: 14 }) {
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
            .fontSize(16)
            .fontColor([$r('app.color.accent_color')])
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(999)

        Column({ space: 3 }) {
          Text('数据刷新间隔')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('影响仪表盘和下载列表更新频率')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.getPollingLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
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
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(22)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(24)
  }

  @Builder
  aboutGroup() {
    Column() {
      this.infoRow('应用版本', 'v1.0.0')

      Divider()
        .color($r('app.color.dashboard_border_soft'))
        .margin({ left: 16 })

      this.infoRow('WebUI API', 'qBittorrent 5.x')
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(22)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(24)
    .clip(true)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
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
    .borderRadius(999)
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

  @Builder
  clearConfigConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .onClick(() => {
          if (!this.isClearingConfig) {
            this.showClearConfigConfirm = false;
          }
        })

      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('清除服务器配置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('将清除已保存的服务器地址、账户和密码，并返回连接配置页。')
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
            .enabled(!this.isClearingConfig)
            .onClick(() => {
              this.showClearConfigConfirm = false;
            })

          Button(this.isClearingConfig ? '清除中…' : '确认清除')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor($r('app.color.tab_active_fg'))
            .backgroundColor($r('app.color.error_color'))
            .borderRadius(999)
            .enabled(!this.isClearingConfig)
            .onClick(() => {
              this.handleClearConfig();
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
