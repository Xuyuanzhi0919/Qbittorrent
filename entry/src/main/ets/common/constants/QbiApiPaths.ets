export class QbiApiPaths {
  static readonly BASE: string = '/api/v2';
  static readonly AUTH_LOGIN: string = '/api/v2/auth/login';
  static readonly AUTH_LOGOUT: string = '/api/v2/auth/logout';
  static readonly TRANSFER_INFO: string = '/api/v2/transfer/info';
  static readonly TORRENTS_INFO: string = '/api/v2/torrents/info';
  static readonly TORRENT_PROPERTIES: string = '/api/v2/torrents/properties';
  static readonly TORRENT_FILES: string = '/api/v2/torrents/files';
  static readonly TORRENT_TRACKERS: string = '/api/v2/torrents/trackers';
  static readonly TORRENT_PEERS: string = '/api/v2/sync/torrentPeers';
  static readonly TORRENT_ADD: string = '/api/v2/torrents/add';
  static readonly TORRENT_PAUSE: string = '/api/v2/torrents/stop';
  static readonly TORRENT_RESUME: string = '/api/v2/torrents/start';
  static readonly TORRENT_REANNOUNCE: string = '/api/v2/torrents/reannounce';
  static readonly TORRENT_DELETE: string = '/api/v2/torrents/delete';
  static readonly TRANSFER_SET_DL_LIMIT: string = '/api/v2/transfer/setDownloadLimit';
  static readonly TRANSFER_SET_UL_LIMIT: string = '/api/v2/transfer/setUploadLimit';
  static readonly TORRENT_FILE_PRIO: string = '/api/v2/torrents/filePrio';
  static readonly TORRENT_SET_DL_LIMIT: string = '/api/v2/torrents/setDownloadLimit';
  static readonly TORRENT_SET_UL_LIMIT: string = '/api/v2/torrents/setUploadLimit';
  static readonly APP_VERSION: string = '/api/v2/app/version';
  static readonly TORRENTS_CATEGORIES: string = '/api/v2/torrents/categories';
  static readonly TORRENT_CREATE_CATEGORY: string = '/api/v2/torrents/createCategory';
  static readonly TORRENT_REMOVE_CATEGORIES: string = '/api/v2/torrents/removeCategories';
  static readonly TORRENT_SET_CATEGORY: string = '/api/v2/torrents/setCategory';
}
