import { QbittorrentApi } from '../network/QbittorrentApi';
import { PreferencesStore } from '../store/PreferencesStore';
import { ServerConfig } from '../model/ServerConfig';
import { ApiResult } from '../model/ApiResult';
import { LogUtil } from '@pura/harmony-utils';

export class ConnectionManager {
  private api: QbittorrentApi = new QbittorrentApi();
  private store: PreferencesStore = PreferencesStore.getInstance();
  private currentConfig: ServerConfig | null = null;
  private _isConnected: boolean = false;

  get isConnected(): boolean {
    LogUtil.info('ConnectionManager.isConnected getter called, returning: ' + this._isConnected);
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

  async connect(url: string, username: string, password: string, rememberPassword: boolean = true, apiKey: string = ''): Promise<ApiResult<string>> {
    LogUtil.info('Connecting to ' + url);
    if (this._isConnected) {
      const validationApi: QbittorrentApi = new QbittorrentApi(false);
      const validationResult: ApiResult<string> = await validationApi.login(url, username, password, apiKey);
      if (!validationResult.success) {
        LogUtil.error('Connection validation failed: ' + validationResult.error);
        return validationResult;
      }
      await validationApi.logout();
      await this.api.logout();
      this._isConnected = false;
      this.currentConfig = null;
    }
    const result: ApiResult<string> = await this.api.login(url, username, password, apiKey);
    if (result.success) {
      await this.api.getWebApiVersion();
      this._isConnected = true;
      // 当前会话配置（内存中保存完整密码用于API调用）
      const config: ServerConfig = new ServerConfig(url, username, password, apiKey);
      this.currentConfig = config;
      // 根据用户选择决定持久化保存的内容
      await this.store.saveServerConfig(config, rememberPassword);
      await this.store.saveRememberPassword(rememberPassword);
      LogUtil.info('Connected successfully, rememberPassword=' + rememberPassword);
    } else {
      this._isConnected = false;
      this.currentConfig = null;
      LogUtil.error('Connection failed: ' + result.error);
    }
    return result;
  }

  async autoReconnect(): Promise<boolean> {
    if (this.currentConfig === null) {
      return false;
    }
    const config: ServerConfig = this.currentConfig as ServerConfig;
    if (config.password.length === 0 && config.apiKey.length === 0) {
      return false;
    }
    const result: ApiResult<string> = await this.api.login(config.url, config.username, config.password, config.apiKey);
    if (result.success) {
      await this.api.getWebApiVersion();
      this._isConnected = true;
      LogUtil.info('Auto-reconnect successful');
      return true;
    }
    this._isConnected = false;
    LogUtil.error('Auto-reconnect failed');
    return false;
  }

  async disconnect(): Promise<void> {
    await this.api.logout();
    this._isConnected = false;
    this.currentConfig = null;
    // 断开连接时不清除保存的配置，用户下次可以直接重连
    LogUtil.info('Disconnected (config preserved)');
  }

  async disconnectAndClear(): Promise<void> {
    await this.api.logout();
    this._isConnected = false;
    this.currentConfig = null;
    await this.store.clearServerConfig();
    LogUtil.info('Disconnected and config cleared');
  }

  getApi(): QbittorrentApi {
    return this.api;
  }
}
