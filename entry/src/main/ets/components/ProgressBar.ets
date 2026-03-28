@Component
export struct ProgressBar {
  @Prop progress: number = 0;
  @Prop barHeight: number = 6;
  @Prop showLabel: boolean = false;

  build() {
    Column({ space: 4 }) {
      Row() {
        Row()
          .width(`${this.progress * 100}%`)
          .height('100%')
          .borderRadius(this.barHeight / 2)
          .backgroundColor(this.getProgressColor())
      }
      .width('100%')
      .height(this.barHeight)
      .borderRadius(this.barHeight / 2)
      .backgroundColor($r('app.color.progress_background'))

      if (this.showLabel) {
        Text(`${(this.progress * 100).toFixed(1)}%`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.End)
      }
    }
  }

  private getProgressColor(): Resource {
    if (this.progress >= 1.0) {
      return $r('app.color.progress_complete');
    }
    return $r('app.color.progress_active');
  }
}
