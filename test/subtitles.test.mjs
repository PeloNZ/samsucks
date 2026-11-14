import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { CueTrack, parseSubtitles } from '../app/js/player/subtitles.js';

describe('parseSubtitles', () => {
  test('reads SRT cues with comma milliseconds and strips markup', () => {
    const srt = '1\r\n00:00:01,500 --> 00:00:04,000\r\nHello <i>world</i>\r\n\r\n2\r\n01:02:03,040 --> 01:02:05,000\r\nSecond\r\nline\r\n';
    assert.deepEqual(parseSubtitles(srt, 'srt'), [
      { start: 1500, end: 4000, text: 'Hello world' },
      { start: 3723040, end: 3725000, text: 'Second\nline' },
    ]);
  });

  test('reads WebVTT cues without hours', () => {
    const vtt = 'WEBVTT\n\n00:01.000 --> 00:02.500 align:start\nShort form\n';
    assert.deepEqual(parseSubtitles(vtt, 'vtt'), [{ start: 1000, end: 2500, text: 'Short form' }]);
  });

  test('reads ASS dialogue in time order and drops override tags', () => {
    const ass = [
      '[Script Info]',
      '[Events]',
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
      'Dialogue: 0,0:00:05.00,0:00:06.00,Default,,0,0,0,,Later',
      'Dialogue: 0,0:00:01.50,0:00:03.00,Default,,0,0,0,,{\\i1}First, with comma\\Nnext',
    ].join('\n');
    assert.deepEqual(parseSubtitles(ass, 'ass'), [
      { start: 1500, end: 3000, text: 'First, with comma\nnext' },
      { start: 5000, end: 6000, text: 'Later' },
    ]);
  });
});

describe('CueTrack.at', () => {
  const cues = [
    { start: 1000, end: 2000, text: 'one' },
    { start: 5000, end: 6000, text: 'two' },
    { start: 90000, end: 91000, text: 'three' },
  ];

  test('shows a cue from its start up to, not including, its end', () => {
    const track = new CueTrack(cues);
    assert.equal(track.at(999), '');
    assert.equal(track.at(1000), 'one');
    assert.equal(track.at(1999), 'one');
    assert.equal(track.at(2000), '');
  });

  test('finds the right cue after seeking forward and back', () => {
    const track = new CueTrack(cues);
    assert.equal(track.at(90500), 'three');
    assert.equal(track.at(5500), 'two');
    assert.equal(track.at(1500), 'one');
  });

  test('shows overlapping cues together, earlier cue first', () => {
    const track = new CueTrack([
      { start: 0, end: 4000, text: 'top' },
      { start: 1000, end: 2000, text: 'bottom' },
    ]);
    assert.equal(track.at(1500), 'top\nbottom');
  });

  test('returns nothing for an empty track', () => {
    assert.equal(new CueTrack([]).at(0), '');
  });
});
