class OtpModel {
  final String id;
  final String sender;
  final String code;
  final String body;
  final DateTime dateTime;
  final String serviceName;

  OtpModel({
    required this.id,
    required this.sender,
    required this.code,
    required this.body,
    required this.dateTime,
    required this.serviceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'code': code,
      'body': body,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'serviceName': serviceName,
    };
  }

  factory OtpModel.fromMap(Map<String, dynamic> map) {
    return OtpModel(
      id: map['id'] as String,
      sender: map['sender'] as String,
      code: map['code'] as String,
      body: map['body'] as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime'] as int),
      serviceName: map['serviceName'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OtpModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
