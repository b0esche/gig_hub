import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CityValidationResult {
  final bool isValid;
  final String? suggestedName;

  CityValidationResult({required this.isValid, this.suggestedName});
}

class PlacesValidationService {
  static Future<bool> validateCity(String value) async {
    final result = await validateCityWithSuggestion(value);
    return result.isValid;
  }

  static Future<CityValidationResult> validateCityWithSuggestion(
    String value,
  ) async {
    // Get platform-specific API key
    String? apiKey;
    if (Platform.isIOS) {
      apiKey = dotenv.env['GOOGLE_API_KEY_IOS'];
    } else if (Platform.isAndroid) {
      apiKey = dotenv.env['GOOGLE_API_KEY_ANDROID'];
    } else {
      // Fallback to generic key for other platforms
      apiKey = dotenv.env['GOOGLE_API_KEY'];
    }

    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty || apiKey == null) {
      return CityValidationResult(isValid: false);
    }

    final query = Uri.encodeComponent(trimmedValue);

    // Enhanced API call with language support and better result types
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=$query'
      '&result_type=locality|administrative_area_level_1|administrative_area_level_2'
      '&language=en|de|fr|es|it|pt|nl' // Support multiple languages
      '&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'OK') {
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          // If Google found ANY results for our city query, it's valid
          // Google is very good at matching international city names
          for (var result in results) {
            final List types = result['types'] ?? [];
            final addressComponents = result['address_components'] as List?;

            // Check if this result contains location types we're interested in
            bool hasValidType = types.any(
              (type) => [
                'locality',
                'administrative_area_level_1',
                'administrative_area_level_2',
                'administrative_area_level_3',
                'political',
              ].contains(type),
            );

            if (hasValidType && addressComponents != null) {
              // Find the primary city/locality name
              String? primaryCityName;
              String? countryName;

              for (var component in addressComponents) {
                final longName = component['long_name']?.toString() ?? '';
                final componentTypes = component['types'] as List? ?? [];

                // Get the primary locality name
                if (componentTypes.contains('locality') &&
                    primaryCityName == null) {
                  primaryCityName = longName;
                }

                // Get country for context
                if (componentTypes.contains('country') && countryName == null) {
                  countryName = longName;
                }
              }

              // If we found a city, it's valid regardless of exact name match
              // Google's geocoding handles international names beautifully
              if (primaryCityName != null) {
                // For international cities, show both the input and resolved name
                final suggestedName =
                    primaryCityName.toLowerCase() != trimmedValue.toLowerCase()
                        ? '$primaryCityName ($trimmedValue)'
                        : primaryCityName;

                return CityValidationResult(
                  isValid: true,
                  suggestedName: suggestedName,
                );
              }
            }
          }
        }
      }

      // Also handle common Google API responses that still indicate a valid location
      if (response.statusCode == 200 &&
          (data['status'] == 'ZERO_RESULTS' ||
              data['status'] == 'PARTIAL_MATCH')) {
        // Try a more permissive search as fallback
        return await _fallbackValidation(trimmedValue, apiKey);
      }

      return CityValidationResult(isValid: false);
    } catch (e) {
      // If the API fails, try fallback validation
      return await _fallbackValidation(trimmedValue, apiKey);
    }
  }

  /// Fallback validation using Places API instead of Geocoding API
  /// This handles edge cases where geocoding might be too strict
  static Future<CityValidationResult> _fallbackValidation(
    String cityName,
    String apiKey,
  ) async {
    try {
      final query = Uri.encodeComponent(cityName);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=$query'
        '&type=locality'
        '&language=en'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'OK') {
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          // If Places API found results, the city is valid
          final firstResult = results.first;
          final name = firstResult['name']?.toString() ?? cityName;

          return CityValidationResult(isValid: true, suggestedName: name);
        }
      }

      return CityValidationResult(isValid: false);
    } catch (e) {
      return CityValidationResult(isValid: false);
    }
  }
}
