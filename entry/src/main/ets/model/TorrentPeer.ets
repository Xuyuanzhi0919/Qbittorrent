export class TorrentPeer {
  ip: string = '';
  port: number = 0;
  client: string = '';
  progress: number = 0;
  dl_speed: number = 0;
  up_speed: number = 0;
  flags: string = '';
  country: string = '';
  country_code: string = '';

  static fromJson(json: Record<string, Object>): TorrentPeer {
    const p: TorrentPeer = new TorrentPeer();
    p.ip = json['ip'] as string;
    p.port = json['port'] as number;
    p.client = json['client'] as string;
    p.progress = json['progress'] as number;
    p.dl_speed = json['dl_speed'] as number;
    p.up_speed = json['up_speed'] as number;
    p.flags = json['flags'] as string;
    p.country = json['country'] as string;
    p.country_code = json['country_code'] as string;
    return p;
  }
}
