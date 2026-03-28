@Component
export struct EmptyState {
  @Prop message: string = '暂无数据';
  @Prop icon: string = '📭';

  build() {
    Column({ space: 12 }) {
      Text(this.icon)
        .fontSize(48)
      Text(this.message)
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(48)
  }
}
