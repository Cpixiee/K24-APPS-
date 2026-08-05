class DriverModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String plateNumber;
  final bool isActive;
  final double rating;
  final String role;

  DriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.plateNumber,
    required this.isActive,
    required this.rating,
    required this.role,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      plateNumber: json['plate_number'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.00,
      role: json['role'] as String? ?? 'DRIVER',
    );
  }
}

class StatsModel {
  final double todayEarnings;
  final int todayOrders;
  final double totalEarnings;
  final int totalOrders;

  StatsModel({
    required this.todayEarnings,
    required this.todayOrders,
    required this.totalEarnings,
    required this.totalOrders,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      todayEarnings: (json['today_earnings'] as num?)?.toDouble() ?? 0.0,
      todayOrders: json['today_orders'] as int? ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      totalOrders: json['total_orders'] as int? ?? 0,
    );
  }
}

class OrderModel {
  final int id;
  final String orderNumber;
  final int? driverId;
  final String status; // 'PICKING_UP', 'DELIVERING', 'COMPLETED', 'CANCELLED'
  final String pharmacyName;
  final String pharmacyAddress;
  final String deliveryAddress;
  final String customerName;
  final String customerPhone;
  final String medicineSummary;
  final double deliveryFee;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double pharmacyLat;
  final double pharmacyLng;
  final double customerLat;
  final double customerLng;
  final String unboxingOption;
  final String checkedInvoices;
  final String extraItemsNote;
  final String parentOrderNumber;
  final String dispatchId;
  final String facturePhotoUrl;
  final String signaturePhotoUrl;
  final String pickupPhotoUrl;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.driverId,
    required this.status,
    required this.pharmacyName,
    required this.pharmacyAddress,
    required this.deliveryAddress,
    required this.customerName,
    required this.customerPhone,
    required this.medicineSummary,
    required this.deliveryFee,
    required this.createdAt,
    this.completedAt,
    required this.pharmacyLat,
    required this.pharmacyLng,
    required this.customerLat,
    required this.customerLng,
    required this.unboxingOption,
    this.checkedInvoices = '',
    required this.extraItemsNote,
    required this.parentOrderNumber,
    this.dispatchId = '',
    this.facturePhotoUrl = '',
    this.signaturePhotoUrl = '',
    this.pickupPhotoUrl = '',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int? ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      driverId: json['driver_id'] as int?,
      status: json['status'] as String? ?? '',
      pharmacyName: json['pharmacy_name'] as String? ?? '',
      pharmacyAddress: json['pharmacy_address'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      medicineSummary: json['medicine_summary'] as String? ?? '',
      deliveryFee: (json['driver_fee'] != null && (json['driver_fee'] as num).toDouble() > 0)
          ? (json['driver_fee'] as num).toDouble()
          : ((json['delivery_fee'] as num?)?.toDouble() ?? 0.0),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      pharmacyLat: (json['pharmacy_lat'] as num?)?.toDouble() ?? -6.17511,
      pharmacyLng: (json['pharmacy_lng'] as num?)?.toDouble() ?? 106.865039,
      customerLat: (json['customer_lat'] as num?)?.toDouble() ?? -6.23000,
      customerLng: (json['customer_lng'] as num?)?.toDouble() ?? 106.99000,
      unboxingOption: json['unboxing_option'] as String? ?? '',
      checkedInvoices: json['checked_invoices'] as String? ?? '',
      extraItemsNote: json['extra_items_note'] as String? ?? '',
      parentOrderNumber: json['parent_order_number'] as String? ?? '',
      dispatchId: json['dispatch_id'] as String? ?? '',
      facturePhotoUrl: json['facture_photo_url'] as String? ?? '',
      signaturePhotoUrl: json['signature_photo_url'] as String? ?? '',
      pickupPhotoUrl: json['pickup_photo_url'] as String? ?? '',
    );
  }
}

class DashboardDataModel {
  final DriverModel driver;
  final StatsModel stats;
  final OrderModel? activeOrder;
  final List<OrderModel> activeOrders;
  final List<OrderModel> recentOrders;

  DashboardDataModel({
    required this.driver,
    required this.stats,
    this.activeOrder,
    required this.activeOrders,
    required this.recentOrders,
  });

  factory DashboardDataModel.fromJson(Map<String, dynamic> json) {
    return DashboardDataModel(
      driver: DriverModel.fromJson(json['driver'] as Map<String, dynamic>? ?? {}),
      stats: StatsModel.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      activeOrder: json['active_order'] != null 
          ? OrderModel.fromJson(json['active_order'] as Map<String, dynamic>) 
          : null,
      activeOrders: (json['active_orders'] as List<dynamic>?)
              ?.map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
              .toList() ?? 
          [],
      recentOrders: (json['recent_orders'] as List<dynamic>?)
              ?.map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
              .toList() ?? 
          [],
    );
  }
}

class MitraModel {
  final int id;
  final String username;
  final String name;
  final String email;
  final String phone;
  final String role;
  final DateTime createdAt;

  MitraModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  factory MitraModel.fromJson(Map<String, dynamic> json) {
    return MitraModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'MITRA',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }
}

class AdminStatsModel {
  final int totalDrivers;
  final int totalMitra;
  final int totalOrders;

  AdminStatsModel({
    required this.totalDrivers,
    required this.totalMitra,
    required this.totalOrders,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalDrivers: json['total_drivers'] as int? ?? 0,
      totalMitra: json['total_mitra'] as int? ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
    );
  }
}

