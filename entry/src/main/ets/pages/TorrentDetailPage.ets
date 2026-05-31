import { hilog } from '@kit.PerformanceAnalysisKit';
import { QbittorrentService } from '../service/QbittorrentService';
import { TorrentInfo } from '../model/TorrentInfo';
import { TorrentFile } from '../model/TorrentFile';
import { TorrentTracker } from '../model/TorrentTracker';
import { TorrentPeer } from '../model/TorrentPeer';
import { TorrentProperties } from '../model/TorrentProperties';
import { TorrentPeersSync } from '../model/TorrentPeersSync';
import { FormatUtils } from '../common/utils/FormatUtils';
import { AppConstants } from '../common/constants/AppConstants';
import { AppService } from './Index';

@Component
export struct TorrentDetailPage {
  private service: QbittorrentService = AppService.getService();
  @Prop torrentHash: string = '';
  @State torrentInfo: TorrentInfo = new TorrentInfo();
  @State files: TorrentFile[] = [];
  @State trackers: TorrentTracker[] = [];
  @State peers: TorrentPeer[] = [];
  @State properties: TorrentProperties = new TorrentProperties();
  @State selectedTab: number = 0;
  @State isLoading: boolean = false;
  @State isPullRefreshing: boolean = false;
  @State actionMessage: string = '';
  @State pendingDeleteMode: string = '';
  @State isActionPending: boolean = false;
  @State pendingFilePriorityIndex: number = -1;
  @State showSpeedLimitSheet: boolean = false;
  @State speedLimitDlInput: string = '';
  @State speedLimitUlInput: string = '';
  @State isSettingSpeedLimit: boolean = false;

  private pathStack: NavPathStack = new NavPathStack();
  private contentScroller: Scroller = new Scroller();
  private actionMessageTimer: number = -1;
  private refreshInterval: number = -1;
  private isRefreshing: boolean = false;
  private peerRid: number = 0;
  private hasQueuedRefresh: boolean = false;
  private queuedRefreshWithLoading: boolean = false;
  private queuedRefreshFromPull: boolean = false;

  aboutToAppear(): void {
    this.loadData(true);
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
    if (this.actionMessageTimer !== -1) {
      clearTimeout(this.actionMessageTimer);
      this.actionMessageTimer = -1;
    }
  }

  private startAutoRefresh(): void {
    if (this.refreshInterval === -1) {
      this.refreshInterval = setInterval(() => {
        this.loadData();
      }, AppConstants.DEFAULT_POLLING_INTERVAL);
    }
  }

