import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole {
  networkAdministrator('role_network_admin', 'Network Administrator'),
  ictManager('role_ict_manager', 'ICT Manager'),
  systemAdministrator('role_system_admin', 'System Administrator');

  const UserRole(this.roleId, this.displayName);

  final String roleId;
  final String displayName;

  static UserRole fromRoleId(String? roleId) {
    switch (roleId) {
      case 'role_network_admin':
        return UserRole.networkAdministrator;
      case 'role_ict_manager':
        return UserRole.ictManager;
      case 'role_system_admin':
        return UserRole.systemAdministrator;
      default:
        return UserRole.networkAdministrator;
    }
  }
}

class UserModel extends Equatable {
  const UserModel({
    required this.userId,
    required this.username,
    required this.role,
    this.email,
    this.department,
    this.phoneNumber,
    this.mfaEnabled = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  final String userId;
  final String? email;
  final String username;
  final String? department;
  final String? phoneNumber;
  final bool mfaEnabled;
  final bool isActive;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;

  factory UserModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawRole = data['roleId'] as String? ?? data['role'] as String?;

    return UserModel(
      userId: (data['userId'] as String?) ?? doc.id,
      email: data['email'] as String?,
      username: (data['username'] as String?) ?? 'User',
      department: data['department'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      mfaEnabled: data['mfaEnabled'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      role: UserRole.fromRoleId(rawRole),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, {String? userId}) {
    final rawRole = data['roleId'] as String? ?? data['role'] as String?;
    return UserModel(
      userId: (userId ?? data['userId'] as String?) ?? 'unknown',
      email: data['email'] as String?,
      username: (data['username'] as String?) ?? 'User',
      department: data['department'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      mfaEnabled: data['mfaEnabled'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      role: UserRole.fromRoleId(rawRole),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] is String ? DateTime.tryParse(data['createdAt'] as String) : null),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ??
          (data['updatedAt'] is String ? DateTime.tryParse(data['updatedAt'] as String) : null),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ??
          (data['lastLogin'] is String ? DateTime.tryParse(data['lastLogin'] as String) : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'username': username,
      'department': department,
      'phoneNumber': phoneNumber,
      'mfaEnabled': mfaEnabled,
      'isActive': isActive,
      'roleId': role.roleId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastLogin': lastLogin,
    };
  }

  @override
  List<Object?> get props => [
    userId,
    email,
    username,
    department,
    phoneNumber,
    mfaEnabled,
    isActive,
    role,
    createdAt,
    updatedAt,
    lastLogin,
  ];
}
