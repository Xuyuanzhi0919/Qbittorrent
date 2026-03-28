export class FormatUtils {
  static formatFileSize(bytes: number): string {
    if (bytes < 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return `${bytes.toFixed(0)} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
    return `${(bytes / (1024 * 1024 * 1024 * 1024)).toFixed(2)} TB`;
  }

  static formatSpeed(bytesPerSecond: number): string {
    return FormatUtils.formatFileSize(bytesPerSecond) + '/s';
  }

  static formatProgress(progress: number): string {
    return `${(progress * 100).toFixed(1)}%`;
  }

  static formatEta(seconds: number): string {
    if (seconds < 0 || seconds === 8640000) {
      return '∞';
    }
    if (seconds < 60) {
      return `${seconds.toFixed(0)}秒`;
    }
    if (seconds < 3600) {
      const minutes: number = Math.floor(seconds / 60);
      const secs: number = seconds % 60;
      return `${minutes}分${secs.toFixed(0)}秒`;
    }
    const hours: number = Math.floor(seconds / 3600);
    const minutes: number = Math.floor((seconds % 3600) / 60);
    return `${hours}时${minutes}分`;
  }

  static formatTimestamp(timestamp: number): string {
    if (timestamp <= 0) {
      return '-';
    }
    const date: Date = new Date(timestamp * 1000);
    const year: number = date.getFullYear();
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    const hours: string = date.getHours().toString().padStart(2, '0');
    const minutes: string = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  static formatRatio(ratio: number): string {
    if (ratio < 0) {
      return '∞';
    }
    return ratio.toFixed(2);
  }

  static formatDuration(seconds: number): string {
    if (seconds < 60) {
      return `${seconds.toFixed(0)}秒`;
    }
    if (seconds < 3600) {
      return `${(seconds / 60).toFixed(0)}分钟`;
    }
    if (seconds < 86400) {
      return `${(seconds / 3600).toFixed(1)}小时`;
    }
    return `${(seconds / 86400).toFixed(1)}天`;
  }
}
