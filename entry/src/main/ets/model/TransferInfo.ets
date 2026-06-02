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
    info.dl_info_speed = TransferInfo.readNumber(json['dl_info_speed']);
    info.up_info_speed = TransferInfo.readNumber(json['up_info_speed']);
    info.dl_info_data = TransferInfo.readNumber(json['dl_info_data']);
    info.up_info_data = TransferInfo.readNumber(json['up_info_data']);
    info.dl_rate_limit = TransferInfo.readNumber(json['dl_rate_limit']);
    info.up_rate_limit = TransferInfo.readNumber(json['up_rate_limit']);
    info.dht_nodes = TransferInfo.readNumber(json['dht_nodes']);
    info.connection_status = TransferInfo.readString(json['connection_status']);
    return info;
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

  private static readString(value: Object): string {
    if (typeof value !== 'string') {
      return '';
    }
    return value as string;
  }
}
