import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import '../models/download_item.dart';

class DownloadRepository {
  static const String _boxName = 'downloads';
  Box<DownloadItem>? _cachedBox;

  Future<Box<DownloadItem>> _getBox() async {
    if (_cachedBox != null) return _cachedBox!;
    if (!Hive.isBoxOpen(_boxName)) {
      _cachedBox = await Hive.openBox<DownloadItem>(_boxName);
    } else {
      _cachedBox = Hive.box<DownloadItem>(_boxName);
    }
    return _cachedBox!;
  }
  
  Future<void> save(DownloadItem item) async {
    final box = await _getBox();
    await box.put(item.id, item);
  }
  
  Future<void> updateStatus(String id, String status) async {
    final box = await _getBox();
    final item = box.get(id);
    if (item != null) {
      item.status = status;
      await item.save();
    }
  }
  
  Future<List<DownloadItem>> getAll() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  Future<void> delete(String id) async {
    final box = await _getBox();
    final item = box.get(id);
    if (item != null) {
      // Delete actual file if not web
      if (!kIsWeb && item.filePath.isNotEmpty) {
        final file = File(item.filePath);
        if (await file.exists()) await file.delete();
      }
      await box.delete(id);
    }
  }
  
  Future<bool> isDuplicate(String url) async {
    final box = await _getBox();
    return box.values.any((item) => 
      item.url == url && item.status == DownloadItem.completed);
  }
  
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
