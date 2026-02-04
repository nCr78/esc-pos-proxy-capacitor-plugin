export interface ESCPOSProxyPlugin {
  print(options: { message: Uint8Array, ip: string, port: number }): Promise<{ status: string }>;

  /**
   * Check whether a printer is reachable on the given IP/port.
   */
  ping(options: { ip: string; port?: number }): Promise<{ online: boolean; rtt?: number }>;

  /**
   * Discover ESC/POS-ready printers on the local network.
   * Ports default to common raw printing ports (9100/9101/9102).
   * Timeout is the maximum scan duration in milliseconds.
   */
  discover(options?: { ports?: number[]; timeout?: number }): Promise<{ printers: PrinterDescriptor[] }>;
}

export interface PrinterDescriptor {
  ip: string;
  port: number;
  source: 'scan' | 'mdns';
}
