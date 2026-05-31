export class AppConstants {
  static readonly LOG_DOMAIN: number = 0x0000;
  static readonly LOG_TAG: string = 'QbittorrentApp';
  static readonly PREFS_NAME: string = 'qbittorrent_prefs';
  static readonly KEY_SERVER_URL: string = 'server_url';
  static readonly KEY_SERVER_USERNAME: string = 'server_username';
  static readonly KEY_POLLING_INTERVAL: string = 'polling_interval';
  static readonly DEFAULT_POLLING_INTERVAL: number = 5000;
  static readonly HTTP_TIMEOUT: number = 15000;
  static readonly PAGE_HORIZONTAL_PADDING: number = 20;
  static readonly PAGE_TOP_PADDING: number = 62;
  static readonly PAGE_HEADER_HEIGHT: number = 46;
  static readonly PAGE_HEADER_BOTTOM_PADDING: number = 12;
}
