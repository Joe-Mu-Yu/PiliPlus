import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class CoupleSpacePickedMedia {
  const CoupleSpacePickedMedia({
    required this.imagePath,
    this.videoPath,
    this.width,
    this.height,
    this.temporaryPaths = const <String>{},
  });

  final String imagePath;
  final String? videoPath;
  final int? width;
  final int? height;
  final Set<String> temporaryPaths;

  bool get isLivePhoto => videoPath?.isNotEmpty == true;

  Future<void> cleanup() {
    for (final path in temporaryPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
        final parent = file.parent;
        if (parent.existsSync() && parent.listSync().isEmpty) {
          parent.deleteSync();
        }
      } catch (_) {}
    }
    return Future.value();
  }
}

class CoupleSpaceMediaPicker {
  CoupleSpaceMediaPicker({
    MethodChannel? channel,
    bool? isIOS,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _isIOS = isIOS ?? Platform.isIOS;

  static const _channelName = 'hyper_piliplus/couple_space_media';
  final MethodChannel _channel;
  final bool _isIOS;

  Future<List<CoupleSpacePickedMedia>> pick({required int limit}) async {
    if (limit <= 0) return const [];
    if (_isIOS) return _pickIos(limit);

    final files = await FilePicker.pickFiles(type: FileType.image);
    final picked = <CoupleSpacePickedMedia>[];
    for (final file in files.take(limit)) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      final motionVideo = await MotionPhotoExtractor.extract(File(path));
      final dimensions = motionVideo == null
          ? const (null, null)
          : await _imageDimensions(path);
      picked.add(
        CoupleSpacePickedMedia(
          imagePath: path,
          videoPath: motionVideo?.path,
          width: dimensions.$1,
          height: dimensions.$2,
          temporaryPaths: {
            if (motionVideo != null) motionVideo.path,
          },
        ),
      );
    }
    return picked;
  }

  Future<List<CoupleSpacePickedMedia>> _pickIos(int limit) async {
    final rawItems = await _channel.invokeListMethod<Object?>('pickMedia', {
      'limit': limit,
    });
    if (rawItems == null) return const [];
    return rawItems.map((raw) {
      final item = Map<Object?, Object?>.from(raw! as Map);
      final imagePath = item['imagePath']?.toString() ?? '';
      if (imagePath.isEmpty) {
        throw const FormatException('系统没有返回动态照片封面');
      }
      final videoPath = item['videoPath']?.toString();
      final paths = <String>{imagePath};
      if (videoPath?.isNotEmpty == true) paths.add(videoPath!);
      return CoupleSpacePickedMedia(
        imagePath: imagePath,
        videoPath: videoPath?.isNotEmpty == true ? videoPath : null,
        width: _positiveInt(item['width']),
        height: _positiveInt(item['height']),
        temporaryPaths: paths,
      );
    }).toList();
  }

  static int? _positiveInt(Object? value) {
    final parsed = switch (value) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static Future<(int?, int?)> _imageDimensions(String path) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodecFromBuffer(
        await ui.ImmutableBuffer.fromFilePath(path),
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      return (image.width, image.height);
    } catch (_) {
      return const (null, null);
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}

class MotionPhotoExtractor {
  static const _uuid = Uuid();
  static const _jpegStart = <int>[0xff, 0xd8];
  static const _jpegEnd = <int>[0xff, 0xd9];
  static const _ftyp = <int>[0x66, 0x74, 0x79, 0x70];

  static Future<File?> extract(
    File image, {
    Directory? destinationDirectory,
  }) async {
    if (!image.existsSync()) return null;
    final input = await image.open();
    try {
      final length = await input.length();
      if (length < 16) return null;
      final header = await input.read(2);
      if (!_matches(header, 0, _jpegStart)) return null;

      final mp4Offset = await _findMp4Offset(input, length);
      if (mp4Offset == null) return null;
      if (!await _hasJpegEndBefore(input, mp4Offset)) return null;

      final directory = destinationDirectory ?? Directory.systemTemp;
      await directory.create(recursive: true);
      final output = File(
        p.join(directory.path, 'couple-motion-${_uuid.v4()}.mp4'),
      );
      final sink = output.openWrite();
      try {
        await image.openRead(mp4Offset).pipe(sink);
      } catch (_) {
        await sink.close();
        if (output.existsSync()) output.deleteSync();
        rethrow;
      }
      if (await output.length() < 12) {
        await output.delete();
        return null;
      }
      return output;
    } finally {
      await input.close();
    }
  }

  static Future<int?> _findMp4Offset(
    RandomAccessFile input,
    int length,
  ) async {
    const chunkSize = 64 * 1024;
    var position = 2;
    var overlap = <int>[];
    while (position < length) {
      await input.setPosition(position);
      final chunk = await input.read(
        (length - position).clamp(0, chunkSize),
      );
      if (chunk.isEmpty) break;
      final bytes = <int>[...overlap, ...chunk];
      final baseOffset = position - overlap.length;
      for (var index = 4; index <= bytes.length - _ftyp.length; index++) {
        if (!_matches(bytes, index, _ftyp)) continue;
        final boxOffset = baseOffset + index - 4;
        final boxSize = _uint32(bytes, index - 4);
        if (boxOffset > 2 && boxSize >= 8 && boxOffset + boxSize <= length) {
          return boxOffset;
        }
      }
      overlap = bytes.length <= 7 ? bytes : bytes.sublist(bytes.length - 7);
      position += chunk.length;
    }
    return null;
  }

  static Future<bool> _hasJpegEndBefore(
    RandomAccessFile input,
    int endOffset,
  ) async {
    const chunkSize = 64 * 1024;
    var position = 2;
    var previous = -1;
    while (position < endOffset) {
      await input.setPosition(position);
      final chunk = await input.read(
        (endOffset - position).clamp(0, chunkSize),
      );
      if (chunk.isEmpty) break;
      for (final byte in chunk) {
        if (previous == _jpegEnd.first && byte == _jpegEnd.last) return true;
        previous = byte;
      }
      position += chunk.length;
    }
    return false;
  }

  static bool _matches(List<int> bytes, int offset, List<int> target) {
    if (offset < 0 || offset + target.length > bytes.length) return false;
    for (var index = 0; index < target.length; index++) {
      if (bytes[offset + index] != target[index]) return false;
    }
    return true;
  }

  static int _uint32(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
