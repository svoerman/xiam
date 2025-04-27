/**
 * Phoenix LiveView Hooks
 * This file exports all hooks used in the application.
 */

import PasskeyHooks from './passkey_hooks';
import FlashHooks from './flash_hooks';

// Combine all hooks into a single object
const Hooks = {
  ...PasskeyHooks,
  ...FlashHooks
};

export default Hooks;