  private stopAutoRefresh(): void {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = -1;
    }
  }

  private async loadData(showLoading: boolean = false, showPullRefresh: boolean = false): Promise<void> {
    if (this.isRefreshing) {
      if (showPullRefresh) {
        this.isPullRefreshing = true;
      }
      this.hasQueuedRefresh = true;
      this.queuedRefreshWithLoading = this.queuedRefreshWithLoading || showLoading;
      this.queuedRefreshFromPull = this.queuedRefreshFromPull || showPullRefresh;
      return;
    }
    this.isRefreshing = true;
    if (showLoading) {
      this.isLoading = true;
    }
    if (showPullRefresh) {
      this.isPullRefreshing = true;
    }
    try {
      const torrent: TorrentInfo | null = await this.service.fetchTorrent(this.torrentHash);
      const matched: boolean = torrent !== null;
      if (torrent !== null) {
        this.torrentInfo = torrent;
      }
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `TorrentDetail.loadData hash=${this.torrentHash} matched=${matched}`);

      const properties: TorrentProperties | null = await this.service.fetchTorrentProperties(this.torrentHash);
      if (properties !== null) {
        this.properties = properties;
      }

      this.trackers = await this.service.fetchTorrentTrackers(this.torrentHash);
      if (this.selectedTab === 1) {
        this.files = await this.service.fetchTorrentFiles(this.torrentHash);
      }
      if (this.selectedTab === 2) {
        const peerSync: TorrentPeersSync | null = await this.service.fetchTorrentPeers(this.torrentHash, this.peerRid);
        if (peerSync !== null) {
          this.applyPeerSync(peerSync);
        }
      }
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `TorrentDetail: ${JSON.stringify(err)}`);
    } finally {
      const shouldRefreshAgain: boolean = this.hasQueuedRefresh;
      const nextShowLoading: boolean = this.queuedRefreshWithLoading;
      const nextShowPullRefresh: boolean = this.queuedRefreshFromPull;
      this.hasQueuedRefresh = false;
      this.queuedRefreshWithLoading = false;
      this.queuedRefreshFromPull = false;
      this.isLoading = false;
      if (shouldRefreshAgain) {
        this.isRefreshing = false;
        if (!nextShowPullRefresh) {
          this.isPullRefreshing = false;
        }
        this.loadData(nextShowLoading, nextShowPullRefresh);
        return;
      }
      this.isPullRefreshing = false;
      this.isRefreshing = false;
    }
  }

  private async onTabChange(index: number): Promise<void> {
    this.selectedTab = index;
    this.contentScroller.scrollEdge(Edge.Top);
    if (index === 1 && this.files.length > 0) {
      return;
    }
    if (index === 2 && this.peers.length > 0) {
      return;
    }
    if (index === 3 && this.trackers.length > 0) {
      return;
    }
    await this.loadData(this.files.length === 0 && this.peers.length === 0 && this.trackers.length === 0);
  }

  private applyPeerSync(peerSync: TorrentPeersSync): void {
    this.peerRid = peerSync.rid;
    if (peerSync.full_update || this.peers.length === 0) {
      this.peers = peerSync.peers;
      return;
    }

    const peerMap: Record<string, TorrentPeer> = {};
    for (const peer of this.peers) {
      peerMap[peer.id] = peer;
    }
    for (const peer of peerSync.peers) {
      peerMap[peer.id] = peer;
    }
    const removedPeerMap: Record<string, boolean> = {};
    for (const removedId of peerSync.peers_removed) {
      removedPeerMap[removedId] = true;
    }
    const mergedPeers: TorrentPeer[] = [];
    const peerIds: string[] = Object.keys(peerMap);
    for (const peerId of peerIds) {
      if (!removedPeerMap[peerId]) {
        mergedPeers.push(peerMap[peerId]);
      }
    }
    this.peers = mergedPeers;
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

  private notifyTorrentListRefresh(): void {
    const currentValue: Object | undefined = AppStorage.get('torrentListRefreshToken');
    const currentToken: number = typeof currentValue === 'number' ? currentValue : 0;
    AppStorage.setOrCreate('torrentListRefreshToken', currentToken + 1);
  }

  private async handlePrimaryAction(): Promise<void> {
    if (this.isActionPending) {
      return;
    }
    this.isActionPending = true;
    let success = false;
    try {
      if (this.torrentInfo.isPaused()) {
        success = await this.service.resumeTorrents([this.torrentHash]);
        this.showActionMessage(success ? '任务已恢复' : '恢复失败');
      } else {
        success = await this.service.pauseTorrents([this.torrentHash]);
        this.showActionMessage(success ? '任务已暂停' : '暂停失败');
      }
      if (success) {
        this.notifyTorrentListRefresh();
        await this.loadData();
      }
    } finally {
      this.isActionPending = false;
    }
  }

  private async handleReannounce(): Promise<void> {
    if (this.isActionPending) {
      return;
    }
    this.isActionPending = true;
    try {
      const success = await this.service.reannounceTorrents([this.torrentHash]);
      this.showActionMessage(success ? '已重新汇报' : '重新汇报失败');
      if (success) {
        await this.loadData();
      }
    } finally {
      this.isActionPending = false;
    }
  }

  private requestDelete(): void {
    this.pendingDeleteMode = 'pending';
  }

  private cancelDelete(): void {
    this.pendingDeleteMode = '';
  }

  private async handleSetFilePriority(fileIndex: number, priority: number): Promise<void> {
    this.pendingFilePriorityIndex = -1;
    const success: boolean = await this.service.setFilePriority(this.torrentHash, fileIndex, priority);
    if (success) {
      this.files = await this.service.fetchTorrentFiles(this.torrentHash);
      this.showActionMessage('文件优先级已设置');
    } else {
      this.showActionMessage('设置失败');
    }
  }

  private openSpeedLimitSheet(): void {
    const dlKbs: number = this.torrentInfo.dl_limit > 0 ? Math.round(this.torrentInfo.dl_limit / 1024) : 0;
    const ulKbs: number = this.torrentInfo.ul_limit > 0 ? Math.round(this.torrentInfo.ul_limit / 1024) : 0;
    this.speedLimitDlInput = dlKbs > 0 ? dlKbs.toString() : '';
    this.speedLimitUlInput = ulKbs > 0 ? ulKbs.toString() : '';
    this.showSpeedLimitSheet = true;
  }

  private async handleSetSpeedLimit(): Promise<void> {
    const dlKbs: number = parseInt(this.speedLimitDlInput);
    const ulKbs: number = parseInt(this.speedLimitUlInput);
    const dlBytes: number = isNaN(dlKbs) || dlKbs < 0 ? 0 : dlKbs * 1024;
    const ulBytes: number = isNaN(ulKbs) || ulKbs < 0 ? 0 : ulKbs * 1024;
    this.isSettingSpeedLimit = true;
    const dlOk: boolean = await this.service.setDownloadLimit(this.torrentHash, dlBytes);
    const ulOk: boolean = await this.service.setUploadLimit(this.torrentHash, ulBytes);
    this.isSettingSpeedLimit = false;
    this.showSpeedLimitSheet = false;
    this.showActionMessage(dlOk && ulOk ? '限速已设置' : '部分设置失败');
    await this.loadData();
  }

  private async confirmDelete(deleteFiles: boolean): Promise<void> {
    if (this.isActionPending) {
      return;
    }
    this.isActionPending = true;
    this.pendingDeleteMode = '';
    try {
      const success = await this.service.deleteTorrents([this.torrentHash], deleteFiles);
      if (success) {
        this.notifyTorrentListRefresh();
        this.pathStack.pop();
        return;
      }
      this.showActionMessage(deleteFiles ? '删除任务和文件失败' : '删除失败');
    } finally {
      this.isActionPending = false;
    }
  }

  private getDownloadedBytes(torrent: TorrentInfo): number {
    let downloadedBytes = torrent.size - torrent.amount_left;
    if (downloadedBytes <= 0 && torrent.progress > 0 && torrent.size > 0) {
      downloadedBytes = Math.floor(torrent.progress * torrent.size);
    }
    if (downloadedBytes <= 0) {
      downloadedBytes = torrent.downloaded;
    }
    return Math.max(0, downloadedBytes);
  }

  private getTaskMetaText(): string {
    return `已下载 ${FormatUtils.formatFileSize(this.getDownloadedBytes(this.torrentInfo))} / ${FormatUtils.formatFileSize(this.getTorrentSize())} · ${this.getEtaText()}`;
  }

  private getEtaText(): string {
    const etaSeconds: number = this.getTorrentEta();
    if (etaSeconds > 0 && etaSeconds < 8640000) {
      return `剩余 ${FormatUtils.formatEta(etaSeconds)}`;
    }
    return '剩余 --';
  }

  private getTorrentSize(): number {
    const totalSize: number = this.properties.total_size;
    if (totalSize > 0) {
      return totalSize;
    }
    return this.torrentInfo.size;
  }

  private getTorrentEta(): number {
    if (this.properties.eta > 0) {
      return this.properties.eta;
    }
    return this.torrentInfo.eta;
  }

  private getTorrentSavePath(): string {
    const savePath: string = this.properties.save_path;
    if (savePath.length > 0) {
      return savePath;
    }
    return this.torrentInfo.save_path;
  }

  private getTorrentAddedOn(): number {
    const additionDate: number = this.properties.addition_date;
    if (additionDate > 0) {
      return additionDate;
    }
    return this.torrentInfo.added_on;
  }

  private getDownloadSpeedText(): string {
    if (this.properties.dl_speed > 0) {
      return FormatUtils.formatSpeed(this.properties.dl_speed);
    }
    return FormatUtils.formatSpeed(this.torrentInfo.dlspeed);
  }

  private getUploadSpeedText(): string {
    if (this.properties.up_speed > 0) {
      return FormatUtils.formatSpeed(this.properties.up_speed);
    }
    return FormatUtils.formatSpeed(this.torrentInfo.upspeed);
  }

  private getProgressPercentText(): string {
    const percent: number = Math.max(0, Math.min(100, Math.floor(this.torrentInfo.progress * 100)));
    return `${percent}%`;
  }

  private getStatusText(): string {
    if (this.torrentInfo.isDownloading()) {
      return '下载中';
    }
    if (this.torrentInfo.isPaused()) {
      return '已暂停';
    }
    if (this.torrentInfo.isCompleted()) {
      return '已完成';
    }
    return this.torrentInfo.getStateLabel();
  }

  private getStatusFillColor(): ResourceStr {
    if (this.torrentInfo.isDownloading()) {
      return $r('app.color.dashboard_surface_info');
    }
    if (this.torrentInfo.isPaused()) {
      return $r('app.color.download_pause_bg');
    }
    if (this.torrentInfo.isCompleted()) {
      return $r('app.color.dashboard_surface_success');
    }
    if (this.torrentInfo.state === 'error' || this.torrentInfo.state === 'missingFiles') {
      return $r('app.color.dashboard_surface_danger');
    }
    return $r('app.color.dashboard_surface_muted');
  }

  private getStatusTextColor(): ResourceStr {
    if (this.torrentInfo.isDownloading()) {
      return $r('app.color.accent_color');
    }
    if (this.torrentInfo.isPaused()) {
      return $r('app.color.download_pause_fg');
    }
    if (this.torrentInfo.isCompleted()) {
      return $r('app.color.success_color');
    }
    if (this.torrentInfo.state === 'error' || this.torrentInfo.state === 'missingFiles') {
      return $r('app.color.error_color');
    }
    return $r('app.color.text_secondary');
  }

  private getPeerMetricText(): string {
    if (this.peers.length > 0) {
      return `${this.peers.length} peers`;
    }
    if (this.properties.peers > 0 || this.properties.peers_total > 0) {
      return `${this.properties.peers}/${this.properties.peers_total} peers`;
    }
    return `${this.torrentInfo.num_leechs} peers`;
  }

  private getSeedMetricText(): string {
    if (this.properties.seeds > 0 || this.properties.seeds_total > 0) {
      return `${this.properties.seeds}/${this.properties.seeds_total} seeds`;
    }
    return `${this.torrentInfo.num_seeds} seeds`;
  }

  private getRatioText(): string {
    if (this.properties.share_ratio > 0) {
      return this.properties.share_ratio.toFixed(2);
    }
    if (this.torrentInfo.ratio > 0) {
      return this.torrentInfo.ratio.toFixed(2);
    }
    return '0.00';
  }

  private getTrackerSummaryText(): string {
    if (this.trackers.length > 0) {
      return `Tracker ${this.trackers.length} 个活跃 · DHT 已接入`;
    }
    return 'Tracker 信息加载中';
  }

  private getPrimaryActionText(): string {
    if (this.torrentInfo.isPaused()) {
      return '恢复任务';
    }
    return '暂停任务';
  }

  private getTabTitle(index: number): string {
    if (index === 0) {
      return '概览';
    }
    if (index === 1) {
      return '文件';
    }
    if (index === 2) {
      return 'Peer';
    }
    return 'Tracker';
  }

  private getFilePriorityLabel(priority: number): string {
    if (priority === 0) {
      return '不下载';
    }
    if (priority === 1) {
      return '正常';
    }
    if (priority === 6) {
      return '高';
    }
    if (priority === 7) {
      return '最大';
    }
    return '正常';
  }

  private getTrackerStatusFillColor(tracker: TorrentTracker): ResourceStr {
    if (tracker.status === 2 || tracker.status === 3) {
      return $r('app.color.dashboard_surface_success');
    }
    if (tracker.status === 4) {
      return $r('app.color.dashboard_surface_warning');
    }
    if (tracker.status === 0) {
      return $r('app.color.dashboard_surface_danger');
    }
    return $r('app.color.dashboard_surface_info');
  }

  private getTrackerStatusTextColor(tracker: TorrentTracker): ResourceStr {
    if (tracker.status === 2 || tracker.status === 3) {
      return $r('app.color.success_color');
    }
    if (tracker.status === 4) {
      return $r('app.color.warning_color');
    }
    if (tracker.status === 0) {
      return $r('app.color.error_color');
    }
    return $r('app.color.accent_color');
  }

  private getFileRenderKey(file: TorrentFile, index: number): string {
    return `${index}_${file.name}_${Math.floor(file.progress * 1000)}_${file.priority}_${file.size}`;
  }

  private getPeerRenderKey(peer: TorrentPeer, index: number): string {
    return `${peer.id}_${Math.floor(peer.progress * 1000)}_${peer.dl_speed}_${peer.up_speed}_${index}`;
  }

  private getTrackerRenderKey(tracker: TorrentTracker, index: number): string {
    return `${index}_${tracker.url}_${tracker.status}_${tracker.num_seeds}_${tracker.num_leeches}`;
  }

  private getSpeedLimitSummaryText(): string {
    const dl: number = this.torrentInfo.dl_limit;
    const ul: number = this.torrentInfo.ul_limit;
    const dlText: string = dl > 0 ? `↓ ${FormatUtils.formatSpeed(dl)}` : '↓ 不限速';
    const ulText: string = ul > 0 ? `↑ ${FormatUtils.formatSpeed(ul)}` : '↑ 不限速';
    return `${dlText}  ${ulText}`;
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          Row()
            .width('100%')
            .height(420)
            .linearGradient({
              angle: 180,
              colors: [[$r('app.color.page_gradient_top'), 0], [$r('app.color.page_gradient_mid'), 0.5], [$r('app.color.page_background'), 1]]
            })
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))

        Column({ space: 8 }) {
          if (this.actionMessage.length > 0) {
            this.actionBanner()
          }
          this.headerSection()
          this.heroSection()
          this.segmentSection()

          Refresh({ refreshing: $$this.isPullRefreshing }) {
            Scroll(this.contentScroller) {
              Column({ space: 0 }) {
                if (this.selectedTab === 0) {
                  this.overviewSection()
                } else if (this.selectedTab === 1) {
                  this.filesSection()
                } else if (this.selectedTab === 2) {
                  this.peersSection()
                } else {
                  this.trackersSection()
                }
                Blank()
                  .height(104)
              }
              .width('100%')
            }
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .width('100%')
          }
          .onRefreshing(() => {
            this.loadData(false, true);
          })
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, top: 44, bottom: 0 })
        .backgroundColor(Color.Transparent)
        .blur(this.pendingDeleteMode.length > 0 || this.pendingFilePriorityIndex >= 0 || this.showSpeedLimitSheet ? 16 : 0)
        .animation({ duration: 220, curve: Curve.EaseOut })

        this.bottomActionBar()

        if (this.pendingDeleteMode.length > 0) {
          this.deleteConfirmDialog()
        }
        if (this.pendingFilePriorityIndex >= 0) {
          this.filePrioritySheet()
        }
        if (this.showSpeedLimitSheet) {
          this.speedLimitSheet()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
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
  headerSection() {
    Row() {
      Row({ space: 10 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(17)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.glass_bg_card'))
        .backdropBlur(20)
        .border({
          width: 1,
          color: $r('app.color.glass_border')
        })
        .borderRadius(16)
        .onClick(() => {
          this.pathStack.pop();
        })

        Text('任务详情')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }

      Blank()

      Row({ space: 5 }) {
        SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
          .fontSize(13)
          .fontColor([$r('app.color.accent_color')])
        Text('汇报')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))
      }
      .padding({ left: 10, right: 10 })
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(16)
      .opacity(this.isActionPending ? 0.55 : 1)
      .onClick(() => {
        this.handleReannounce();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  heroSection() {
    Column({ space: 10 }) {
      Row() {
        Text(this.torrentInfo.name.length > 0 ? this.torrentInfo.name : '任务信息加载中')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Row() {
          Text(this.getStatusText())
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getStatusTextColor())
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.getStatusFillColor())
        .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.getTaskMetaText())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(10)
          .backgroundColor($r('app.color.dashboard_progress_track'))
          .borderRadius(999)
        Row()
          .width(this.getProgressPercentText())
          .height(10)
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

      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text('下载速度')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.tab_inactive_fg'))
          Text(this.getDownloadSpeedText())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .borderRadius(18)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('上传速度')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.tab_inactive_fg'))
          Text(this.getUploadSpeedText())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .borderRadius(18)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(24)
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(28)
    .shadow({
      radius: 20,
      color: '#0F172A14',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  segmentSection() {
    Row({ space: 8 }) {
      ForEach([0, 1, 2, 3], (index: number) => {
        Row({ space: 4 }) {
          if (index === 0) {
            SymbolGlyph($r('sys.symbol.info_circle'))
              .fontSize(13)
              .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
          } else if (index === 1) {
            SymbolGlyph($r('sys.symbol.folder'))
              .fontSize(13)
              .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
          } else if (index === 2) {
            SymbolGlyph($r('sys.symbol.person_2'))
              .fontSize(13)
              .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
          } else {
            SymbolGlyph($r('sys.symbol.link'))
              .fontSize(13)
              .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
          }
          Text(this.getTabTitle(index))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg'))
        }
        .layoutWeight(1)
        .padding({ left: 0, right: 0, top: 8, bottom: 8 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.selectedTab === index ? $r('app.color.tab_active_bg') : $r('app.color.glass_bg_card'))
        .backdropBlur(this.selectedTab === index ? 0 : 20)
        .border(this.selectedTab === index ? { width: 0 } : {
          width: 1,
          color: $r('app.color.glass_border')
        })
        .borderRadius(999)
        .onClick(() => {
          this.onTabChange(index);
        })
      })
    }
    .width('100%')
  }

  @Builder
  overviewSection() {
    Column({ space: 10 }) {
      Column({ space: 10 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
            .fontSize(14)
            .fontColor([$r('app.color.accent_color')])
          Text('传输概览')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text('可用节点')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.tab_inactive_fg'))
            Text(this.getPeerMetricText())
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .borderRadius(18)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('做种节点')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.tab_inactive_fg'))
            Text(this.getSeedMetricText())
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .borderRadius(18)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('分享率')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.tab_inactive_fg'))
            Text(this.getRatioText())
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .borderRadius(18)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(24)

      Column({ space: 8 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.externaldrive'))
            .fontSize(14)
            .fontColor([$r('app.color.accent_color')])
          Text('存储与来源')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(`保存路径  ${this.getTorrentSavePath().length > 0 ? this.getTorrentSavePath() : '--'}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(`文件大小  ${FormatUtils.formatFileSize(this.getTorrentSize())} · 添加于 ${FormatUtils.formatTimestamp(this.getTorrentAddedOn())}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(this.getTrackerSummaryText())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(24)

      Row() {
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.slider_horizontal_2'))
              .fontSize(13)
              .fontColor([$r('app.color.accent_color')])
            Text('限速设置')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .alignItems(VerticalAlign.Center)
          Text(this.getSpeedLimitSummaryText())
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.arrow_up_right'))
            .fontSize(12)
            .fontColor([$r('app.color.accent_color')])
          Text('修改')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_color'))
        }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .borderRadius(999)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(20)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openSpeedLimitSheet();
      })
    }
    .width('100%')
  }

  @Builder
  filesSection() {
    Column({ space: 8 }) {
      if (this.files.length === 0) {
        this.emptyStateCard('暂无文件信息')
      } else {
        ForEach(this.files, (file: TorrentFile, index?: number) => {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.doc'))
                .fontSize(15)
                .fontColor([$r('app.color.accent_color')])
              Text(file.name)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(6)
                .backgroundColor($r('app.color.dashboard_progress_track'))
                .borderRadius(999)
              Row()
                .width(Math.max(0, Math.min(100, Math.floor(file.progress * 100))) + '%')
                .height(6)
                .backgroundColor($r('app.color.accent_color'))
                .borderRadius(999)
            }
            .width('100%')

            Row() {
              Text(FormatUtils.formatFileSize(file.size))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              Text(FormatUtils.formatProgress(file.progress))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              Blank()
              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.flag'))
                  .fontSize(11)
                  .fontColor([$r('app.color.accent_color')])
                Text(this.getFilePriorityLabel(file.priority))
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.accent_color'))
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.dashboard_surface_info'))
              .borderRadius(999)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.pendingFilePriorityIndex = file.index;
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.glass_bg_elevated'))
          .border({
            width: 1,
            color: $r('app.color.glass_border')
          })
          .borderRadius(20)
        }, (file: TorrentFile, index?: number) => this.getFileRenderKey(file, index ?? 0))
      }
    }
    .width('100%')
  }

  @Builder
  peersSection() {
    Column({ space: 8 }) {
      if (this.peers.length === 0) {
        this.emptyStateCard('暂无 Peer 信息')
      } else {
        ForEach(this.peers, (peer: TorrentPeer, index?: number) => {
          Column({ space: 8 }) {
            Row() {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.person'))
                  .fontSize(14)
                  .fontColor([$r('app.color.accent_color')])
                Text(`${peer.ip}:${peer.port}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
              }
              Blank()
              Text(peer.client)
                .fontSize(11)
                .fontColor($r('app.color.tab_inactive_fg'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 120 })
            }
            .width('100%')

            Row({ space: 12 }) {
              Text(`进度 ${FormatUtils.formatProgress(peer.progress)}`)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              if (peer.dl_speed > 0) {
                Text(`↓ ${FormatUtils.formatSpeed(peer.dl_speed)}`)
                  .fontSize(11)
                  .fontColor($r('app.color.accent_color'))
              }
              if (peer.up_speed > 0) {
                Text(`↑ ${FormatUtils.formatSpeed(peer.up_speed)}`)
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.glass_bg_elevated'))
          .border({
            width: 1,
            color: $r('app.color.glass_border')
          })
          .borderRadius(20)
        }, (peer: TorrentPeer, index?: number) => this.getPeerRenderKey(peer, index ?? 0))
      }
    }
    .width('100%')
  }

  @Builder
  trackersSection() {
    Column({ space: 8 }) {
      if (this.trackers.length === 0) {
        this.emptyStateCard('暂无 Tracker 信息')
      } else {
        ForEach(this.trackers, (tracker: TorrentTracker, index?: number) => {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.link'))
                .fontSize(14)
                .fontColor([$r('app.color.accent_color')])
              Text(tracker.url)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            Row({ space: 12 }) {
              Text(tracker.getStatusLabel())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getTrackerStatusTextColor(tracker))
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(this.getTrackerStatusFillColor(tracker))
                .borderRadius(999)
              Text(`种子 ${tracker.num_seeds}`)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              Text(`下载 ${tracker.num_leeches}`)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')

            if (tracker.msg.length > 0) {
              Text(tracker.msg)
                .fontSize(11)
                .fontColor($r('app.color.tab_inactive_fg'))
                .width('100%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.glass_bg_elevated'))
          .border({
            width: 1,
            color: $r('app.color.glass_border')
          })
          .borderRadius(20)
        }, (tracker: TorrentTracker, index?: number) => this.getTrackerRenderKey(tracker, index ?? 0))
      }
    }
    .width('100%')
  }

  @Builder
  emptyStateCard(message: string) {
    Column({ space: 8 }) {
      Text(message)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('当前任务没有返回可展示的数据。')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.glass_bg_elevated'))
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  deleteConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .onClick(() => {
          this.cancelDelete();
        })

      Column({ space: 14 }) {
        Column({ space: 6 }) {
          Text('删除任务')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('请选择删除方式')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Button('仅删除任务')
            .width('100%')
            .height(46)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .border({
              width: 1,
              color: $r('app.color.dashboard_border')
            })
            .borderRadius(14)
            .onClick(() => {
              this.confirmDelete(false);
            })

          Button('删除任务和文件')
            .width('100%')
            .height(46)
            .fontSize(14)
            .fontColor($r('app.color.tab_active_fg'))
            .backgroundColor($r('app.color.error_color'))
            .borderRadius(14)
            .onClick(() => {
              this.confirmDelete(true);
            })

          Button('取消')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(14)
            .onClick(() => {
              this.cancelDelete();
            })
        }
        .width('100%')
      }
      .width(290)
      .padding(18)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(24)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  filePrioritySheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .onClick(() => {
          this.pendingFilePriorityIndex = -1;
        })

      Column({ space: 12 }) {
        Row()
          .width(46)
          .height(5)
          .backgroundColor($r('app.color.download_sheet_handle'))
          .borderRadius(999)
          .alignSelf(ItemAlign.Center)

        Column({ space: 6 }) {
          Text('文件优先级')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('选择此文件的下载优先级')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Button('不下载')
            .width('100%').height(46).fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .border({ width: 1, color: $r('app.color.dashboard_border') })
            .borderRadius(14)
            .onClick(() => { this.handleSetFilePriority(this.pendingFilePriorityIndex, 0); })
          Button('正常优先级')
            .width('100%').height(46).fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .border({ width: 1, color: $r('app.color.dashboard_border') })
            .borderRadius(14)
            .onClick(() => { this.handleSetFilePriority(this.pendingFilePriorityIndex, 1); })
          Button('高优先级')
            .width('100%').height(46).fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .border({ width: 1, color: $r('app.color.dashboard_border') })
            .borderRadius(14)
            .onClick(() => { this.handleSetFilePriority(this.pendingFilePriorityIndex, 6); })
          Button('最大优先级')
            .width('100%').height(46).fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .border({ width: 1, color: $r('app.color.dashboard_border') })
            .borderRadius(14)
            .onClick(() => { this.handleSetFilePriority(this.pendingFilePriorityIndex, 7); })

          Button('取消')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(14)
            .onClick(() => {
              this.pendingFilePriorityIndex = -1;
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 40 })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  speedLimitSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.dashboard_overlay'))
        .onClick(() => {
          if (!this.isSettingSpeedLimit) {
            this.showSpeedLimitSheet = false;
          }
        })

      Column({ space: 14 }) {
        Row()
          .width(46)
          .height(5)
          .backgroundColor($r('app.color.download_sheet_handle'))
          .borderRadius(999)
          .alignSelf(ItemAlign.Center)

        Column({ space: 6 }) {
          Text('限速设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('0 或留空表示不限速（KB/s）')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          Column({ space: 6 }) {
            Text('下载限速（KB/s）')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            TextInput({ placeholder: '0 = 不限速', text: this.speedLimitDlInput })
              .type(InputType.Number)
              .height(46)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .caretColor($r('app.color.accent_color'))
              .backgroundColor($r('app.color.dashboard_surface_soft'))
              .borderRadius(12)
              .onChange((v: string) => {
                this.speedLimitDlInput = v;
              })
          }

          Column({ space: 6 }) {
            Text('上传限速（KB/s）')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            TextInput({ placeholder: '0 = 不限速', text: this.speedLimitUlInput })
              .type(InputType.Number)
              .height(46)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .caretColor($r('app.color.accent_color'))
              .backgroundColor($r('app.color.dashboard_surface_soft'))
              .borderRadius(12)
              .onChange((v: string) => {
                this.speedLimitUlInput = v;
              })
          }
        }
        .width('100%')

        Column({ space: 8 }) {
          Button(this.isSettingSpeedLimit ? '设置中...' : '确认设置')
            .width('100%')
            .height(46)
            .fontSize(14)
            .fontColor($r('app.color.dashboard_primary_action_fg'))
            .backgroundColor($r('app.color.dashboard_primary_action_bg'))
            .borderRadius(14)
            .enabled(!this.isSettingSpeedLimit)
            .onClick(() => {
              this.handleSetSpeedLimit();
            })

          Button('取消')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(14)
            .onClick(() => {
              if (!this.isSettingSpeedLimit) {
                this.showSpeedLimitSheet = false;
              }
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 40 })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  bottomActionBar() {
    Row() {
      Row({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.torrentInfo.isPaused() ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause'))
            .fontSize(15)
            .fontColor([$r('app.color.dashboard_primary_action_fg')])
          Text(this.getPrimaryActionText())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.dashboard_primary_action_fg'))
        }
        .layoutWeight(1)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.dashboard_primary_action_bg'))
        .borderRadius(999)
        .opacity(this.isActionPending ? 0.6 : 1)
        .onClick(() => {
          this.handlePrimaryAction();
        })

        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(15)
            .fontColor([$r('app.color.error_color')])
          Text('删除任务')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.error_color'))
        }
        .layoutWeight(1)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.dashboard_surface_danger'))
        .border({
          width: 1,
          color: $r('app.color.download_warn_border')
        })
        .borderRadius(999)
        .opacity(this.isActionPending ? 0.6 : 1)
        .onClick(() => {
          this.requestDelete();
        })
      }
      .width('100%')
      .padding(6)
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(24)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(999)
    }
    .width('100%')
    .padding({ top: 10, right: 21, bottom: 22, left: 21 })
    .backgroundColor('#00000000')
    .alignItems(VerticalAlign.Center)
  }
}
