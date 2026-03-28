import { ConnectionManager } from '../service/ConnectionManager';
import { AppConstants } from '../common/constants/AppConstants';
import { AppService } from './Index';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PreferencesStore } from '../store/PreferencesStore';

@Component
export struct ServerConfigPage {
  private connectionManager: ConnectionManager = AppService.getConnectionManager();
  private store: PreferencesStore = PreferencesStore.getInstance();
  @StorageLink('isConnected') isConnected: boolean = false;
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State rememberPassword: boolean = true;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  private pathStack: NavPathStack = new NavPathStack();

  async aboutToAppear(): Promise<void> {
    // 先加载记住密码设置
    this.rememberPassword = await this.store.loadRememberPassword();
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `ServerConfigPage: rememberPassword=${this.rememberPassword}`);

    const config = this.connectionManager.serverConfig;
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `ServerConfigPage: config=${config ? 'not null' : 'null'}`);
    if (config !== null) {
      this.serverUrl = config.url;
      this.username = config.username;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `ServerConfigPage: url=${config.url}, username=${config.username}, password length=${config.password.length}`);
      // 只有在用户之前选择了记住密码时才填充密码
      if (this.rememberPassword) {
        this.password = config.password;
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `ServerConfigPage: password loaded, length=${this.password.length}`);
      } else {
        this.password = '';
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'ServerConfigPage: password not loaded (rememberPassword=false)');
      }
    }
  }

  private async handleConnect(): Promise<void> {
    if (this.serverUrl.trim().length === 0) {
      this.errorMessage = '请输入服务器地址';
      return;
    }
    if (this.username.trim().length === 0) {
      this.errorMessage = '请输入用户名';
      return;
    }
    // 长度校验
    if (this.username.trim().length > 128) {
      this.errorMessage = '用户名不能超过128个字符';
      return;
    }
    if (this.password.length > 256) {
      this.errorMessage = '密码不能超过256个字符';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
      `ServerConfigPage: connecting with rememberPassword=${this.rememberPassword}`);

    const result = await this.connectionManager.connect(
      this.serverUrl.trim(),
      this.username.trim(),
      this.password,
      this.rememberPassword
    );
    this.isLoading = false;

    if (result.success) {
      this.isConnected = true;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        'ServerConfigPage: connection successful, navigating to Dashboard');
      // 关键：登录成功后触发页面跳转
      this.pathStack.replacePath({ name: 'Dashboard' });
    } else {
      this.errorMessage = result.error || '连接失败';
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `ServerConfigPage: connection failed: ${this.errorMessage}`);
    }
  }

  build() {
    NavDestination() {
      Column() {
        Blank().layoutWeight(1)

        // Brand
        Column({ space: 8 }) {
          Stack() {
            Circle()
              .width(72)
              .height(72)
              .fill($r('app.color.accent_color'))
            Text('qB')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .margin({ bottom: 12 })

          Text('qBittorrent')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .letterSpacing(1)

          Text('远程管理客户端')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 40 })

        // Form card
        Column({ space: 20 }) {
          // Server URL
          Column({ space: 6 }) {
            Text('服务器地址')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            TextInput({ placeholder: 'http://192.168.1.x:8080', text: this.serverUrl })
              .type(InputType.URL)
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .caretColor($r('app.color.accent_color'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(10)
              .height(46)
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.serverUrl = value;
                this.errorMessage = '';
              })
          }

          // Username
          Column({ space: 6 }) {
            Text('用户名')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            TextInput({ placeholder: 'admin', text: this.username })
              .type(InputType.USER_NAME)  // 关键属性：用户名类型
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .caretColor($r('app.color.accent_color'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(10)
              .height(46)
              .padding({ left: 14, right: 14 })
              .maxLength(128)  // 长度限制
              .onChange((value: string) => {
                this.username = value;
                this.errorMessage = '';
              })
          }

          // Password
          Column({ space: 6 }) {
            Text('密码')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            TextInput({ placeholder: '输入密码', text: this.password })
              .type(InputType.Password)  // 关键属性：密码类型
              .showPasswordIcon(true)    // 关键属性：显示密码图标
              .placeholderColor($r('app.color.text_hint'))
              .fontColor($r('app.color.text_primary'))
              .caretColor($r('app.color.accent_color'))
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(10)
              .height(46)
              .padding({ left: 14, right: 14 })
              .maxLength(256)  // 长度限制
              .onChange((value: string) => {
                this.password = value;
                this.errorMessage = '';
              })
          }

          // Remember password toggle
          Row() {
            Text('记住密码')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.rememberPassword })
              .onChange((isOn: boolean) => {
                this.rememberPassword = isOn;
              })
              .selectedColor($r('app.color.accent_color'))
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })

          // Error
          if (this.errorMessage.length > 0) {
            Row({ space: 6 }) {
              Text('!')
                .fontSize(11)
                .fontColor('#FFFFFF')
                .width(16)
                .height(16)
                .borderRadius(8)
                .backgroundColor($r('app.color.error_color'))
                .textAlign(TextAlign.Center)
                .fontWeight(FontWeight.Bold)
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor($r('app.color.error_color'))
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 4, top: 4, bottom: 4 })
          }

          // Connect button
          Button(this.isLoading ? '正在连接...' : '连接服务器')
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.accent_color'))
            .borderRadius(10)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .enabled(!this.isLoading)
            .opacity(this.isLoading ? 0.6 : 1)
            .margin({ top: 4 })
            .onClick(() => {
              this.handleConnect();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 28, bottom: 28 })
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(20)

        Blank().layoutWeight(1)

        Text('请确保 qBittorrent Web UI 已启用')
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
          .margin({ bottom: 40 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20 })
      .backgroundColor($r('app.color.page_background'))
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      if (this.connectionManager.isConnected) {
        this.pathStack.replacePath({ name: 'Dashboard' });
      }
    })
  }
}
