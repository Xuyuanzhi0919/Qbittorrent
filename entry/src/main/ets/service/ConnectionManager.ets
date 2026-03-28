import { QbittorrentApi } from '../network/QbittorrentApi';
import { PreferencesStore } from '../store/PreferencesStore';
import { ServerConfig } from '../model/ServerConfig';
import { ApiResult } from '../model/ApiResult';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../common/constants/AppConstants';

export class ConnectionManager {
  private api: QbittorrentApi = new QbittorrentApi();
  private store: PreferencesStore = PreferencesStore.getInstance();
  private currentConfig: ServerConfig | null = null;
  private _isConnected: boolean = false;

  get isConnected(): boolean {
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `ConnectionManager.isConnected getter called, returning: ${this._isConnected}`);
    return this._isConnected;
  }

  get serverConfig(): ServerConfig | null {
    return this.currentConfig;
  }

  async loadSavedConfig(): Promise<boolean> {
    const config: ServerConfig | null = await this.store.loadServerConfig();
    if (config !== null && config.isValid()) {
      this.currentConfig = config;
      return true;
    }
    return false;
  }

  async connect(url: string, username: string, password: string, rememberPassword: boolean = true): Promise<ApiResult<string>> {
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Connecting to ${url}`);
    const result: ApiResult<string> = await this.api.login(url, username, password);
    if (result.success) {
      this._isConnected = true;
      // 当前会话配置（内存中保存完整密码用于API调用）
      const config: ServerConfig = new ServerConfig(url, username, password);
      this.currentConfig = config;
      // 根据用户选择决定持久化保存的内容
      await this.store.saveServerConfig(config, rememberPassword);
      await this.store.saveRememberPassword(rememberPassword);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Connected successfully, rememberPassword=${rememberPassword}`);
    } else {
      this._isConnected = false;
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Connection failed: ${result.error}`);
    }
    return result;
  }

  async autoReconnect(): Promise<boolean> {
    if (this.currentConfig === null) {
      return false;
    }
    const config: ServerConfig = this.currentConfig as ServerConfig;
    if (config.password.length === 0) {
      return false;
    }
    const result: ApiResult<string> = await this.api.login(config.url, config.username, config.password);
    if (result.success) {
      this._isConnected = true;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Auto-reconnect successful');
      return true;
    }
    this._isConnected = false;
    hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Auto-reconnect failed');
    return false;
  }

  async disconnect(): Promise<void> {
    await this.api.logout();
    this._isConnected = false;
    this.currentConfig = null;
    await this.store.clearServerConfig();
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Disconnected');
  }

  getApi(): QbittorrentApi {
    return this.api;
  }
}
