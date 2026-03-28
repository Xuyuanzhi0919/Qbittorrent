export class ApiResult<T> {
  success: boolean = false;
  data: T | null = null;
  error: string = '';
  statusCode: number = 0;

  static ok<U>(data: U, statusCode: number = 200): ApiResult<U> {
    const result: ApiResult<U> = new ApiResult<U>();
    result.success = true;
    result.data = data;
    result.statusCode = statusCode;
    return result;
  }

  static fail<U>(error: string, statusCode: number = 0): ApiResult<U> {
    const result: ApiResult<U> = new ApiResult<U>();
    result.success = false;
    result.error = error;
    result.statusCode = statusCode;
    return result;
  }
}
