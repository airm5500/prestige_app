class LicenceModel {
  final String id;
  final String typeLicence;
  final String dateStart;
  final String dateEnd;

  LicenceModel({
    required this.id,
    required this.typeLicence,
    required this.dateStart,
    required this.dateEnd,
  });

  factory LicenceModel.fromJson(Map<String, dynamic> json) {
    return LicenceModel(
      id: json['id']?.toString() ?? '',
      typeLicence: json['typeLicence']?.toString() ?? '',
      dateStart: json['dateStart']?.toString() ?? '',
      dateEnd: json['dateEnd']?.toString() ?? '',
    );
  }

  DateTime? get expiryDate {
    if (dateEnd.isEmpty) return null;
    try {
      return DateTime.parse(dateEnd);
    } catch (e) {
      return null;
    }
  }

  int get daysRemaining {
    final end = expiryDate;
    if (end == null) return 0;

    final now = DateTime.now();
    final dateEndOnly = DateTime(end.year, end.month, end.day);
    final dateNowOnly = DateTime(now.year, now.month, now.day);

    return dateEndOnly.difference(dateNowOnly).inDays;
  }

  bool get isValid {
    return daysRemaining >= 0;
  }
}