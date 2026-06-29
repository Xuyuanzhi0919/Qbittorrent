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
import { SyncMainData } from '../model/SyncMainData';
import { LogUtil } from '@pura/harmony-utils';

export class QbittorrentApi {
  private client: HttpClient;
  private webApiVersion: string = '';
  private usingApiKey: boolean = false;

  constructor(useSharedClient: boolean = true) {
    this.client = useSharedClient ? HttpClient.getInstance() : new HttpClient();
  }

  async login(baseUrl: string, username: string, password: string, apiKey: string = ''): Promise<ApiResult<string>> {
    this.client.setBaseUrl(baseUrl);
    this.client.clearAuth();
    this.webApiVersion = '';
    this.usingApiKey = false;

    const trimmedApiKey: string = apiKey.trim();
    if (trimmedApiKey.length > 0) {
      this.client.setApiKey(trimmedApiKey);
      const verifyResult: ApiResult<string> = await this.client.get(QbiApiPaths.APP_WEB_API_VERSION);
      if (verifyResult.success) {
        this.webApiVersion = (verifyResult.data as string).trim();
        this.usingApiKey = true;
        return ApiResult.ok<string>('登录成功');
      }
      this.client.clearAuth();
      LogUtil.warn('API key verification failed: ' + verifyResult.error + ', statusCode=' + verifyResult.statusCode);
      if (username.trim().length === 0) {
        return ApiResult.fail<string>('API 密钥校验失败：' + verifyResult.error, verifyResult.statusCode);
      }
      LogUtil.warn('API key unavailable, fallback to username/password login');
    }

    return await this.loginWithPassword(username, password);
  }

