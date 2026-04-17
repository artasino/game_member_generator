import '../entities/inquiry.dart';

abstract class InquiryRepository {
  Future<void> sendInquiry(Inquiry inquiry);
}
