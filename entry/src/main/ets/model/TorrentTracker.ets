export class TorrentTracker {
  url: string = '';
  status: number = 0;
  tier: number = 0;
  num_peers: number = 0;
  num_seeds: number = 0;
  num_leeches: number = 0;
  num_downloaded: number = 0;
  msg: string = '';

  getStatusLabel(): string {
    if (this.status === 0) {
      return '禁用';
    }
    if (this.status === 1) {
      return '未联系';
    }
    if (this.status === 2) {
      return '工作中';
    }
    if (this.status === 3) {
      return '更新中';
    }
    if (this.status === 4) {
      return '未工作';
    }
    return '未知';
  }

  static fromJson(json: Record<string, Object>): TorrentTracker {
    const t: TorrentTracker = new TorrentTracker();
    t.url = json['url'] as string;
    t.status = json['status'] as number;
    t.tier = json['tier'] as number;
    t.num_peers = json['num_peers'] as number;
    t.num_seeds = json['num_seeds'] as number;
    t.num_leeches = json['num_leeches'] as number;
    t.num_downloaded = json['num_downloaded'] as number;
    t.msg = json['msg'] as string;
    return t;
  }
}
