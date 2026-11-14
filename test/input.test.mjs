import assert from 'node:assert/strict';
import { test } from 'node:test';

// input.js and platform/tizen.js touch these browser globals at load.
const classes = new Set();
globalThis.window = {};
globalThis.document = {
  documentElement: {
    classList: {
      contains: c => classes.has(c),
      toggle: (c, on) => (on ? classes.add(c) : classes.delete(c)),
    },
  },
  addEventListener() {},
  activeElement: null,
};
globalThis.requestAnimationFrame = () => 0;

const { inject, isFast } = await import('../app/js/input.js');

test('injected direction keys pressed in quick succession count as a held key', () => {
  inject('down');
  inject('down');
  assert.equal(isFast(), true);
});
