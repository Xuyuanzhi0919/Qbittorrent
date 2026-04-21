export class TorrentFile {
  index: number = 0;
  name: string = '';
  size: number = 0;
  progress: number = 0;
  priority: number = 0;
  is_seed: boolean = false;

  static fromJson(json: Record<string, Object>): TorrentFile {
    const f: TorrentFile = new TorrentFile();
    f.index = typeof json['index'] === 'number' ? json['index'] as number : -1;
    f.name = json['name'] as string;
    f.size = json['size'] as number;
    f.progress = json['progress'] as number;
    f.priority = json['priority'] as number;
    f.is_seed = json['is_seed'] as boolean;
    return f;
  }
}
