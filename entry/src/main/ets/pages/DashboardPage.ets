import { QbittorrentService } from '../service/QbittorrentService';
import { TransferInfo } from '../model/TransferInfo';
import { TorrentInfo } from '../model/TorrentInfo';
import { FormatUtils } from '../common/utils/FormatUtils';
import { AppConstants } from '../common/constants/AppConstants';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppService } from './Index';
import { DemoDataProvider } from '../mock/DemoDataProvider';
import { motion } from '@kit.MultimodalAwarenessKit';
import { BusinessError } from '@kit.BasicServicesKit';

@Component
struct WaveCanvas {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private offset1: number = 0;
  private offset2: number = 0;
  private canvasW: number = 0;
  private canvasH: number = 0;
  private readonly frameInterval: number = 33;

  aboutToDisappear(): void {
    this.stop();
  }

  private start(): void {
    if (this.timer !== -1 || this.canvasW <= 0) {
      return;
    }
    this.draw();
    this.timer = setInterval(() => {
      this.draw();
    }, this.frameInterval);
  }

  private stop(): void {
    if (this.timer === -1) {
      return;
    }
    clearInterval(this.timer);
    this.timer = -1;
  }

  private draw(): void {
    if (this.canvasW <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, this.canvasW, this.canvasH);
    const period: number = this.canvasW * 0.85;
    this.offset1 = (this.offset1 + 1.8) % period;
    this.offset2 = (this.offset2 + 1.1) % period;
    this.drawWave(this.offset1, period, 'rgba(37,99,235,0.32)', 0);
    this.drawWave(this.offset2, period, 'rgba(22,163,74,0.22)', -6);
  }

  private drawWave(offset: number, period: number, color: string, yOff: number): void {
    const w: number = this.canvasW;
    const h: number = this.canvasH;
    const amp: number = 7;
    const baseline: number = h * 0.42 + yOff;

    this.ctx.beginPath();
    let x: number = -(period * 2) + (offset % period);
    this.ctx.moveTo(x, baseline);
    while (x < w + period) {
      this.ctx.quadraticCurveTo(x + period * 0.25, baseline - amp, x + period * 0.5, baseline);
      this.ctx.quadraticCurveTo(x + period * 0.75, baseline + amp, x + period, baseline);
      x += period;
    }
    this.ctx.lineTo(w + 1, h + 1);
    this.ctx.lineTo(-1, h + 1);
    this.ctx.closePath();
    this.ctx.fillStyle = color;
    this.ctx.fill();
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(52)
      .onReady(() => {
        this.start();
      })
      .onAreaChange((_old: Area, newV: Area) => {
        this.canvasW = newV.width as number;
        this.canvasH = newV.height as number;
        this.start();
      })
  }
}

@Component
export struct DashboardPage {
  @StorageLink('guestMode') guestMode: boolean = false;
  @StorageLink('rootTabBarReserveHeight') rootTabBarReserveHeight: number = 0;
  @State isLoading: boolean = false;
  @State isPullRefreshing: boolean = false;
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
  @State actionMessage: string = '';
  @State @Watch('onAnySheetChanged') pendingDeleteHash: string = '';
  @State expandedTaskHash: string = '';
  @State @Watch('onAnySheetChanged') showGlobalLimitSheet: boolean = false;
  @State globalLimitDlInput: string = '';
  @State globalLimitUlInput: string = '';
  @State isSettingGlobalLimit: boolean = false;
  @State fabX: number = -1;
  @State fabY: number = -1;
  @State pageWidth: number = 0;
  @State pageHeight: number = 0;

  private isRefreshing: boolean = false;
  private service: QbittorrentService | null = null;
  private refreshInterval: number = -1;
  private actionMessageTimer: number = -1;
  private sessionStartTime: number = 0;
  private recentSpeedSamples: number[] = [];
  private hasQueuedRefresh: boolean = false;
  private queuedRefreshWithLoading: boolean = false;
  private fabDragStartX: number = 0;
  private fabDragStartY: number = 0;
  private suppressNextFabClick: boolean = false;
  private readonly fabWidth: number = 92;
  private readonly fabHeight: number = 48;
  private demoRefreshTick: number = 0;
  private holdingHandChangedCallback: Callback<motion.HoldingHandStatus> = (status: motion.HoldingHandStatus): void => {
    this.handleHoldingHandChanged(status);
  };

