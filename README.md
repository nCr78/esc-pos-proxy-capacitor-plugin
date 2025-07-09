# esc-pos-proxy-capacitor-plugin

![PRINTER-STUFF](https://github.com/nCr78/esc-pos-proxy-capacitor-plugin/blob/master/printer-stuff.png)

[![npm version](https://badge.fury.io/js/esc-pos-proxy-capacitor-plugin.svg)](https://badge.fury.io/js/esc-pos-proxy-capacitor-plugin)

## Install

```bash
npm install esc-pos-proxy-capacitor-plugin
npx cap sync
```

## API

<docgen-index>

* [`print(...)`](#print)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### print(...)

```typescript
print(options: { message: Uint8Array; ip: string; port: number; }) => Promise<{ status: string; }>
```

| Param         | Type                                                                                      |
| ------------- | ----------------------------------------------------------------------------------------- |
| **`options`** | <code>{ message: <a href="#uint8array">Uint8Array</a>; ip: string; port: number; }</code> |

**Returns:** <code>Promise&lt;{ status: string; }&gt;</code>

</docgen-api>
