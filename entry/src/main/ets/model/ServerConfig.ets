export class ServerConfig {
  url: string = '';
  username: string = '';
  password: string = '';
  apiKey: string = '';

  constructor(url: string = '', username: string = '', password: string = '', apiKey: string = '') {
    this.url = url;
    this.username = username;
    this.password = password;
    this.apiKey = apiKey;
  }

  isValid(): boolean {
    return this.url.length > 0 && (this.apiKey.length > 0 || this.username.length > 0);
  }

  toJson(): Record<string, Object> {
    const map: Record<string, Object> = {};
    map['url'] = this.url;
    map['username'] = this.username;
    map['password'] = this.password;
    map['apiKey'] = this.apiKey;
    return map;
  }

  static fromJson(json: Record<string, Object>): ServerConfig {
    const config: ServerConfig = new ServerConfig();
    config.url = json['url'] as string;
    config.username = json['username'] as string;
    config.password = json['password'] as string;
    const apiKey: Object | undefined = json['apiKey'];
    config.apiKey = typeof apiKey === 'string' ? apiKey as string : '';
    return config;
  }
}
