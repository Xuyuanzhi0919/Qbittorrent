import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { AppConstants } from '../common/constants/AppConstants';
import { ServerConfig } from '../model/ServerConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class PreferencesStore {
  private prefs: preferences.Preferences | null = null;
  private static instance: PreferencesStore | null = null;
  private initPromise: Promise<void> | null = null;
  private initStarted: boolean = false;

  static getInstance(): PreferencesStore {
    if (PreferencesStore.instance === null) {
      PreferencesStore.instance = new PreferencesStore();
    }
    return PreferencesStore.instance;
  }

  async init(context: Context): Promise<void> {
    if (this.initPromise !== null) {
      return this.initPromise;
    }
    this.initStarted = true;
    this.initPromise = this.doInit(context);
    return this.initPromise;
  }

  private async doInit(context: Context): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, AppConstants.PREFS_NAME);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'PreferencesStore initialized');
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to init PreferencesStore: ${JSON.stringify(err)}`);
    }
  }

  async waitForInit(): Promise<void> {
    // 等待 init() 被调用
    let retryCount: number = 0;
    while (!this.initStarted && retryCount < 50) {
      await new Promise<void>(resolve => setTimeout(resolve, 100));
      retryCount++;
    }
    if (!this.initStarted) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'waitForInit timeout: init() was never called');
      return;
    }
    // 等待 init 完成
    if (this.initPromise !== null) {
      await this.initPromise;
    }
  }

  async saveServerConfig(config: ServerConfig, includePassword: boolean = true): Promise<void> {
    await this.waitForInit();
    if (this.prefs === null) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'saveServerConfig: prefs is null');
      return;
    }
    try {
      const json: Record<string, Object> = config.toJson();
      // 如果不需要保存密码，则清空密码字段
      if (!includePassword) {
        json['password'] = '';
      }
      const jsonStr: string = JSON.stringify(json);
      await this.prefs.put('server_config', jsonStr);
      await this.prefs.flush();
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Server config saved, includePassword=${includePassword}, password length=${includePassword ? config.password.length : 0}`);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Saved config: ${jsonStr.substring(0, 200)}`);
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to save server config: ${JSON.stringify(err)}`);
    }
  }

  async loadServerConfig(): Promise<ServerConfig | null> {
    await this.waitForInit();
    if (this.prefs === null) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'loadServerConfig: prefs is null');
      return null;
    }
    try {
      const jsonStr: string = await this.prefs.get('server_config', '') as string;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Loaded config string: ${jsonStr.substring(0, 200)}`);
      if (jsonStr.length === 0) {
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'No saved server config found');
        return null;
      }
      const parsed: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>;
      const config: ServerConfig = ServerConfig.fromJson(parsed);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `Server config loaded: url=${config.url}, username=${config.username}, password length=${config.password.length}`);
      return config;
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to load server config: ${JSON.stringify(err)}`);
      return null;
    }
  }

  async clearServerConfig(): Promise<void> {
    await this.waitForInit();
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.delete('server_config');
      await this.prefs.flush();
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to clear server config: ${JSON.stringify(err)}`);
    }
  }

  async savePollingInterval(intervalMs: number): Promise<void> {
    await this.waitForInit();
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(AppConstants.KEY_POLLING_INTERVAL, intervalMs);
      await this.prefs.flush();
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to save polling interval: ${JSON.stringify(err)}`);
    }
  }

  async loadPollingInterval(): Promise<number> {
    await this.waitForInit();
    if (this.prefs === null) {
      return AppConstants.DEFAULT_POLLING_INTERVAL;
    }
    try {
      return await this.prefs.get(AppConstants.KEY_POLLING_INTERVAL, AppConstants.DEFAULT_POLLING_INTERVAL) as number;
    } catch (err) {
      return AppConstants.DEFAULT_POLLING_INTERVAL;
    }
  }

  async saveRememberPassword(remember: boolean): Promise<void> {
    await this.waitForInit();
    if (this.prefs === null) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'saveRememberPassword: prefs is null');
      return;
    }
    try {
      await this.prefs.put('remember_password', remember);
      await this.prefs.flush();
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `remember_password saved: ${remember}`);
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to save remember_password: ${JSON.stringify(err)}`);
    }
  }

  async loadRememberPassword(): Promise<boolean> {
    await this.waitForInit();
    if (this.prefs === null) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'loadRememberPassword: prefs is null');
      return true; // 默认记住密码
    }
    try {
      const value: boolean = await this.prefs.get('remember_password', true) as boolean;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `remember_password loaded: ${value}`);
      return value;
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Failed to load remember_password: ${JSON.stringify(err)}`);
      return true;
    }
  }
}
