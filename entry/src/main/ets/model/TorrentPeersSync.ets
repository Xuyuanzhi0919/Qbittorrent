import { TorrentPeer } from './TorrentPeer';

export class TorrentPeersSync {
  rid: number = 0;
  full_update: boolean = false;
  show_flags: boolean = false;
  peers: TorrentPeer[] = [];
  peers_removed: string[] = [];
}
