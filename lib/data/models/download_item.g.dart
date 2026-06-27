// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final int typeId = 0;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadItem()
      ..id = fields[0] as String
      ..url = fields[1] as String
      ..title = fields[2] as String
      ..platform = fields[3] as String
      ..quality = fields[4] as String
      ..filePath = fields[5] as String
      ..thumbnailUrl = fields[6] as String
      ..status = fields[7] as String
      ..fileSize = fields[8] as int
      ..createdAt = fields[9] as DateTime;
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.platform)
      ..writeByte(4)
      ..write(obj.quality)
      ..writeByte(5)
      ..write(obj.filePath)
      ..writeByte(6)
      ..write(obj.thumbnailUrl)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.fileSize)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
