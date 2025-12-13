class Folder {
  final double? lastMtime;
  final int count;
  final String folderName;
  final String? mark;

  Folder({
    required this.lastMtime,
    required this.count,
    required this.folderName,
    this.mark,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    lastMtime: json['last_mtime'],
    count: json['count'],
    folderName: json['folder'],
    mark: json['mark'],
  );
}