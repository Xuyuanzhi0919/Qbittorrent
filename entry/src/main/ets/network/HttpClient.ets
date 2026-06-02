import { http } from '@kit.NetworkKit';
import { AppConstants } from '../common/constants/AppConstants';
import { ApiResult } from '../model/ApiResult';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class HttpClient {
  private baseUrl: string = '';
  private sid: string = '';
  private origin: string = '';
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
    this.origin = this.extractOrigin(this.baseUrl);
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
          'Referer': this.origin,
          'Origin': this.origin,
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
      const headerRecord: Record<string, Object> = response.header as Record<string, Object>;
      const setCookie: string = this.readHeaderValue(headerRecord, 'Set-Cookie');
      const sidFromCookie: string = this.extractSidFromCookie(setCookie);
      if (sidFromCookie.length > 0) {
        this.sid = sidFromCookie;
        hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Extracted SID: ${this.sid.substring(0, 8)}...`);
        return true;
      }

      const headerStr: string = JSON.stringify(response.header);
      hilog.info(AppConstants.LOG_DOMAIN, AppConstants.LOG_TAG, `Response headers: ${headerStr}`);
      const sidFromSerialized: string = this.extractSidFromCookie(headerStr);
      if (sidFromSerialized.length > 0) {
        this.sid = sidFromSerialized;
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
    headers['Referer'] = this.origin;
    headers['Origin'] = this.origin;
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

  private extractOrigin(url: string): string {
    const schemeEnd: number = url.indexOf('://');
    if (schemeEnd < 0) {
      return url;
    }
    const pathStart: number = url.indexOf('/', schemeEnd + 3);
    if (pathStart < 0) {
      return url;
    }
    return url.substring(0, pathStart);
  }

  private readHeaderValue(headers: Record<string, Object>, name: string): string {
    const keys: string[] = Object.keys(headers);
    const target: string = name.toLowerCase();
    for (const key of keys) {
      if (key.toLowerCase() === target) {
        const value: Object = headers[key];
        if (typeof value === 'string') {
          return value as string;
        }
        if (Array.isArray(value)) {
          return (value as Object[]).join(';');
        }
        return JSON.stringify(value);
      }
    }
    return '';
  }

  private extractSidFromCookie(cookie: string): string {
    const idx: number = cookie.indexOf('SID=');
    if (idx < 0) {
      return '';
    }
    const start: number = idx + 4;
    let end: number = cookie.indexOf(';', start);
    if (end <= start) {
      end = cookie.indexOf('"', start);
    }
    if (end <= start) {
      end = cookie.indexOf(',', start);
    }
    if (end <= start) {
      end = cookie.length;
    }
    return cookie.substring(start, end);
  }
}
