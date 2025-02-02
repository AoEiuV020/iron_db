import 'dart:io';

import 'package:path/path.dart' as path;

import 'database.dart';
import 'serialize.dart';
import 'database_assets_io.dart';
import 'database_impl.dart';

/// linux: /tmp
/// mac: /Users/<username>/Library/Containers/<organization>.<app_name>/Data/tmp
Future<String> getDefaultBase() async {
  final folder = Directory.systemTemp;
  return path.join(folder.path, 'IronDB');
}

Database getDefaultDatabase(
  String base, 
  SubSerializer subSerializer,
  KeySerializer keySerializer,
  DataSerializer dataSerializer
) =>
    DatabaseImpl(base, keySerializer, subSerializer, dataSerializer);

Database getDefaultAssetsDatabase(
        String assetsBase, DataSerializer dataSerializer) =>
    DatabaseAssetsIO(Directory(assetsBase), '', dataSerializer);
