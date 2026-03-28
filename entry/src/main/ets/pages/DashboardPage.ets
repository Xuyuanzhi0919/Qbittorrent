import { QbittorrentService } from '../service/QbittorrentService';
import { TransferInfo } from '../model/TransferInfo';
import { TorrentInfo } from '../model/TorrentInfo';
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
  @State dlRateLimit: number = 0;
  @State ulRateLimit: number = 0;
  @State dhtNodes: number = 0;
  @State connectionStatus: string = '';
  @State totalTorrentCount: number = 0;
  @State downloadingCount: number = 0;
  @State pausedCount: number = 0;
  @State activeTorrents: TorrentInfo[] = [];
  @State averageSpeed: number = 0;
  @State peakSpeed: number = 0;
  @State etaSeconds: number = -1;
  @State totalDownloadedBytes: number = 0;
  @State sessionSeconds: number = 0;
  @State decorAnimated: boolean = false;
  @State actionMessage: string = '';
  @State pendingDeleteHash: string = '';
  @State expandedTaskHash: string = '';

  private isRefreshing: boolean = false;
  private service: QbittorrentService | null = null;
  private refreshInterval: number = -1;
  private sessionStartTime: number = 0;
  private recentSpeedSamples: number[] = [];

  aboutToAppear(): void {
    this.service = AppService.getService();
    this.sessionStartTime = Date.now();
    animateTo({
      duration: 3600,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.decorAnimated = true;
    });
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

  private async pauseTorrentByHash(hash: string): Promise<void> {
    if (!this.service || hash.length === 0) {
      return;
    }
    const success = await this.service.pauseTorrents([hash]);
    if (!success) {
      this.actionMessage = '暂停失败';
      return;
    }
    this.actionMessage = '任务已暂停';
    await this.refreshData();
  }

  private requestDeleteTorrent(hash: string): void {
    if (hash.length === 0) {
      return;
    }
    this.pendingDeleteHash = hash;
  }

  private cancelDeleteTorrent(): void {
    this.pendingDeleteHash = '';
  }

  private async confirmDeleteTorrent(): Promise<void> {
    if (this.pendingDeleteHash.length === 0) {
      return;
    }
    const hash = this.pendingDeleteHash;
    await this.deleteTorrentByHash(hash);
    this.pendingDeleteHash = '';
  }

  private async deleteTorrentByHash(hash: string): Promise<void> {
    if (!this.service || hash.length === 0) {
      return;
    }
    const success = await this.service.deleteTorrents([hash], false);
    await this.refreshData();
    const exists = this.activeTorrents.some((torrent: TorrentInfo) => torrent.hash === hash);
    if (success || !exists) {
      this.actionMessage = '任务已删除';
      return;
    }
    this.actionMessage = '删除失败';
  }

  private async refreshData(showLoading: boolean = false): Promise<void> {
    if (this.isRefreshing || !this.service) {
      return;
    }
    this.isRefreshing = true;
    if (showLoading) {
      this.isLoading = true;
    }

    try {
      const info: TransferInfo | null = await this.service.fetchTransferInfo();
      if (info !== null) {
        this.dlSpeed = info.dl_info_speed;
        this.ulSpeed = info.up_info_speed;
        this.dlData = info.dl_info_data;
        this.ulData = info.up_info_data;
        this.dlRateLimit = info.dl_rate_limit;
        this.ulRateLimit = info.up_rate_limit;
        this.dhtNodes = info.dht_nodes;
        this.connectionStatus = info.connection_status;
      }

      const torrents: TorrentInfo[] = await this.service.fetchTorrentList();
      this.totalTorrentCount = torrents.length;
      this.downloadingCount = 0;
      this.pausedCount = 0;
      this.totalDownloadedBytes = 0;
      this.etaSeconds = -1;
      const activeTorrents: TorrentInfo[] = [];

      for (const torrent of torrents) {
        if (torrent.isDownloading()) {
          this.downloadingCount++;
          activeTorrents.push(torrent);
        }
        if (torrent.isPaused()) {
          this.pausedCount++;
        }
        this.totalDownloadedBytes += Math.max(0, torrent.downloaded);
        if (torrent.isDownloading() && torrent.eta > 0 && torrent.eta < 8640000) {
          if (this.etaSeconds < 0 || torrent.eta < this.etaSeconds) {
            this.etaSeconds = torrent.eta;
          }
        }
      }
      activeTorrents.sort((a: TorrentInfo, b: TorrentInfo) => b.dlspeed - a.dlspeed);
      this.activeTorrents = activeTorrents.slice(0, 2);

      const totalSpeed = this.getTotalSpeed();
      this.peakSpeed = Math.max(this.peakSpeed, totalSpeed);
      this.pushRecentSpeedSample(totalSpeed);
      this.averageSpeed = this.getRecentAverageSpeed();
      this.sessionSeconds = Math.max(0, Math.floor((Date.now() - this.sessionStartTime) / 1000));
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Dashboard: ${JSON.stringify(err)}`);
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  private getTotalSpeed(): number {
    return this.dlSpeed + this.ulSpeed;
  }

  private pushRecentSpeedSample(speed: number): void {
    this.recentSpeedSamples.push(speed);
    if (this.recentSpeedSamples.length > 8) {
      this.recentSpeedSamples.shift();
    }
  }

  private getRecentAverageSpeed(): number {
    if (this.recentSpeedSamples.length === 0) {
      return 0;
    }
    let total = 0;
    for (const sample of this.recentSpeedSamples) {
      total += sample;
    }
    return Math.floor(total / this.recentSpeedSamples.length);
  }

  private getConnectionText(): string {
    if (this.connectionStatus === 'connected') {
      return '服务器在线';
    }
    if (this.connectionStatus === 'firewalled') {
      return '连接受限';
    }
    if (this.connectionStatus === 'disconnected') {
      return '连接断开';
    }
    return '连接检测中';
  }

  private getConnectionColor(): ResourceStr {
    if (this.connectionStatus === 'connected') {
      return '#22C55E';
    }
    if (this.connectionStatus === 'firewalled') {
      return '#2563EB';
    }
    return '#EF4444';
  }

  private getStatusSummary(): string {
    if (this.connectionStatus === 'connected') {
      return '稳定';
    }
    if (this.connectionStatus === 'firewalled') {
      return '受限';
    }
    if (this.connectionStatus === 'disconnected') {
      return '离线';
    }
    return '检测中';
  }

  private getRatePercent(speed: number, limit: number): number {
    if (limit > 0) {
      return Math.max(0, Math.min(100, Math.floor((speed / limit) * 100)));
    }
    const totalSpeed = this.getTotalSpeed();
    if (totalSpeed <= 0) {
      return 0;
    }
    return Math.max(12, Math.min(100, Math.floor((speed / totalSpeed) * 100)));
  }

  private getDownloadPercent(): number {
    return this.getRatePercent(this.dlSpeed, this.dlRateLimit);
  }

  private getUploadPercent(): number {
    return this.getRatePercent(this.ulSpeed, this.ulRateLimit);
  }

  private getTrackWidth(percent: number, maxWidth: number): number {
    if (percent <= 0) {
      return 0;
    }
    return Math.max(36, Math.floor((maxWidth * percent) / 100));
  }

  private formatDashboardSpeed(bytesPerSecond: number): string {
    if (bytesPerSecond < 1024) {
      return `${bytesPerSecond.toFixed(0)} B/s`;
    }
    const kiloBytes = bytesPerSecond / 1024;
    if (kiloBytes < 1000) {
      return `${kiloBytes.toFixed(2)} KB/s`;
    }
    if (bytesPerSecond < 1024 * 1024 * 1024) {
      return `${(bytesPerSecond / (1024 * 1024)).toFixed(2)} MB/s`;
    }
    return `${(bytesPerSecond / (1024 * 1024 * 1024)).toFixed(2)} GB/s`;
  }

  private getAverageSpeedText(): string {
    return this.formatHeroMetricSpeed(this.averageSpeed);
  }

  private getPeakSpeedText(): string {
    return this.formatHeroMetricSpeed(this.peakSpeed);
  }

  private formatHeroMetricSpeed(bytesPerSecond: number): string {
    if (bytesPerSecond < 1024) {
      return `${bytesPerSecond.toFixed(0)}B/s`;
    }
    if (bytesPerSecond < 1024 * 1024) {
      return `${(bytesPerSecond / 1024).toFixed(0)}KB/s`;
    }
    if (bytesPerSecond < 1024 * 1024 * 1024) {
      return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)}MB/s`;
    }
    return `${(bytesPerSecond / (1024 * 1024 * 1024)).toFixed(1)}GB/s`;
  }

  private getEtaText(): string {
    if (this.etaSeconds < 0) {
      return '--';
    }
    return FormatUtils.formatEta(this.etaSeconds);
  }

  private getSessionText(): string {
    const hours = Math.floor(this.sessionSeconds / 3600);
    const minutes = Math.floor((this.sessionSeconds % 3600) / 60);
    const seconds = this.sessionSeconds % 60;
    const hh = hours.toString().padStart(2, '0');
    const mm = minutes.toString().padStart(2, '0');
    const ss = seconds.toString().padStart(2, '0');
    return `${hh}:${mm}:${ss}`;
  }

  private getDownloadRailText(): string {
    if (this.dlRateLimit > 0) {
      return `${this.formatDashboardSpeed(this.dlSpeed)} · ${this.getDownloadPercent()}%`;
    }
    return this.formatDashboardSpeed(this.dlSpeed);
  }

  private getUploadRailText(): string {
    if (this.ulRateLimit > 0) {
      return `${this.formatDashboardSpeed(this.ulSpeed)} · ${this.getUploadPercent()}%`;
    }
    return this.formatDashboardSpeed(this.ulSpeed);
  }

  private getTaskStatusText(torrent: TorrentInfo): string {
    if (torrent.isDownloading()) {
      return '下载中';
    }
    if (torrent.isPaused()) {
      return '暂停';
    }
    if (torrent.isCompleted()) {
      return '已完成';
    }
    return torrent.getStateLabel();
  }

  private getTaskStatusFill(torrent: TorrentInfo): ResourceStr {
    if (torrent.isDownloading()) {
      return '#EFF6FF';
    }
    if (torrent.isPaused()) {
      return '#F3F4F6';
    }
    if (torrent.isCompleted()) {
      return '#ECFDF5';
    }
    return '#FEF2F2';
  }

  private getTaskStatusColor(torrent: TorrentInfo): ResourceStr {
    if (torrent.isDownloading()) {
      return '#2563EB';
    }
    if (torrent.isPaused()) {
      return '#64748B';
    }
    if (torrent.isCompleted()) {
      return '#16A34A';
    }
    return '#DC2626';
  }

  private getTaskProgressText(torrent: TorrentInfo): string {
    return `${Math.floor(torrent.progress * 100)}%`;
  }

  private getTaskDownloadedText(torrent: TorrentInfo): string {
    return `已下载 ${FormatUtils.formatFileSize(torrent.downloaded)} / ${FormatUtils.formatFileSize(torrent.size)}`;
  }

  private getTaskSpeedText(torrent: TorrentInfo): string {
    const dl = `↓ ${this.formatDashboardSpeed(torrent.dlspeed)}`;
    const ul = `↑ ${this.formatDashboardSpeed(torrent.upspeed)}`;
    return `${this.getTaskProgressText(torrent)} · ${dl} ${ul}`;
  }

  private getTaskEtaText(torrent: TorrentInfo): string {
    if (torrent.eta > 0 && torrent.eta < 8640000) {
      return `剩余 ${FormatUtils.formatEta(torrent.eta)}`;
    }
    return '剩余 --';
  }

  private getTaskPeersText(torrent: TorrentInfo): string {
    const peers = torrent.num_leechs + torrent.num_seeds;
    return `${peers} peers`;
  }

  private getTaskTypeText(torrent: TorrentInfo): string {
    const name = torrent.name.toLowerCase();
    if (name.endsWith('.mp4') || name.endsWith('.mkv') || name.endsWith('.avi')) {
      return '视频文件';
    }
    if (name.endsWith('.iso')) {
      return '系统镜像';
    }
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.7z')) {
      return '压缩文件';
    }
    return '下载任务';
  }

  private getTaskProgressWidth(torrent: TorrentInfo, maxWidth: number): number {
    if (torrent.progress <= 0) {
      return 0;
    }
    const width = Math.floor(maxWidth * torrent.progress);
    return Math.min(maxWidth, Math.max(24, width));
  }

  private toggleTaskExpanded(hash: string): void {
    if (this.expandedTaskHash === hash) {
      this.expandedTaskHash = '';
      return;
    }
    this.expandedTaskHash = hash;
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.isLoading }) {
        Scroll() {
          Column({ space: 12 }) {
            if (this.actionMessage.length > 0) {
              this.actionBanner()
            }
            this.headerSection()
            this.heroSection()
            Row({ space: 12 }) {
              this.activeTaskCard()
              this.dhtCard()
            }
            .width('100%')

            this.tasksSection()

            Row({ space: 10 }) {
              this.primaryActionChip('添加任务', () => {
                AppService.getNavPathStack().pushPath({ name: 'AddTorrent' });
              })
              this.secondaryActionChip('导入磁链', () => {
                AppService.getNavPathStack().pushPath({ name: 'AddTorrent' });
              })
            }
            .width('100%')

          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 62, bottom: 104 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))
      }
      .onRefreshing(() => {
        this.refreshData(true);
      })

      if (this.pendingDeleteHash.length > 0) {
        this.deleteConfirmDialog()
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
        .fontColor('#0F172A')
      Blank()
      Text('关闭')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2563EB')
        .onClick(() => {
          this.actionMessage = '';
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#DCE7F6'
    })
    .borderRadius(16)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  deleteConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#0F172A33')
        .onClick(() => {
          this.cancelDeleteTorrent();
        })

      Column({ space: 14 }) {
        Text('删除任务')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Text('只删除任务，不删除已下载文件。')
          .fontSize(13)
          .fontWeight(FontWeight.Normal)
          .fontColor('#64748B')
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor('#0F172A')
            .backgroundColor('#F3F4F6')
            .borderRadius(999)
            .onClick(() => {
              this.cancelDeleteTorrent();
            })
          Button('删除')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#DC2626')
            .borderRadius(999)
            .onClick(() => {
              this.confirmDeleteTorrent();
            })
        }
        .width('100%')
      }
      .width(280)
      .padding(18)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  headerSection() {
    Row() {
      Column({ space: 4 }) {
        Text('DOWNLOAD CENTER')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(1)
          .fontColor('#64748B')
        Text('仪表盘')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.5)
          .fontColor('#0F172A')
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row({ space: 8 }) {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getConnectionColor())
        Text(this.getConnectionText())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#D8E5F8'
      })
      .borderRadius(999)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  heroSection() {
    Stack() {
      Circle()
        .width(180)
        .height(180)
        .fill('#DCEAFF')
        .opacity(this.decorAnimated ? 0.52 : 0.38)
        .position({ x: 220, y: -34 })
        .translate({
          x: this.decorAnimated ? -8 : 0,
          y: this.decorAnimated ? 10 : 0
        })
        .scale({
          x: this.decorAnimated ? 1.04 : 1,
          y: this.decorAnimated ? 1.04 : 1
        })
        .animation({
          duration: 3600,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })

      Circle()
        .width(120)
        .height(120)
        .fill('#EDF4FF')
        .opacity(this.decorAnimated ? 0.58 : 0.44)
        .position({ x: -24, y: 88 })
        .translate({
          x: this.decorAnimated ? 8 : 0,
          y: this.decorAnimated ? 6 : 0
        })
        .scale({
          x: this.decorAnimated ? 1.05 : 1,
          y: this.decorAnimated ? 1.05 : 1
        })
        .animation({
          duration: 3000,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })

      Column({ space: 12 }) {
        Row() {
        Column({ space: 8 }) {
          Text('总传输速率')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')

          Text(this.formatDashboardSpeed(this.getTotalSpeed()))
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.6)
            .fontColor('#0F172A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Column({ space: 6 }) {
            this.downloadSpeedLine()
            this.uploadSpeedLine()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width(214)
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column({ space: 8 }) {
          Text('当前状态')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')

          Text(this.getStatusSummary())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Column({ space: 6 }) {
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor('#E8F0FB')
                .borderRadius(999)
              Row()
                .width(this.getTrackWidth(this.getDownloadPercent(), 64))
                .height(8)
                .linearGradient({
                  angle: 90,
                  colors: [
                    ['#3B82F6', 0],
                    ['#60A5FA', 1]
                  ]
                })
                .borderRadius(999)
            }
            .width('100%')

            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor('#E8F0FB')
                .borderRadius(999)
              Row()
                .width(this.getTrackWidth(this.getUploadPercent(), 64))
                .height(8)
                .backgroundColor('#BFD8FF')
                .borderRadius(999)
            }
            .width('100%')
          }
          .width('100%')
        }
        .width(80)
        .padding({ top: 12, bottom: 12, left: 12, right: 12 })
        .backgroundColor('#F8FBFF')
        .border({
          width: 1,
          color: '#E2ECF8'
        })
        .borderRadius(20)
        .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Row({ space: 8 }) {
          this.averageSpeedChip()
          this.peakSpeedChip()
          this.etaChip()
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#DDE8F5'
    })
    .borderRadius(28)
    .shadow({
      radius: 14,
      color: '#1D4ED814',
      offsetX: 0,
      offsetY: 10
    })
  }

  @Builder
  downloadSpeedLine() {
    Row({ space: 6 }) {
      Circle()
        .width(8)
        .height(8)
        .fill('#22C55E')
      Text(`下载 ${this.formatDashboardSpeed(this.dlSpeed)}`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#166534')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor('#ECFDF5')
    .borderRadius(999)
  }

  @Builder
  uploadSpeedLine() {
    Row({ space: 6 }) {
      Circle()
        .width(8)
        .height(8)
        .fill('#F97316')
      Text(`上传 ${this.formatDashboardSpeed(this.ulSpeed)}`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#C2410C')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor('#FFF7ED')
    .borderRadius(999)
  }

  @Builder
  averageSpeedChip() {
    Column({ space: 4 }) {
      Text('平均速度')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#64748B')
      Text(this.getAverageSpeedText())
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 12, bottom: 12 })
    .backgroundColor('#F8FBFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  peakSpeedChip() {
    Column({ space: 4 }) {
      Text('峰值速度')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#64748B')
      Text(this.getPeakSpeedText())
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 12, bottom: 12 })
    .backgroundColor('#F8FBFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  etaChip() {
    Column({ space: 4 }) {
      Text('剩余时间')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#64748B')
      Text(this.getEtaText())
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 12, bottom: 12 })
    .backgroundColor('#F8FBFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  activeTaskCard() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.arrow_down'))
          .fontSize(14)
          .fontColor(['#2563EB'])
        Text('活跃任务')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.6)
          .fontColor('#64748B')
      }

      Text(`${this.downloadingCount}`)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('高优先级下载中')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2563EB')
    }
    .layoutWeight(1)
    .height(132)
    .padding(14)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#E2ECF8'
    })
    .borderRadius(24)
  }

  @Builder
  dhtCard() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Row()
          .width(14)
          .height(14)
          .border({
            width: 1.5,
            color: '#0F172A'
          })
          .borderRadius(999)
        Text('DHT 节点')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.6)
          .fontColor('#64748B')
      }

      Text(`${this.dhtNodes}`)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('连接稳定')
        .fontSize(13)
        .fontWeight(FontWeight.Normal)
        .fontColor('#64748B')
    }
    .layoutWeight(1)
    .height(132)
    .padding(14)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#E2ECF8'
    })
    .borderRadius(24)
  }

  @Builder
  tasksSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text('正在下载')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
          Text(`${this.activeTorrents.length} 个任务进行中`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
      }
      .width('100%')

      if (this.activeTorrents.length === 0) {
        this.emptyTaskCard()
      }

      ForEach(this.activeTorrents, (torrent: TorrentInfo, index?: number) => {
        Column({ space: 8 }) {
          this.taskRow(index as number)
          if (this.expandedTaskHash === torrent.hash) {
            this.taskExpandedPanel(index as number)
          }
        }
      }, (torrent: TorrentInfo) => torrent.hash)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#E2ECF8'
    })
    .borderRadius(24)
  }

  @Builder
  emptyTaskCard() {
    Column({ space: 8 }) {
      Text('当前没有活跃下载任务')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0F172A')
      Text('添加任务后会在这里显示进度、速度和剩余时间。')
        .fontSize(12)
        .fontWeight(FontWeight.Normal)
        .fontColor('#64748B')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F8FBFF')
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  taskRow(index: number) {
    Row() {
      Column({ space: 4 }) {
        Text(this.activeTorrents[index].name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.getTaskProgressText(this.activeTorrents[index])} · ↓ ${this.formatDashboardSpeed(this.activeTorrents[index].dlspeed)} · ${this.getTaskEtaText(this.activeTorrents[index])}`)
          .fontSize(11)
          .fontWeight(FontWeight.Normal)
          .fontColor('#64748B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(224)
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row() {
        Text(this.getTaskStatusText(this.activeTorrents[index]))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getTaskStatusColor(this.activeTorrents[index]))
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.getTaskStatusFill(this.activeTorrents[index]))
      .borderRadius(999)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#E8EEF8'
    })
    .borderRadius(18)
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      this.toggleTaskExpanded(this.activeTorrents[index].hash);
    })
  }

  @Builder
  taskExpandedPanel(index: number) {
    Column({ space: 8 }) {
      Text(this.getTaskDownloadedText(this.activeTorrents[index]))
        .fontSize(11)
        .fontWeight(FontWeight.Normal)
        .fontColor('#64748B')
        .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor('#E5EEFA')
          .borderRadius(999)
        Row()
          .width(this.getTaskProgressWidth(this.activeTorrents[index], 300))
          .height(8)
          .linearGradient({
            angle: 90,
            colors: [
              ['#2D7DFF', 0],
              ['#6AAFFF', 1]
            ]
          })
          .borderRadius(999)
      }
      .width('100%')

      Row() {
        Text(this.getTaskSpeedText(this.activeTorrents[index]))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2563EB')
        Blank()
        Text(this.getTaskEtaText(this.activeTorrents[index]))
          .fontSize(11)
          .fontWeight(FontWeight.Normal)
          .fontColor('#64748B')
      }
      .width('100%')

      Row() {
        Text(`${this.getTaskPeersText(this.activeTorrents[index])} · ${this.getTaskTypeText(this.activeTorrents[index])}`)
          .fontSize(10)
          .fontWeight(FontWeight.Normal)
          .fontColor('#94A3B8')
        Blank()
        Row({ space: 10 }) {
          Text('Ⅱ')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')
            .onClick(() => {
              this.pauseTorrentByHash(this.activeTorrents[index].hash);
            })
          Text('×')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')
            .onClick(() => {
              this.requestDeleteTorrent(this.activeTorrents[index].hash);
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FBFF')
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  primaryActionChip(title: string, action: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(16)
        .fontColor(['#FFFFFF'])
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#0F172A')
    .borderRadius(999)
    .onClick(action)
  }

  @Builder
  secondaryActionChip(title: string, action: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.arrow_up_right'))
        .fontSize(16)
        .fontColor(['#2563EB'])
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0F172A')
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#DCE7F6'
    })
    .borderRadius(999)
    .onClick(action)
  }
}
