@Observed
export class DashboardData {
  dlSpeed: number = 0;
  ulSpeed: number = 0;
  dlData: number = 0;
  ulData: number = 0;
  dhtNodes: number = 0;
  connectionStatus: string = '';
  activeTorrentCount: number = 0;
  completedTorrentCount: number = 0;
  pausedTorrentCount: number = 0;
  totalTorrentCount: number = 0;
  serverVersion: string = '';
}
