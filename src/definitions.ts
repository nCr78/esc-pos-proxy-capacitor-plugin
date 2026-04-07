export interface ESCPOSProxyPlugin {
  /**
   * Send raw ESC/POS bytes to a network printer at the given IP/port.
   *
   * `message` must be a base64-encoded string. Callers that already hold a
   * Uint8Array should encode it with `btoa(String.fromCharCode(...bytes))` or
   * an equivalent helper before passing it in. Rejects with a descriptive
   * error if the socket fails to connect or write.
   */
  print(options: { message: string; ip: string; port: number }): Promise<{ status: string }>;

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