  aboutToAppear(): void {
    this.service = AppService.getService();
    this.sessionStartTime = Date.now();
    this.startHoldingHandMonitoring();
    if (this.guestMode) {
      this.loadGuestDemoData();
      this.startAutoRefresh();
      return;
    }
    this.refreshData();
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    this.stopHoldingHandMonitoring();
    this.stopAutoRefresh();
    if (this.actionMessageTimer !== -1) {
      clearTimeout(this.actionMessageTimer);
      this.actionMessageTimer = -1;
    }
    AppStorage.setOrCreate('showRootTabBar', true);
  }

  private onAnySheetChanged(): void {
    const anyOpen: boolean = this.pendingDeleteHash.length > 0 || this.showGlobalLimitSheet;
    AppStorage.setOrCreate('showRootTabBar', !anyOpen);
  }

  private startHoldingHandMonitoring(): void {
    try {
      motion.on('holdingHandChanged', this.holdingHandChangedCallback);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Holding hand monitoring started');
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Holding hand monitoring failed: ${error.code}, ${error.message}`);
    }
  }

  private stopHoldingHandMonitoring(): void {
    try {
      motion.off('holdingHandChanged', this.holdingHandChangedCallback);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Holding hand monitoring stopped');
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Stop holding hand monitoring failed: ${error.code}, ${error.message}`);
    }
  }

  private handleHoldingHandChanged(status: motion.HoldingHandStatus): void {
    if (this.pageWidth <= 0) {
      return;
    }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.moveFabToEdge(true);
      return;
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      this.moveFabToEdge(false);
    }
  }

  private moveFabToEdge(left: boolean): void {
    const targetX: number = left ? 20 : this.pageWidth - this.fabWidth - 20;
    const targetY: number = this.fabY < 0 ?
      this.clampFabY(this.pageHeight - this.rootTabBarReserveHeight - this.fabHeight - 16) :
      this.clampFabY(this.fabY);
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.fabX = this.clampFabX(targetX);
      this.fabY = targetY;
    });
  }

  private updatePageSize(width: number, height: number): void {
    this.pageWidth = width;
    this.pageHeight = height;
    if (this.fabX < 0 || this.fabY < 0) {
      this.resetFabPosition();
      return;
    }
    this.fabX = this.clampFabX(this.fabX);
    this.fabY = this.clampFabY(this.fabY);
  }

  private resetFabPosition(): void {
    this.fabX = this.clampFabX(this.pageWidth - this.fabWidth - 20);
    this.fabY = this.clampFabY(this.pageHeight - this.rootTabBarReserveHeight - this.fabHeight - 16);
  }

  private clampFabX(x: number): number {
    if (this.pageWidth <= 0) {
      return 20;
    }
    const maxX: number = Math.max(20, this.pageWidth - this.fabWidth - 20);
    if (x < 20) {
      return 20;
    }
    if (x > maxX) {
      return maxX;
    }
    return x;
  }

  private clampFabY(y: number): number {
    const minY: number = 88;
    if (this.pageHeight <= 0) {
      return minY;
    }
    const maxY: number = Math.max(minY, this.pageHeight - this.rootTabBarReserveHeight - this.fabHeight - 16);
    if (y < minY) {
      return minY;
    }
    if (y > maxY) {
      return maxY;
    }
    return y;
  }

  private attachFabToEdge(): void {
    const centerX: number = this.fabX + this.fabWidth / 2;
    const targetX: number = centerX < this.pageWidth / 2 ? 20 : this.pageWidth - this.fabWidth - 20;
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.fabX = this.clampFabX(targetX);
      this.fabY = this.clampFabY(this.fabY);
    });
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
    if (this.guestMode) {
      this.showActionMessage('演示模式暂不支持暂停任务');
      return;
    }
    if (!this.service || hash.length === 0) {
      return;
    }
    const success = await this.service.pauseTorrents([hash]);
    if (!success) {
      this.showActionMessage('暂停失败');
      return;
    }
    this.showActionMessage('任务已暂停');
    await this.refreshData();
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

  private requestDeleteTorrent(hash: string): void {
    if (hash.length === 0) {
      return;
    }
    if (this.guestMode) {
      this.showActionMessage('演示模式暂不支持删除任务');
      return;
    }
    this.pendingDeleteHash = hash;
  }

  private openTorrentDetail(hash: string): void {
    if (hash.length === 0) {
      return;
    }
    if (this.guestMode) {
      this.showActionMessage('演示模式暂不支持查看详情');
      return;
    }
    AppService.pushPage('TorrentDetail', hash);
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
      this.showActionMessage('任务已删除');
      return;
    }
    this.showActionMessage('删除失败');
  }

  private async refreshData(showLoading: boolean = false): Promise<void> {
    if (this.guestMode) {
      this.loadGuestDemoData();
      this.isLoading = false;
      this.isPullRefreshing = false;
      return;
    }
    if (!this.service) {
      this.isPullRefreshing = false;
      return;
    }
    if (this.isRefreshing) {
      this.hasQueuedRefresh = true;
      this.queuedRefreshWithLoading = this.queuedRefreshWithLoading || showLoading;
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
      const shouldRefreshAgain: boolean = this.hasQueuedRefresh;
      const nextShowLoading: boolean = this.queuedRefreshWithLoading;
      this.hasQueuedRefresh = false;
      this.queuedRefreshWithLoading = false;
      this.isLoading = false;
      this.isPullRefreshing = false;
      if (shouldRefreshAgain) {
        this.isRefreshing = false;
        this.refreshData(nextShowLoading);
        return;
      }
      this.isRefreshing = false;
    }
  }

  private loadGuestDemoData(): void {
    const info: TransferInfo = DemoDataProvider.createTransferInfo(this.demoRefreshTick);
    const torrents: TorrentInfo[] = DemoDataProvider.createTorrents(this.demoRefreshTick);

    this.dlSpeed = info.dl_info_speed;
    this.ulSpeed = info.up_info_speed;
    this.dlData = info.dl_info_data;
    this.ulData = info.up_info_data;
    this.dlRateLimit = info.dl_rate_limit;
    this.ulRateLimit = info.up_rate_limit;
    this.dhtNodes = info.dht_nodes;
    this.connectionStatus = info.connection_status;
    this.totalTorrentCount = torrents.length;
    this.downloadingCount = 0;
    this.pausedCount = 0;
    this.totalDownloadedBytes = 0;
    this.etaSeconds = -1;

    const activeTorrents: TorrentInfo[] = [];
    let i: number = 0;
    while (i < torrents.length) {
      const torrent: TorrentInfo = torrents[i];
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
      i += 1;
    }

    activeTorrents.sort((a: TorrentInfo, b: TorrentInfo) => b.dlspeed - a.dlspeed);
    this.activeTorrents = activeTorrents.slice(0, 2);

    const totalSpeed: number = this.getTotalSpeed();
    this.peakSpeed = Math.max(this.peakSpeed, totalSpeed);
    this.pushRecentSpeedSample(totalSpeed);
    this.averageSpeed = this.getRecentAverageSpeed();
    this.sessionSeconds = Math.max(0, Math.floor((Date.now() - this.sessionStartTime) / 1000));
    this.demoRefreshTick += 1;
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
    if (this.guestMode) {
      return '演示';
    }
    if (this.connectionStatus === 'connected') {
      return '公网';
    }
    if (this.connectionStatus === 'firewalled') {
      return '内网';
    }
    if (this.connectionStatus === 'disconnected') {
      return '离线';
    }
    return '检测中';
  }

  private getConnectionColor(): ResourceStr {
    if (this.guestMode) {
      return $r('app.color.accent_color');
    }
    if (this.connectionStatus === 'connected') {
      return $r('app.color.success_color');
    }
    if (this.connectionStatus === 'firewalled') {
      return $r('app.color.accent_color');
    }
    return $r('app.color.error_color');
  }

  private getStatusSummary(): string {
    if (this.guestMode) {
      return '演示数据';
    }
    if (this.connectionStatus === 'connected') {
      return '公网';
    }
    if (this.connectionStatus === 'firewalled') {
      return '内网';
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

  private getPercentWidth(percent: number): string {
    if (percent <= 0) {
      return '0%';
    }
    return `${Math.min(100, Math.max(4, percent))}%`;
  }

  private formatDashboardSpeed(bytesPerSecond: number): string {
    if (bytesPerSecond < 1024) {
      return `${bytesPerSecond.toFixed(0)} B/s`;
    }
    const kiloBytes = bytesPerSecond / 1024;
    if (kiloBytes < 10) {
      return `${kiloBytes.toFixed(1)} KB/s`;
    }
    if (kiloBytes < 1000) {
      return `${kiloBytes.toFixed(0)} KB/s`;
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
      return $r('app.color.dashboard_surface_info');
    }
    if (torrent.isPaused()) {
      return $r('app.color.dashboard_surface_muted');
    }
    if (torrent.isCompleted()) {
      return $r('app.color.dashboard_surface_success');
    }
    return $r('app.color.dashboard_surface_danger');
  }

  private getTaskStatusColor(torrent: TorrentInfo): ResourceStr {
    if (torrent.isDownloading()) {
      return $r('app.color.accent_color');
    }
    if (torrent.isPaused()) {
      return $r('app.color.text_secondary');
    }
    if (torrent.isCompleted()) {
      return $r('app.color.success_color');
    }
    return $r('app.color.error_color');
  }

  private getTaskProgressText(torrent: TorrentInfo): string {
    return `${Math.floor(torrent.progress * 100)}%`;
  }

  private getTaskDownloadedText(torrent: TorrentInfo): string {
    let downloadedBytes = torrent.size - torrent.amount_left;
    if (downloadedBytes <= 0 && torrent.progress > 0 && torrent.size > 0) {
      downloadedBytes = Math.floor(torrent.progress * torrent.size);
    }
    if (downloadedBytes <= 0) {
      downloadedBytes = torrent.downloaded;
    }
    return `已下载 ${FormatUtils.formatFileSize(Math.max(0, downloadedBytes))} / ${FormatUtils.formatFileSize(torrent.size)}`;
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

  private getTaskProgressWidth(torrent: TorrentInfo): string {
    if (torrent.progress <= 0) {
      return '0%';
    }
    const percent: number = Math.min(100, Math.max(2, Math.floor(torrent.progress * 100)));
    return `${percent}%`;
  }

  private getTaskRenderKey(torrent: TorrentInfo): string {
    return `${torrent.hash}_${torrent.state}_${Math.floor(torrent.progress * 1000)}_${torrent.dlspeed}_${torrent.upspeed}_${torrent.num_seeds}_${torrent.num_leechs}`;
  }

  private getGlobalLimitSummaryText(): string {
    const dlText: string = this.dlRateLimit > 0
      ? `↓ ${this.formatDashboardSpeed(this.dlRateLimit)}` : '↓ 不限速';
    const ulText: string = this.ulRateLimit > 0
      ? `↑ ${this.formatDashboardSpeed(this.ulRateLimit)}` : '↑ 不限速';
    return `${dlText}  ${ulText}`;
  }

  private openGlobalLimitSheet(): void {
    if (this.guestMode) {
      this.showActionMessage('演示模式不支持修改限速');
      return;
    }
    const dlKbs: number = this.dlRateLimit > 0 ? Math.round(this.dlRateLimit / 1024) : 0;
    const ulKbs: number = this.ulRateLimit > 0 ? Math.round(this.ulRateLimit / 1024) : 0;
    this.globalLimitDlInput = dlKbs > 0 ? dlKbs.toString() : '';
    this.globalLimitUlInput = ulKbs > 0 ? ulKbs.toString() : '';
    this.showGlobalLimitSheet = true;
  }

  private async handleSetGlobalLimit(): Promise<void> {
    if (!this.service) {
      return;
    }
    const dlKbs: number = parseInt(this.globalLimitDlInput);
    const ulKbs: number = parseInt(this.globalLimitUlInput);
    const dlBytes: number = isNaN(dlKbs) || dlKbs < 0 ? 0 : dlKbs * 1024;
    const ulBytes: number = isNaN(ulKbs) || ulKbs < 0 ? 0 : ulKbs * 1024;
    this.isSettingGlobalLimit = true;
    const dlOk: boolean = await this.service.setGlobalDownloadLimit(dlBytes);
    const ulOk: boolean = await this.service.setGlobalUploadLimit(ulBytes);
    this.isSettingGlobalLimit = false;
    this.showGlobalLimitSheet = false;
    this.showActionMessage(dlOk && ulOk ? '全局限速已设置' : '部分设置失败');
    await this.refreshData();
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
      // Gradient background layer — gives glassmorphism cards their colour to blur through
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

      Refresh({ refreshing: $$this.isPullRefreshing }) {
        Scroll() {
          Column({ space: 12 }) {
            if (this.actionMessage.length > 0) {
              this.actionBanner()
            }
            this.headerSection()
            this.heroSection()
            this.bentoGrid()

            this.tasksSection()
            this.globalSpeedLimitCard()
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 62, bottom: this.rootTabBarReserveHeight + 12 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .blur(this.showGlobalLimitSheet || this.pendingDeleteHash.length > 0 ? 16 : 0)
        .animation({ duration: 220, curve: Curve.EaseOut })
      }
      .onRefreshing(() => {
        this.isPullRefreshing = true;
        this.refreshData(false);
      })

      if (this.pendingDeleteHash.length > 0) {
        this.deleteConfirmDialog()
      }
      if (this.showGlobalLimitSheet) {
        this.globalLimitSheet()
      }
      if (this.pendingDeleteHash.length === 0 && !this.showGlobalLimitSheet) {
        this.newTaskFloatingButton()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .onAreaChange((_old: Area, newV: Area) => {
      this.updatePageSize(newV.width as number, newV.height as number);
    })
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
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  deleteConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .onClick(() => {
          this.cancelDeleteTorrent();
        })

      Column({ space: 14 }) {
        Text('删除任务')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('只删除任务，不删除已下载文件。')
          .fontSize(13)
          .fontWeight(FontWeight.Normal)
          .fontColor($r('app.color.text_secondary'))
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(999)
            .onClick(() => {
              this.cancelDeleteTorrent();
            })
          Button('删除')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.tab_active_fg'))
            .backgroundColor($r('app.color.error_color'))
            .borderRadius(999)
            .onClick(() => {
              this.confirmDeleteTorrent();
            })
        }
        .width('100%')
      }
      .width(280)
      .padding(18)
      .backgroundColor($r('app.color.card_background'))
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
        Text('仪表盘')
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
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
          .fontColor($r('app.color.text_primary'))
      }
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor($r('app.color.card_background'))
      .backdropBlur(24)
      .border({ width: 1, color: $r('app.color.dashboard_border_soft') })
      .borderRadius(999)
      .shadow({ radius: 10, color: '#0D0F172A', offsetX: 0, offsetY: 4 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  newTaskFloatingButton() {
    Stack() {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(17)
          .fontColor([$r('app.color.accent_color')])
        Text('新建')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_color'))
      }
      .width(this.fabWidth)
      .height(48)
      .padding({ left: 16, right: 18 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.glass_bg_elevated'))
      .backdropBlur(24)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(999)
      .shadow({ radius: 18, color: '#242563EB', offsetX: 0, offsetY: 6 })
      .position({ x: this.fabX < 0 ? this.clampFabX(this.pageWidth - this.fabWidth - 20) : this.fabX,
        y: this.fabY < 0 ? this.clampFabY(this.pageHeight - this.rootTabBarReserveHeight - this.fabHeight - 16) : this.fabY })
      .gesture(
        PanGesture({ fingers: 1 })
          .onActionStart(() => {
            this.fabDragStartX = this.fabX < 0 ? this.clampFabX(this.pageWidth - this.fabWidth - 20) : this.fabX;
            this.fabDragStartY = this.fabY < 0 ? this.clampFabY(this.pageHeight - this.rootTabBarReserveHeight - this.fabHeight - 16) : this.fabY;
            this.suppressNextFabClick = false;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (Math.abs(event.offsetX) > 4 || Math.abs(event.offsetY) > 4) {
              this.suppressNextFabClick = true;
            }
            this.fabX = this.clampFabX(this.fabDragStartX + event.offsetX);
            this.fabY = this.clampFabY(this.fabDragStartY + event.offsetY);
          })
          .onActionEnd(() => {
            if (this.suppressNextFabClick) {
              this.attachFabToEdge();
            }
          })
      )
      .onClick(() => {
        if (this.suppressNextFabClick) {
          this.suppressNextFabClick = false;
          return;
        }
        AppService.pushPage('AddTorrent');
      })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  heroSection() {
    Column() {
      Column({ space: 18 }) {
        if (this.isLoading) {
          Column({ space: 14 }) {
            Row() {
              Column({ space: 8 }) {
                Row()
                  .width(100)
                  .height(12)
                  .backgroundColor($r('app.color.dashboard_border_soft'))
                  .borderRadius(999)
                Row()
                  .width(180)
                  .height(36)
                  .backgroundColor($r('app.color.dashboard_border'))
                  .borderRadius(14)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            Column({ space: 8 }) {
              Row()
                .width('100%')
                .height(32)
                .backgroundColor($r('app.color.dashboard_surface_success'))
                .borderRadius(999)
              Row()
                .width('100%')
                .height(32)
                .backgroundColor($r('app.color.dashboard_surface_warning'))
                .borderRadius(999)
            }
            .width('100%')

            Row({ space: 8 }) {
              this.summarySkeletonChip()
              this.summarySkeletonChip()
              this.summarySkeletonChip()
            }
            .width('100%')
          }
          .width('100%')
        } else {
          Row() {
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                Row()
                  .width(4)
                  .height(16)
                  .backgroundColor('#5EEAD4')
                  .borderRadius(999)
                Text('总速率')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#B9D8F4')
              }

              Text(this.formatDashboardSpeed(this.getTotalSpeed()))
                .fontSize(40)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(`累计 ${FormatUtils.formatFileSize(this.totalDownloadedBytes)}`)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor('#A9C4DE')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 6 }) {
              Text(this.getStatusSummary())
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#1FFFFFFF')
            .border({ width: 1, color: '#2EFFFFFF' })
            .borderRadius(18)
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Column({ space: 10 }) {
            this.transferRail('下载', this.getDownloadRailText(), this.getDownloadPercent(), '#5EEAD4')
            this.transferRail('上传', this.getUploadRailText(), this.getUploadPercent(), '#FDBA74')
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .backgroundColor('#12FFFFFF')
          .border({ width: 1, color: '#1FFFFFFF' })
          .borderRadius(18)

          Row({ space: 8 }) {
            this.heroMetricChip('平均', this.getAverageSpeedText())
            this.heroMetricChip('峰值', this.getPeakSpeedText())
            this.heroMetricChip('剩余', this.getEtaText())
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: this.isLoading ? 18 : 12 })

      if (!this.isLoading) {
        WaveCanvas()
      }
    }
    .width('100%')
    .linearGradient({
      angle: 135,
      colors: [
        ['#102A43', 0],
        ['#125C7A', 0.58],
        ['#0F766E', 1]
      ]
    })
    .border({ width: 1, color: '#2EFFFFFF' })
    .borderRadius(24)
    .clip(true)
    .shadow({
      radius: 24,
      color: '#240F172A',
      offsetX: 0,
      offsetY: 10
    })
  }

  @Builder
  transferRail(label: string, value: string, percent: number, fillColor: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#B9D8F4')
        Blank()
        Text(value)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor('#24FFFFFF')
          .borderRadius(999)
        Row()
          .width(this.getPercentWidth(percent))
          .height(6)
          .backgroundColor(fillColor)
          .borderRadius(999)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  heroMetricChip(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#B9D8F4')
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .backgroundColor('#14FFFFFF')
    .border({ width: 1, color: '#24FFFFFF' })
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  bentoGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.metricCard('下载速度', this.formatDashboardSpeed(this.dlSpeed),
          this.dlRateLimit > 0 ? `限速 ${this.formatDashboardSpeed(this.dlRateLimit)}` : '不限速',
          '#14A38B', $r('app.color.success_color'), 108)
        this.metricCard('上传速度', this.formatDashboardSpeed(this.ulSpeed),
          this.ulRateLimit > 0 ? `限速 ${this.formatDashboardSpeed(this.ulRateLimit)}` : '不限速',
          '#C97716', $r('app.color.warning_color'), 108)
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricCard('下载任务', `${this.downloadingCount}`, '下载中',
          '#2563EB', $r('app.color.accent_color'), 96)
        this.metricCard('DHT 节点', `${this.dhtNodes}`,
          this.dhtNodes > 200 ? '健康' : this.dhtNodes > 30 ? '连接' : '搜索',
          '#64748B', $r('app.color.text_secondary'), 96)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  metricCard(title: string, value: string, caption: string, accent: string, dotColor: ResourceStr, height: number) {
    Row({ space: 12 }) {
      Row()
        .width(4)
        .height('100%')
        .backgroundColor(accent)
        .borderRadius(999)

      Column({ space: 8 }) {
        Row({ space: 6 }) {
          Circle()
            .width(7)
            .height(7)
            .fill(dotColor)
          Text(title)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }

        if (this.isLoading) {
          Row()
            .width(80)
            .height(28)
            .backgroundColor($r('app.color.dashboard_border_soft'))
            .borderRadius(10)
        } else {
          Text(value)
            .minFontSize(14)
            .maxFontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Text(caption)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.tab_inactive_fg'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .layoutWeight(1)
    .height(height)
    .padding({ left: 12, right: 14, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.dashboard_border_soft') })
    .borderRadius(20)
    .shadow({ radius: 14, color: '#0D1D4ED8', offsetX: 0, offsetY: 6 })
  }

  @Builder
  tasksSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text('活动任务')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(`${this.downloadingCount} 个进行中`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        if (this.downloadingCount > 0 && !this.guestMode) {
          Text('查看全部')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_color'))
            .onClick(() => {
              AppStorage.setOrCreate('currentTabIndex', 1);
            })
        }
      }
      .width('100%')

      if (this.isLoading) {
        this.tasksSkeleton()
      } else if (this.activeTorrents.length === 0) {
        this.emptyTaskCard()
      }

      if (!this.isLoading) {
        ForEach(this.activeTorrents, (torrent: TorrentInfo, index?: number) => {
          Column({ space: 8 }) {
            this.taskRow(index as number)
            if (this.expandedTaskHash === torrent.hash) {
              this.taskExpandedPanel(index as number)
            }
          }
        }, (torrent: TorrentInfo) => this.getTaskRenderKey(torrent))
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.glass_bg_elevated'))
    .backdropBlur(24)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(24)
    .shadow({ radius: 16, color: '#100F172A', offsetX: 0, offsetY: 6 })
  }

  @Builder
  summarySkeletonChip() {
    Column({ space: 4 }) {
      Row()
        .width(46)
        .height(10)
        .backgroundColor($r('app.color.dashboard_border_soft'))
        .borderRadius(999)
      Row()
        .width(68)
        .height(14)
        .backgroundColor($r('app.color.dashboard_border'))
        .borderRadius(999)
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  tasksSkeleton() {
    Column({ space: 8 }) {
      this.taskSkeletonRow()
      this.taskSkeletonRow()
    }
    .width('100%')
  }

  @Builder
  taskSkeletonRow() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 6 }) {
          Row()
            .width(162)
            .height(13)
            .backgroundColor($r('app.color.dashboard_border'))
            .borderRadius(999)
          Row()
            .width(196)
            .height(11)
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(999)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row()
          .width(56)
          .height(24)
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.glass_bg_chip'))
    .borderRadius(18)
  }

  @Builder
  emptyTaskCard() {
    Column({ space: 8 }) {
      Text('暂无活动任务')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .border({ width: 1, color: $r('app.color.dashboard_border_soft') })
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
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.getTaskProgressText(this.activeTorrents[index])} · ↓ ${this.formatDashboardSpeed(this.activeTorrents[index].dlspeed)} · ${this.getTaskEtaText(this.activeTorrents[index])}`)
          .fontSize(11)
          .fontWeight(FontWeight.Normal)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(this.getTaskStatusText(this.activeTorrents[index]))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getTaskStatusColor(this.activeTorrents[index]))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.getTaskStatusFill(this.activeTorrents[index]))
      .borderRadius(999)
      .constraintSize({ maxWidth: 88 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.dashboard_border_soft') })
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
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor($r('app.color.dashboard_progress_track'))
          .borderRadius(999)
        Row()
          .width(this.getTaskProgressWidth(this.activeTorrents[index]))
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
          .fontColor($r('app.color.accent_color'))
        Blank()
        Text(this.getTaskEtaText(this.activeTorrents[index]))
          .fontSize(11)
          .fontWeight(FontWeight.Normal)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Row() {
        Text(`${this.getTaskPeersText(this.activeTorrents[index])} · ${this.getTaskTypeText(this.activeTorrents[index])}`)
          .fontSize(10)
          .fontWeight(FontWeight.Normal)
          .fontColor($r('app.color.tab_inactive_fg'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Row({ space: 4 }) {
          Text('详情')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_color'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .border({ width: 1, color: $r('app.color.download_selected_border') })
        .borderRadius(999)
        .onClick(() => {
          this.openTorrentDetail(this.activeTorrents[index].hash);
        })

        Row({ space: 4 }) {
          Text('暂停')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.card_background'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border')
        })
        .borderRadius(999)
        .onClick(() => {
          this.pauseTorrentByHash(this.activeTorrents[index].hash);
        })

        Row({ space: 4 }) {
          Text('删除')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.error_color'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_danger'))
        .border({ width: 1, color: $r('app.color.download_warn_border') })
        .borderRadius(999)
        .onClick(() => {
          this.requestDeleteTorrent(this.activeTorrents[index].hash);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .border({ width: 1, color: $r('app.color.dashboard_border_soft') })
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  globalSpeedLimitCard() {
    Row() {
      Column({ space: 4 }) {
        Text('全局限速')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.getGlobalLimitSummaryText())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('修改')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(999)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(24)
    .border({ width: 1, color: $r('app.color.glass_border') })
    .borderRadius(20)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openGlobalLimitSheet();
    })
  }

  @Builder
  globalLimitSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .transition(TransitionEffect.opacity(0).animation({ duration: 260, curve: Curve.EaseOut }))
        .onClick(() => {
          if (!this.isSettingGlobalLimit) {
            this.showGlobalLimitSheet = false;
          }
        })

      Column() {
        Row()
          .width(36)
          .height(4)
          .backgroundColor($r('app.color.dashboard_border'))
          .borderRadius(2)
          .alignSelf(ItemAlign.Center)
          .margin({ top: 10, bottom: 4 })

        this.globalLimitSheetContent()
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .transition(
        TransitionEffect.translate({ y: 700 }).animation({ duration: 340, curve: Curve.FastOutSlowIn })
      )
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  globalLimitSheetContent() {
    Column({ space: 0 }) {
      Column({ space: 6 }) {
        Text('全局限速')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('对所有任务生效，0 或留空表示不限速')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 20 })

      Column({ space: 8 }) {
        Text('↓ 下载速度上限（KB/s）')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({ placeholder: '0 = 不限速', text: this.globalLimitDlInput })
          .type(InputType.Number)
          .height(48)
          .placeholderColor($r('app.color.text_hint'))
          .fontColor($r('app.color.text_primary'))
          .caretColor($r('app.color.accent_color'))
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .borderRadius(14)
          .onChange((v: string) => {
            this.globalLimitDlInput = v;
          })
        Row({ space: 8 }) {
          this.speedPresetChip('不限速', '', true)
          this.speedPresetChip('1 MB/s', '1024', true)
          this.speedPresetChip('5 MB/s', '5120', true)
          this.speedPresetChip('10 MB/s', '10240', true)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ bottom: 20 })

      Column({ space: 8 }) {
        Text('↑ 上传速度上限（KB/s）')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        TextInput({ placeholder: '0 = 不限速', text: this.globalLimitUlInput })
          .type(InputType.Number)
          .height(48)
          .placeholderColor($r('app.color.text_hint'))
          .fontColor($r('app.color.text_primary'))
          .caretColor($r('app.color.accent_color'))
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .borderRadius(14)
          .onChange((v: string) => {
            this.globalLimitUlInput = v;
          })
        Row({ space: 8 }) {
          this.speedPresetChip('不限速', '', false)
          this.speedPresetChip('512 KB', '512', false)
          this.speedPresetChip('1 MB/s', '1024', false)
          this.speedPresetChip('2 MB/s', '2048', false)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ bottom: 28 })

      Button(this.isSettingGlobalLimit ? '设置中...' : '确认设置')
        .width('100%')
        .height(50)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.dashboard_primary_action_fg'))
        .backgroundColor($r('app.color.dashboard_primary_action_bg'))
        .borderRadius(999)
        .enabled(!this.isSettingGlobalLimit)
        .onClick(() => {
          this.handleSetGlobalLimit();
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 12, bottom: 36 })
  }

  @Builder
  speedPresetChip(label: string, value: string, isDownload: boolean) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(
        (isDownload ? this.globalLimitDlInput : this.globalLimitUlInput) === value
          ? $r('app.color.accent_color')
          : $r('app.color.text_secondary')
      )
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(
        (isDownload ? this.globalLimitDlInput : this.globalLimitUlInput) === value
          ? $r('app.color.dashboard_surface_info')
          : $r('app.color.dashboard_surface_soft')
      )
      .borderRadius(999)
      .onClick(() => {
        if (isDownload) {
          this.globalLimitDlInput = value;
        } else {
          this.globalLimitUlInput = value;
        }
      })
  }

  @Builder
  primaryActionChip(title: string, action: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(16)
        .fontColor([$r('app.color.dashboard_primary_action_fg')])
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.dashboard_primary_action_fg'))
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.dashboard_primary_action_bg'))
    .borderRadius(999)
    .onClick(action)
  }

  @Builder
  secondaryActionChip(title: string, action: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.arrow_up_right'))
        .fontSize(16)
        .fontColor([$r('app.color.accent_color')])
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(999)
    .onClick(action)
  }
}
