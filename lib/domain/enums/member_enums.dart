/// Statut d'un membre au sein d'une organisation.
enum MemberStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended'),
  pending('pending');

  const MemberStatus(this.code);

  final String code;

  static MemberStatus fromCode(String value) => MemberStatus.values.firstWhere(
    (MemberStatus s) => s.code == value,
    orElse: () => MemberStatus.active,
  );
}

enum Gender {
  male('male'),
  female('female'),
  unspecified('unspecified');

  const Gender(this.code);

  final String code;

  static Gender fromCode(String value) => Gender.values.firstWhere(
    (Gender g) => g.code == value,
    orElse: () => Gender.unspecified,
  );
}
