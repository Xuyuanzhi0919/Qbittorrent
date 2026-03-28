export class AppConstants {
  static readonly LOG_DOMAIN: number = 0x0000;
  static readonly LOG_TAG: string = 'QbittorrentApp';
  static readonly PREFS_NAME: string = 'qbittorrent_prefs';
  static readonly KEY_SERVER_URL: string = 'server_url';
  static readonly KEY_SERVER_USERNAME: string = 'server_username';
  static readonly KEY_POLLING_INTERVAL: string = 'polling_interval';
  static readonly DEFAULT_POLLING_INTERVAL: number = 5000;
  static readonly HTTP_TIMEOUT: number = 15000;
}
