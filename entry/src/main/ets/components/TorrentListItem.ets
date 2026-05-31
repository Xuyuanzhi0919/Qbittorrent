import { TorrentInfo } from '../model/TorrentInfo';
import { FormatUtils } from '../common/utils/FormatUtils';

@Component
export struct TorrentListItem {
  @Prop torrent: TorrentInfo = new TorrentInfo();
  @Prop selectionMode: boolean = false;
  @Prop isSelected: boolean = false;
  onItemClick?: (hash: string) => void;
  onToggleSelect?: (hash: string) => void;

  build() {
    Column({ space: 9 }) {
      // Row 1: state indicator · name · badge
      Row({ space: 10 }) {
        if (this.selectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(20)
              .height(20)
              .backgroundColor(this.isSelected ? $r('app.color.accent_color') : Color.Transparent)
              .border({
                width: 1.5,
                color: this.isSelected ? $r('app.color.accent_color') : $r('app.color.download_selected_border')
              })
              .borderRadius(999)
            if (this.isSelected) {
              Text('✓')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.tab_active_fg'))
            }
          }
          .width(20)
          .height(20)
        } else {
          Row()
            .width(7)
            .height(7)
            .backgroundColor(this.getStateTextColor())
            .borderRadius(999)
        }

        Text(this.torrent.name)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text(this.torrent.getStateLabel())
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStateTextColor())
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.getStateBackgroundColor())
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // Row 2: progress bar + speed info
      Column({ space: 6 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(5)
            .backgroundColor($r('app.color.dashboard_progress_track'))
            .borderRadius(999)
          Row()
            .width(`${this.getProgressPercent()}%`)
            .height(5)
            .linearGradient({
              angle: 90,
              colors: [['#2563EB', 0], ['#60A5FA', 1]]
            })
            .borderRadius(999)
        }
        .width('100%')

        Row({ space: 8 }) {
          Text(`${this.getProgressPercent().toFixed(0)}%`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_color'))

          Text(`↓ ${FormatUtils.formatSpeed(this.torrent.dlspeed)}`)
            .fontSize(11)
            .fontWeight(FontWeight.Normal)
            .fontColor($r('app.color.text_secondary'))

          Text(`↑ ${FormatUtils.formatSpeed(this.torrent.upspeed)}`)
            .fontSize(11)
            .fontWeight(FontWeight.Normal)
            .fontColor($r('app.color.tab_inactive_fg'))

          Blank()

          Text(this.getEtaOrSizeText())
            .fontSize(11)
            .fontWeight(FontWeight.Normal)
            .fontColor($r('app.color.tab_inactive_fg'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.isSelected ? $r('app.color.download_selected_bg') : $r('app.color.glass_bg_elevated'))
    .border({
      width: 1,
      color: this.isSelected ? $r('app.color.download_selected_border') : $r('app.color.glass_border')
    })
    .borderRadius(20)
    .animation({ duration: 220, curve: Curve.EaseOut })
    .onClick(() => {
      if (this.selectionMode) {
        if (this.onToggleSelect) {
          this.onToggleSelect(this.torrent.hash);
        }
        return;
      }
      if (this.onItemClick) {
        this.onItemClick(this.torrent.hash);
      }
    })
  }

  private getEtaOrSizeText(): string {
    if (this.torrent.isDownloading() && this.torrent.eta > 0 && this.torrent.eta < 8640000) {
      return FormatUtils.formatEta(this.torrent.eta);
    }
    return FormatUtils.formatFileSize(this.torrent.size);
  }

  private getProgressPercent(): number {
    const percent: number = this.torrent.progress * 100;
    if (percent <= 0) {
      return 0;
    }
    if (percent >= 100) {
      return 100;
    }
    return percent;
  }

  private getStateBackgroundColor(): ResourceStr {
    if (this.torrent.isDownloading()) {
      return $r('app.color.dashboard_surface_info');
    }
    if (this.torrent.isCompleted()) {
      return $r('app.color.dashboard_surface_success');
    }
    if (this.torrent.isPaused()) {
      return $r('app.color.download_pause_bg');
    }
    if (this.torrent.state === 'error' || this.torrent.state === 'missingFiles') {
      return $r('app.color.dashboard_surface_danger');
    }
    return $r('app.color.dashboard_surface_muted');
  }

  private getStateTextColor(): ResourceStr {
    if (this.torrent.isDownloading()) {
      return $r('app.color.accent_color');
    }
    if (this.torrent.isCompleted()) {
      return $r('app.color.success_color');
    }
    if (this.torrent.isPaused()) {
      return $r('app.color.download_pause_fg');
    }
    if (this.torrent.state === 'error' || this.torrent.state === 'missingFiles') {
      return $r('app.color.error_color');
    }
    return $r('app.color.text_secondary');
  }
}
