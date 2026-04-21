import { ConnectionManager } from './ConnectionManager';
import { TransferInfo } from '../model/TransferInfo';
import { TorrentInfo } from '../model/TorrentInfo';
import { TorrentFile } from '../model/TorrentFile';
import { TorrentTracker } from '../model/TorrentTracker';
import { TorrentPeer } from '../model/TorrentPeer';
import { TorrentProperties } from '../model/TorrentProperties';
import { TorrentPeersSync } from '../model/TorrentPeersSync';
import { ApiResult } from '../model/ApiResult';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../common/constants/AppConstants';

export class TorrentFilter {
  static readonly ALL: string = 'all';
  static readonly DOWNLOADING: string = 'downloading';
  static readonly COMPLETED: string = 'completed';
  static readonly PAUSED: string = 'paused';
  static readonly ACTIVE: string = 'active';
  static readonly INACTIVE: string = 'inactive';
}

export class QbittorrentService {
  private connectionManager: ConnectionManager;
  private pollingTimer: number = -1;

  constructor(connectionManager: ConnectionManager) {
    this.connectionManager = connectionManager;
  }

  private getApi() {
    return this.connectionManager.getApi();
  }

  async fetchTransferInfo(): Promise<TransferInfo | null> {
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
      `QbittorrentService.fetchTransferInfo: isConnected=${this.connectionManager.isConnected}`);
    if (!this.connectionManager.isConnected) {
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'QbittorrentService.fetchTransferInfo: not connected, returning null');
      return null;
    }
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'QbittorrentService.fetchTransferInfo: calling API...');
    const result: ApiResult<TransferInfo> = await this.getApi().getTransferInfo();
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
      `QbittorrentService.fetchTransferInfo: API result success=${result.success}, error=${result.error || 'none'}`);
    if (result.success) {
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `QbittorrentService.fetchTransferInfo: data dl_speed=${result.data?.dl_info_speed}, up_speed=${result.data?.up_info_speed}`);
      return result.data;
    }
    hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `fetchTransferInfo failed: ${result.error}`);
    return null;
  }

  async fetchTorrentList(filter?: string, sort?: string, hashes?: string): Promise<TorrentInfo[]> {
    if (!this.connectionManager.isConnected) {
      return [];
    }
    const result: ApiResult<TorrentInfo[]> = await this.getApi().getTorrentList(filter, sort, undefined, hashes);
    if (result.success) {
      return result.data as TorrentInfo[];
    }
    hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `fetchTorrentList failed: ${result.error}`);
    return [];
  }

  async fetchTorrent(hash: string): Promise<TorrentInfo | null> {
    const torrents: TorrentInfo[] = await this.fetchTorrentList(undefined, undefined, hash);
    if (torrents.length > 0) {
      return torrents[0];
    }
    return null;
  }

  async fetchTorrentProperties(hash: string): Promise<TorrentProperties | null> {
    if (!this.connectionManager.isConnected) {
      return null;
    }
    const result: ApiResult<TorrentProperties> = await this.getApi().getTorrentProperties(hash);
    if (result.success) {
      return result.data;
    }
    return null;
  }

  async fetchTorrentFiles(hash: string): Promise<TorrentFile[]> {
    if (!this.connectionManager.isConnected) {
      return [];
    }
    const result: ApiResult<TorrentFile[]> = await this.getApi().getTorrentFiles(hash);
    if (result.success) {
      return result.data as TorrentFile[];
    }
    return [];
  }

  async fetchTorrentTrackers(hash: string): Promise<TorrentTracker[]> {
    if (!this.connectionManager.isConnected) {
      return [];
    }
    const result: ApiResult<TorrentTracker[]> = await this.getApi().getTorrentTrackers(hash);
    if (result.success) {
      return result.data as TorrentTracker[];
    }
    return [];
  }

  async fetchTorrentPeers(hash: string, rid: number = 0): Promise<TorrentPeersSync | null> {
    if (!this.connectionManager.isConnected) {
      return null;
    }
    const result: ApiResult<TorrentPeersSync> = await this.getApi().getTorrentPeers(hash, rid);
    if (result.success) {
      return result.data;
    }
    return null;
  }

  async addTorrent(urls: string, savePath?: string, category?: string, tags?: string, paused?: boolean): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().addTorrent(urls, savePath, category, tags, paused);
    return result.success;
  }

  async pauseTorrents(hashes: string[]): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().pauseTorrents(hashes);
    return result.success;
  }

  async resumeTorrents(hashes: string[]): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().resumeTorrents(hashes);
    return result.success;
  }

  async reannounceTorrents(hashes: string[]): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().reannounceTorrents(hashes);
    return result.success;
  }

  async deleteTorrents(hashes: string[], deleteFiles: boolean): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().deleteTorrents(hashes, deleteFiles);
    return result.success;
  }

  async setGlobalDownloadLimit(limitBps: number): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().setGlobalDownloadLimit(limitBps);
    return result.success;
  }

  async setGlobalUploadLimit(limitBps: number): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().setGlobalUploadLimit(limitBps);
    return result.success;
  }

  async setFilePriority(hash: string, fileId: number, priority: number): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().setFilePriority(hash, fileId, priority);
    return result.success;
  }

  async setDownloadLimit(hash: string, limitBps: number): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().setDownloadLimit(hash, limitBps);
    return result.success;
  }

  async setUploadLimit(hash: string, limitBps: number): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().setUploadLimit(hash, limitBps);
    return result.success;
  }

  async addTorrentFile(filePath: string, fileName: string, savePath?: string, category?: string, tags?: string, paused?: boolean): Promise<boolean> {
    if (!this.connectionManager.isConnected) {
      return false;
    }
    const result: ApiResult<string> = await this.getApi().addTorrentFile(filePath, fileName, savePath, category, tags, paused);
    return result.success;
  }

  async getVersion(): Promise<string> {
    if (!this.connectionManager.isConnected) {
      return '';
    }
    const result: ApiResult<string> = await this.getApi().getVersion();
    if (result.success) {
      return result.data as string;
    }
    return '';
  }

  startPolling(intervalMs: number, callback: () => void): void {
    this.stopPolling();
    this.pollingTimer = setInterval(callback, intervalMs);
  }

  stopPolling(): void {
    if (this.pollingTimer !== -1) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = -1;
    }
  }
}
