import { FormatUtils } from '../common/utils/FormatUtils';

@Component
export struct SpeedIndicator {
  @Prop speed: number = 0;
  @Prop label: string = '';
  @Prop direction: string = 'down'; // 'down' or 'up'

  build() {
    Row({ space: 6 }) {
      Text(this.direction === 'down' ? '↓' : '↑')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.direction === 'down' ? $r('app.color.download_color') : $r('app.color.upload_color'))
      Column({ space: 2 }) {
        Text(FormatUtils.formatSpeed(this.speed))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        if (this.label.length > 0) {
          Text(this.label)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
  }
}
