import 'package:gig_hub/src/Data/interfaces/database_repository.dart';
import 'package:gig_hub/src/Data/models/users.dart';
import 'package:gig_hub/src/Data/firebase/cached_firestore_repository.dart';

class LegalAgreementService {
  // Current versions - increment these when updating agreements
  static const String _currentTermsVersion = '1.0.0';
  static const String _currentPrivacyVersion = '1.0.0';

  static final DatabaseRepository _db = CachedFirestoreRepository();

  /// Check if user has accepted current version of Terms of Service
  static Future<bool> hasAcceptedTerms([AppUser? user]) async {
    user ??= await _db.getCurrentUser();
    return user.hasAcceptedTerms;
  }

  /// Check if user has accepted current version of Privacy Policy
  static Future<bool> hasAcceptedPrivacy([AppUser? user]) async {
    user ??= await _db.getCurrentUser();
    return user.hasAcceptedPrivacy;
  }

  /// Check if user has accepted both current agreements
  static Future<bool> hasAcceptedAllAgreements([AppUser? user]) async {
    user ??= await _db.getCurrentUser();
    return user.hasAcceptedAllAgreements;
  }

  /// Mark Terms of Service as accepted for a user
  static Future<void> acceptTerms([AppUser? user]) async {
    user ??= await _db.getCurrentUser();
    final now = DateTime.now().toIso8601String();

    if (user is DJ) {
      final updatedUser = DJ(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        headImageUrl: user.headImageUrl,
        name: user.name,
        city: user.city,
        about: user.about,
        info: user.info,
        genres: user.genres,
        bpm: user.bpm,
        streamingUrls: user.streamingUrls,
        trackTitles: user.trackTitles,
        trackUrls: user.trackUrls,
        headImageBlurHash: user.headImageBlurHash,
        avgRating: user.avgRating,
        ratingCount: user.ratingCount,
        mediaImageUrls: user.mediaImageUrls,
        mediaImageBlurHashes: user.mediaImageBlurHashes,
        favoriteUIds: user.favoriteUIds,
        hasAcceptedTerms: true,
        hasAcceptedPrivacy: user.hasAcceptedPrivacy,
        termsAcceptedAt: now,
        privacyAcceptedAt: user.privacyAcceptedAt,
      );
      await _db.updateDJ(updatedUser);
    } else if (user is Booker) {
      final updatedUser = Booker(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        headImageUrl: user.headImageUrl,
        name: user.name,
        city: user.city,
        about: user.about,
        info: user.info,
        category: user.category,
        headImageBlurHash: user.headImageBlurHash,
        avgRating: user.avgRating,
        ratingCount: user.ratingCount,
        mediaImageUrls: user.mediaImageUrls,
        mediaImageBlurHashes: user.mediaImageBlurHashes,
        favoriteUIds: user.favoriteUIds,
        hasAcceptedTerms: true,
        hasAcceptedPrivacy: user.hasAcceptedPrivacy,
        termsAcceptedAt: now,
        privacyAcceptedAt: user.privacyAcceptedAt,
      );
      await _db.updateBooker(updatedUser);
    } else if (user is Guest) {
      final updatedUser = Guest(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        name: user.name,
        favoriteUIds: user.favoriteUIds,
        isFlinta: user.isFlinta,
        hasAcceptedTerms: true,
        hasAcceptedPrivacy: user.hasAcceptedPrivacy,
        termsAcceptedAt: now,
        privacyAcceptedAt: user.privacyAcceptedAt,
      );
      await _db.updateGuest(updatedUser);
    }
  }

