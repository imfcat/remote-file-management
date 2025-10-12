class FileRecord {
  final String filePath;
  final String file;
  final String rootFolder;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String md5Hash;
  final int? width;
  final int? height;

  FileRecord({
    required this.filePath,
    required this.file,
    required this.rootFolder,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.md5Hash,
    this.width,
    this.height,
  });

  factory FileRecord.fromJson(Map<String, dynamic> json) => FileRecord(
    filePath: json['file_path'],
    file: json['file'],
    rootFolder: json['root_folder'],
    fileName: json['file_name'],
    fileType: json['file_type'],
    fileSize: json['file_size'],
    md5Hash: json['md5_hash'],
    width: json['width'],
    height: json['height'],
  );
}