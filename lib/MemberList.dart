import 'Member.dart';

class MemberListSingleton {
  static final MemberListSingleton _cache = MemberListSingleton._internal();
  static final List<Member> _memberList = [];

  MemberListSingleton._internal();

  factory MemberListSingleton() {
    return _cache;
  }

  static void addMember(Member member) {
    _memberList.add(member);
  }

  List<Member> get memberList => _memberList;
}
