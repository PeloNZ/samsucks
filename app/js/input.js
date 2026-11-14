// Remote input. Navigation keys are applied at most once per animation frame
// (extra presses of the same key in one frame collapse), so holding a direction
// can never queue up work and the UI stops the instant the key is released.
// While a key is held, <html> gets .fast which shortens transitions.
import { actionFor } from './platform/tizen.js';

const NAV = { left: 1, right: 1, up: 1, down: 1 };

let handler = null;
let pending = null;
let scheduled = false;
let fastTimer = 0;
let lastNavAt = 0;
const root = document.documentElement;

export const stats = { keyAt: 0, latency: 0 };

export function setHandler(fn) {
  handler = fn;
}

function setFast(on) {
  if (root.classList.contains('fast') !== on) root.classList.toggle('fast', on);
}

function flush() {
  if (!scheduled) return;
  scheduled = false;
  const action = pending;
  pending = null;
  if (action && handler) handler(action);
}

// Key presses and the dev remote's inject() both come through here.
function dispatch(action, repeat) {
  stats.keyAt = performance.now();
  if (!NAV[action]) {
    if (handler) handler(action);
    return;
  }
  const now = performance.now();
  const held = repeat || now - lastNavAt < 140;
  lastNavAt = now;
  if (held) {
    setFast(true);
    clearTimeout(fastTimer);
    fastTimer = setTimeout(() => setFast(false), 220);
  }
  pending = action;
  if (!scheduled) {
    scheduled = true;
    requestAnimationFrame(flush);
    // rAF pauses when the page is occluded; never let input stall on it.
    setTimeout(flush, 50);
  }
}

document.addEventListener(
  'keydown',
  e => {
    const action = actionFor(e);
    if (!action) return;
    // Let text inputs (search) handle their own keys except navigation out.
    const tag = document.activeElement && document.activeElement.tagName;
    if (tag === 'INPUT' && action !== 'back' && action !== 'down' && action !== 'up' && action !== 'enter') return;
    e.preventDefault();
    dispatch(action, e.repeat);
  },
  true,
);

// Feed an action through the same path as a real key press (dev remote).
export function inject(action) {
  dispatch(action, false);
}

document.addEventListener('keyup', () => {
  clearTimeout(fastTimer);
  fastTimer = setTimeout(() => setFast(false), 60);
});

export function isFast() {
  return root.classList.contains('fast');
}
