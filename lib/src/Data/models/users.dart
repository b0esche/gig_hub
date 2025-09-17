enum UserType { guest, dj, booker }

abstract class AppUser {
  final String id;
  final UserType type;

  const AppUser({required this.id, required this.type});

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

  Guest({
    required super.id,
    required this.avatarImageUrl,
    this.name = '', // Empty by default, set when joining first group chat
    this.favoriteUIds = const [],
    this.isFlinta = false,
  }) : super(type: UserType.guest);

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'name': name,
    'favoriteUIds': favoriteUIds,
    'avatarImageUrl': avatarImageUrl,
    'isFlinta': isFlinta,
  };

  factory Guest.fromJson(String id, Map<String, dynamic> json) => Guest(
    id: id,
    name: json['name'] as String? ?? '',
    favoriteUIds: List<String>.from(json['favoriteUIds'] ?? []),
    avatarImageUrl: json['avatarImageUrl'] as String,
    isFlinta: json['isFlinta'] as bool? ?? false,
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
}
