import { http } from '@kit.NetworkKit';

type JsonValue = string | number | boolean | null | JsonObject | JsonValue[];

interface JsonObject {
  [key: string]: JsonValue;
}

export class ZhihuApi {
  private static readonly DEFAULT_HEADERS: Record<string, string> = {
    'Accept': 'application/json, text/plain, */*',
    'User-Agent': 'ZhihuPlusNext/0.1.0 HarmonyOS'
  };

  static async getJson(url: string, headers: Record<string, string> = {}): Promise<JsonObject> {
    const client = http.createHttp();
    try {
      const response = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: {
          ...this.DEFAULT_HEADERS,
          ...headers
        }
      });

      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }

      const payload = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return JSON.parse(payload) as JsonObject;
    } finally {
      client.destroy();
    }
  }

  static buildSignedRequestTodo(): string {
    return 'TODO: port zse96 signing bridge and cookie refresh flow from Android AccountData/Utils.';
  }
}
