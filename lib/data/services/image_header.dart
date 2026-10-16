import 'dart:typed_data';

/// 从文件头读出图片的像素尺寸。
///
/// 不解码像素，所以仓储层拿尺寸不需要碰图片编解码器。这一版 Flutter 的
/// `ui.decodeImageFromList` 没有失败回调，用文件头判定格式就不会留下一个
/// 永远不完成的 Future。
({int width, int height})? readImageHeaderSize(Uint8List bytes) {
  if (bytes.length < 26) return null;
  return _png(bytes) ?? _jpeg(bytes) ?? _webp(bytes);
}

({int width, int height})? _png(Uint8List b) {
  const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < magic.length; i++) {
    if (b[i] != magic[i]) return null;
  }
  if (b.length < 24) return null;
  // 8 字节签名加 4 字节长度加 4 字节 'IHDR'，之后是宽高。
  return (_be32(b, 16), _be32(b, 20));
}

({int width, int height})? _jpeg(Uint8List b) {
  if (b[0] != 0xFF || b[1] != 0xD8) return null;
  var offset = 2;
  while (offset + 9 < b.length) {
    if (b[offset] != 0xFF) return null;
    final marker = b[offset + 1];
    // SOF0 到 SOF15，排除 JPG、DHT 与 DAC。
    if (marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC) {
      // 2 字节段长，1 字节精度，2 字节高，2 字节宽。
      return (_be16(b, offset + 7), _be16(b, offset + 5));
    }
    final segmentLength = (b[offset + 2] << 8) | b[offset + 3];
    if (segmentLength < 2) return null;
    offset += 2 + segmentLength;
  }
  return null;
}

({int width, int height})? _webp(Uint8List b) {
  if (b[0] != 0x52 || b[1] != 0x49 || b[2] != 0x46 || b[3] != 0x46) return null;
  if (b[8] != 0x57 || b[9] != 0x45 || b[10] != 0x42 || b[11] != 0x50) return null;

  final chunk = String.fromCharCodes(b.sublist(12, 16));
  switch (chunk) {
    case 'VP8X':
      if (b.length < 30) return null;
      return (
        1 + _u24le(b, 24),
        1 + _u24le(b, 27),
      );
    case 'VP8L':
      if (b.length < 26) return null;
      // 1 字节签名之后是 14 位宽减 1、14 位高减 1。
      final bits = _le32(b, 21);
      return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8 ':
      // 3 字节帧标签之后是同步码，同步码之后是宽高。
      const sync = 0x9D;
      for (var i = 20; i + 8 < b.length; i++) {
        if (b[i] != sync) continue;
        return (_le16(b, i + 3), _le16(b, i + 5));
      }
      return null;
    default:
      return null;
  }
}

int _be32(Uint8List b, int offset) =>
    (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];

int _be16(Uint8List b, int offset) => (b[offset] << 8) | b[offset + 1];

int _le32(Uint8List b, int offset) =>
    b[offset] | (b[offset + 1] << 8) | (b[offset + 2] << 16) | (b[offset + 3] << 24);

int _le16(Uint8List b, int offset) => b[offset] | (b[offset + 1] << 8);

int _u24le(Uint8List b, int offset) =>
    b[offset] | (b[offset + 1] << 8) | (b[offset + 2] << 16);
