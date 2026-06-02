import { TransferInfo } from './TransferInfo';

export class SyncMainData {
  rid: number = 0;
  full_update: boolean = false;
  torrents: Record<string, Record<string, Object>> = {};
  torrents_removed: string[] = [];
  categories: Record<string, Object> = {};
  categories_removed: string[] = [];
  tags: string[] = [];
  tags_removed: string[] = [];
  server_state: TransferInfo | null = null;

  static fromJson(json: Record<string, Object>): SyncMainData {
    const data: SyncMainData = new SyncMainData();
    data.rid = SyncMainData.readNumber(json['rid']);
    data.full_update = SyncMainData.readBoolean(json['full_update']);

    const torrentsRaw: Object | undefined = json['torrents'];
    if (torrentsRaw !== undefined && typeof torrentsRaw === 'object' && !Array.isArray(torrentsRaw)) {
      data.torrents = torrentsRaw as Record<string, Record<string, Object>>;
    }

    const torrentsRemovedRaw: Object | undefined = json['torrents_removed'];
    if (Array.isArray(torrentsRemovedRaw)) {
      data.torrents_removed = SyncMainData.readStringArray(torrentsRemovedRaw as Object[]);
    }

    const categoriesRaw: Object | undefined = json['categories'];
    if (categoriesRaw !== undefined && typeof categoriesRaw === 'object' && !Array.isArray(categoriesRaw)) {
      data.categories = categoriesRaw as Record<string, Object>;
    }

    const categoriesRemovedRaw: Object | undefined = json['categories_removed'];
    if (Array.isArray(categoriesRemovedRaw)) {
      data.categories_removed = SyncMainData.readStringArray(categoriesRemovedRaw as Object[]);
    }

    const tagsRaw: Object | undefined = json['tags'];
    if (Array.isArray(tagsRaw)) {
      data.tags = SyncMainData.readStringArray(tagsRaw as Object[]);
    }

    const tagsRemovedRaw: Object | undefined = json['tags_removed'];
    if (Array.isArray(tagsRemovedRaw)) {
      data.tags_removed = SyncMainData.readStringArray(tagsRemovedRaw as Object[]);
    }

    const serverStateRaw: Object | undefined = json['server_state'];
    if (serverStateRaw !== undefined && typeof serverStateRaw === 'object' && !Array.isArray(serverStateRaw)) {
      data.server_state = TransferInfo.fromJson(serverStateRaw as Record<string, Object>);
    }

    return data;
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

  private static readBoolean(value: Object): boolean {
    if (typeof value !== 'boolean') {
      return false;
    }
    return value as boolean;
  }

  private static readStringArray(values: Object[]): string[] {
    const result: string[] = [];
    for (const item of values) {
      if (typeof item === 'string') {
        result.push(item as string);
      }
    }
    return result;
  }
}
