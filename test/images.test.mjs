import assert from 'node:assert/strict';
import { test } from 'node:test';
import { setTimeout as sleep } from 'node:timers/promises';

// Browser globals that images.js, input.js and platform/tizen.js touch.
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
const started = [];
globalThis.Image = class {
  set src(url) {
    started.push(url);
  }
};
const fakeImg = () => ({ classList: { add() {}, remove() {} }, removeAttribute() {} });

const { inject } = await import('../app/js/input.js');
const { load } = await import('../app/js/ui/images.js');

test('poster downloads wait while a direction key is held, then start', async () => {
  inject('down');
  inject('down'); // two quick presses: held
  load(fakeImg(), 'http://plex/poster-1.jpg');
  assert.deepEqual(started, []);

  await sleep(400); // the held state clears 220 ms after the last press
  assert.deepEqual(started, ['http://plex/poster-1.jpg']);
});
