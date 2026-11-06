import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads the deliberately small subset of ZIP emitted by this app: stored
/// (uncompressed), unencrypted regular files, no ZIP64 or data descriptors.
/// This prevents allocation based on attacker-controlled inflated lengths and
/// independently checks CRCs without relying on a general-purpose decoder.
/// File names are returned as keys and never used to extract paths to disk.
Map<String, Uint8List> readStoredBackupFiles(
  Uint8List bytes, {
  required Map<String, int> limits,
  required int maxArchiveBytes,
}) {
  const invalid = FormatException('备份 ZIP 格式不正确或已损坏');
  try {
    if (bytes.length < 22 || bytes.length > maxArchiveBytes) throw invalid;
    final data = ByteData.sublistView(bytes);
    int u16(int offset) => data.getUint16(offset, Endian.little);
    int u32(int offset) => data.getUint32(offset, Endian.little);
    final eocd = bytes.length - 22;
    // App exports no comment. Reject trailing bytes, multipart and ZIP64.
    if (u32(eocd) != 0x06054b50 ||
        u16(eocd + 4) != 0 ||
        u16(eocd + 6) != 0 ||
        u16(eocd + 20) != 0) {
      throw invalid;
    }
    final count = u16(eocd + 10);
    if (count < 1 || count > limits.length || u16(eocd + 8) != count) {
      throw invalid;
    }
    final directorySize = u32(eocd + 12);
    final directoryOffset = u32(eocd + 16);
    if (directoryOffset + directorySize != eocd) throw invalid;
    var cursor = directoryOffset;
    var expectedLocalOffset = 0;
    final result = <String, Uint8List>{};
    for (var i = 0; i < count; i++) {
      if (cursor + 46 > eocd || u32(cursor) != 0x02014b50) throw invalid;
      final flags = u16(cursor + 8);
      final method = u16(cursor + 10);
      final crc = u32(cursor + 16);
      final compressed = u32(cursor + 20);
      final size = u32(cursor + 24);
      final nameLength = u16(cursor + 28);
      final extraLength = u16(cursor + 30);
      final commentLength = u16(cursor + 32);
      final disk = u16(cursor + 34);
      final fileType = (u32(cursor + 38) >> 16) & 0xf000;
      final local = u32(cursor + 42);
      if (u16(cursor + 6) > 20 ||
          (flags != 0 && flags != 0x800) ||
          method != 0 ||
          compressed != size ||
          (extraLength != 0 && extraLength != 9) ||
          commentLength != 0 ||
          disk != 0 ||
          (fileType != 0 && fileType != 0x8000) ||
          local != expectedLocalOffset ||
          local + 30 > directoryOffset ||
          cursor + 46 + nameLength + extraLength > eocd) {
        throw invalid;
      }
      // archive 4.6 emits a 9-byte extended modification timestamp in the
      // central record. It cannot change sizes, offsets, or decoding behavior.
      final extra = cursor + 46 + nameLength;
      if (extraLength == 9 &&
          (u16(extra) != 0x5455 ||
              u16(extra + 2) != 5 ||
              bytes[extra + 4] != 1)) {
        throw invalid;
      }
      final name = utf8.decode(
        bytes.sublist(cursor + 46, cursor + 46 + nameLength),
      );
      final limit = limits[name];
      if (limit == null || result.containsKey(name) || size > limit) {
        throw invalid;
      }
      if (u32(local) != 0x04034b50 ||
          u16(local + 4) > 20 ||
          u16(local + 6) != flags ||
          u16(local + 8) != method ||
          u32(local + 14) != crc ||
          u32(local + 18) != compressed ||
          u32(local + 22) != size ||
          u16(local + 26) != nameLength ||
          u16(local + 28) != 0) {
        throw invalid;
      }
      final contentStart = local + 30 + nameLength;
      final contentEnd = contentStart + size;
      if (contentEnd > directoryOffset ||
          utf8.decode(bytes.sublist(local + 30, contentStart)) != name) {
        throw invalid;
      }
      final content = Uint8List.sublistView(bytes, contentStart, contentEnd);
      if (getCrc32(content) != crc) throw invalid;
      result[name] = content;
      expectedLocalOffset = contentEnd;
      cursor += 46 + nameLength + extraLength;
    }
    if (cursor != eocd || expectedLocalOffset != directoryOffset) throw invalid;
    return result;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw invalid;
  }
}
