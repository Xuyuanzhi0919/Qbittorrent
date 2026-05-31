import { QbittorrentService } from '../service/QbittorrentService';
import { AppService } from './Index';
import pasteboard from '@ohos.pasteboard';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../common/constants/AppConstants';
import { PreferencesStore } from '../store/PreferencesStore';

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
  @State selectedFilePath: string = '';
  @State selectedFileName: string = '';
  private pathStack: NavPathStack = new NavPathStack();
  private store: PreferencesStore = PreferencesStore.getInstance();

  async aboutToAppear(): Promise<void> {
    this.savePath = await this.store.loadLastDownloadPath();
  }

  aboutToDisappear(): void {
  }

  private notifyDownloadListUpdated(): void {
    const currentRefreshValue: Object | undefined = AppStorage.get('torrentListRefreshToken');
    const currentRefreshToken: number = typeof currentRefreshValue === 'number' ? currentRefreshValue : 0;
    AppStorage.setOrCreate('torrentListRefreshToken', currentRefreshToken + 1);

    const currentScrollValue: Object | undefined = AppStorage.get('downloadTabScrollToTopToken');
    const currentScrollToken: number = typeof currentScrollValue === 'number' ? currentScrollValue : 0;
    AppStorage.setOrCreate('downloadTabScrollToTopToken', currentScrollToken + 1);
    AppStorage.setOrCreate('currentTabIndex', 1);
  }

  private async handleAdd(): Promise<void> {
    const hasFile: boolean = this.selectedFilePath.length > 0;
    const hasUrl: boolean = this.torrentUrl.trim().length > 0;

    if (!hasFile && !hasUrl) {
      this.resultMessage = '请输入磁力链接/种子 URL 或选择 .torrent 文件';
      this.isSuccess = false;
      return;
    }

    this.isAdding = true;
    this.resultMessage = '';

    const savePathOpt: string | undefined = this.savePath.trim().length > 0 ? this.savePath.trim() : undefined;
    const categoryOpt: string | undefined = this.category.trim().length > 0 ? this.category.trim() : undefined;
    const tagsOpt: string | undefined = this.tags.trim().length > 0 ? this.tags.trim() : undefined;

    let success: boolean;
    if (hasFile) {
      success = await this.service.addTorrentFile(
        this.selectedFilePath, this.selectedFileName,
        savePathOpt, categoryOpt, tagsOpt, this.startPaused
      );
    } else {
      success = await this.service.addTorrent(
        this.torrentUrl.trim(), savePathOpt, categoryOpt, tagsOpt, this.startPaused
      );
    }

    this.isAdding = false;
    if (success) {
      if (savePathOpt !== undefined) {
        await this.store.saveLastDownloadPath(savePathOpt);
      }
      this.resultMessage = '任务已添加';
      this.isSuccess = true;
      this.notifyDownloadListUpdated();
      setTimeout(() => {
        this.pathStack.pop();
      }, 1000);
    } else {
      this.resultMessage = hasFile ? '文件添加失败，请检查服务器连接' : '添加失败，请检查链接是否有效';
      this.isSuccess = false;
    }
  }

  private async fillFromClipboard(): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = await systemPasteboard.getPasteData();
      let clipboardText: string = '';
      const recordCount: number = pasteData.getRecordCount();
      let index: number = 0;
      while (index < recordCount) {
        const record = pasteData.getRecord(index);
        const plainText = record.plainText;
        if (typeof plainText === 'string' && plainText.length > 0) {
          clipboardText = plainText;
          break;
        }
        index += 1;
      }
      if (clipboardText.length === 0) {
        this.resultMessage = '剪贴板没有可用的文本内容';
        this.isSuccess = false;
        return;
      }
      this.torrentUrl = clipboardText;
      this.resultMessage = '已从剪贴板导入';
      this.isSuccess = true;
    } catch (_err) {
      this.resultMessage = '读取剪贴板失败';
      this.isSuccess = false;
    }
  }

  private clearForm(): void {
    this.torrentUrl = '';
    this.category = '';
    this.tags = '';
    this.startPaused = false;
    this.resultMessage = '';
    this.selectedFilePath = '';
    this.selectedFileName = '';
  }

  private async pickTorrentFile(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker(getContext(this));
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      const uris: string[] = await docPicker.select(selectOptions);
      if (!uris || uris.length === 0) {
        return;
      }
      const sourceUri: string = uris[0];
      const parts: string[] = sourceUri.split('/');
      const rawName: string = parts[parts.length - 1] || 'upload.torrent';
      const fileName: string = rawName.includes('.torrent') ? rawName : rawName + '.torrent';
      const cacheDir: string = getContext(this).cacheDir;
      const destPath: string = `${cacheDir}/torrent_upload.torrent`;
      const srcFile: fs.File = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      const dstFile: fs.File = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.copyFileSync(srcFile.fd, dstFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);
      this.selectedFilePath = destPath;
      this.selectedFileName = fileName;
      this.torrentUrl = '';
      this.resultMessage = `已选择: ${fileName}`;
      this.isSuccess = true;
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `File picker error: ${JSON.stringify(err)}`);
      this.resultMessage = '选择文件失败';
      this.isSuccess = false;
    }
  }

  private getServerSummaryText(): string {
    const config = AppService.getConnectionManager().serverConfig;
    if (config === null) {
      return '未连接服务器';
    }
    return `${config.url} · ${config.username}`;
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Circle()
          .width(220)
          .height(220)
          .fill($r('app.color.dashboard_decor_primary'))
          .opacity(0.92)
          .position({ x: 246, y: -72 })

        Circle()
          .width(168)
          .height(168)
          .fill($r('app.color.dashboard_decor_secondary'))
          .opacity(0.98)
          .position({ x: -54, y: 118 })

        Scroll() {
          Column({ space: 10 }) {
            if (this.resultMessage.length > 0) {
              this.resultBanner()
            }
            this.headerSection()
            this.serverSummaryBar()
            this.sourceCard()
            this.locationCard()
            this.startupCard()
            Blank()
              .height(92)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 62, bottom: 0 })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_background'))

        this.bottomActionBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  private resultBanner() {
    Row() {
      Text(this.resultMessage)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isSuccess ? $r('app.color.success_color') : $r('app.color.error_color'))

      Blank()

      Text('关闭')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .onClick(() => {
          this.resultMessage = '';
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.isSuccess ? $r('app.color.dashboard_surface_success') : $r('app.color.dashboard_surface_danger'))
    .border({
      width: 1,
      color: this.isSuccess ? $r('app.color.success_color') : $r('app.color.error_color')
    })
    .borderRadius(16)
  }

  @Builder
  private headerSection() {
    Column({ space: 4 }) {
      Text('DOWNLOAD CENTER')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(1)
        .fontColor($r('app.color.text_secondary'))

      Text('添加种子')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private serverSummaryBar() {
    Row() {
      Column({ space: 4 }) {
        Text('添加目标服务器')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))

        Text(this.getServerSummaryText())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('已连接')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.success_color'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.dashboard_surface_success'))
          .borderRadius(999)

        Text('准备提交')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_color'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(20)
  }

  @Builder
  private sourceCard() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text('磁力链接 / 种子来源')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('粘贴链接或选择本地 .torrent 文件')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.selectedFileName.length > 0) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('已选择文件')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
            Text(this.selectedFileName)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('清除')
            .fontSize(12)
            .fontColor($r('app.color.error_color'))
            .onClick(() => {
              this.selectedFilePath = '';
              this.selectedFileName = '';
              this.resultMessage = '';
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.dashboard_surface_success'))
        .borderRadius(16)
      } else {
        Column({ space: 6 }) {
          Text('磁力链接 / 种子 URL')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          TextArea({ placeholder: 'magnet:?xt=urn:btih:...', text: this.torrentUrl })
            .height(108)
            .placeholderColor($r('app.color.tab_inactive_fg'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .borderRadius(18)
            .padding(12)
            .onChange((value: string) => {
              this.torrentUrl = value;
              this.resultMessage = '';
            })
        }
        .width('100%')
      }

      Row({ space: 8 }) {
        Row() {
          Text('从剪贴板导入')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_color'))
        }
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(16)
        .onClick(() => {
          this.selectedFilePath = '';
          this.selectedFileName = '';
          this.fillFromClipboard();
        })

        Row() {
          Text('选择文件')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_color'))
        }
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(16)
        .onClick(() => {
          this.pickTorrentFile();
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(20)
  }

  @Builder
  private locationCard() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text('存储与归类')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('可选设置，用于整理下载任务')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        Column({ space: 4 }) {
          Text('保存路径')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))

          TextInput({
            placeholder: '使用服务器默认路径',
            text: this.savePath
          })
            .height(40)
            .placeholderColor($r('app.color.tab_inactive_fg'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .borderRadius(12)
            .padding({ left: 0, right: 0 })
            .onChange((value: string) => {
              this.savePath = value;
              this.store.saveLastDownloadPath(value.trim());
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('选择')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_color'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(16)
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text('分类')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          TextInput({ placeholder: 'movie', text: this.category })
            .height(40)
            .placeholderColor($r('app.color.tab_inactive_fg'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .borderRadius(12)
            .padding({ left: 0, right: 0 })
            .onChange((value: string) => {
              this.category = value;
            })
        }
        .layoutWeight(1)
        .padding({ left: 10, right: 10, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('标签')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          TextInput({ placeholder: '4K, 收藏', text: this.tags })
            .height(40)
            .placeholderColor($r('app.color.tab_inactive_fg'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .borderRadius(12)
            .padding({ left: 0, right: 0 })
            .onChange((value: string) => {
              this.tags = value;
            })
        }
        .layoutWeight(1)
        .padding({ left: 10, right: 10, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(20)
  }

  @Builder
  private startupCard() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text('启动策略')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('决定添加后是否立即开始下载')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        Column({ space: 4 }) {
          Text('添加后暂停')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('适合先检查分类和保存路径')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Toggle({ type: ToggleType.Switch, isOn: this.startPaused })
          .selectedColor($r('app.color.accent_color'))
          .onChange((isOn: boolean) => {
            this.startPaused = isOn;
          })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.dashboard_surface_soft'))
    .borderRadius(16)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(20)
  }

  @Builder
  private bottomActionBar() {
    Row({ space: 8 }) {
      Button('清空表单')
        .layoutWeight(1)
        .height(48)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.card_background'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border')
        })
        .borderRadius(16)
        .onClick(() => {
          this.clearForm();
        })

      Button(this.isAdding ? '添加中...' : '添加任务')
        .layoutWeight(1)
        .height(48)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.dashboard_primary_action_fg'))
        .backgroundColor($r('app.color.dashboard_primary_action_bg'))
        .borderRadius(16)
        .enabled(!this.isAdding)
        .onClick(() => {
          this.handleAdd();
        })
    }
    .width('100%')
    .padding({ left: 21, right: 21, top: 10, bottom: 22 })
    .backgroundColor($r('app.color.page_background'))
  }
}