  /// Mark Privacy Policy as accepted for a user
  static Future<void> acceptPrivacy([AppUser? user]) async {
    user ??= await _db.getCurrentUser();
    final now = DateTime.now().toIso8601String();

    if (user is DJ) {
      final updatedUser = DJ(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        headImageUrl: user.headImageUrl,
        name: user.name,
        city: user.city,
        about: user.about,
        info: user.info,
        genres: user.genres,
        bpm: user.bpm,
        streamingUrls: user.streamingUrls,
        trackTitles: user.trackTitles,
        trackUrls: user.trackUrls,
        headImageBlurHash: user.headImageBlurHash,
        avgRating: user.avgRating,
        ratingCount: user.ratingCount,
        mediaImageUrls: user.mediaImageUrls,
        mediaImageBlurHashes: user.mediaImageBlurHashes,
        favoriteUIds: user.favoriteUIds,
        hasAcceptedTerms: user.hasAcceptedTerms,
        hasAcceptedPrivacy: true,
        termsAcceptedAt: user.termsAcceptedAt,
        privacyAcceptedAt: now,
      );
      await _db.updateDJ(updatedUser);
    } else if (user is Booker) {
      final updatedUser = Booker(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        headImageUrl: user.headImageUrl,
        name: user.name,
        city: user.city,
        about: user.about,
        info: user.info,
        category: user.category,
        headImageBlurHash: user.headImageBlurHash,
        avgRating: user.avgRating,
        ratingCount: user.ratingCount,
        mediaImageUrls: user.mediaImageUrls,
        mediaImageBlurHashes: user.mediaImageBlurHashes,
        favoriteUIds: user.favoriteUIds,
        hasAcceptedTerms: user.hasAcceptedTerms,
        hasAcceptedPrivacy: true,
        termsAcceptedAt: user.termsAcceptedAt,
        privacyAcceptedAt: now,
      );
      await _db.updateBooker(updatedUser);
    } else if (user is Guest) {
      final updatedUser = Guest(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        name: user.name,
        favoriteUIds: user.favoriteUIds,
        isFlinta: user.isFlinta,
        hasAcceptedTerms: user.hasAcceptedTerms,
        hasAcceptedPrivacy: true,
        termsAcceptedAt: user.termsAcceptedAt,
        privacyAcceptedAt: now,
      );
      await _db.updateGuest(updatedUser);
    }
  }

  /// Mark both agreements as accepted for a user
  static Future<void> acceptAllAgreements([AppUser? user]) async {
    user ??= await _db.getCurrentUser();
    await acceptTerms(user);
    // Refresh user data after first update
    user = await _db.getCurrentUser();
    await acceptPrivacy(user);
  }

  /// Reset all agreement acceptances for a user (useful for testing)
  static Future<void> resetAgreements([AppUser? user]) async {
    user ??= await _db.getCurrentUser();

    if (user is DJ) {
      final updatedUser = DJ(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        headImageUrl: user.headImageUrl,
        name: user.name,
        city: user.city,
        about: user.about,
        info: user.info,
        genres: user.genres,
        bpm: user.bpm,
        streamingUrls: user.streamingUrls,
        trackTitles: user.trackTitles,
        trackUrls: user.trackUrls,
        headImageBlurHash: user.headImageBlurHash,
        avgRating: user.avgRating,
        ratingCount: user.ratingCount,
        mediaImageUrls: user.mediaImageUrls,
        mediaImageBlurHashes: user.mediaImageBlurHashes,
        favoriteUIds: user.favoriteUIds,
        hasAcceptedTerms: false,
        hasAcceptedPrivacy: false,
        termsAcceptedAt: null,
        privacyAcceptedAt: null,
      );
      await _db.updateDJ(updatedUser);
    } else if (user is Booker) {
      final updatedUser = Booker(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        headImageUrl: user.headImageUrl,
        name: user.name,
        city: user.city,
        about: user.about,
        info: user.info,
        category: user.category,
        headImageBlurHash: user.headImageBlurHash,
        avgRating: user.avgRating,
        ratingCount: user.ratingCount,
        mediaImageUrls: user.mediaImageUrls,
        mediaImageBlurHashes: user.mediaImageBlurHashes,
        favoriteUIds: user.favoriteUIds,
        hasAcceptedTerms: false,
        hasAcceptedPrivacy: false,
        termsAcceptedAt: null,
        privacyAcceptedAt: null,
      );
      await _db.updateBooker(updatedUser);
    } else if (user is Guest) {
      final updatedUser = Guest(
        id: user.id,
        avatarImageUrl: user.avatarImageUrl,
        name: user.name,
        favoriteUIds: user.favoriteUIds,
        isFlinta: user.isFlinta,
        hasAcceptedTerms: false,
        hasAcceptedPrivacy: false,
        termsAcceptedAt: null,
        privacyAcceptedAt: null,
      );
      await _db.updateGuest(updatedUser);
    }
  }

  /// Get current agreement versions
  static Map<String, String> getVersions() {
    return {'terms': _currentTermsVersion, 'privacy': _currentPrivacyVersion};
  }

  /// Check if agreements need to be shown (either first time or updated version)
  static Future<bool> needsToShowAgreements([AppUser? user]) async {
    return !await hasAcceptedAllAgreements(user);
  }
}
