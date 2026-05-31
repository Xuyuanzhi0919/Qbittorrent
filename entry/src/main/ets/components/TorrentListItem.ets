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
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        this.selectionControl()

        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(this.torrent.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            this.statePill()
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Row({ space: 8 }) {
            Text(this.getPrimaryMetaText())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(this.getEtaOrSizeText())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.tab_inactive_fg'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 7 }) {
        Row() {
          Text('进度')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(`${this.getProgressPercent().toFixed(0)}%`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_color'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(7)
            .backgroundColor($r('app.color.dashboard_progress_track'))
            .borderRadius(999)
          Row()
            .width(`${this.getProgressPercent()}%`)
            .height(7)
            .linearGradient({
              angle: 90,
              colors: [['#2563EB', 0], ['#60A5FA', 1]]
            })
            .borderRadius(999)
        }
        .width('100%')
      }
      .width('100%')

      Row({ space: 8 }) {
        this.metricBlock('下载', `↓ ${FormatUtils.formatSpeed(this.torrent.dlspeed)}`, $r('app.color.accent_color'))
        this.metricBlock('上传', `↑ ${FormatUtils.formatSpeed(this.torrent.upspeed)}`, $r('app.color.text_secondary'))
        this.metricBlock('比例', FormatUtils.formatRatio(this.torrent.ratio), $r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
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

  @Builder
  selectionControl() {
    if (this.selectionMode) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(22)
          .height(22)
          .backgroundColor(this.isSelected ? $r('app.color.accent_color') : Color.Transparent)
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
      .width(22)
      .height(22)
      .margin({ top: 2 })
    } else {
      Row()
        .width(8)
        .height(8)
        .backgroundColor(this.getStateTextColor())
        .borderRadius(999)
        .margin({ top: 8 })
    }
  }

  @Builder
  statePill() {
    Text(this.torrent.getStateLabel())
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getStateTextColor())
      .padding({ left: 9, right: 9, top: 5, bottom: 5 })
      .backgroundColor(this.getStateBackgroundColor())
      .borderRadius(999)
  }

  @Builder
  metricBlock(label: string, value: string, valueColor: ResourceStr) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.tab_inactive_fg'))
      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(14)
  }

  private getEtaOrSizeText(): string {
    if (this.torrent.isDownloading() && this.torrent.eta > 0 && this.torrent.eta < 8640000) {
      return `剩余 ${FormatUtils.formatEta(this.torrent.eta)}`;
    }
    return FormatUtils.formatFileSize(this.torrent.size);
  }

  private getPrimaryMetaText(): string {
    if (this.torrent.category.length > 0 && this.torrent.tags.length > 0) {
      return `${this.torrent.category} · ${this.torrent.tags}`;
    }
    if (this.torrent.category.length > 0) {
      return this.torrent.category;
    }
    if (this.torrent.tags.length > 0) {
      return this.torrent.tags;
    }
    if (this.torrent.save_path.length > 0) {
      return this.torrent.save_path;
    }
    return '未设置分类';
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
