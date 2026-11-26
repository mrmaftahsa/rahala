import 'dart:io';

import 'package:rahala/core/geography.dart';
import 'package:rahala/core/progress.dart';

GeographyCatalog loadCatalog() => GeographyCatalog.decode(
  File('test/fixtures/geography.v1.json').readAsStringSync(),
);

class MemoryProgressBackend implements ProgressBackend {
  String? snapshot;
  bool failNextSave = false;

  @override
  Future<String?> load() async => snapshot;

  @override
  Future<void> save(String value) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Write failed');
    }
    snapshot = value;
  }
}

GeographyCatalog loadWorldCatalog() => GeographyCatalog.decode(
  File('assets/data/geography.v2.json').readAsStringSync(),
);
