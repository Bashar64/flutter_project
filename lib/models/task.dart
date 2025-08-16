class Task {
  final String id;
  final String name;
  final DateTime dateTime;
  final String? description;
  final bool isCompleted;

  Task({
    required this.id,
    required this.name,
    required this.dateTime,
    this.description,
    this.isCompleted = false,
  });

  Task copyWith({
    String? id,
    String? name,
    DateTime? dateTime,
    String? description,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'description': description,
      'isCompleted': isCompleted,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      name: map['name'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      description: map['description'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
