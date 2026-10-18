import '../../auth/domain/user.dart';

abstract class ProfileRepository {
  Future<User> me();
  Future<User> updateMe({String? fullName, String? avatarUrl});
  Future<String> uploadAvatar(String filePath);
  Future<User> user(String userId);
}
