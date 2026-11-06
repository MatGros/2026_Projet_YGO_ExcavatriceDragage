#!/usr/bin/env node
// Decode the append-only DSH JSONL/Zstandard artifact using Node's built-in zstd.
// Output is machine-only JSON; transcript text is never printed to the console.
import fs from 'node:fs';
import {zstdDecompressSync} from 'node:zlib';

const [file, expectedId, rawOffset] = process.argv.slice(2);
if (!file || !expectedId || rawOffset === undefined) {
  process.stderr.write('usage: dsh_zstd_decode.mjs FILE SESSION_ID OFFSET|tail\n');
  process.exit(2);
}
const buffer = fs.readFileSync(file);
const magic = 0xfd2fb528;
const frames = [];
let offset = 0;
let tornStart;
if (buffer.length >= 4 && buffer.readUInt32LE(0) === magic) {
  while (offset < buffer.length) {
    const start = offset;
    if (buffer.length - offset < 5) { tornStart = start; break; }
    if (buffer.readUInt32LE(offset) !== magic) throw new Error(`invalid zstd frame at ${offset}`);
    offset += 4;
    const descriptor = buffer.readUInt8(offset++);
    if ((descriptor & 24) !== 0) throw new Error(`reserved zstd header bit at ${offset - 1}`);
    const sizeFlag = descriptor >>> 6;
    const single = (descriptor & 32) !== 0;
    const checksum = (descriptor & 4) !== 0;
    const dictFlag = descriptor & 3;
    const dictBytes = dictFlag === 3 ? 4 : dictFlag;
    const contentBytes = sizeFlag === 0 ? (single ? 1 : 0) : 1 << sizeFlag;
    const headerBytes = (single ? 0 : 1) + dictBytes + contentBytes;
    if (buffer.length - offset < headerBytes) { tornStart = start; break; }
    offset += headerBytes;
    let last = false;
    while (!last) {
      if (buffer.length - offset < 3) { tornStart = start; break; }
      const block = buffer.readUIntLE(offset, 3); offset += 3;
      last = Boolean(block & 1);
      const type = (block >>> 1) & 3;
      if (type === 3) throw new Error(`reserved zstd block at ${offset - 3}`);
      const bytes = type === 1 ? 1 : block >>> 3;
      if (buffer.length - offset < bytes) { tornStart = start; break; }
      offset += bytes;
    }
    if (tornStart !== undefined) break;
    if (checksum) {
      if (buffer.length - offset < 4) { tornStart = start; break; }
      offset += 4;
    }
    frames.push({start, end: offset});
  }
} else {
  frames.push({start: 0, end: buffer.length});
}

if (!frames.length) throw new Error('empty or incomplete DSH transcript');
const headerBytes = zstdDecompressSync(buffer.subarray(frames[0].start, frames[0].end));
const firstLine = headerBytes.toString('utf8').split('\n', 1)[0];
const header = JSON.parse(firstLine);
if (header?.type !== 'session' || header.id !== expectedId || !Number.isSafeInteger(header.version)) {
  throw new Error('DSH transcript header does not match the requested session ID');
}
const completeEnd = frames.at(-1).end;
let startOffset;
if (rawOffset === 'tail') startOffset = completeEnd;
else if (rawOffset === 'all') startOffset = frames[0].end;
else {
  startOffset = Number(rawOffset);
  if (!Number.isSafeInteger(startOffset) || startOffset < frames[0].end || startOffset > completeEnd ||
      (startOffset !== completeEnd && !frames.some(frame => frame.start === startOffset))) {
    throw new Error('invalid DSH frame cursor');
  }
}
const pieces = [];
if (rawOffset !== 'tail') {
  for (const frame of frames) {
    if (frame.start >= startOffset) pieces.push(zstdDecompressSync(buffer.subarray(frame.start, frame.end)));
  }
}
process.stdout.write(JSON.stringify({header, complete_end: completeEnd,
  payload: Buffer.concat(pieces).toString('base64')}));
