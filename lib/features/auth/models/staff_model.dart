class StaffModel {
  final String uid;
  final String staffId;
  final String empId;
  final String name;
  final String phone;
  final String role;
  final String branchCode;
  final String tenantId;
  final String storeId;
  final bool isActive;
  final bool isDeleted;

  StaffModel({
    required this.uid,
    required this.staffId,
    required this.empId,
    required this.name,
    required this.phone,
    required this.role,
    required this.branchCode,
    required this.tenantId,
    required this.storeId,
    required this.isActive,
    required this.isDeleted,
  });

  factory StaffModel.fromMap(Map<String, dynamic> map, String docId) {
    return StaffModel(
      uid: docId,
      staffId: map['staffId'] ?? docId,
      empId: map['empId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? '',
      branchCode: map['branchCode'] ?? '',
      tenantId: map['tenantId'] ?? '',
      storeId: map['storeId'] ?? '',
      isActive: map['isActive'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}
