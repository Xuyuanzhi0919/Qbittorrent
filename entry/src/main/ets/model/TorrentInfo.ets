export class TorrentInfo {
  hash: string = '';
  name: string = '';
  size: number = 0;
  progress: number = 0;
  dlspeed: number = 0;
  upspeed: number = 0;
  state: string = '';
  num_seeds: number = 0;
  num_leechs: number = 0;
  ratio: number = 0;
  eta: number = 0;
  added_on: number = 0;
  completion_on: number = 0;
  save_path: string = '';
  tags: string = '';
  category: string = '';
  uploaded: number = 0;
  downloaded: number = 0;
  amount_left: number = 0;
  dl_limit: number = 0;
  ul_limit: number = 0;

  isDownloading(): boolean {
    return this.state === 'downloading' || this.state === 'stalledDL' || this.state === 'metaDL' || this.state === 'forcedDL';
  }

  isCompleted(): boolean {
    return this.state === 'uploading' || this.state === 'stalledUP' || this.state === 'forcedUP' ||
      this.state === 'stoppedUP';
  }

  isPaused(): boolean {
    return this.state === 'pausedDL' || this.state === 'pausedUP' ||
      this.state === 'stoppedDL' || this.state === 'stoppedUP';
  }

  isActive(): boolean {
    return this.dlspeed > 0 || this.upspeed > 0;
  }

  getStateLabel(): string {
    const stateMap: Record<string, string> = {
      'downloading': '下载中',
      'stalledDL': '等待下载',
      'metaDL': '获取元数据',
      'forcedDL': '强制下载',
      'uploading': '做种中',
      'stalledUP': '等待做种',
      'forcedUP': '强制做种',
      'pausedDL': '已暂停',
      'pausedUP': '暂停做种',
      'stoppedDL': '已暂停',
      'stoppedUP': '暂停做种',
      'queuedDL': '排队下载',
      'queuedUP': '排队做种',
      'checkingDL': '校验中',
      'checkingUP': '校验做种',
      'checkingResumeData': '校验数据',
      'allocating': '分配空间',
      'moving': '移动中',
      'error': '错误',
      'missingFiles': '文件缺失',
      'unknown': '未知'
    };
    return stateMap[this.state] || this.state;
  }

  static fromJson(json: Record<string, Object>): TorrentInfo {
    const t: TorrentInfo = new TorrentInfo();
    t.hash = json['hash'] as string;
    t.name = json['name'] as string;
    t.size = json['size'] as number;
    t.progress = json['progress'] as number;
    t.dlspeed = json['dlspeed'] as number;
    t.upspeed = json['upspeed'] as number;
    t.state = json['state'] as string;
    t.num_seeds = json['num_seeds'] as number;
    t.num_leechs = json['num_leechs'] as number;
    t.ratio = json['ratio'] as number;
    t.eta = json['eta'] as number;
    t.added_on = json['added_on'] as number;
    t.completion_on = json['completion_on'] as number;
    t.save_path = json['save_path'] as string;
    t.tags = json['tags'] as string;
    t.category = json['category'] as string;
    t.uploaded = json['uploaded'] as number;
    t.downloaded = json['downloaded'] as number;
    t.amount_left = json['amount_left'] as number;
    t.dl_limit = typeof json['dl_limit'] === 'number' ? json['dl_limit'] as number : 0;
    t.ul_limit = typeof json['ul_limit'] === 'number' ? json['ul_limit'] as number : 0;
    return t;
  }
}
