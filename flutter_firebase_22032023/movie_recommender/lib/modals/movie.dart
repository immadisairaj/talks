// ignore: depend_on_referenced_packages
import 'package:uuid/uuid.dart';

class Movie {
  final String id;
  final String title;
  final String? description;
  final String? userId;
  final String userName;
  final DateTime timestamp;

  Movie({
    required this.title,
    String? id,
    this.description,
    required this.userId,
    required this.userName,
    required this.timestamp,
  }) : id = id ?? const Uuid().v4();

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
        title: json['title'] as String,
        id: json['id'] as String?,
        description: json['description'] as String?,
        userId: json['userId'] as String?,
        userName: json['userName'] as String,
        timestamp: DateTime.parse(json['timestamp']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'userId': userId,
        'userName': userName,
        'timestamp': timestamp.toString(),
      };

  Movie copyWith({
    String? id,
    String? title,
    String? description,
    String? userId,
    String? userName,
    DateTime? timestamp,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
