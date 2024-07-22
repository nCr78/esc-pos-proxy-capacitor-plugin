import { registerPlugin } from '@capacitor/core';

import type { ESCPOSProxyPlugin } from './definitions';

const ESCPOSProxy = registerPlugin<ESCPOSProxyPlugin>('ESCPOSProxy', {
  web: () => import('./web').then(m => new m.ESCPOSProxyWeb()),
});

export * from './definitions';
export { ESCPOSProxy };
