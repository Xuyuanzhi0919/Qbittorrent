@Component
export struct LoadingOverlay {
  @Prop visible: boolean = false;

  build() {
    if (this.visible) {
      Row() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color($r('app.color.accent_color'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#33000000')
      .position({ x: 0, y: 0 })
    }
  }
}
