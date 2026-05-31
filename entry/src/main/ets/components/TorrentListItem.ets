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
    Stack({ alignContent: Alignment.TopStart }) {
      this.cardMaskLayer()

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.selectionControl()

          Text(this.torrent.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          this.statePill()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Text(`↓ ${FormatUtils.formatSpeed(this.torrent.dlspeed)}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_color'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.getEtaOrSizeText())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 6 }) {
          Row() {
            Text('进度')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            Blank()
            Text(`${this.getProgressPercent().toFixed(0)}%`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_color'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

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
                colors: [['#2563EB', 0], ['#60A5FA', 1]]
              })
              .borderRadius(999)
          }
          .width('100%')
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(this.isSelected ? $r('app.color.download_selected_bg') : $r('app.color.card_background'))
    .border({
      width: 1,
      color: this.isSelected ? $r('app.color.download_selected_border') : $r('app.color.dashboard_border')
    })
    .borderRadius(20)
    .clip(true)
    .shadow({ radius: 10, color: '#0F172A0D', offsetX: 0, offsetY: 4 })
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
  cardMaskLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width('100%')
        .height(54)
        .linearGradient({
          angle: 135,
          colors: [
            [$r('app.color.card_mask_primary'), 0],
            [Color.Transparent, 1]
          ]
        })

      Row()
        .width(120)
        .height(120)
        .backgroundColor($r('app.color.card_mask_secondary'))
        .borderRadius(999)
        .position({ x: -54, y: -62 })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
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
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getStateTextColor())
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(this.getStateBackgroundColor())
      .border({ width: 1, color: this.getStateBorderColor() })
      .borderRadius(999)
  }

  private getEtaOrSizeText(): string {
    if (this.torrent.isDownloading() && this.torrent.eta > 0 && this.torrent.eta < 8640000) {
      return `剩余 ${FormatUtils.formatEta(this.torrent.eta)}`;
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

  private getStateBorderColor(): ResourceStr {
    if (this.torrent.isDownloading()) {
      return $r('app.color.download_selected_border');
    }
    if (this.torrent.isCompleted()) {
      return $r('app.color.success_color');
    }
    if (this.torrent.isPaused()) {
      return $r('app.color.warning_color');
    }
    if (this.torrent.state === 'error' || this.torrent.state === 'missingFiles') {
      return $r('app.color.error_color');
    }
    return $r('app.color.dashboard_border');
  }
}
