# esc-pos-proxy-capacitor-plugin

![PRINTER-STUFF](https://github.com/nCr78/esc-pos-proxy-capacitor-plugin/blob/master/printer-stuff.png)

[![npm version](https://badge.fury.io/js/esc-pos-proxy-capacitor-plugin.svg)](https://badge.fury.io/js/esc-pos-proxy-capacitor-plugin)

A Capacitor 8 plugin for talking to network-attached ESC/POS thermal printers over raw TCP. It can:

- **Print** — dispatch raw ESC/POS byte sequences to a printer (default port `9100`)
- **Ping** — check whether a printer is reachable and measure round-trip time
- **Discover** — find printers on the local network via mDNS (`_printer._tcp`, `_pdl-datastream._tcp`) plus a subnet scan on common raw-print ports (`9100`/`9101`/`9102`)

Native implementations are provided for **Android** and **iOS**. The web implementation is a no-op — browsers can't open raw TCP sockets to a printer.

## Install

```bash
npm install esc-pos-proxy-capacitor-plugin
npx cap sync
```

## Usage

```typescript
import { ESCPOSProxy } from 'esc-pos-proxy-capacitor-plugin';

// Raw ESC/POS bytes (init + "Hello" + line feed + cut), base64-encoded
const bytes = new Uint8Array([0x1b, 0x40, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x0a, 0x1d, 0x56, 0x00]);
const message = btoa(String.fromCharCode(...bytes));
await ESCPOSProxy.print({ ip: '192.168.1.50', port: 9100, message });

// Check if a printer is reachable
const { online, rtt } = await ESCPOSProxy.ping({ ip: '192.168.1.50', port: 9100 });

// Find printers on the local network
const { printers } = await ESCPOSProxy.discover({ timeout: 10000 });
// → [{ ip: '192.168.1.50', port: 9100, source: 'mdns' | 'scan' }, ...]
```

## API

<docgen-index>

* [`print(...)`](#print)
* [`ping(...)`](#ping)
* [`discover(...)`](#discover)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### print(...)

```typescript
print(options: { message: string; ip: string; port: number; }) => Promise<{ status: string; }>
```

Send raw ESC/POS bytes to a network printer at the given IP/port.

`message` must be a base64-encoded string. Callers that already hold a
Uint8Array should encode it with `btoa(String.fromCharCode(...bytes))` or
an equivalent helper before passing it in. Rejects with a descriptive
error if the socket fails to connect or write.

| Param         | Type                                                        |
| ------------- | ----------------------------------------------------------- |
| **`options`** | <code>{ message: string; ip: string; port: number; }</code> |

**Returns:** <code>Promise&lt;{ status: string; }&gt;</code>

--------------------


### ping(...)

```typescript
ping(options: { ip: string; port?: number; }) => Promise<{ online: boolean; rtt?: number; }>
```

Check whether a printer is reachable on the given IP/port.

| Param         | Type                                        |
| ------------- | ------------------------------------------- |
| **`options`** | <code>{ ip: string; port?: number; }</code> |

**Returns:** <code>Promise&lt;{ online: boolean; rtt?: number; }&gt;</code>

--------------------


### discover(...)

```typescript
discover(options?: { ports?: number[] | undefined; timeout?: number | undefined; } | undefined) => Promise<{ printers: PrinterDescriptor[]; }>
```

Discover ESC/POS-ready printers on the local network.
Ports default to common raw printing ports (9100/9101/9102).
Timeout is the maximum scan duration in milliseconds.

| Param         | Type                                                 |
| ------------- | ---------------------------------------------------- |
| **`options`** | <code>{ ports?: number[]; timeout?: number; }</code> |

**Returns:** <code>Promise&lt;{ printers: PrinterDescriptor[]; }&gt;</code>

--------------------


### Interfaces


#### PrinterDescriptor

| Prop         | Type                          |
| ------------ | ----------------------------- |
| **`ip`**     | <code>string</code>           |
| **`port`**   | <code>number</code>           |
| **`source`** | <code>'scan' \| 'mdns'</code> |

</docgen-api>
