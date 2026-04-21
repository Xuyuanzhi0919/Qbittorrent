import { http } from '@kit.NetworkKit';
import { AppConstants } from '../common/constants/AppConstants';
import { ApiResult } from '../model/ApiResult';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class HttpClient {
  private baseUrl: string = '';
  private sid: string = '';
  private static instance: HttpClient | null = null;

  static getInstance(): HttpClient {
    if (HttpClient.instance === null) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  setBaseUrl(url: string): void {
    if (url.endsWith('/')) {
      this.baseUrl = url.substring(0, url.length - 1);
    } else {
      this.baseUrl = url;
    }
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  setSid(sid: string): void {
    this.sid = sid;
  }

  getSid(): string {
    return this.sid;
  }

  clearSid(): void {
    this.sid = '';
  }

  async get(path: string): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `GET ${url} SID=${this.sid.length > 0 ? this.sid.substring(0, 8) + '...' : 'empty'}`);
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildHeaders(),
        connectTimeout: AppConstants.HTTP_TIMEOUT,
        readTimeout: AppConstants.HTTP_TIMEOUT,
      });
      const code: number = response.responseCode as number;
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `GET ${path} response: ${code}`);
      if (code === 403) {
        hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'Auth failed - SID may be invalid');
      }
      const result: ApiResult<string> = this.handleResponse(response);
      request.destroy();
      request = null;
      return result;
    } catch (err) {
      if (request !== null) {
        request.destroy();
      }
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `GET error: ${JSON.stringify(err)}`);
      return ApiResult.fail<string>('网络请求失败');
    }
  }

  async post(path: string, params: Record<string, string>): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `POST ${url}`);
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const body: string = this.encodeFormData(params);
      const headers: Record<string, string> = this.buildHeaders();
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        connectTimeout: AppConstants.HTTP_TIMEOUT,
        readTimeout: AppConstants.HTTP_TIMEOUT,
      });
      const result: ApiResult<string> = this.handleResponse(response);
      request.destroy();
      request = null;
      return result;
    } catch (err) {
      if (request !== null) {
        request.destroy();
      }
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `POST error: ${JSON.stringify(err)}`);
      return ApiResult.fail<string>('网络请求失败');
    }
  }

  async postMultipart(path: string, formFields: Record<string, string>, filePath: string, fileName: string): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `POST (multipart) ${url} file=${fileName}`);
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const headers: Record<string, string> = this.buildHeaders();
      const multiFormDataList: http.MultiFormData[] = [
        {
          name: 'torrents',
          contentType: 'application/x-bittorrent',
          filePath: filePath,
          remoteFileName: fileName,
        }
      ];
      const fieldKeys: string[] = Object.keys(formFields);
      for (const key of fieldKeys) {
        multiFormDataList.push({
          name: key,
          contentType: 'text/plain; charset=UTF-8',
          data: formFields[key],
        });
      }
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        multiFormDataList: multiFormDataList,
        connectTimeout: AppConstants.HTTP_TIMEOUT,
        readTimeout: 60000,
      });
      const result: ApiResult<string> = this.handleResponse(response);
      request.destroy();
      request = null;
      return result;
    } catch (err) {
      if (request !== null) {
        request.destroy();
      }
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Multipart POST error: ${JSON.stringify(err)}`);
      return ApiResult.fail<string>('文件上传失败');
    }
  }

  async postForLogin(path: string, params: Record<string, string>): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `POST (login) ${url}`);
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const body: string = this.encodeFormData(params);
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'text/plain',
          'Cache-Control': 'no-cache',
          'Cookie': '',
        },
        extraData: body,
        connectTimeout: AppConstants.HTTP_TIMEOUT,
        readTimeout: AppConstants.HTTP_TIMEOUT,
      });

      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Login response code: ${response.responseCode}`);

      const statusCode: number = response.responseCode as number;
      if (statusCode === 200 || statusCode === 201) {
        const resultStr: string = typeof response.result === 'string' ? (response.result as string).trim() : JSON.stringify(response.result);
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Login result: ${resultStr}`);
        if (resultStr === 'Ok.') {
          this.extractSidFromResponse(response);
        } else {
          hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Login rejected: ${resultStr}, SID not extracted`);
        }
        request.destroy();
        return ApiResult.ok<string>(resultStr, statusCode);
      }
      request.destroy();
      return ApiResult.fail<string>(`登录失败 (${statusCode})`, statusCode);
    } catch (err) {
      if (request !== null) {
        request.destroy();
      }
      const errMsg: string = `${err}`;
      hilog.error(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Login error: ${errMsg}`);
      return ApiResult.fail<string>('登录请求失败');
    }
  }

  private extractSidFromResponse(response: http.HttpResponse): boolean {
    try {
      // Serialize headers to string and search for SID
      const headerStr: string = JSON.stringify(response.header);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Response headers: ${headerStr}`);
      const idx: number = headerStr.indexOf('SID=');
      if (idx >= 0) {
        const start: number = idx + 4;
        const end: number = headerStr.indexOf(';', start);
        if (end > start) {
          this.sid = headerStr.substring(start, end);
        } else {
          // SID might be at end of string or followed by quote
          const quoteEnd: number = headerStr.indexOf('"', start);
          if (quoteEnd > start) {
            this.sid = headerStr.substring(start, quoteEnd);
          } else {
            this.sid = headerStr.substring(start);
          }
        }
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Extracted SID: ${this.sid.substring(0, 8)}...`);
        return this.sid.length > 0;
      } else {
        hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, 'No SID found in response headers');
      }
    } catch (err) {
      hilog.warn(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `SID extraction skipped: ${err}`);
    }
    return false;
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json';
    if (this.sid.length > 0) {
      headers['Cookie'] = `SID=${this.sid}`;
    }
    return headers;
  }

  private handleResponse(response: http.HttpResponse): ApiResult<string> {
    const statusCode: number = response.responseCode as number;
    if (statusCode === 200 || statusCode === 201) {
      const result: string = typeof response.result === 'string' ? response.result as string : JSON.stringify(response.result);
      return ApiResult.ok<string>(result, statusCode);
    }
    if (statusCode === 401 || statusCode === 403) {
      return ApiResult.fail<string>('认证失败，请重新登录', statusCode);
    }
    return ApiResult.fail<string>(`请求失败 (${statusCode})`, statusCode);
  }

  private encodeFormData(params: Record<string, string>): string {
    const parts: string[] = [];
    const keys: string[] = Object.keys(params);
    for (const key of keys) {
      const value: string = params[key];
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    }
    return parts.join('&');
  }
}
