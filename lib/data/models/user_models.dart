import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing the three user roles in NetVision AI.
enum UserRole {
  networkAdministrator,
  ictManager,
  systemAdministrator;

  static UserRole fromRoleId(String roleId) {
    switch (roleId) {
      case 'role_network_admin':
        return UserRole.networkAdministrator;
      case 'role_ict_manager':
        return UserRole.ictManager;
      case 'role_system_admin':
        return UserRole.systemAdministrator;
      default:
        throw ArgumentError('Unknown roleId: $roleId');
    }
  }

  String get roleId {
    switch (this) {
      case UserRole.networkAdministrator:
        return 'role_network_admin';
      case UserRole.ictManager:
        return 'role_ict_manager';
      case UserRole.systemAdministrator:
        return 'role_system_admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.networkAdministrator:
        return 'Network Administrator';
      case UserRole.ictManager:
        return 'ICT Manager';
      case UserRole.systemAdministrator:
        return 'System Administrator';
    }
  }
}

/// Domain model representing a system user.
/// Maps 1:1 to the Firestore `users/{userId}` document.
class UserModel {
  final String userId;
  final String username;
  final String email;
  final UserRole role;
  final String? department;
  final String? phoneNumber;
  final bool isActive;
  final bool mfaEnabled;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final DateTime updatedAt;

  const UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    this.department,
    this.phoneNumber,
    required this.isActive,
    required this.mfaEnabled,
    required this.createdAt,
    this.lastLogin,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: doc.id,
      username: d['username'] as String? ?? '',
      email: d['email'] as String? ?? '',
      role: UserRole.fromRoleId(d['roleId'] as String? ?? ''),
      department: d['department'] as String?,
      phoneNumber: d['phoneNumber'] as String?,
      isActive: d['isActive'] as bool? ?? true,
      mfaEnabled: d['mfaEnabled'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (d['lastLogin'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'username': username,
        'email': email,
        'roleId': role.roleId,
        'department': department,
        'phoneNumber': phoneNumber,
        'isActive': isActive,
        'mfaEnabled': mfaEnabled,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  UserModel copyWith({
    String? username,
    String? email,
    UserRole? role,
    String? department,
    String? phoneNumber,
    bool? isActive,
    bool? mfaEnabled,
    DateTime? createdAt,
    DateTime? lastLogin,
    DateTime? updatedAt,
  }) {
    return UserModel(
      userId: userId,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}