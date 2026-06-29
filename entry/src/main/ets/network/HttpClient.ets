import { http } from '@kit.NetworkKit';
import { AppConstants } from '../common/constants/AppConstants';
import { ApiResult } from '../model/ApiResult';
import { LogUtil } from '@pura/harmony-utils';

export class HttpClient {
  private baseUrl: string = '';
  private sid: string = '';
  private sidCookieName: string = 'SID';
  private apiKey: string = '';
  private origin: string = '';
  private request: http.HttpRequest | null = null;
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
    this.sidCookieName = 'SID';
  }

  getSid(): string {
    return this.sid;
  }

  setApiKey(apiKey: string): void {
    this.apiKey = apiKey;
  }

  clearApiKey(): void {
    this.apiKey = '';
  }

  clearAuth(): void {
    this.sid = '';
    this.sidCookieName = 'SID';
    this.apiKey = '';
    this.destroyRequest();
  }

  clearSid(): void {
    this.sid = '';
    this.sidCookieName = 'SID';
    this.destroyRequest();
  }

  async get(path: string): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    LogUtil.info('GET ' + url + ' SID=' + (this.sid.length > 0 ? this.sid.substring(0, 8) + '...' : 'empty'));
    try {
      const request: http.HttpRequest = this.getRequest();
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildHeaders(),
        connectTimeout: AppConstants.HTTP_TIMEOUT,
        readTimeout: AppConstants.HTTP_TIMEOUT,
      });
      const code: number = response.responseCode as number;
      LogUtil.info('GET ' + path + ' response: ' + code);
      if (code === 403) {
        LogUtil.warn('Auth failed - SID may be invalid');
      }
      const result: ApiResult<string> = this.handleResponse(response);
      return result;
    } catch (err) {
      LogUtil.error('GET error: ' + JSON.stringify(err));
      return ApiResult.fail<string>('网络请求失败');
    }
  }

  async post(path: string, params: Record<string, string>): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    LogUtil.info('POST ' + url);
    try {
      const request: http.HttpRequest = this.getRequest();
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
      return result;
    } catch (err) {
      LogUtil.error('POST error: ' + JSON.stringify(err));
      return ApiResult.fail<string>('网络请求失败');
    }
  }

  async postMultipart(path: string, formFields: Record<string, string>, filePath: string, fileName: string): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    LogUtil.info('POST (multipart) ' + url + ' file=' + fileName);
    try {
      const request: http.HttpRequest = this.getRequest();
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
      return result;
    } catch (err) {
      LogUtil.error('Multipart POST error: ' + JSON.stringify(err));
      return ApiResult.fail<string>('文件上传失败');
    }
  }

  async postForLogin(path: string, params: Record<string, string>): Promise<ApiResult<string>> {
    const url: string = this.baseUrl + path;
    LogUtil.info('POST (login) ' + url);
    try {
      const request: http.HttpRequest = this.getRequest();
      const body: string = this.encodeFormData(params);
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'text/plain',
          'Cache-Control': 'no-cache',
        },
        extraData: body,
        connectTimeout: AppConstants.HTTP_TIMEOUT,
        readTimeout: AppConstants.HTTP_TIMEOUT,
      });

      LogUtil.info('Login response code: ' + response.responseCode);
      this.logLoginResponseDiagnostics(response);

      const statusCode: number = response.responseCode as number;
      if (statusCode === 204) {
        const hasSid: boolean = this.extractSidFromResponse(response);
        if (!hasSid) {
          LogUtil.warn('Login returned 204 without SID cookie, continue with session verification');
        }
        return ApiResult.ok<string>('Ok.', statusCode);
      }
      if (statusCode === 200 || statusCode === 201) {
        const resultStr: string = typeof response.result === 'string' ? (response.result as string).trim() : JSON.stringify(response.result);
        LogUtil.info('Login result: ' + resultStr);
        if (resultStr === 'Ok.') {
          this.extractSidFromResponse(response);
        } else {
          LogUtil.warn('Login rejected: ' + resultStr + ', SID not extracted');
        }
        return ApiResult.ok<string>(resultStr, statusCode);
      }
      return ApiResult.fail<string>(this.buildHttpErrorMessage('登录失败', response), statusCode);
    } catch (err) {
      const errMsg: string = '' + err;
      LogUtil.error('Login error: ' + errMsg);
      return ApiResult.fail<string>('登录请求失败');
    }
  }

  private getRequest(): http.HttpRequest {
    if (this.request === null) {
      this.request = http.createHttp();
    }
    return this.request;
  }

  private destroyRequest(): void {
    if (this.request !== null) {
      this.request.destroy();
      this.request = null;
    }
  }

  private extractSidFromResponse(response: http.HttpResponse): boolean {
    try {
      const headerRecord: Record<string, Object> = response.header as Record<string, Object>;
      const setCookie: string = this.readHeaderValue(headerRecord, 'Set-Cookie');
      if (this.extractSidFromCookie(setCookie)) {
        return true;
      }

      if (this.extractSidFromCookie(this.readHeaderValue(headerRecord, 'Cookie'))) {
        return true;
      }

      if (this.extractSidFromCookie(response.cookies)) {
        return true;
      }

      const headerStr: string = JSON.stringify(response.header);
      LogUtil.info('Response headers: ' + headerStr);
      if (this.extractSidFromCookie(headerStr)) {
        return this.sid.length > 0;
      } else {
        LogUtil.warn('No SID found in response headers');
      }
    } catch (err) {
      LogUtil.warn('SID extraction skipped: ' + err);
    }
    return false;
  }

  private logLoginResponseDiagnostics(response: http.HttpResponse): void {
    try {
      const headerRecord: Record<string, Object> = response.header as Record<string, Object>;
      const keys: string[] = Object.keys(headerRecord);
      const setCookie: string = this.readHeaderValue(headerRecord, 'Set-Cookie');
      const cookieHeader: string = this.readHeaderValue(headerRecord, 'Cookie');
      const sidInSetCookie: boolean = this.hasSidCookie(setCookie);
      const sidInCookieHeader: boolean = this.hasSidCookie(cookieHeader);
      const sidInResponseCookies: boolean = this.hasSidCookie(response.cookies);
      LogUtil.info('Login response header keys: ' + keys.join(','));
      LogUtil.info('Login response Set-Cookie length=' + setCookie.length +
        ', Cookie length=' + cookieHeader.length +
        ', response.cookies length=' + response.cookies.length);
      LogUtil.info('Login response SID flags: setCookie=' + sidInSetCookie +
        ', cookieHeader=' + sidInCookieHeader +
        ', responseCookies=' + sidInResponseCookies);
    } catch (err) {
      LogUtil.warn('Login diagnostics skipped: ' + err);
    }
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json';
    if (this.apiKey.length > 0) {
      headers['Authorization'] = 'Bearer ' + this.apiKey;
    } else if (this.sid.length > 0) {
      headers['Cookie'] = this.sidCookieName + '=' + this.sid;
    }
    return headers;
  }

  private handleResponse(response: http.HttpResponse): ApiResult<string> {
    const statusCode: number = response.responseCode as number;
    if (statusCode === 200 || statusCode === 201) {
      const result: string = this.responseResultToString(response);
      return ApiResult.ok<string>(result, statusCode);
    }
    if (statusCode === 401 || statusCode === 403) {
      return ApiResult.fail<string>(this.buildHttpErrorMessage('认证失败，请重新登录', response), statusCode);
    }
    return ApiResult.fail<string>(this.buildHttpErrorMessage('请求失败', response), statusCode);
  }

  private buildHttpErrorMessage(prefix: string, response: http.HttpResponse): string {
    const statusCode: number = response.responseCode as number;
    const body: string = this.responseResultToString(response).trim();
    if (body.length > 0) {
      return prefix + ' (' + statusCode + '): ' + body;
    }
    return prefix + ' (' + statusCode + ')';
  }

  private responseResultToString(response: http.HttpResponse): string {
    if (typeof response.result === 'string') {
      return response.result as string;
    }
    return JSON.stringify(response.result);
  }

  private encodeFormData(params: Record<string, string>): string {
    const parts: string[] = [];
    const keys: string[] = Object.keys(params);
    for (const key of keys) {
      const value: string = params[key];
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
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

  private hasSidCookie(cookie: string): boolean {
    return this.findSidCookiePair(cookie).length > 0;
  }

  private extractSidFromCookie(cookie: string): boolean {
    const pair: string = this.findSidCookiePair(cookie);
    if (pair.length === 0) {
      return false;
    }
    const equalIndex: number = pair.indexOf('=');
    this.sidCookieName = pair.substring(0, equalIndex);
    this.sid = pair.substring(equalIndex + 1);
    LogUtil.info('Extracted SID cookie: ' + this.sidCookieName + '=' + this.sid.substring(0, 8) + '...');
    return true;
  }

  private findSidCookiePair(cookie: string): string {
    const normalizedCookie: string = cookie.toLowerCase();
    const sidIndex: number = normalizedCookie.indexOf('sid');
    if (sidIndex < 0) {
      return '';
    }
    let start: number = sidIndex;
    while (start > 0) {
      const previous: string = cookie.substring(start - 1, start);
      if (previous === ';' || previous === ',' || previous === '"' || previous === '[') {
        break;
      }
      start--;
    }
    while (start < cookie.length && this.isCookieSeparator(cookie.substring(start, start + 1))) {
      start++;
    }
    const equalIndex: number = cookie.indexOf('=', start);
    const nextSeparator: number = this.findNextCookieSeparator(cookie, start);
    if (equalIndex <= start || equalIndex > nextSeparator) {
      return '';
    }
    const name: string = cookie.substring(start, equalIndex);
    if (name.toLowerCase().indexOf('sid') < 0) {
      return '';
    }
    let end: number = nextSeparator;
    if (end <= equalIndex + 1) {
      end = cookie.length;
    }
    return cookie.substring(start, end);
  }

  private findNextCookieSeparator(cookie: string, start: number): number {
    let end: number = cookie.indexOf(';', start);
    if (end < 0) {
      end = cookie.indexOf(',', start);
    }
    if (end < 0) {
      end = cookie.indexOf('"', start);
    }
    if (end < 0) {
      end = cookie.indexOf(']', start);
    }
    if (end < 0) {
      end = cookie.length;
    }
    return end;
  }

  private isCookieSeparator(char: string): boolean {
    return char === ';' || char === ',' || char === '"' || char === '[' || char === ' ';
  }
}
