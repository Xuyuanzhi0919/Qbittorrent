import { ConnectionManager } from '../service/ConnectionManager';
import { QbittorrentService } from '../service/QbittorrentService';
import { PreferencesStore } from '../store/PreferencesStore';
import { AppConstants } from '../common/constants/AppConstants';
import { AppService } from './Index';

@Component
export struct SettingsPage {
  private connectionManager: ConnectionManager = AppService.getConnectionManager();
  private service: QbittorrentService = AppService.getService();
  @StorageLink('isConnected') isConnected: boolean = false;
  @State serverUrl: string = '';
  @State serverUsername: string = '';
  @State pollingInterval: number = AppConstants.DEFAULT_POLLING_INTERVAL;

  async aboutToAppear(): Promise<void> {
    const config = this.connectionManager.serverConfig;
    if (config !== null) {
      this.serverUrl = config.url;
      this.serverUsername = config.username;
    }
    const store: PreferencesStore = PreferencesStore.getInstance();
    this.pollingInterval = await store.loadPollingInterval();
  }

  private async handleDisconnect(): Promise<void> {
    this.service.stopPolling();
    await this.connectionManager.disconnect();
    this.isConnected = false;
  }

  private async savePollingInterval(interval: number): Promise<void> {
    this.pollingInterval = interval;
    const store: PreferencesStore = PreferencesStore.getInstance();
    await store.savePollingInterval(interval);
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // Server info section
        Column({ space: 0 }) {
          Text('服务器信息')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 16, top: 12, bottom: 8 })

          this.settingsRow('服务器地址', this.serverUrl)
          this.settingsRow('用户名', this.serverUsername)
          this.settingsRow('连接状态', this.connectionManager.isConnected ? '已连接' : '未连接')
        }
        .width('100%')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)

        // Polling settings
        Column({ space: 0 }) {
          Text('刷新设置')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 16, top: 12, bottom: 8 })

          Row() {
            Text('刷新间隔')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Row({ space: 8 }) {
              Button('1s')
                .fontSize(12)
                .height(32)
                .borderRadius(6)
                .backgroundColor(this.pollingInterval === 1000 ? $r('app.color.accent_color') : $r('app.color.progress_background'))
                .fontColor(this.pollingInterval === 1000 ? '#FFFFFF' : $r('app.color.text_primary'))
                .onClick(() => this.savePollingInterval(1000))
              Button('2s')
                .fontSize(12)
                .height(32)
                .borderRadius(6)
                .backgroundColor(this.pollingInterval === 2000 ? $r('app.color.accent_color') : $r('app.color.progress_background'))
                .fontColor(this.pollingInterval === 2000 ? '#FFFFFF' : $r('app.color.text_primary'))
                .onClick(() => this.savePollingInterval(2000))
              Button('5s')
                .fontSize(12)
                .height(32)
                .borderRadius(6)
                .backgroundColor(this.pollingInterval === 5000 ? $r('app.color.accent_color') : $r('app.color.progress_background'))
                .fontColor(this.pollingInterval === 5000 ? '#FFFFFF' : $r('app.color.text_primary'))
                .onClick(() => this.savePollingInterval(5000))
              Button('10s')
                .fontSize(12)
                .height(32)
                .borderRadius(6)
                .backgroundColor(this.pollingInterval === 10000 ? $r('app.color.accent_color') : $r('app.color.progress_background'))
                .fontColor(this.pollingInterval === 10000 ? '#FFFFFF' : $r('app.color.text_primary'))
                .onClick(() => this.savePollingInterval(10000))
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        }
        .width('100%')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)

        // About section
        Column({ space: 0 }) {
          Text('关于')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 16, top: 12, bottom: 8 })

          this.settingsRow('应用名称', 'qBittorrent')
          this.settingsRow('版本', '1.0.0')
        }
        .width('100%')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)

        // Disconnect button
        Button('断开连接')
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.button_danger'))
          .borderRadius(12)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.handleDisconnect();
          })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  settingsRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 200 })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }
}
