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
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        if (this.selectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(22)
              .height(22)
              .backgroundColor(this.isSelected ? $r('app.color.accent_color') : $r('app.color.card_background'))
              .border({
                width: 1.5,
                color: this.isSelected ? $r('app.color.accent_color') : $r('app.color.download_selected_border')
              })
              .borderRadius(999)

            if (this.isSelected) {
              Text('✓')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.tab_active_fg'))
            }
          }
        }

        Column({ space: 4 }) {
          Text(this.torrent.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.getMetaText())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.torrent.getStateLabel())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStateTextColor())
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.getStateBackgroundColor())
          .borderRadius(999)
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
          .width(`${this.getProgressPercent()}%`)
          .height(6)
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
        Text(`${this.getProgressPercent().toFixed(0)}%`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .borderRadius(999)

        Text(`↓ ${FormatUtils.formatSpeed(this.torrent.dlspeed)}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))

        Text(`↑ ${FormatUtils.formatSpeed(this.torrent.upspeed)}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.tab_inactive_fg'))

        Blank()

        Text(`${this.torrent.num_seeds} peers`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.tab_inactive_fg'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.getLabelText().length > 0) {
        Row({ space: 8 }) {
          Text(this.getLabelText())
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_color'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.dashboard_surface_info'))
            .borderRadius(999)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.isSelected ? $r('app.color.download_selected_bg') : $r('app.color.card_background'))
    .border({
      width: 1,
      color: this.isSelected ? $r('app.color.download_selected_border') : $r('app.color.dashboard_border')
    })
    .borderRadius(20)
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

  private getMetaText(): string {
    const typeText: string = this.getTaskTypeText();
    const sizeText: string = FormatUtils.formatFileSize(this.torrent.size);
    const remainingBytes: number = this.torrent.amount_left > 0 ? this.torrent.amount_left :
      Math.max(0, this.torrent.size - Math.floor(this.torrent.size * this.torrent.progress));
    const remainingText: string = FormatUtils.formatFileSize(remainingBytes);
    return `${typeText} • ${sizeText} • 剩余 ${remainingText}`;
  }

  private getTaskTypeText(): string {
    const name: string = this.torrent.name.toLowerCase();
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

  private getLabelText(): string {
    const tags: string = this.torrent.tags.trim();
    if (tags.length > 0) {
      return `标签: ${tags}`;
    }

    const category: string = this.torrent.category.trim();
    if (category.length > 0) {
      return `分类: ${category}`;
    }

    return '';
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
