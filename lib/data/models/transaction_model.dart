class TransactionModel {
  final String id;
  final DateTime dateTime;
  final double amount;
  final bool isCredit; // true = income, false = expense
  final String category;
  final String description;
  final String bankName;
  final String rawSms;

  TransactionModel({
    required this.id,
    required this.dateTime,
    required this.amount,
    required this.isCredit,
    required this.category,
    required this.description,
    required this.bankName,
    required this.rawSms,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'amount': amount,
      'isCredit': isCredit ? 1 : 0,
      'category': category,
      'description': description,
      'bankName': bankName,
      'rawSms': rawSms,
    };
  }

  // Create from Map (database retrieval)
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime'] as int),
      amount: map['amount'] as double,
      isCredit: (map['isCredit'] as int) == 1,
      category: map['category'] as String,
      description: map['description'] as String,
      bankName: map['bankName'] as String,
      rawSms: map['rawSms'] as String,
    );
  }

  // Helper methods
  bool isUselessSpend() {
    const uselessCategories = [
      'Food Delivery',
      'Online Shopping',
      'Entertainment',
      'Subscriptions',
    ];
    return uselessCategories.contains(category);
  }

  // Copy with method for updates
  TransactionModel copyWith({
    String? id,
    DateTime? dateTime,
    double? amount,
    bool? isCredit,
    String? category,
    String? description,
    String? bankName,
    String? rawSms,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      amount: amount ?? this.amount,
      isCredit: isCredit ?? this.isCredit,
      category: category ?? this.category,
      description: description ?? this.description,
      bankName: bankName ?? this.bankName,
      rawSms: rawSms ?? this.rawSms,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, amount: $amount, isCredit: $isCredit, category: $category, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
