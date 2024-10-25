class User {
  final String name;
  final String email;
  final String gender;
  final int phoneNumber;
  final String username;
  final String password;
  final String uuid;
  final String firebaseToken;
  final String firstName;
  final String lastName;

  User({
    required this.name,
    required this.email,
    required this.gender,
    required this.phoneNumber,
    required this.username,
    required this.password,
    required this.uuid,
    required this.firebaseToken,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'username': username,
      'password': password,
      'uuid': uuid,
      'firebaseToken': firebaseToken,
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'],
      email: json['email'],
      gender: json['gender'],
      phoneNumber: json['phoneNumber'],
      username: json['username'],
      password: json['password'],
      uuid: json['uuid'],
      firebaseToken: json['firebaseToken'],
      firstName: json['firstName'],
      lastName: json['lastName'],
    );
  }
}
