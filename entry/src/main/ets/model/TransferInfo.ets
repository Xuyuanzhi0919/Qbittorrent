export class TransferInfo {
  dl_info_speed: number = 0;
  up_info_speed: number = 0;
  dl_info_data: number = 0;
  up_info_data: number = 0;
  dl_rate_limit: number = 0;
  up_rate_limit: number = 0;
  dht_nodes: number = 0;
  connection_status: string = '';

  static fromJson(json: Record<string, Object>): TransferInfo {
    const info: TransferInfo = new TransferInfo();
    info.dl_info_speed = json['dl_info_speed'] as number;
    info.up_info_speed = json['up_info_speed'] as number;
    info.dl_info_data = json['dl_info_data'] as number;
    info.up_info_data = json['up_info_data'] as number;
    info.dl_rate_limit = json['dl_rate_limit'] as number;
    info.up_rate_limit = json['up_rate_limit'] as number;
    info.dht_nodes = json['dht_nodes'] as number;
    info.connection_status = json['connection_status'] as string;
    return info;
  }
}
