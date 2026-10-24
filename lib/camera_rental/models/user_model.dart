class CameraUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String mobileNumber;
  final String email;
  final String role; // 'client' or 'admin'
  final bool isVerified;

  CameraUser({
    required this.uid,
    required this.firstName,
    this.lastName = '',
    this.dateOfBirth = '',
    required this.mobileNumber,
    this.email = '',
    this.role = 'client',
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'mobileNumber': mobileNumber,
      'email': email,
      'role': role,
      'isVerified': isVerified,
    };
  }

  factory CameraUser.fromMap(Map<String, dynamic> map) {
    return CameraUser(
      uid: map['uid'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'client',
      isVerified: map['isVerified'] ?? false,
    );
  }
}
