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
  @StorageLink('guestMode') guestMode: boolean = false;
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State rememberPassword: boolean = true;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State heroVisible: boolean = false;
  @State formVisible: boolean = false;
  @State actionVisible: boolean = false;
  @State decorAnimated: boolean = false;
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

    setTimeout(() => {
      this.heroVisible = true;
    }, 0);
    setTimeout(() => {
      this.formVisible = true;
    }, 120);
    setTimeout(() => {
      this.actionVisible = true;
    }, 220);
    setTimeout(() => {
      this.decorAnimated = true;
    }, 0);
  }

  aboutToDisappear(): void {
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
      this.guestMode = false;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        'ServerConfigPage: connection successful');
      // 连接成功后返回主页
      this.pathStack.clear();
    } else {
      this.isConnected = this.connectionManager.isConnected;
      this.errorMessage = result.error || '连接失败';
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `ServerConfigPage: connection failed: ${this.errorMessage}`);
    }
  }

  private enterDemoMode(): void {
    this.errorMessage = '';
    this.isConnected = false;
    this.guestMode = true;
    AppStorage.setOrCreate('currentTabIndex', 0);
  }

  build() {
    NavDestination() {
      Stack() {
        Circle()
          .width(260)
          .height(260)
          .fill($r('app.color.login_decor_primary'))
          .opacity(this.decorAnimated ? 0.95 : 0.78)
          .position({ x: 248, y: -72 })
          .translate({
            x: this.decorAnimated ? -12 : 0,
            y: this.decorAnimated ? 18 : 0
          })
          .scale({
            x: this.decorAnimated ? 1.06 : 1,
            y: this.decorAnimated ? 1.06 : 1
          })
          .animation({
            duration: 3600,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate
          })

        Circle()
          .width(220)
          .height(220)
          .fill($r('app.color.login_decor_secondary'))
          .opacity(this.decorAnimated ? 0.74 : 0.58)
          .position({ x: -64, y: 620 })
          .translate({
            x: this.decorAnimated ? 14 : 0,
            y: this.decorAnimated ? -12 : 0
          })
          .scale({
            x: this.decorAnimated ? 1.04 : 1,
            y: this.decorAnimated ? 1.04 : 1
          })
          .animation({
            duration: 4200,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate
          })

        Circle()
          .width(120)
          .height(120)
          .fill($r('app.color.login_decor_tertiary'))
          .opacity(this.decorAnimated ? 0.98 : 0.88)
          .position({ x: 36, y: 118 })
          .translate({
            x: this.decorAnimated ? 10 : 0,
            y: this.decorAnimated ? 8 : 0
          })
          .scale({
            x: this.decorAnimated ? 1.08 : 1,
            y: this.decorAnimated ? 1.08 : 1
          })
          .animation({
            duration: 3000,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate
          })

        Column({ space: 24 }) {
          Column({ space: 8 }) {
            Text('连接 TorrentPilot')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text('输入服务器信息后开始远程管理。')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .opacity(this.heroVisible ? 1 : 0)
          .translate({ y: this.heroVisible ? 0 : 18 })
          .animation({
            duration: 450,
            curve: Curve.EaseOut
          })

          Column({ space: 14 }) {
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
                .backgroundColor($r('app.color.login_input_background'))
                .border({
                  width: 1,
                  color: $r('app.color.login_input_border')
                })
                .borderRadius(16)
                .height(54)
                .padding({ left: 16, right: 16 })
                .onChange((value: string) => {
                  this.serverUrl = value;
                  this.errorMessage = '';
                })
            }

            Column({ space: 6 }) {
              Text('用户名')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
              TextInput({ placeholder: 'admin', text: this.username })
                .type(InputType.USER_NAME)
                .placeholderColor($r('app.color.text_hint'))
                .fontColor($r('app.color.text_primary'))
                .caretColor($r('app.color.accent_color'))
                .backgroundColor($r('app.color.login_input_background'))
                .border({
                  width: 1,
                  color: $r('app.color.login_input_border')
                })
                .borderRadius(16)
                .height(54)
                .padding({ left: 16, right: 16 })
                .maxLength(128)
                .onChange((value: string) => {
                  this.username = value;
                  this.errorMessage = '';
                })
            }

            Column({ space: 6 }) {
              Text('密码')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
              TextInput({ placeholder: '输入密码', text: this.password })
                .type(InputType.Password)
                .showPasswordIcon(true)
                .placeholderColor($r('app.color.text_hint'))
                .fontColor($r('app.color.text_primary'))
                .caretColor($r('app.color.accent_color'))
                .backgroundColor($r('app.color.login_input_background'))
                .border({
                  width: 1,
                  color: $r('app.color.login_input_border')
                })
                .borderRadius(16)
                .height(54)
                .padding({ left: 16, right: 16 })
                .maxLength(256)
                .onChange((value: string) => {
                  this.password = value;
                  this.errorMessage = '';
                })
            }

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
            .padding({ top: 2, bottom: 2 })

            if (this.errorMessage.length > 0) {
              Row({ space: 6 }) {
                Circle()
                  .width(8)
                  .height(8)
                  .fill($r('app.color.error_color'))
                Text(this.errorMessage)
                  .fontSize(13)
                  .fontColor($r('app.color.error_color'))
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .backgroundColor($r('app.color.login_error_background'))
              .borderRadius(14)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 18, bottom: 18 })
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(24)
          .shadow({
            radius: 24,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 12
          })
          .opacity(this.formVisible ? 1 : 0)
          .translate({ y: this.formVisible ? 0 : 28 })
          .scale({
            x: this.formVisible ? 1 : 0.97,
            y: this.formVisible ? 1 : 0.97
          })
          .animation({
            duration: 500,
            curve: Curve.EaseOut
          })

          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Button(this.isLoading ? '正在连接...' : '连接服务器')
                .layoutWeight(1)
                .height(56)
                .backgroundColor($r('app.color.accent_color'))
                .borderRadius(18)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .enabled(!this.isLoading)
                .opacity(this.isLoading ? 0.6 : 1)
                .onClick(() => {
                  this.handleConnect();
                })

              Button('示例体验')
                .layoutWeight(1)
                .height(56)
                .backgroundColor($r('app.color.login_secondary_button_bg'))
                .borderRadius(18)
                .border({
                  width: 1,
                  color: $r('app.color.login_secondary_button_border')
                })
                .fontSize(16)
                .fontColor($r('app.color.accent_color'))
                .enabled(!this.isLoading)
                .opacity(this.isLoading ? 0.6 : 1)
                .onClick(() => {
                  this.enterDemoMode();
                })
            }
            .width('100%')

            Column({ space: 8 }) {
              Text('支持保存连接信息，也可以先浏览示例界面。')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)

              Text('示例体验为只读浏览，不会连接真实服务器')
                .fontSize(12)
                .fontColor($r('app.color.text_hint'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .opacity(this.actionVisible ? 1 : 0)
          .translate({ y: this.actionVisible ? 0 : 20 })
          .animation({
            duration: 520,
            curve: Curve.EaseOut
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 48, bottom: 40 })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      // 已连接状态下也可以编辑配置，不再自动跳转到 Dashboard
    })
  }
}
