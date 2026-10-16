import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/services/image_header.dart';

Uint8List _png(int width, int height) {
  final bytes = Uint8List(32);
  const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  bytes.setRange(0, magic.length, magic);
  bytes.setRange(12, 16, [0x49, 0x48, 0x44, 0x52]);
  void put32(int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  put32(16, width);
  put32(20, height);
  return bytes;
}

/// 构造一个 JPEG：SOI，任意个前置段，最后是 SOF0。
Uint8List _jpeg(int width, int height, {int extraSegments = 1}) {
  final bytes = Uint8List(128);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;

  var offset = 2;
  for (var i = 0; i < extraSegments; i++) {
    bytes[offset] = 0xFF;
    bytes[offset + 1] = 0xE0 + i;
    bytes[offset + 2] = 0x00;
    bytes[offset + 3] = 0x10;
    // 段长含 2 字节长度本身，再加 2 字节标记。
    offset += 18;
  }

  bytes[offset] = 0xFF;
  bytes[offset + 1] = 0xC0;
  bytes[offset + 2] = 0x00;
  bytes[offset + 3] = 0x11;
  bytes[offset + 4] = 0x08;
  void put16(int at, int value) {
    bytes[at] = (value >> 8) & 0xFF;
    bytes[at + 1] = value & 0xFF;
  }

  put16(offset + 5, height);
  put16(offset + 7, width);
  return bytes;
}

Uint8List _webpVp8x(int width, int height) {
  final bytes = Uint8List(32);
  bytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
  bytes.setRange(8, 12, [0x57, 0x45, 0x42, 0x50]);
  bytes.setRange(12, 16, [0x56, 0x50, 0x38, 0x58]);
  void put24(int at, int value) {
    bytes[at] = value & 0xFF;
    bytes[at + 1] = (value >> 8) & 0xFF;
    bytes[at + 2] = (value >> 16) & 0xFF;
  }

  put24(24, width - 1);
  put24(27, height - 1);
  return bytes;
}

Uint8List _webpVp8l(int width, int height) {
  final bytes = Uint8List(32);
  bytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
  bytes.setRange(8, 12, [0x57, 0x45, 0x42, 0x50]);
  bytes.setRange(12, 16, [0x56, 0x50, 0x38, 0x4C]);
  bytes[20] = 0x2F;
  final bits = ((width - 1) & 0x3FFF) | (((height - 1) & 0x3FFF) << 14);
  for (var i = 0; i < 4; i++) {
    bytes[21 + i] = (bits >> (8 * i)) & 0xFF;
  }
  return bytes;
}

Uint8List _webpVp8(int width, int height) {
  final bytes = Uint8List(40);
  bytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
  bytes.setRange(8, 12, [0x57, 0x45, 0x42, 0x50]);
  bytes.setRange(12, 16, [0x56, 0x50, 0x38, 0x20]);
  bytes[23] = 0x9D;
  bytes[24] = 0x01;
  bytes[25] = 0x2A;
  bytes[26] = width & 0xFF;
  bytes[27] = (width >> 8) & 0xFF;
  bytes[28] = height & 0xFF;
  bytes[29] = (height >> 8) & 0xFF;
  return bytes;
}

void expectSize(Uint8List bytes, int width, int height) {
  final size = readImageHeaderSize(bytes);
  expect(size, isNotNull, reason: 'length ${bytes.length}');
  expect(size!.width, width);
  expect(size.height, height);
}

void main() {
  group('readImageHeaderSize 读三种格式', () {
    test('PNG 宽高按大端放在 IHDR 之后', () {
      expectSize(_png(1200, 800), 1200, 800);
      expectSize(_png(1, 1), 1, 1);
      expectSize(_png(65535, 65535), 65535, 65535);
    });

    test('JPEG 宽高在 SOF 段内，按大端', () {
      expectSize(_jpeg(1080, 1920), 1080, 1920);
      expectSize(_jpeg(640, 480, extraSegments: 0), 640, 480);
    });

    test('JPEG 会跳过任意数量的前置段', () {
      expectSize(_jpeg(300, 200, extraSegments: 3), 300, 200);
    });

    test('WebP 三种子格式都能读', () {
      expectSize(_webpVp8x(2000, 1500), 2000, 1500);
      expectSize(_webpVp8l(333, 222), 333, 222);
      expectSize(_webpVp8(777, 888), 777, 888);
    });
  });

  group('readImageHeaderSize 拒绝坏数据', () {
    test('空、过短、纯垃圾都返回 null', () {
      expect(readImageHeaderSize(Uint8List(0)), isNull);
      expect(readImageHeaderSize(Uint8List(10)), isNull);
      expect(readImageHeaderSize(Uint8List(64)), isNull);
    });

    test('SOI 之后没有段标记返回 null', () {
      final bytes = Uint8List(64);
      bytes[0] = 0xFF;
      bytes[1] = 0xD8;
      expect(readImageHeaderSize(bytes), isNull);
    });

    test('RIFF 但不是 WEBP 返回 null', () {
      final bytes = _webpVp8(10, 10);
      bytes[8] = 0x41;
      expect(readImageHeaderSize(bytes), isNull);
    });

    test('WebP 未知子块返回 null', () {
      final bytes = Uint8List(32);
      bytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
      bytes.setRange(8, 12, [0x57, 0x45, 0x42, 0x50]);
      bytes.setRange(12, 16, [0x41, 0x4E, 0x4D, 0x46]);
      expect(readImageHeaderSize(bytes), isNull);
    });
  });
}
