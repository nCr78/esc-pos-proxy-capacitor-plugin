import { WebPlugin } from '@capacitor/core';

import type { ESCPOSProxyPlugin } from './definitions';

export class ESCPOSProxyWeb extends WebPlugin implements ESCPOSProxyPlugin {
  async print(options: { message: Uint8Array, ip: string, port: number }): Promise<{ status: string }> {
    console.log('ECHO', options);
    return { status: 'printed' };
  }
}
