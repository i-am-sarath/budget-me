import 'package:uuid/uuid.dart';

class TripModel {
  final String id;
  final String name;
  final String destination;
  final String icon;
  final double budget;
  final DateTime startDate;
  final DateTime endDate;
  final String note;
  final DateTime createdAt;

  TripModel({
    String? id,
    required this.name,
    this.destination = '',
    this.icon = '✈️',
    this.budget = 0,
    required this.startDate,
    required this.endDate,
    this.note = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isOngoing {
    final today = _dateOnly(DateTime.now());
    return !today.isBefore(_dateOnly(startDate)) && !today.isAfter(_dateOnly(endDate));
  }

  bool get isUpcoming => _dateOnly(DateTime.now()).isBefore(_dateOnly(startDate));

  bool get isPast => _dateOnly(DateTime.now()).isAfter(_dateOnly(endDate));

  int get durationDays => _dateOnly(endDate).difference(_dateOnly(startDate)).inDays + 1;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'destination': destination,
        'icon': icon,
        'budget': budget,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory TripModel.fromMap(Map<String, dynamic> map) => TripModel(
        id: map['id'] as String,
        name: map['name'] as String,
        destination: map['destination'] as String? ?? '',
        icon: (map['icon'] as String?)?.isNotEmpty == true ? map['icon'] as String : '✈️',
        budget: (map['budget'] as num?)?.toDouble() ?? 0,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        note: map['note'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  TripModel copyWith({
    String? name,
    String? destination,
    String? icon,
    double? budget,
    DateTime? startDate,
    DateTime? endDate,
    String? note,
  }) =>
      TripModel(
        id: id,
        name: name ?? this.name,
        destination: destination ?? this.destination,
        icon: icon ?? this.icon,
        budget: budget ?? this.budget,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        note: note ?? this.note,
        createdAt: createdAt,
      );
}
