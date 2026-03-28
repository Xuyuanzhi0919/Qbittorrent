import { QbittorrentService } from '../service/QbittorrentService';
import { TorrentInfo } from '../model/TorrentInfo';
import { TorrentFile } from '../model/TorrentFile';
import { TorrentTracker } from '../model/TorrentTracker';
import { TorrentPeer } from '../model/TorrentPeer';
import { FormatUtils } from '../common/utils/FormatUtils';
import { ProgressBar } from '../components/ProgressBar';
import { EmptyState } from '../components/EmptyState';
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
  @State properties: Record<string, Object> = {};
  @State selectedTab: number = 0;
  @State isLoading: boolean = false;
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;

    // Load torrent info from list
    const torrents: TorrentInfo[] = await this.service.fetchTorrentList();
    for (const t of torrents) {
      if (t.hash === this.torrentHash) {
        this.torrentInfo = t;
        break;
      }
    }

    // Load tab-specific data
    if (this.selectedTab === 1) {
      this.files = await this.service.fetchTorrentFiles(this.torrentHash);
    } else if (this.selectedTab === 2) {
      this.trackers = await this.service.fetchTorrentTrackers(this.torrentHash);
    } else if (this.selectedTab === 3) {
      this.peers = await this.service.fetchTorrentPeers(this.torrentHash);
    }

    this.isLoading = false;
  }

  private async onTabChange(index: number): Promise<void> {
    this.selectedTab = index;
    await this.loadData();
  }

  build() {
    NavDestination() {
      Column() {
        // Action buttons
        Row({ space: 8 }) {
          if (this.torrentInfo.isPaused()) {
            Button('恢复')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor($r('app.color.download_color'))
              .borderRadius(8)
              .height(36)
              .onClick(async () => {
                await this.service.resumeTorrents([this.torrentHash]);
                this.loadData();
              })
          } else {
            Button('暂停')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor($r('app.color.state_paused'))
              .borderRadius(8)
              .height(36)
              .onClick(async () => {
                await this.service.pauseTorrents([this.torrentHash]);
                this.loadData();
              })
          }
          Button('删除')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor($r('app.color.button_danger'))
            .borderRadius(8)
            .height(36)
            .onClick(async () => {
              await this.service.deleteTorrents([this.torrentHash], false);
              this.pathStack.pop();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .justifyContent(FlexAlign.End)

        // Sub-tabs
        Tabs({ index: this.selectedTab }) {
          TabContent() {
            this.generalTab();
          }.tabBar('概览')

          TabContent() {
            this.filesTab();
          }.tabBar('文件')

          TabContent() {
            this.trackersTab();
          }.tabBar('Tracker')

          TabContent() {
            this.peersTab();
          }.tabBar('Peer')
        }
        .onChange((index: number) => {
          this.onTabChange(index);
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .title(this.torrentInfo.name.length > 0 ? this.torrentInfo.name : '种子详情')
    .backgroundColor($r('app.color.page_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  generalTab() {
    Scroll() {
      Column({ space: 12 }) {
        // Progress
        Column({ space: 8 }) {
          Row() {
            Text('进度')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Blank()
            Text(FormatUtils.formatProgress(this.torrentInfo.progress))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          ProgressBar({ progress: this.torrentInfo.progress, barHeight: 8, showLabel: false })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)

        // Speed info
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('下载速度')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
            Text(FormatUtils.formatSpeed(this.torrentInfo.dlspeed))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.download_color'))
          }
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('上传速度')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
            Text(FormatUtils.formatSpeed(this.torrentInfo.upspeed))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.upload_color'))
          }
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        // Details
        Column({ space: 0 }) {
          this.detailRow('状态', this.torrentInfo.getStateLabel())
          this.detailRow('大小', FormatUtils.formatFileSize(this.torrentInfo.size))
          this.detailRow('已下载', FormatUtils.formatFileSize(this.torrentInfo.downloaded))
          this.detailRow('已上传', FormatUtils.formatFileSize(this.torrentInfo.uploaded))
          this.detailRow('分享率', FormatUtils.formatRatio(this.torrentInfo.ratio))
          if (this.torrentInfo.eta > 0 && this.torrentInfo.eta !== 8640000) {
            this.detailRow('剩余时间', FormatUtils.formatEta(this.torrentInfo.eta))
          }
          this.detailRow('做种数', `${this.torrentInfo.num_seeds}`)
          this.detailRow('下载数', `${this.torrentInfo.num_leechs}`)
          this.detailRow('分类', this.torrentInfo.category.length > 0 ? this.torrentInfo.category : '无')
          this.detailRow('标签', this.torrentInfo.tags.length > 0 ? this.torrentInfo.tags : '无')
          this.detailRow('保存路径', this.torrentInfo.save_path)
          this.detailRow('Hash', this.torrentInfo.hash)
          this.detailRow('添加时间', FormatUtils.formatTimestamp(this.torrentInfo.added_on))
          if (this.torrentInfo.completion_on > 0) {
            this.detailRow('完成时间', FormatUtils.formatTimestamp(this.torrentInfo.completion_on))
          }
        }
        .width('100%')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    }
    .scrollBar(BarState.Off)
  }

  @Builder
  detailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width(80)
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(44)
  }

  @Builder
  filesTab() {
    if (this.files.length === 0) {
      EmptyState({ message: '暂无文件信息', icon: '📁' })
    } else {
      List({ space: 8 }) {
        ForEach(this.files, (file: TorrentFile) => {
          ListItem() {
            Column({ space: 6 }) {
              Text(file.name)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')

              ProgressBar({ progress: file.progress, barHeight: 4, showLabel: false })

              Row({ space: 12 }) {
                Text(FormatUtils.formatFileSize(file.size))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                Text(FormatUtils.formatProgress(file.progress))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(this.getFilePriorityLabel(file.priority))
                  .fontSize(12)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(8)
          }
        }, (file: TorrentFile, index?: number) => `${index}`)
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  trackersTab() {
    if (this.trackers.length === 0) {
      EmptyState({ message: '暂无 Tracker 信息', icon: '🌐' })
    } else {
      List({ space: 8 }) {
        ForEach(this.trackers, (tracker: TorrentTracker) => {
          ListItem() {
            Column({ space: 6 }) {
              Text(tracker.url)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')

              Row({ space: 12 }) {
                Text(`状态: ${tracker.getStatusLabel()}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                Text(`种子: ${tracker.num_seeds}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                Text(`下载: ${tracker.num_leeches}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              if (tracker.msg.length > 0) {
                Text(tracker.msg)
                  .fontSize(11)
                  .fontColor($r('app.color.text_hint'))
                  .width('100%')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(8)
          }
        }, (tracker: TorrentTracker, index?: number) => `${index}`)
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  peersTab() {
    if (this.peers.length === 0) {
      EmptyState({ message: '暂无 Peer 信息', icon: '👥' })
    } else {
      List({ space: 8 }) {
        ForEach(this.peers, (peer: TorrentPeer) => {
          ListItem() {
            Column({ space: 4 }) {
              Row() {
                Text(`${peer.ip}:${peer.port}`)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)
                Blank()
                Text(peer.client)
                  .fontSize(11)
                  .fontColor($r('app.color.text_hint'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: 120 })
              }
              .width('100%')

              Row({ space: 12 }) {
                Text(`进度: ${FormatUtils.formatProgress(peer.progress)}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                if (peer.dl_speed > 0) {
                  Text(`↓${FormatUtils.formatSpeed(peer.dl_speed)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.download_color'))
                }
                if (peer.up_speed > 0) {
                  Text(`↑${FormatUtils.formatSpeed(peer.up_speed)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.upload_color'))
                }
                if (peer.country.length > 0) {
                  Text(peer.country)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(8)
          }
        }, (peer: TorrentPeer, index?: number) => `${index}`)
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .scrollBar(BarState.Off)
    }
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
}
