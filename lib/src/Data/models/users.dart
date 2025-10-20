enum UserType { guest, dj, booker }

abstract class AppUser {
  final String id;
  final UserType type;
  final String? email; // Optional email field for all user types

  const AppUser({
    required this.id,
    required this.type,
    this.email, // Made optional since it might not be available for all users
  });

  factory AppUser.fromJson(String id, Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final type = UserType.values.firstWhere(
      (e) => e.name == typeString as String,
      orElse: () => throw Exception('unknown user type: $typeString'),
    );

    switch (type) {
      case UserType.guest:
        return Guest.fromJson(id, json);
      case UserType.dj:
        return DJ.fromJson(id, json);
      case UserType.booker:
        return Booker.fromJson(id, json);
    }
  }
}

class Guest extends AppUser {
  String avatarImageUrl;
  String name; // Username for group chats
  List<String> favoriteUIds;
  bool isFlinta; // FLINTA* marking
  bool hasAcceptedTerms;
  bool hasAcceptedPrivacy;
  String? termsAcceptedAt;
  String? privacyAcceptedAt;

  Guest({
    required super.id,
    required this.avatarImageUrl,
    this.name = '', // Empty by default, set when joining first group chat
    this.favoriteUIds = const [],
    this.isFlinta = false,
    this.hasAcceptedTerms = false,
    this.hasAcceptedPrivacy = false,
    this.termsAcceptedAt,
    this.privacyAcceptedAt,
    super.email,
  }) : super(type: UserType.guest);

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'name': name,
    'favoriteUIds': favoriteUIds,
    'avatarImageUrl': avatarImageUrl,
    'isFlinta': isFlinta,
    'hasAcceptedTerms': hasAcceptedTerms,
    'hasAcceptedPrivacy': hasAcceptedPrivacy,
    'termsAcceptedAt': termsAcceptedAt,
    'privacyAcceptedAt': privacyAcceptedAt,
    'email': email,
  };

  factory Guest.fromJson(String id, Map<String, dynamic> json) => Guest(
    id: id,
    name: json['name'] as String? ?? '',
    favoriteUIds: List<String>.from(json['favoriteUIds'] ?? []),
    avatarImageUrl: json['avatarImageUrl'] as String,
    isFlinta: json['isFlinta'] as bool? ?? false,
    hasAcceptedTerms: json['hasAcceptedTerms'] as bool? ?? false,
    hasAcceptedPrivacy: json['hasAcceptedPrivacy'] as bool? ?? false,
    termsAcceptedAt: json['termsAcceptedAt'] as String?,
    privacyAcceptedAt: json['privacyAcceptedAt'] as String?,
    email: json['email'] as String?,
  );
}

class DJ extends AppUser {
  String name,
      city,
      about,
      info,
      headImageUrl,
      avatarImageUrl,
      headImageBlurHash;

  final double avgRating;

  final int ratingCount;

  List<String> mediaImageUrls,
      favoriteUIds,
      genres,
      streamingUrls,
      trackTitles,
      trackUrls,
      mediaImageBlurHashes;

  List<int> bpm;

  bool hasAcceptedTerms;
  bool hasAcceptedPrivacy;
  String? termsAcceptedAt;
  String? privacyAcceptedAt;

  DJ({
    required super.id,
    required this.avatarImageUrl,
    required this.headImageUrl,
    required this.name,
    required this.city,
    required this.about,
    required this.info,
    required this.genres,
    required this.bpm,
    required this.streamingUrls,
    required this.trackTitles,
    required this.trackUrls,
    this.headImageBlurHash = '',
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.mediaImageUrls = const [],
    this.mediaImageBlurHashes = const [],
    this.favoriteUIds = const [],
    this.hasAcceptedTerms = false,
    this.hasAcceptedPrivacy = false,
    this.termsAcceptedAt,
    this.privacyAcceptedAt,
    super.email,
  }) : super(type: UserType.dj);

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'avatarImageUrl': avatarImageUrl,
    'headImageUrl': headImageUrl,
    'headImageBlurHash': headImageBlurHash,
    'name': name,
    'city': city,
    'about': about,
    'info': info,
    'genres': genres,
    'bpm': bpm,
    'streamingUrls': streamingUrls,
    'trackTitles': trackTitles,
    'trackUrls': trackUrls,
    'avgRating': avgRating,
    'ratingCount': ratingCount,
    'mediaImageUrls': mediaImageUrls,
    'mediaImageBlurHashes': mediaImageBlurHashes,
    'favoriteUIds': favoriteUIds,
    'hasAcceptedTerms': hasAcceptedTerms,
    'hasAcceptedPrivacy': hasAcceptedPrivacy,
    'termsAcceptedAt': termsAcceptedAt,
    'privacyAcceptedAt': privacyAcceptedAt,
    'email': email,
  };

  factory DJ.fromJson(String id, Map<String, dynamic> json) => DJ(
    id: id,
    avatarImageUrl: json['avatarImageUrl'] as String,
    headImageUrl: json['headImageUrl'] as String,
    headImageBlurHash: json['headImageBlurHash'] as String? ?? '',
    name: json['name'] as String,
    city: json['city'] as String,
    about: json['about'] as String,
    info: json['info'] as String,
    genres: List<String>.from(json['genres'] ?? []),
    bpm: List<int>.from(json['bpm'] ?? []),
    streamingUrls: List<String>.from(json['streamingUrls'] ?? []),
    trackTitles: List<String>.from(json['trackTitles'] ?? []),
    trackUrls: List<String>.from(json['trackUrls']),
    avgRating: (json['avgRating'] ?? 0.0).toDouble() as double,
    ratingCount: (json['ratingCount'] ?? 0) as int,
    mediaImageUrls: List<String>.from(json['mediaImageUrls'] ?? []),
    mediaImageBlurHashes: List<String>.from(json['mediaImageBlurHashes'] ?? []),
    favoriteUIds: List<String>.from(json['favoriteUIds'] ?? []),
    hasAcceptedTerms: json['hasAcceptedTerms'] as bool? ?? false,
    hasAcceptedPrivacy: json['hasAcceptedPrivacy'] as bool? ?? false,
    termsAcceptedAt: json['termsAcceptedAt'] as String?,
    privacyAcceptedAt: json['privacyAcceptedAt'] as String?,
    email: json['email'] as String?,
  );
}

