export class ServerConfig {
  url: string = '';
  username: string = '';
  password: string = '';

  constructor(url: string = '', username: string = '', password: string = '') {
    this.url = url;
    this.username = username;
    this.password = password;
  }

  isValid(): boolean {
    return this.url.length > 0 && this.username.length > 0;
  }

  toJson(): Record<string, Object> {
    const map: Record<string, Object> = {};
    map['url'] = this.url;
    map['username'] = this.username;
    map['password'] = this.password;
    return map;
  }

  static fromJson(json: Record<string, Object>): ServerConfig {
    const config: ServerConfig = new ServerConfig();
    config.url = json['url'] as string;
    config.username = json['username'] as string;
    config.password = json['password'] as string;
    return config;
  }
}
