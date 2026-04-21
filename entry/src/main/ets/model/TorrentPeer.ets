export class TorrentPeer {
  id: string = '';
  ip: string = '';
  port: number = 0;
  client: string = '';
  progress: number = 0;
  dl_speed: number = 0;
  up_speed: number = 0;
  flags: string = '';
  country: string = '';
  country_code: string = '';

  private static toNumber(value: Object | undefined): number {
    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0;
    }
    if (typeof value === 'string') {
      const parsed: number = Number(value);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  static fromJson(json: Record<string, Object>, id: string = ''): TorrentPeer {
    const p: TorrentPeer = new TorrentPeer();
    p.id = id;
    p.ip = json['ip'] as string;
    p.port = TorrentPeer.toNumber(json['port']);
    p.client = json['client'] as string;
    p.progress = TorrentPeer.toNumber(json['progress']);
    p.dl_speed = TorrentPeer.toNumber(json['dl_speed']);
    p.up_speed = TorrentPeer.toNumber(json['up_speed']);
    p.flags = json['flags'] as string;
    p.country = json['country'] as string;
    p.country_code = json['country_code'] as string;
    return p;
  }
}
