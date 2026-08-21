import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/attachment.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/auth_tokens.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';

/// Conversion JSON ⇄ entités d'identité.
class UserDto {
  const UserDto._();

  static User fromJson(JsonMap json) => User(
    id: Json.string(json, 'id'),
    firstName: Json.stringOr(json, 'firstName'),
    lastName: Json.stringOr(json, 'lastName'),
    phone: Json.stringOr(json, 'phone'),
    email: Json.stringOrNull(json, 'email'),
    avatarUrl: Json.stringOrNull(json, 'avatarUrl'),
    gender: Gender.fromCode(Json.stringOr(json, 'gender', 'unspecified')),
    birthDate: Json.dateOrNull(json, 'birthDate'),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
  );

  static JsonMap toJson(User user) => <String, dynamic>{
    'id': user.id,
    'firstName': user.firstName,
    'lastName': user.lastName,
    'phone': user.phone,
    'email': user.email,
    'avatarUrl': user.avatarUrl,
    'gender': user.gender.code,
    'birthDate': Json.iso(user.birthDate),
  };
}

class AuthTokensDto {
  const AuthTokensDto._();

  static AuthTokens fromJson(JsonMap json) => AuthTokens(
    accessToken: Json.string(json, 'accessToken'),
    refreshToken: Json.string(json, 'refreshToken'),
    expiresAt:
        Json.dateOrNull(json, 'expiresAt') ??
        DateTime.now().add(
          Duration(seconds: Json.integer(json, 'expiresIn', 3600)),
        ),
  );
}

class AuthSessionDto {
  const AuthSessionDto._();

  /// Attend `{ "user": {...}, "tokens": {...} }`.
  static AuthSession fromJson(JsonMap json) => AuthSession(
    user: UserDto.fromJson(Json.object(json, 'user')),
    tokens: AuthTokensDto.fromJson(Json.object(json, 'tokens')),
  );
}

class RegisterDraftDto {
  const RegisterDraftDto._();

  static JsonMap toJson(RegisterDraft draft) => <String, dynamic>{
    'firstName': draft.firstName,
    'lastName': draft.lastName,
    'phone': draft.phone,
    'password': draft.password,
    'email': draft.email,
    'gender': draft.gender.code,
  };
}

class AttachmentDto {
  const AttachmentDto._();

  static Attachment fromJson(JsonMap json) => Attachment(
    id: Json.string(json, 'id'),
    fileName: Json.stringOr(json, 'fileName'),
    mimeType: Json.stringOr(json, 'mimeType', 'application/octet-stream'),
    sizeBytes: Json.integer(json, 'sizeBytes'),
    uploadedAt: Json.dateOrNull(json, 'uploadedAt') ?? DateTime.now(),
    localPath: Json.stringOrNull(json, 'localPath'),
    remoteUrl: Json.stringOrNull(json, 'remoteUrl'),
  );
}
