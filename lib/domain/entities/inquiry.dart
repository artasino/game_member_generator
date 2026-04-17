enum InquiryCategory {
  bug('不具合報告'),
  request('機能改善要望'),
  other('その他');

  final String label;

  const InquiryCategory(this.label);
}

class Inquiry {
  final String? uid;
  final String email;
  final InquiryCategory category;
  final String message;
  final String osVersion;
  final String appVersion;
  final DateTime? createdAt;

  Inquiry({
    this.uid,
    required this.email,
    required this.category,
    required this.message,
    required this.osVersion,
    required this.appVersion,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      if (uid != null) 'uid': uid,
      'email': email,
      'category': category.name,
      'message': message,
      'os_version': osVersion,
      'app_version': appVersion,
      'timestamp': createdAt ?? DateTime.now(),
      // 実際には serverTimestamp を使うのが望ましい
    };
  }
}
