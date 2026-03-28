import { QbittorrentService } from '../service/QbittorrentService';
import { TransferInfo } from '../model/TransferInfo';
import { FormatUtils } from '../common/utils/FormatUtils';
import { AppConstants } from '../common/constants/AppConstants';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppService } from './Index';

@Component
export struct DashboardPage {
  @State isLoading: boolean = false;
  @State dlSpeed: number = 0;
  @State ulSpeed: number = 0;
  @State dlData: number = 0;
  @State ulData: number = 0;
  @State dhtNodes: number = 0;
  @State connectionStatus: string = '';
  @State totalTorrentCount: number = 0;
  @State downloadingCount: number = 0;
  @State pausedCount: number = 0;
  @State serverVersion: string = '';

  private isRefreshing: boolean = false;
  private service: QbittorrentService | null = null;
  private refreshInterval: number = -1;

  aboutToAppear(): void {
    this.service = AppService.getService();
    this.refreshData();
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
  }

  private startAutoRefresh(): void {
    if (this.refreshInterval === -1) {
      this.refreshInterval = setInterval(() => {
        this.refreshData();
      }, 3000);
    }
  }

  private stopAutoRefresh(): void {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = -1;
    }
  }

  private async refreshData(showLoading: boolean = false): Promise<void> {
    if (this.isRefreshing || !this.service) return;
    this.isRefreshing = true;
    if (showLoading) this.isLoading = true;

    try {
      const info: TransferInfo | null = await this.service.fetchTransferInfo();
      if (info !== null) {
        this.dlSpeed = info.dl_info_speed;
        this.ulSpeed = info.up_info_speed;
        this.dlData = info.dl_info_data;
        this.ulData = info.up_info_data;
        this.dhtNodes = info.dht_nodes;
        this.connectionStatus = info.connection_status;
      }

      const torrents = await this.service.fetchTorrentList();
      this.totalTorrentCount = torrents.length;
      this.downloadingCount = 0;
      this.pausedCount = 0;
      for (const t of torrents) {
        if (t.isActive()) this.downloadingCount++;
        if (t.isPaused()) this.pausedCount++;
      }

      if (this.serverVersion.length === 0) {
        this.serverVersion = await this.service.getVersion();
      }
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Dashboard: ${JSON.stringify(err)}`);
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  private getConnectionText(): string {
    if (this.connectionStatus === 'connected') return '已连接';
    if (this.connectionStatus === 'firewalled') return '受限';
    if (this.connectionStatus === 'disconnected') return '断开';
    return '检测中';
  }

  private getConnectionColor(): ResourceStr {
    if (this.connectionStatus === 'connected') return '#4CAF50';
    if (this.connectionStatus === 'firewalled') return '#FF9800';
    return '#F44336';
  }

  build() {
    Refresh({ refreshing: $$this.isLoading }) {
      Scroll() {
        Column({ space: 12 }) {
          // 顶部状态
          Row() {
            Row({ space: 6 }) {
              Circle()
                .width(8)
                .height(8)
                .fill(this.getConnectionColor())
              Text(this.getConnectionText())
                .fontSize(13)
                .fontColor(this.getConnectionColor())
            }

            Blank()

            if (this.serverVersion) {
              Text(`v${this.serverVersion}`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })

          // 速度卡片
          Column() {
            Row() {
              // 下载
              Column({ space: 4 }) {
                Text('下载')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                Text(FormatUtils.formatSpeed(this.dlSpeed))
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4CAF50')
                Text(`累计 ${FormatUtils.formatFileSize(this.dlData)}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              // 分隔线
              Divider()
                .vertical(true)
                .height(50)
                .color($r('app.color.divider_color'))
                .strokeWidth(1)

              // 上传
              Column({ space: 4 }) {
                Text('上传')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                Text(FormatUtils.formatSpeed(this.ulSpeed))
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF9800')
                Text(`累计 ${FormatUtils.formatFileSize(this.ulData)}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(20)
          }
          .width('calc(100% - 24px)')
          .margin({ left: 12, right: 12 })
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(16)

          // 状态信息
          Row({ space: 10 }) {
            this.statCard('DHT', `${this.dhtNodes}`, '网络节点')
            this.statCard('任务', `${this.totalTorrentCount}`, `${this.downloadingCount} 个活动中`)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })

          // 快捷操作
          Column({ space: 8 }) {
            Text('快捷操作')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ left: 4 })

            Row({ space: 10 }) {
              this.actionBtn('添加任务', $r('sys.symbol.plus_circle'), () => {
                AppService.getNavPathStack().pushPath({ name: 'AddTorrent' });
              })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
        }
        .padding({ top: 4, bottom: 80 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onRefreshing(() => {
      this.refreshData(true);
    })
  }

  @Builder
  statCard(title: string, value: string, subtitle: string) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(subtitle)
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionBtn(title: string, icon: Resource, action: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.accent_color')])
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('app.color.text_hint')])
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .onClick(action)
  }
}
