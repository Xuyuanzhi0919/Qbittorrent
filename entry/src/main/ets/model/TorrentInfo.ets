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
    t.applyJson(json);
    return t;
  }

  applyJson(json: Record<string, Object>): void {
    if (TorrentInfo.hasField(json, 'hash')) {
      this.hash = TorrentInfo.readString(json['hash']);
    }
    if (TorrentInfo.hasField(json, 'name')) {
      this.name = TorrentInfo.readString(json['name']);
    }
    if (TorrentInfo.hasField(json, 'size')) {
      this.size = TorrentInfo.readNumber(json['size']);
    }
    if (TorrentInfo.hasField(json, 'progress')) {
      this.progress = TorrentInfo.readNumber(json['progress']);
    }
    if (TorrentInfo.hasField(json, 'dlspeed')) {
      this.dlspeed = TorrentInfo.readNumber(json['dlspeed']);
    }
    if (TorrentInfo.hasField(json, 'upspeed')) {
      this.upspeed = TorrentInfo.readNumber(json['upspeed']);
    }
    if (TorrentInfo.hasField(json, 'state')) {
      this.state = TorrentInfo.readString(json['state']);
    }
    if (TorrentInfo.hasField(json, 'num_seeds')) {
      this.num_seeds = TorrentInfo.readNumber(json['num_seeds']);
    }
    if (TorrentInfo.hasField(json, 'num_leechs')) {
      this.num_leechs = TorrentInfo.readNumber(json['num_leechs']);
    }
    if (TorrentInfo.hasField(json, 'ratio')) {
      this.ratio = TorrentInfo.readNumber(json['ratio']);
    }
    if (TorrentInfo.hasField(json, 'eta')) {
      this.eta = TorrentInfo.readNumber(json['eta']);
    }
    if (TorrentInfo.hasField(json, 'added_on')) {
      this.added_on = TorrentInfo.readNumber(json['added_on']);
    }
    if (TorrentInfo.hasField(json, 'completion_on')) {
      this.completion_on = TorrentInfo.readNumber(json['completion_on']);
    }
    if (TorrentInfo.hasField(json, 'save_path')) {
      this.save_path = TorrentInfo.readString(json['save_path']);
    }
    if (TorrentInfo.hasField(json, 'tags')) {
      this.tags = TorrentInfo.readString(json['tags']);
    }
    if (TorrentInfo.hasField(json, 'category')) {
      this.category = TorrentInfo.readString(json['category']);
    }
    if (TorrentInfo.hasField(json, 'uploaded')) {
      this.uploaded = TorrentInfo.readNumber(json['uploaded']);
    }
    if (TorrentInfo.hasField(json, 'downloaded')) {
      this.downloaded = TorrentInfo.readNumber(json['downloaded']);
    }
    if (TorrentInfo.hasField(json, 'amount_left')) {
      this.amount_left = TorrentInfo.readNumber(json['amount_left']);
    }
    if (TorrentInfo.hasField(json, 'dl_limit')) {
      this.dl_limit = TorrentInfo.readNumberAllowNegative(json['dl_limit']);
    }
    if (TorrentInfo.hasField(json, 'ul_limit')) {
      this.ul_limit = TorrentInfo.readNumberAllowNegative(json['ul_limit']);
    }
  }

  static copyFrom(source: TorrentInfo): TorrentInfo {
    const t: TorrentInfo = new TorrentInfo();
    t.hash = source.hash;
    t.name = source.name;
    t.size = source.size;
    t.progress = source.progress;
    t.dlspeed = source.dlspeed;
    t.upspeed = source.upspeed;
    t.state = source.state;
    t.num_seeds = source.num_seeds;
    t.num_leechs = source.num_leechs;
    t.ratio = source.ratio;
    t.eta = source.eta;
    t.added_on = source.added_on;
    t.completion_on = source.completion_on;
    t.save_path = source.save_path;
    t.tags = source.tags;
    t.category = source.category;
    t.uploaded = source.uploaded;
    t.downloaded = source.downloaded;
    t.amount_left = source.amount_left;
    t.dl_limit = source.dl_limit;
    t.ul_limit = source.ul_limit;
    return t;
  }

  private static readNumber(value: Object): number {
    if (typeof value !== 'number') {
      return 0;
    }
    const numberValue: number = value as number;
    if (numberValue !== numberValue || numberValue < 0) {
      return 0;
    }
    return numberValue;
  }

  private static readNumberAllowNegative(value: Object): number {
    if (typeof value !== 'number') {
      return 0;
    }
    const numberValue: number = value as number;
    if (numberValue !== numberValue) {
      return 0;
    }
    return numberValue;
  }

  private static readString(value: Object): string {
    if (typeof value !== 'string') {
      return '';
    }
    return value as string;
  }

  private static hasField(json: Record<string, Object>, key: string): boolean {
    return json[key] !== undefined;
  }
}
