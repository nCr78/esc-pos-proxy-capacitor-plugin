import { WebPlugin } from '@capacitor/core';

import type { ESCPOSProxyPlugin, PrinterDescriptor } from './definitions';

export class ESCPOSProxyWeb extends WebPlugin implements ESCPOSProxyPlugin {
  async print(options: { message: Uint8Array, ip: string, port: number }): Promise<{ status: string }> {
    console.log('ECHO', options);
    return { status: 'printed' };
  }

  async ping(_options: { ip: string; port?: number }): Promise<{ online: boolean; rtt?: number }> {
    // Web cannot reach local printers; report unavailable.
    return { online: false };
  }

  async discover(_options?: { ports?: number[]; timeout?: number }): Promise<{ printers: PrinterDescriptor[] }> {
    // Discovery is not supported on web platform.
    const printers: PrinterDescriptor[] = [];
    return { printers };
  }
}
