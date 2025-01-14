import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import 'isolate_transformer.dart';
import 'database.dart';
import 'logger.dart';
import 'serialize.dart';

class DatabaseImpl implements Database {
  final Directory folder;
  final SubSerializer subSerializer;
  final KeySerializer keySerializer;
  final DataSerializer dataSerializer;

  DatabaseImpl._(
      this.folder, this.subSerializer, this.keySerializer, this.dataSerializer);

  factory DatabaseImpl(String base, SubSerializer subSerializer,
      KeySerializer keySerializer, DataSerializer dataSerializer) {
    return DatabaseImpl._(
        Directory(base), subSerializer, keySerializer, dataSerializer);
  }

  @override
  String getPath() => folder.path;

  @override
  Database sub(String table) {
    final serializedTable = subSerializer.serialize(table);
    final base = path.join(folder.path, serializedTable);
    logger.finer('sub: $base');
    return DatabaseImpl(base, subSerializer, keySerializer, dataSerializer);
  }

  @override
  Future<T?> read<T>(String key) async {
    final file = File(path.join(folder.path, keySerializer.serialize(key)));
    if (!await file.exists()) {
      return null;
    }
    if (T == Uint8List) {
      return await file.readAsBytes() as T;
    }
    return await IsolateTransformer().convert(
        file,
        (e) => e
            .asyncExpand((file) => file.openRead())
            .transform(utf8.decoder)
            .join()
            .asStream()
            .map((str) => dataSerializer.deserialize<T>(str)));
  }

  @override
  Future<void> write<T>(String key, T? value) async {
    await folder.create(recursive: true);
    final file = File(path.join(folder.path, keySerializer.serialize(key)));
    if (value == null) {
      await file.delete();
      return;
    }
    await IsolateTransformer().run(value, (T value) async {
      final data = dataSerializer.serialize<T>(value);
      final write = file.openWrite();
      if (data is String) {
        write.write(data);
      } else {
        assert(data is Uint8List);
        write.add(data);
      }
      await write.flush();
      await write.close();
    });
  }

  @override
  Future<void> drop() async {
    await IsolateTransformer().run(folder, _deleteDirectory);
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    await for (var entity in directory.list()) {
      if (entity is File) {
        await entity.delete(); // 删除文件
      } else if (entity is Directory) {
        await _deleteDirectory(entity); // 递归删除子目录
      }
    }
    await directory.delete(); // 删除当前目录
  }
}
