import { crc32, inflateSync } from 'node:zlib';

const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const maxBytes = 4 * 1024 * 1024;

export function sanitizePng(encoded) {
  if (typeof encoded !== 'string' || !encoded.length || encoded.length > Math.ceil(maxBytes / 3) * 4 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded) || encoded.length % 4) {
    throw new Error('Choose a PNG screenshot up to 4 MiB after conversion.');
  }
  const buffer = Buffer.from(encoded, 'base64');
  if (buffer.length > maxBytes || !buffer.subarray(0, 8).equals(signature)) throw new Error('Image is not a supported PNG.');
  const safeChunks = [signature];
  const data = [];
  let width, height, channels;
  let finished = false;
  let cursor = 8;
  while (cursor + 12 <= buffer.length && safeChunks.length < 1024) {
    const length = buffer.readUInt32BE(cursor);
    const end = cursor + 12 + length;
    if (end > buffer.length) break;
    const type = buffer.toString('ascii', cursor + 4, cursor + 8);
    const payload = buffer.subarray(cursor + 8, end - 4);
    if (!/^[A-Za-z]{4}$/.test(type) || crc32(buffer.subarray(cursor + 4, end - 4)) !== buffer.readUInt32BE(end - 4)) break;
    if (type === 'IHDR' && cursor === 8 && length === 13) {
      width = payload.readUInt32BE(0);
      height = payload.readUInt32BE(4);
      channels = payload[9] === 6 ? 4 : payload[9] === 2 ? 3 : 0;
      if (!width || !height || width > 1920 || height > 1200 || payload[8] !== 8 || !channels ||
          payload[10] || payload[11] || payload[12]) break;
      safeChunks.push(buffer.subarray(cursor, end));
    } else if (!channels) {
      break;
    } else if (type === 'IDAT') {
      data.push(payload);
      safeChunks.push(buffer.subarray(cursor, end));
    } else if (type === 'IEND' && length === 0 && data.length && end === buffer.length) {
      safeChunks.push(buffer.subarray(cursor, end));
      finished = true;
      break;
    } else if (type[0] === type[0].toUpperCase()) {
      break;
    }
    cursor = end;
  }
  if (!finished) throw new Error('PNG is damaged or exceeds the studio image limits.');
  const stride = width * channels + 1;
  const expected = stride * height;
  try {
    const pixels = inflateSync(Buffer.concat(data), { maxOutputLength: expected });
    if (pixels.length !== expected) throw new Error();
    for (let row = 0; row < height; row++) if (pixels[row * stride] > 4) throw new Error();
  } catch { throw new Error('PNG contains invalid pixel data.'); }
  return { width, height, bytes: Buffer.concat(safeChunks) };
}