class Booker extends AppUser {
  String name,
      city,
      about,
      info,
      category,
      headImageUrl,
      avatarImageUrl,
      headImageBlurHash;

  final double avgRating;

  final int ratingCount;

  List<String> mediaImageUrls, favoriteUIds, mediaImageBlurHashes;

  bool hasAcceptedTerms;
  bool hasAcceptedPrivacy;
  String? termsAcceptedAt;
  String? privacyAcceptedAt;

  Booker({
    required super.id,
    required this.avatarImageUrl,
    required this.headImageUrl,
    required this.name,
    required this.city,
    required this.about,
    required this.info,
    required this.category,
    this.headImageBlurHash = '',
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.mediaImageUrls = const [],
    this.mediaImageBlurHashes = const [],
    this.favoriteUIds = const [],
    this.hasAcceptedTerms = false,
    this.hasAcceptedPrivacy = false,
    this.termsAcceptedAt,
    this.privacyAcceptedAt,
    super.email,
  }) : super(type: UserType.booker);

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'avatarImageUrl': avatarImageUrl,
    'headImageUrl': headImageUrl,
    'headImageBlurHash': headImageBlurHash,
    'name': name,
    'city': city,
    'about': about,
    'info': info,
    'category': category,
    'avgRating': avgRating,
    'ratingCount': ratingCount,
    'mediaImageUrls': mediaImageUrls,
    'mediaImageBlurHashes': mediaImageBlurHashes,
    'favoriteUIds': favoriteUIds,
    'hasAcceptedTerms': hasAcceptedTerms,
    'hasAcceptedPrivacy': hasAcceptedPrivacy,
    'termsAcceptedAt': termsAcceptedAt,
    'privacyAcceptedAt': privacyAcceptedAt,
    'email': email,
  };

  factory Booker.fromJson(String id, Map<String, dynamic> json) => Booker(
    id: id,
    avatarImageUrl: json['avatarImageUrl'] as String,
    headImageUrl: json['headImageUrl'] as String,
    headImageBlurHash: json['headImageBlurHash'] as String? ?? '',
    name: json['name'] as String,
    city: json['city'] as String,
    about: json['about'] as String,
    info: json['info'] as String,
    category: json['category'] as String,
    avgRating: (json['avgRating'] ?? 0.0).toDouble() as double,
    ratingCount: (json['ratingCount'] ?? 0) as int,
    mediaImageUrls: List<String>.from(json['mediaImageUrls'] ?? []),
    mediaImageBlurHashes: List<String>.from(json['mediaImageBlurHashes'] ?? []),
    favoriteUIds: List<String>.from(json['favoriteUIds'] ?? []),
    hasAcceptedTerms: json['hasAcceptedTerms'] as bool? ?? false,
    hasAcceptedPrivacy: json['hasAcceptedPrivacy'] as bool? ?? false,
    termsAcceptedAt: json['termsAcceptedAt'] as String?,
    privacyAcceptedAt: json['privacyAcceptedAt'] as String?,
    email: json['email'] as String?,
  );
}

extension AppUserView on AppUser {
  String get displayName {
    if (this is DJ) return (this as DJ).name;
    if (this is Booker) return (this as Booker).name;
    if (this is Guest) {
      final guestName = (this as Guest).name;
      return guestName.isNotEmpty ? guestName : 'Guest';
    }
    return 'unknown user';
  }

  String get avatarUrl {
    if (this is DJ) return (this as DJ).avatarImageUrl;
    if (this is Booker) return (this as Booker).avatarImageUrl;
    if (this is Guest) return (this as Guest).avatarImageUrl;
    return 'https://firebasestorage.googleapis.com/v0/b/gig-hub-8ac24.firebasestorage.app/o/default%2Fdefault_avatar.jpg?alt=media&token=9c48f377-736e-4a9a-bf31-6ffc3ed020f7';
  }

  // Legal agreement helpers
  bool get hasAcceptedTerms {
    if (this is DJ) return (this as DJ).hasAcceptedTerms;
    if (this is Booker) return (this as Booker).hasAcceptedTerms;
    if (this is Guest) return (this as Guest).hasAcceptedTerms;
    return false;
  }

  bool get hasAcceptedPrivacy {
    if (this is DJ) return (this as DJ).hasAcceptedPrivacy;
    if (this is Booker) return (this as Booker).hasAcceptedPrivacy;
    if (this is Guest) return (this as Guest).hasAcceptedPrivacy;
    return false;
  }

  bool get hasAcceptedAllAgreements => hasAcceptedTerms && hasAcceptedPrivacy;

  String? get userEmail => email; // Convenience getter for the email field

  String? get termsAcceptedAt {
    if (this is DJ) return (this as DJ).termsAcceptedAt;
    if (this is Booker) return (this as Booker).termsAcceptedAt;
    if (this is Guest) return (this as Guest).termsAcceptedAt;
    return null;
  }

  String? get privacyAcceptedAt {
    if (this is DJ) return (this as DJ).privacyAcceptedAt;
    if (this is Booker) return (this as Booker).privacyAcceptedAt;
    if (this is Guest) return (this as Guest).privacyAcceptedAt;
    return null;
  }
}
