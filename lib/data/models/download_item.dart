import 'package:hive/hive.dart';

part 'download_item.g.dart';

@HiveType(typeId: 0)
class DownloadItem extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String url;
  @HiveField(2) late String title;
  @HiveField(3) late String platform;
  @HiveField(4) late String quality;
  @HiveField(5) late String filePath;
  @HiveField(6) late String thumbnailUrl;
  @HiveField(7) late String status;
  @HiveField(8) late int fileSize;
  @HiveField(9) late DateTime createdAt;
  
  static const String downloading = 'downloading';
  static const String completed = 'completed';
  static const String failed = 'failed';
}
