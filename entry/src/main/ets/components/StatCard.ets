@Component
export struct StatCard {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop subtitle: string = '';
  @Prop icon: string = '';

  build() {
    Column({ space: 8 }) {
      if (this.icon.length > 0) {
        Text(this.icon)
          .fontSize(24)
      }
      Text(this.label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      Text(this.value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .alignItems(HorizontalAlign.Start)
  }
}