  private async loginWithPassword(username: string, password: string): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'username': username,
      'password': password,
    };
    const result: ApiResult<string> = await this.client.postForLogin(QbiApiPaths.AUTH_LOGIN, params);
    if (result.success && result.data === 'Ok.') {
      const verifyResult: ApiResult<string> = await this.client.get(QbiApiPaths.APP_WEB_API_VERSION);
      if (!verifyResult.success) {
        const sidLength: number = this.client.getSid().length;
        const statusCode: number = verifyResult.statusCode;
        const error: string = verifyResult.error || '未知错误';
        this.client.clearAuth();
        LogUtil.warn('Login session verification failed: ' + verifyResult.error + ', statusCode=' + verifyResult.statusCode + ', sidLength=' + sidLength);
        if (result.statusCode === 204 && sidLength === 0) {
          return ApiResult.fail<string>(
            '登录接口返回204，但会话校验失败，且客户端未读取到 SID Cookie；旧版 qB 请使用用户名密码登录并检查 WebUI Cookie/Host/反向代理配置。详情：' +
              error + '，状态码=' + statusCode,
            statusCode
          );
        }
        return ApiResult.fail<string>('登录后会话校验失败：' + error + '，状态码=' + statusCode + '，SID长度=' + sidLength, statusCode);
      }
      this.webApiVersion = (verifyResult.data as string).trim();
      return ApiResult.ok<string>('登录成功');
    }
    this.client.clearAuth();
    if (result.success) {
      // HTTP 200 but response body is not "Ok." — treat as auth failure
      LogUtil.warn('Login rejected: ' + result.data);
      return ApiResult.fail<string>('用户名或密码错误');
    }
    return result;
  }

  async logout(): Promise<ApiResult<string>> {
    if (this.usingApiKey) {
      this.client.clearAuth();
      this.webApiVersion = '';
      this.usingApiKey = false;
      return ApiResult.ok<string>('已断开连接');
    }
    const result: ApiResult<string> = await this.client.post(QbiApiPaths.AUTH_LOGOUT, {});
    this.client.clearAuth();
    this.webApiVersion = '';
    this.usingApiKey = false;
    return result;
  }

  async getVersion(): Promise<ApiResult<string>> {
    return await this.client.get(QbiApiPaths.APP_VERSION);
  }

  async getWebApiVersion(): Promise<ApiResult<string>> {
    const result: ApiResult<string> = await this.client.get(QbiApiPaths.APP_WEB_API_VERSION);
    if (result.success) {
      this.webApiVersion = (result.data as string).trim();
    }
    return result;
  }

  async getTransferInfo(): Promise<ApiResult<TransferInfo>> {
    const result: ApiResult<string> = await this.client.get(QbiApiPaths.TRANSFER_INFO);
    if (!result.success) {
      return ApiResult.fail<TransferInfo>(result.error, result.statusCode);
    }
    try {
      const raw: string = result.data as string;
      LogUtil.info('TransferInfo raw: ' + raw.substring(0, 200));
      const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const connStatus: Object | undefined = parsed['connection_status'];
      LogUtil.info('connection_status debug: value=[' + connStatus + '] type=' + typeof connStatus + ' keys=' + Object.keys(parsed).join(','));
      const info: TransferInfo = TransferInfo.fromJson(parsed);
      LogUtil.info('TransferInfo parsed: dl_speed=' + info.dl_info_speed + ' up_speed=' + info.up_info_speed + ' dht=' + info.dht_nodes + ' conn=' + info.connection_status);
      return ApiResult.ok<TransferInfo>(info);
    } catch (err) {
      LogUtil.error('TransferInfo parse error: ' + JSON.stringify(err) + ', data type: ' + typeof result.data);
      return ApiResult.fail<TransferInfo>('解析传输信息失败');
    }
  }

  async getTorrentList(filter?: string, sort?: string, category?: string, hashes?: string): Promise<ApiResult<TorrentInfo[]>> {
    let path: string = QbiApiPaths.TORRENTS_INFO;
    const params: string[] = [];
    if (filter) {
      const normalizedFilter: string = await this.normalizeTorrentFilter(filter);
      params.push('filter=' + encodeURIComponent(normalizedFilter));
    }
    if (sort) {
      params.push('sort=' + encodeURIComponent(sort));
    }
    if (category) {
      params.push('category=' + encodeURIComponent(category));
    }
    if (hashes) {
      params.push('hashes=' + encodeURIComponent(hashes));
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
      LogUtil.info('TorrentList parsed: ' + torrents.length + ' torrents');
      return ApiResult.ok<TorrentInfo[]>(torrents);
    } catch (err) {
      LogUtil.error('TorrentList parse error: ' + JSON.stringify(err));
      return ApiResult.fail<TorrentInfo[]>('解析种子列表失败');
    }
  }

  async getTorrentProperties(hash: string): Promise<ApiResult<TorrentProperties>> {
    const path: string = QbiApiPaths.TORRENT_PROPERTIES + '?hash=' + encodeURIComponent(hash);
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
    const path: string = QbiApiPaths.TORRENT_FILES + '?hash=' + encodeURIComponent(hash);
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
    const path: string = QbiApiPaths.TORRENT_TRACKERS + '?hash=' + encodeURIComponent(hash);
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
    const path: string = QbiApiPaths.TORRENT_PEERS + '?hash=' + encodeURIComponent(hash) + '&rid=' + rid;
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

  async getMainData(rid: number = 0): Promise<ApiResult<SyncMainData>> {
    const path: string = QbiApiPaths.SYNC_MAIN_DATA + '?rid=' + rid;
    const result: ApiResult<string> = await this.client.get(path);
    if (!result.success) {
      return ApiResult.fail<SyncMainData>(result.error, result.statusCode);
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(result.data as string) as Record<string, Object>;
      return ApiResult.ok<SyncMainData>(SyncMainData.fromJson(parsed));
    } catch (err) {
      LogUtil.error('MainData parse error: ' + JSON.stringify(err));
      return ApiResult.fail<SyncMainData>('解析同步数据失败');
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
    const primaryPath: string = await this.getPausePath();
    const result: ApiResult<string> = await this.client.post(primaryPath, params);
    if (!result.success && this.shouldTryLegacyTorrentStatePath(primaryPath, result.statusCode)) {
      return await this.client.post(QbiApiPaths.TORRENT_PAUSE_LEGACY, params);
    }
    return result;
  }

  async resumeTorrents(hashes: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
    };
    const primaryPath: string = await this.getResumePath();
    const result: ApiResult<string> = await this.client.post(primaryPath, params);
    if (!result.success && this.shouldTryLegacyTorrentStatePath(primaryPath, result.statusCode)) {
      return await this.client.post(QbiApiPaths.TORRENT_RESUME_LEGACY, params);
    }
    return result;
  }

  async reannounceTorrents(hashes: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
    };
    return await this.client.post(QbiApiPaths.TORRENT_REANNOUNCE, params);
  }

  async recheckTorrents(hashes: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
    };
    return await this.client.post(QbiApiPaths.TORRENT_RECHECK, params);
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

  async setShareLimits(hashes: string[], ratioLimit: number, seedingTimeLimit: number): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
      'ratioLimit': ratioLimit.toString(),
      'seedingTimeLimit': seedingTimeLimit.toString(),
    };
    return await this.client.post(QbiApiPaths.TORRENT_SET_SHARE_LIMITS, params);
  }

  async setLocation(hashes: string[], location: string): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
      'location': location,
    };
    return await this.client.post(QbiApiPaths.TORRENT_SET_LOCATION, params);
  }

  async renameTorrent(hash: string, name: string): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hash': hash,
      'name': name,
    };
    return await this.client.post(QbiApiPaths.TORRENT_RENAME, params);
  }

  async getCategories(): Promise<ApiResult<string[]>> {
    const result: ApiResult<string> = await this.client.get(QbiApiPaths.TORRENTS_CATEGORIES);
    if (!result.success) {
      return ApiResult.fail<string[]>(result.error, result.statusCode);
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(result.data as string) as Record<string, Object>;
      return ApiResult.ok<string[]>(Object.keys(parsed));
    } catch (err) {
      return ApiResult.fail<string[]>('解析分类列表失败');
    }
  }

  async createCategory(name: string, savePath: string): Promise<ApiResult<string>> {
    const params: Record<string, string> = {};
    params['category'] = name;
    params['savePath'] = savePath;
    return await this.client.post(QbiApiPaths.TORRENT_CREATE_CATEGORY, params);
  }

  async removeCategories(names: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {};
    params['categories'] = names.join('\n');
    return await this.client.post(QbiApiPaths.TORRENT_REMOVE_CATEGORIES, params);
  }

  async setTorrentCategory(hashes: string[], category: string): Promise<ApiResult<string>> {
    const params: Record<string, string> = {};
    params['hashes'] = hashes.join('|');
    params['category'] = category;
    return await this.client.post(QbiApiPaths.TORRENT_SET_CATEGORY, params);
  }

  async getTags(): Promise<ApiResult<string[]>> {
    const result: ApiResult<string> = await this.client.get(QbiApiPaths.TORRENTS_TAGS);
    if (!result.success) {
      return ApiResult.fail<string[]>(result.error, result.statusCode);
    }
    try {
      const parsedArray: Object[] = JSON.parse(result.data as string) as Object[];
      const tags: string[] = [];
      for (const item of parsedArray) {
        if (typeof item === 'string') {
          tags.push(item as string);
        }
      }
      return ApiResult.ok<string[]>(tags);
    } catch (err) {
      return ApiResult.fail<string[]>('解析标签列表失败');
    }
  }

  async createTags(tags: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'tags': tags.join(','),
    };
    return await this.client.post(QbiApiPaths.TORRENT_CREATE_TAGS, params);
  }

  async deleteTags(tags: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'tags': tags.join(','),
    };
    return await this.client.post(QbiApiPaths.TORRENT_DELETE_TAGS, params);
  }

  async addTags(hashes: string[], tags: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
      'tags': tags.join(','),
    };
    return await this.client.post(QbiApiPaths.TORRENT_ADD_TAGS, params);
  }

  async removeTags(hashes: string[], tags: string[]): Promise<ApiResult<string>> {
    const params: Record<string, string> = {
      'hashes': hashes.join('|'),
      'tags': tags.join(','),
    };
    return await this.client.post(QbiApiPaths.TORRENT_REMOVE_TAGS, params);
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

  private async normalizeTorrentFilter(filter: string): Promise<string> {
    if (await this.isModernStateApi()) {
      if (filter === 'paused') {
        return 'stopped';
      }
      if (filter === 'resumed') {
        return 'running';
      }
    } else {
      if (filter === 'stopped') {
        return 'paused';
      }
      if (filter === 'running') {
        return 'resumed';
      }
    }
    return filter;
  }

  private async getPausePath(): Promise<string> {
    return await this.isModernStateApi() ? QbiApiPaths.TORRENT_PAUSE : QbiApiPaths.TORRENT_PAUSE_LEGACY;
  }

  private async getResumePath(): Promise<string> {
    return await this.isModernStateApi() ? QbiApiPaths.TORRENT_RESUME : QbiApiPaths.TORRENT_RESUME_LEGACY;
  }

  private shouldTryLegacyTorrentStatePath(path: string, statusCode: number): boolean {
    return path !== QbiApiPaths.TORRENT_PAUSE_LEGACY &&
      path !== QbiApiPaths.TORRENT_RESUME_LEGACY &&
      (statusCode === 404 || statusCode === 405 || statusCode === 0);
  }

  private async isModernStateApi(): Promise<boolean> {
    if (this.webApiVersion.length === 0) {
      await this.getWebApiVersion();
    }
    if (this.webApiVersion.length === 0) {
      return true;
    }
    return this.compareVersion(this.webApiVersion, '2.11.0') >= 0;
  }

  private compareVersion(left: string, right: string): number {
    const leftParts: string[] = left.split('.');
    const rightParts: string[] = right.split('.');
    const maxLen: number = Math.max(leftParts.length, rightParts.length);
    for (let i: number = 0; i < maxLen; i++) {
      const leftValue: number = this.parseVersionPart(i < leftParts.length ? leftParts[i] : '0');
      const rightValue: number = this.parseVersionPart(i < rightParts.length ? rightParts[i] : '0');
      if (leftValue > rightValue) {
        return 1;
      }
      if (leftValue < rightValue) {
        return -1;
      }
    }
    return 0;
  }

  private parseVersionPart(value: string): number {
    const parsed: number = Number(value);
    if (parsed !== parsed || parsed < 0) {
      return 0;
    }
    return parsed;
  }
}
