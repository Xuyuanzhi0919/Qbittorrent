import { HttpClient } from './HttpClient';
import { QbiApiPaths } from '../common/constants/QbiApiPaths';
import { ApiResult } from '../model/ApiResult';
import { TransferInfo } from '../model/TransferInfo';
import { TorrentInfo } from '../model/TorrentInfo';
import { TorrentFile } from '../model/TorrentFile';
import { TorrentTracker } from '../model/TorrentTracker';
import { TorrentPeer } from '../model/TorrentPeer';
import { TorrentProperties } from '../model/TorrentProperties';
import { TorrentPeersSync } from '../model/TorrentPeersSync';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../common/constants/AppConstants';

export class QbittorrentApi {
  private client: HttpClient;

  constructor(useSharedClient: boolean = true) {
    this.client = useSharedClient ? HttpClient.getInstance() : new HttpClient();
  }

  async login(baseUrl: string, username: string, password: string): Promise<ApiResult<string>> {
    this.client.setBaseUrl(baseUrl);
    this.client.clearSid();
    const params: Record<string, string> = {
      'username': username,
      'password': password,
    };
    const result: ApiResult<string> = await this.client.postForLogin(QbiApiPaths.AUTH_LOGIN, params);
    if (result.success && result.data === 'Ok.') {
      return ApiResult.ok<string>('登录成功');
    }
    this.client.clearSid();
    if (result.success) {
      // HTTP 200 but response body is not "Ok." — treat as auth failure
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Login rejected: ${result.data}`);
      return ApiResult.fail<string>('用户名或密码错误');
    }
    return result;
  }

  async logout(): Promise<ApiResult<string>> {
    const result: ApiResult<string> = await this.client.post(QbiApiPaths.AUTH_LOGOUT, {});
    this.client.clearSid();
    return result;
  }

  async getVersion(): Promise<ApiResult<string>> {
    return await this.client.get(QbiApiPaths.APP_VERSION);
  }

  async getTransferInfo(): Promise<ApiResult<TransferInfo>> {
    const result: ApiResult<string> = await this.client.get(QbiApiPaths.TRANSFER_INFO);
    if (!result.success) {
      return ApiResult.fail<TransferInfo>(result.error, result.statusCode);
    }
    try {
      const raw: string = result.data as string;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `TransferInfo raw: ${raw.substring(0, 200)}`);
      const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const connStatus: Object | undefined = parsed['connection_status'];
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `connection_status debug: value=[${connStatus}] type=${typeof connStatus} keys=${Object.keys(parsed).join(',')}`);
      const info: TransferInfo = TransferInfo.fromJson(parsed);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG,
        `TransferInfo parsed: dl_speed=${info.dl_info_speed} up_speed=${info.up_info_speed} dht=${info.dht_nodes} conn=${info.connection_status}`);
      return ApiResult.ok<TransferInfo>(info);
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `TransferInfo parse error: ${JSON.stringify(err)}, data type: ${typeof result.data}`);
      return ApiResult.fail<TransferInfo>('解析传输信息失败');
    }
  }

  async getTorrentList(filter?: string, sort?: string, category?: string, hashes?: string): Promise<ApiResult<TorrentInfo[]>> {
    let path: string = QbiApiPaths.TORRENTS_INFO;
    const params: string[] = [];
    if (filter) {
      params.push(`filter=${encodeURIComponent(filter)}`);
    }
    if (sort) {
      params.push(`sort=${encodeURIComponent(sort)}`);
    }
    if (category) {
      params.push(`category=${encodeURIComponent(category)}`);
    }
    if (hashes) {
      params.push(`hashes=${encodeURIComponent(hashes)}`);
    }
    if (params.length > 0) {
      path += '?' + params.join('&');
    }

    const result: ApiResult<string> = await this.client.get(path);
    if (!result.success) {
      return ApiResult.fail<TorrentInfo[]>(result.error, result.statusCode);
    }
    try {
      const parsedArray: Object[] = JSON.parse(result.data as string) as Object[];
      const torrents: TorrentInfo[] = [];
      for (const item of parsedArray) {
        const record: Record<string, Object> = item as Record<string, Object>;
        torrents.push(TorrentInfo.fromJson(record));
      }
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `TorrentList parsed: ${torrents.length} torrents`);
      return ApiResult.ok<TorrentInfo[]>(torrents);
    } catch (err) {
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `TorrentList parse error: ${JSON.stringify(err)}`);
      return ApiResult.fail<TorrentInfo[]>('解析种子列表失败');
    }
  }

  async getTorrentProperties(hash: string): Promise<ApiResult<TorrentProperties>> {
    const path: string = `${QbiApiPaths.TORRENT_PROPERTIES}?hash=${encodeURIComponent(hash)}`;
    const result: ApiResult<string> = await this.client.get(path);
    if (!result.success) {
      return ApiResult.fail<TorrentProperties>(result.error, result.statusCode);
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(result.data as string) as Record<string, Object>;
      return ApiResult.ok<TorrentProperties>(TorrentProperties.fromJson(parsed));
    } catch (err) {
      return ApiResult.fail<TorrentProperties>('解析种子属性失败');
    }
  }

  async getTorrentFiles(hash: string): Promise<ApiResult<TorrentFile[]>> {
    const path: string = `${QbiApiPaths.TORRENT_FILES}?hash=${encodeURIComponent(hash)}`;
    const result: ApiResult<string> = await this.client.get(path);
    if (!result.success) {
      return ApiResult.fail<TorrentFile[]>(result.error, result.statusCode);
    }
    try {
      const parsedArray: Object[] = JSON.parse(result.data as string) as Object[];
      const files: TorrentFile[] = [];
      let arrayIdx: number = 0;
      for (const item of parsedArray) {
        const record: Record<string, Object> = item as Record<string, Object>;
        const file: TorrentFile = TorrentFile.fromJson(record);
        if (file.index < 0) {
          file.index = arrayIdx;
        }
        files.push(file);
        arrayIdx++;
      }
      return ApiResult.ok<TorrentFile[]>(files);
    } catch (err) {
      return ApiResult.fail<TorrentFile[]>('解析文件列表失败');
    }
  }

  async getTorrentTrackers(hash: string): Promise<ApiResult<TorrentTracker[]>> {
    const path: string = `${QbiApiPaths.TORRENT_TRACKERS}?hash=${encodeURIComponent(hash)}`;
    const result: ApiResult<string> = await this.client.get(path);
    if (!result.success) {
      return ApiResult.fail<TorrentTracker[]>(result.error, result.statusCode);
    }
    try {
      const parsedArray: Object[] = JSON.parse(result.data as string) as Object[];
      const trackers: TorrentTracker[] = [];
      for (const item of parsedArray) {
        const record: Record<string, Object> = item as Record<string, Object>;
        const tier: number = record['tier'] as number;
        const status: number = record['status'] as number;
        if (tier < 0 && status === 0) {
          continue;
        }
        trackers.push(TorrentTracker.fromJson(record));
      }
      return ApiResult.ok<TorrentTracker[]>(trackers);
    } catch (err) {
      return ApiResult.fail<TorrentTracker[]>('解析 Tracker 列表失败');
    }
  }

  async getTorrentPeers(hash: string, rid: number = 0): Promise<ApiResult<TorrentPeersSync>> {
    const path: string = `${QbiApiPaths.TORRENT_PEERS}?hash=${encodeURIComponent(hash)}&rid=${rid}`;
    const result: ApiResult<string> = await this.client.get(path);
    if (!result.success) {
      return ApiResult.fail<TorrentPeersSync>(result.error, result.statusCode);
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(result.data as string) as Record<string, Object>;
      const response: TorrentPeersSync = new TorrentPeersSync();
      response.rid = parsed['rid'] as number;
      response.full_update = parsed['full_update'] as boolean;
      response.show_flags = parsed['show_flags'] as boolean;
      const peersMap: Record<string, Object> = parsed['peers'] as Record<string, Object>;
      const keys: string[] = Object.keys(peersMap);
      for (const key of keys) {
        const peerRecord: Record<string, Object> = peersMap[key] as Record<string, Object>;
        response.peers.push(TorrentPeer.fromJson(peerRecord, key));
      }
      const removed: Object | undefined = parsed['peers_removed'];
      if (Array.isArray(removed)) {
        response.peers_removed = removed as string[];
      }
      return ApiResult.ok<TorrentPeersSync>(response);
    } catch (err) {
      return ApiResult.fail<TorrentPeersSync>('解析 Peer 列表失败');
    }
  }

  async addTorrent(urls: string, savePath?: string, category?: string, tags?: string, paused?: boolean): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'urls': urls,
    };
    if (savePath) {
      params['savepath'] = savePath;
    }
    if (category) {
      params['category'] = category;
    }
    if (tags) {
      params['tags'] = tags;
    }
    if (paused !== undefined) {
      params['paused'] = paused ? 'true' : 'false';
    }
    const result: ApiResult<string> = await this.client.post(QbiApiPaths.TORRENT_ADD, params);
    if (result.success) {
      return ApiResult.ok<string>('添加成功');
    }
    return result;
  }

  async pauseTorrents(hashes: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
    };
    return await this.client.post(QbiApiPaths.TORRENT_PAUSE, params);
  }

  async resumeTorrents(hashes: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
    };
    return await this.client.post(QbiApiPaths.TORRENT_RESUME, params);
  }

  async reannounceTorrents(hashes: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
    };
    return await this.client.post(QbiApiPaths.TORRENT_REANNOUNCE, params);
  }

  async deleteTorrents(hashes: string[], deleteFiles: boolean): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
      'deleteFiles': deleteFiles ? 'true' : 'false',
    };
    return await this.client.post(QbiApiPaths.TORRENT_DELETE, params);
  }

  async setGlobalDownloadLimit(limitBps: number): Promise<ApiResult<string>> {
    const params: Record<string, string> = {};
    params['limit'] = limitBps.toString();
    return await this.client.post(QbiApiPaths.TRANSFER_SET_DL_LIMIT, params);
  }

  async setGlobalUploadLimit(limitBps: number): Promise<ApiResult<string>> {
    const params: Record<string, string> = {};
    params['limit'] = limitBps.toString();
    return await this.client.post(QbiApiPaths.TRANSFER_SET_UL_LIMIT, params);
  }

  async setFilePriority(hash: string, fileId: number, priority: number): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hash': hash,
      'id': fileId.toString(),
      'priority': priority.toString(),
    };
    return await this.client.post(QbiApiPaths.TORRENT_FILE_PRIO, params);
  }

  async setDownloadLimit(hash: string, limitBps: number): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hash,
      'limit': limitBps.toString(),
    };
    return await this.client.post(QbiApiPaths.TORRENT_SET_DL_LIMIT, params);
  }

  async setUploadLimit(hash: string, limitBps: number): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hash,
      'limit': limitBps.toString(),
    };
    return await this.client.post(QbiApiPaths.TORRENT_SET_UL_LIMIT, params);
  }

  async addTorrentFile(filePath: string, fileName: string, savePath?: string, category?: string, tags?: string, paused?: boolean): Promise<ApiResult<string>> {
    const params: Record<string, string> = {};
    if (savePath) {
      params['savepath'] = savePath;
    }
    if (category) {
      params['category'] = category;
    }
    if (tags) {
      params['tags'] = tags;
    }
    if (paused !== undefined) {
      params['paused'] = paused ? 'true' : 'false';
    }
    const result: ApiResult<string> = await this.client.postMultipart(QbiApiPaths.TORRENT_ADD, params, filePath, fileName);
    if (result.success) {
      return ApiResult.ok<string>('添加成功');
    }
    return result;
  }
}
