import { QbittorrentService } from '../service/QbittorrentService';
import { AppService } from './Index';

@Component
export struct AddTorrentPage {
  private service: QbittorrentService = AppService.getService();
  @State torrentUrl: string = '';
  @State savePath: string = '';
  @State category: string = '';
  @State tags: string = '';
  @State startPaused: boolean = false;
  @State isAdding: boolean = false;
  @State resultMessage: string = '';
  @State isSuccess: boolean = false;
  private pathStack: NavPathStack = new NavPathStack();

  private async handleAdd(): Promise<void> {
    if (this.torrentUrl.trim().length === 0) {
      this.resultMessage = '请输入磁力链接或种子 URL';
      this.isSuccess = false;
      return;
    }

    this.isAdding = true;
    this.resultMessage = '';

    const success: boolean = await this.service.addTorrent(
      this.torrentUrl.trim(),
      this.savePath.trim().length > 0 ? this.savePath.trim() : undefined,
      this.category.trim().length > 0 ? this.category.trim() : undefined,
      this.tags.trim().length > 0 ? this.tags.trim() : undefined,
      this.startPaused
    );

    this.isAdding = false;
    if (success) {
      this.resultMessage = '添加成功';
      this.isSuccess = true;
      setTimeout(() => {
        this.pathStack.pop();
      }, 1000);
    } else {
      this.resultMessage = '添加失败，请检查链接是否有效';
      this.isSuccess = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // URL/Magnet input
          Column({ space: 8 }) {
            Text('磁力链接 / 种子 URL')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Medium)
            TextArea({ placeholder: '输入磁力链接或种子文件 URL', text: this.torrentUrl })
              .height(100)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .onChange((value: string) => {
                this.torrentUrl = value;
              })
          }
          .width('100%')

          // Save path (optional)
          Column({ space: 8 }) {
            Text('保存路径（可选）')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '使用服务器默认路径', text: this.savePath })
              .height(48)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .onChange((value: string) => {
                this.savePath = value;
              })
          }
          .width('100%')

          // Category (optional)
          Column({ space: 8 }) {
            Text('分类（可选）')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '输入分类名称', text: this.category })
              .height(48)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .onChange((value: string) => {
                this.category = value;
              })
          }
          .width('100%')

          // Tags (optional)
          Column({ space: 8 }) {
            Text('标签（可选）')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '输入标签，逗号分隔', text: this.tags })
              .height(48)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)
              .onChange((value: string) => {
                this.tags = value;
              })
          }
          .width('100%')

          // Start paused toggle
          Row() {
            Text('添加后暂停')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.startPaused })
              .onChange((isOn: boolean) => {
                this.startPaused = isOn;
              })
              .selectedColor($r('app.color.accent_color'))
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .height(52)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)

          // Result message
          if (this.resultMessage.length > 0) {
            Text(this.resultMessage)
              .fontSize(14)
              .fontColor(this.isSuccess ? $r('app.color.download_color') : $r('app.color.error_color'))
              .width('100%')
              .textAlign(TextAlign.Center)
          }

          // Add button
          Button(this.isAdding ? '添加中...' : '添加')
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.button_primary'))
            .borderRadius(12)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .enabled(!this.isAdding)
            .onClick(() => {
              this.handleAdd();
            })
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .scrollBar(BarState.Off)
    }
    .title('添加种子')
    .backgroundColor($r('app.color.page_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
