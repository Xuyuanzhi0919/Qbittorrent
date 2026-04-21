import { TransferInfo } from '../model/TransferInfo';
import { TorrentInfo } from '../model/TorrentInfo';

export class DemoDataProvider {
  static getServerUrl(): string {
    return 'https://demo.torrentpilot.local:9443';
  }

  static getUsername(): string {
    return 'demo.operator';
  }

  static createTransferInfo(tick: number): TransferInfo {
    const profiles: number[][] = [
      [8.6 * 1024 * 1024, 1.2 * 1024 * 1024, 182.4 * 1024 * 1024 * 1024, 24.6 * 1024 * 1024 * 1024, 12 * 1024 * 1024, 3 * 1024 * 1024, 428],
      [7.9 * 1024 * 1024, 1.5 * 1024 * 1024, 183.1 * 1024 * 1024 * 1024, 24.8 * 1024 * 1024 * 1024, 12 * 1024 * 1024, 3 * 1024 * 1024, 436],
      [9.3 * 1024 * 1024, 1.1 * 1024 * 1024, 183.8 * 1024 * 1024 * 1024, 25.0 * 1024 * 1024 * 1024, 12 * 1024 * 1024, 3 * 1024 * 1024, 441]
    ];
    const profile: number[] = profiles[tick % profiles.length];
    const info: TransferInfo = new TransferInfo();
    info.dl_info_speed = Math.floor(profile[0]);
    info.up_info_speed = Math.floor(profile[1]);
    info.dl_info_data = Math.floor(profile[2]);
    info.up_info_data = Math.floor(profile[3]);
    info.dl_rate_limit = Math.floor(profile[4]);
    info.up_rate_limit = Math.floor(profile[5]);
    info.dht_nodes = Math.floor(profile[6]);
    info.connection_status = 'connected';
    return info;
  }

  static createTorrents(tick: number): TorrentInfo[] {
    const torrents: TorrentInfo[] = [];
    const tickOffset: number = tick % 3;

    const torrent1: TorrentInfo = new TorrentInfo();
    torrent1.hash = 'demo-ubuntu-2404';
    torrent1.name = 'Ubuntu 24.04.2 Desktop amd64.iso';
    torrent1.size = 6325 * 1024 * 1024;
    torrent1.progress = 0.68 + tickOffset * 0.01;
    torrent1.dlspeed = (5.8 + tickOffset * 0.4) * 1024 * 1024;
    torrent1.upspeed = 420 * 1024;
    torrent1.state = 'downloading';
    torrent1.num_seeds = 128;
    torrent1.num_leechs = 42;
    torrent1.ratio = 0.21;
    torrent1.eta = 780 - tickOffset * 45;
    torrent1.added_on = 1711603200;
    torrent1.category = '系统镜像';
    torrent1.tags = 'linux,iso';
    torrent1.downloaded = Math.floor(torrent1.size * torrent1.progress);
    torrent1.amount_left = torrent1.size - torrent1.downloaded;
    torrents.push(torrent1);

    const torrent2: TorrentInfo = new TorrentInfo();
    torrent2.hash = 'demo-blender-openmovie';
    torrent2.name = 'Blender Open Movie Collection 4K.mkv';
    torrent2.size = 2840 * 1024 * 1024;
    torrent2.progress = 0.34 + tickOffset * 0.015;
    torrent2.dlspeed = (2.1 + tickOffset * 0.2) * 1024 * 1024;
    torrent2.upspeed = 160 * 1024;
    torrent2.state = 'stalledDL';
    torrent2.num_seeds = 36;
    torrent2.num_leechs = 18;
    torrent2.ratio = 0.08;
    torrent2.eta = 2640 - tickOffset * 120;
    torrent2.added_on = 1711689600;
    torrent2.category = '视频';
    torrent2.tags = 'movie,4k';
    torrent2.downloaded = Math.floor(torrent2.size * torrent2.progress);
    torrent2.amount_left = torrent2.size - torrent2.downloaded;
    torrents.push(torrent2);

    const torrent3: TorrentInfo = new TorrentInfo();
    torrent3.hash = 'demo-archived-assets';
    torrent3.name = 'Design Assets Archive 2026.7z';
    torrent3.size = 1840 * 1024 * 1024;
    torrent3.progress = 1;
    torrent3.dlspeed = 0;
    torrent3.upspeed = 320 * 1024;
    torrent3.state = 'uploading';
    torrent3.num_seeds = 22;
    torrent3.num_leechs = 6;
    torrent3.ratio = 1.42;
    torrent3.eta = 8640000;
    torrent3.added_on = 1711776000;
    torrent3.category = '归档';
    torrent3.tags = 'design,archive';
    torrent3.downloaded = torrent3.size;
    torrent3.amount_left = 0;
    torrents.push(torrent3);

    const torrent4: TorrentInfo = new TorrentInfo();
    torrent4.hash = 'demo-course-pack';
    torrent4.name = 'Frontend Course Pack.zip';
    torrent4.size = 920 * 1024 * 1024;
    torrent4.progress = 0.12;
    torrent4.dlspeed = 0;
    torrent4.upspeed = 0;
    torrent4.state = 'pausedDL';
    torrent4.num_seeds = 14;
    torrent4.num_leechs = 0;
    torrent4.ratio = 0;
    torrent4.eta = 8640000;
    torrent4.added_on = 1711862400;
    torrent4.category = '学习';
    torrent4.tags = 'course,zip';
    torrent4.downloaded = Math.floor(torrent4.size * torrent4.progress);
    torrent4.amount_left = torrent4.size - torrent4.downloaded;
    torrents.push(torrent4);

    return torrents;
  }
}
