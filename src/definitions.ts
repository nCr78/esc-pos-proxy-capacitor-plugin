export interface ESCPOSProxyPlugin {
  print(options: { message: Uint8Array, ip: string, port: number }): Promise<{ status: string }>;
}
