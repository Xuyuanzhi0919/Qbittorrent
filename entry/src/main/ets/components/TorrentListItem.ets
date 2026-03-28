import { TorrentInfo } from '../model/TorrentInfo';
import { FormatUtils } from '../common/utils/FormatUtils';
import { ProgressBar } from './ProgressBar';

@Component
export struct TorrentListItem {
  @Prop torrent: TorrentInfo = new TorrentInfo();
  onItemClick?: (hash: string) => void;

  build() {
    Column({ space: 8 }) {
      // Torrent name
      Text(this.torrent.name)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      // Progress bar
      ProgressBar({ progress: this.torrent.progress, barHeight: 4 })

      // Info row
      Row({ space: 12 }) {
        // State badge
        Text(this.torrent.getStateLabel())
          .fontSize(11)
          .fontColor('#FFFFFF')
          .backgroundColor(this.getStateColor())
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })

        // Size
        Text(FormatUtils.formatFileSize(this.torrent.size))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))

        // ETA
        if (this.torrent.eta > 0 && this.torrent.eta !== 8640000) {
          Text(FormatUtils.formatEta(this.torrent.eta))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }

        Blank()

        // Speed indicators
        if (this.torrent.dlspeed > 0) {
          Text(`↓${FormatUtils.formatSpeed(this.torrent.dlspeed)}`)
            .fontSize(12)
            .fontColor($r('app.color.download_color'))
        }
        if (this.torrent.upspeed > 0) {
          Text(`↑${FormatUtils.formatSpeed(this.torrent.upspeed)}`)
            .fontSize(12)
            .fontColor($r('app.color.upload_color'))
        }
      }
      .width('100%')

      // Seeds / Leechs
      Row({ space: 8 }) {
        Text(`做种: ${this.torrent.num_seeds}`)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
        Text(`下载: ${this.torrent.num_leechs}`)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
        Text(`分享率: ${FormatUtils.formatRatio(this.torrent.ratio)}`)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick(this.torrent.hash);
      }
    })
  }

  private getStateColor(): ResourceStr {
    if (this.torrent.isDownloading()) {
      return $r('app.color.state_downloading');
    }
    if (this.torrent.isCompleted()) {
      return $r('app.color.state_seeding');
    }
    if (this.torrent.isPaused()) {
      return $r('app.color.state_paused');
    }
    if (this.torrent.state === 'error' || this.torrent.state === 'missingFiles') {
      return $r('app.color.state_error');
    }
    return $r('app.color.accent_color');
  }
}
