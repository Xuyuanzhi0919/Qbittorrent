import { QbittorrentService } from '../service/QbittorrentService';
import { TransferInfo } from '../model/TransferInfo';
import { FormatUtils } from '../common/utils/FormatUtils';
import { AppConstants } from '../common/constants/AppConstants';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppService } from './Index';

@Component
export struct DashboardPage {
  @State isLoading: boolean = false;
  // 传输状态
  @State dlSpeed: number = 0;
  @State ulSpeed: number = 0;
  @State dlData: number = 0;
  @State ulData: number = 0;
  @State dhtNodes: number = 0;
  @State connectionStatus: string = '';
  // 种子统计
  @State totalTorrentCount: number = 0;
  @State activeTorrentCount: number = 0;
  @State completedTorrentCount: number = 0;
  @State pausedTorrentCount: number = 0;
  @State serverVersion: string = '';

  private pathStack: NavPathStack = new NavPathStack();
  private isRefreshing: boolean = false;
  private service: QbittorrentService | null = null;
  private refreshInterval: number = -1;  // 定时器 ID
  private readonly REFRESH_INTERVAL_MS: number = 3000;  // 刷新间隔 3 秒

  aboutToAppear(): void {
    this.service = AppService.getService();
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
      `DashboardPage aboutToAppear: service=${this.service ? 'ok' : 'null'}`);
    // 首次加载数据
    this.refreshData();
    // 启动定时刷新
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    // 停止定时刷新
    this.stopAutoRefresh();
  }

  private startAutoRefresh(): void {
    if (this.refreshInterval === -1) {
      this.refreshInterval = setInterval(() => {
        this.refreshData();
      }, this.REFRESH_INTERVAL_MS);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Dashboard: auto refresh started');
    }
  }

  private stopAutoRefresh(): void {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = -1;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Dashboard: auto refresh stopped');
    }
  }

  /**
   * 刷新数据
   * @param showLoading 是否显示加载动画（手动下拉刷新时为 true，自动刷新时为 false）
   */
  private async refreshData(showLoading: boolean = false): Promise<void> {
    if (this.isRefreshing) {
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Dashboard: refreshData skipped - already refreshing');
      return;
    }
    if (!this.service) {
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Dashboard: service is null, re-acquiring...');
      this.service = AppService.getService();
      if (!this.service) {
        hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Dashboard: failed to acquire service');
        return;
      }
    }

    this.isRefreshing = true;
    // 只有手动下拉刷新时才显示加载动画
    if (showLoading) {
      this.isLoading = true;
    }
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Dashboard: refreshData started (showLoading=${showLoading})`);

    try {
      // 获取传输信息
      const info: TransferInfo | null = await this.service.fetchTransferInfo();
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Dashboard: fetchTransferInfo returned ${info ? 'data' : 'null'}`);

      if (info !== null) {
        // 分别更新每个状态变量
        this.dlSpeed = info.dl_info_speed;
        this.ulSpeed = info.up_info_speed;
        this.dlData = info.dl_info_data;
        this.ulData = info.up_info_data;
        this.dhtNodes = info.dht_nodes;
        this.connectionStatus = info.connection_status;

        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
          `Dashboard: transfer info updated - dlSpeed=${this.dlSpeed}, ulSpeed=${this.ulSpeed}, ` +
          `dhtNodes=${this.dhtNodes}, connectionStatus=${this.connectionStatus}`);
      } else {
        hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Dashboard: fetchTransferInfo returned null');
      }

      // 获取种子列表
      const torrents = await this.service.fetchTorrentList();
      let active = 0;
      let completed = 0;
      let paused = 0;
      for (const t of torrents) {
        if (t.isActive()) active++;
        if (t.isCompleted()) completed++;
        if (t.isPaused()) paused++;
      }
      this.totalTorrentCount = torrents.length;
      this.activeTorrentCount = active;
      this.completedTorrentCount = completed;
      this.pausedTorrentCount = paused;

      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Dashboard: torrents - total=${this.totalTorrentCount}, active=${this.activeTorrentCount}, ` +
        `completed=${this.completedTorrentCount}, paused=${this.pausedTorrentCount}`);

      // 获取版本
      if (this.serverVersion.length === 0) {
        this.serverVersion = await this.service.getVersion();
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
          `Dashboard: version=${this.serverVersion}`);
      }
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Dashboard: refreshData error: ${JSON.stringify(err)}`);
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  private getConnectionLabel(): string {
    if (this.connectionStatus === 'connected') {
      return '可达';
    }
    if (this.connectionStatus === 'firewalled') {
      return '受限';
    }
    if (this.connectionStatus === 'disconnected') {
      return '不可达';
    }
    return this.connectionStatus.length === 0 ? '加载中' : '未知';
  }

  @Builder
  statusItem(label: string, value: string, color: Resource) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
    }
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(14)
    .backgroundColor($r('app.color.card_background'))
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  statChip(label: string, count: number, color: Resource) {
    Column({ space: 6 }) {
      Text(`${count}`)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .padding({ top: 16, bottom: 16 })
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  actionRow(title: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
        Text(title)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontColor([$r('app.color.text_hint')])
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height(56)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .onClick(action)
  }

  build() {
    NavDestination() {
      Refresh({ refreshing: $$this.isLoading }) {
        Scroll() {
          Column({ space: 16 }) {
            // Hero speed section
            Column({ space: 20 }) {
              Row() {
                Column({ space: 4 }) {
                  Text('↓ 下载')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Text(FormatUtils.formatSpeed(this.dlSpeed))
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.download_color'))
                  Text(`累计 ${FormatUtils.formatFileSize(this.dlData)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_hint'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Column({ space: 4 }) {
                  Text('↑ 上传')
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Text(FormatUtils.formatSpeed(this.ulSpeed))
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.upload_color'))
                  Text(`累计 ${FormatUtils.formatFileSize(this.ulData)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_hint'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 24, bottom: 24 })
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(20)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })

            // Status row
            Row({ space: 12 }) {
              // DHT - 直接内联，不使用 @Builder
              Column({ space: 4 }) {
                Text('DHT')
                  .fontSize(11)
                  .fontColor($r('app.color.text_hint'))
                Text(`${this.dhtNodes}`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.accent_color'))
              }
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .borderRadius(14)
              .backgroundColor($r('app.color.card_background'))
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              // 端口状态 - 直接内联
              Column({ space: 4 }) {
                Text('端口')
                  .fontSize(11)
                  .fontColor($r('app.color.text_hint'))
                Text(this.getConnectionLabel())
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.connectionStatus === 'connected' ?
                    $r('app.color.download_color') : $r('app.color.error_color'))
              }
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .borderRadius(14)
              .backgroundColor($r('app.color.card_background'))
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              // 版本 - 直接内联
              if (this.serverVersion.length > 0) {
                Column({ space: 4 }) {
                  Text('版本')
                    .fontSize(11)
                    .fontColor($r('app.color.text_hint'))
                  Text(`v${this.serverVersion}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_secondary'))
                }
                .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                .borderRadius(14)
                .backgroundColor($r('app.color.card_background'))
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16 })

            // Torrent stats
            Column({ space: 12 }) {
              Text('种子统计')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .padding({ left: 4 })

              Row({ space: 10 }) {
                // 全部 - 直接内联
                Column({ space: 6 }) {
                  Text(`${this.totalTorrentCount}`)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.accent_color'))
                  Text('全部')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .padding({ top: 16, bottom: 16 })
                .borderRadius(16)
                .backgroundColor($r('app.color.card_background'))
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                // 活跃
                Column({ space: 6 }) {
                  Text(`${this.activeTorrentCount}`)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.download_color'))
                  Text('活跃')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .padding({ top: 16, bottom: 16 })
                .borderRadius(16)
                .backgroundColor($r('app.color.card_background'))
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                // 完成
                Column({ space: 6 }) {
                  Text(`${this.completedTorrentCount}`)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.progress_complete'))
                  Text('完成')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .padding({ top: 16, bottom: 16 })
                .borderRadius(16)
                .backgroundColor($r('app.color.card_background'))
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)

                // 暂停
                Column({ space: 6 }) {
                  Text(`${this.pausedTorrentCount}`)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.state_paused'))
                  Text('暂停')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .padding({ top: 16, bottom: 16 })
                .borderRadius(16)
                .backgroundColor($r('app.color.card_background'))
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20 })

            // Quick actions
            Column({ space: 10 }) {
              this.actionRow('查看种子', $r('sys.symbol.doc'), () => {
                this.pathStack.pushPath({ name: 'TorrentList' });
              })
              this.actionRow('添加种子', $r('sys.symbol.ohos_folder_badge_plus'), () => {
                this.pathStack.pushPath({ name: 'AddTorrent' });
              })
              this.actionRow('设置', $r('sys.symbol.gearshape'), () => {
                this.pathStack.pushPath({ name: 'Settings' });
              })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .padding({ top: 12, bottom: 32 })
        }
        .scrollBar(BarState.Off)
      }
      .onRefreshing(() => {
        this.refreshData(true);  // 手动下拉刷新，显示加载动画
      })
    }
    .title('仪表盘')
    .hideBackButton(true)
    .backgroundColor($r('app.color.page_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'DashboardPage: onReady called');
    })
    .onAppear(() => {
      // 页面重新显示时刷新数据（如从子页面返回）
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'DashboardPage: onAppear');
      this.refreshData();
      // 确保自动刷新已启动
      this.startAutoRefresh();
    })
  }
}
