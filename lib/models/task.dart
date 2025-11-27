// lib/models/task.dart
import 'package:flutter/foundation.dart';

class WorkPeriod {
  String id;
  DateTime startTime;
  DateTime? endTime;
  String? description;

  WorkPeriod({
    required this.id,
    required this.startTime,
    this.endTime,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'description': description,
      };

  factory WorkPeriod.fromJson(Map<String, dynamic> json) => WorkPeriod(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
        description: json['description'] as String?,
      );
}

class IdlePeriod {
  String id;
  DateTime startTime;
  DateTime? endTime;

  IdlePeriod({
    required this.id,
    required this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      };

  factory IdlePeriod.fromJson(Map<String, dynamic> json) => IdlePeriod(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      );
}

class TaskModel {
  String id;
  String userId;
  DateTime startTime;
  DateTime? endTime;
  String description;
  String category;
  List<String> tags;
  String status; // active, completed, idle
  List<WorkPeriod> workPeriods;
  List<IdlePeriod> idlePeriods;

  TaskModel({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.description,
    this.category = 'Development',
    this.tags = const [],
    this.status = 'active',
    this.workPeriods = const [],
    this.idlePeriods = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'description': description,
        'category': category,
        'tags': tags,
        'status': status,
        'workPeriods': workPeriods.map((p) => p.toJson()).toList(),
        'idlePeriods': idlePeriods.map((p) => p.toJson()).toList(),
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Development',
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        status: json['status'] as String? ?? 'active',
        workPeriods: (json['workPeriods'] as List<dynamic>?)
                ?.map((e) => WorkPeriod.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        idlePeriods: (json['idlePeriods'] as List<dynamic>?)
                ?.map((e) => IdlePeriod.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}


















// import 'package:flutter/foundation.dart';

// class WorkPeriod {
//   String id;
//   DateTime startTime;
//   DateTime? endTime;
//   String? description;

//   WorkPeriod({
//     required this.id,
//     required this.startTime,
//     this.endTime,
//     this.description,
//   });
// }

// class IdlePeriod {
//   String id;
//   DateTime startTime;
//   DateTime? endTime;

//   IdlePeriod({
//     required this.id,
//     required this.startTime,
//     this.endTime,
//   });
// }

// class TaskModel {
//   String id;
//   String userId;
//   DateTime startTime;
//   DateTime? endTime;
//   String description;
//   String category;
//   List<String> tags;
//   String status; // active, completed, idle
//   List<WorkPeriod> workPeriods;
//   List<IdlePeriod> idlePeriods;

//   TaskModel({
//     required this.id,
//     required this.userId,
//     required this.startTime,
//     this.endTime,
//     required this.description,
//     this.category = 'Development',
//     this.tags = const [],
//     this.status = 'active',
//     this.workPeriods = const [],
//     this.idlePeriods = const [],
//   });
// }
