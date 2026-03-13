class Job {
  final String id;
  final String company;
  final String title;
  final String location;
  final String salary;
  final String description;
  bool isFavorite;

  Job({
    required this.id,
    required this.company,
    required this.title,
    required this.location,
    required this.salary,
    this.description = '',
    this.isFavorite = false,
  });

  factory Job.fromMap(String id, Map<String, dynamic> m) {
    return Job(
      id: id,
      company: (m['Company'] ?? m['company'] ?? '') as String,
      title: (m['Job'] ?? m['job'] ?? '') as String,
      // support multiple possible field names for location used by seed/console
      location:
          (m['Location'] ?? m['location'] ?? m['Rental'] ?? m['rental'] ?? '')
              as String,
      salary: (m['Salary'] ?? m['salary'] ?? '') as String,
      description: m['description']?.toString() ?? '',
      isFavorite: m['isFavorite'] as bool? ?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'location': location,
      'salary': salary,
      'description': description,
      'isFavorite': isFavorite,
    };
  }

  // Copy with
  Job copyWith({
    String? id,
    String? title,
    String? company,
    String? location,
    String? salary,
    String? description,
    bool? isFavorite,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      salary: salary ?? this.salary,
      description: description ?? this.description,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
