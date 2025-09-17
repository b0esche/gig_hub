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
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=$query&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'OK') {
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          // For geocoding API, we just check if we got any results
          // and if they contain locality information
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
              // Check if any address component matches our input
              for (var component in addressComponents) {
                final longName = component['long_name']?.toString() ?? '';
                final shortName = component['short_name']?.toString() ?? '';
                final componentTypes = component['types'] as List? ?? [];

                if (componentTypes.contains('locality') ||
                    componentTypes.contains('administrative_area_level_1')) {
                  if (longName.toLowerCase().contains(
                        trimmedValue.toLowerCase(),
                      ) ||
                      shortName.toLowerCase().contains(
                        trimmedValue.toLowerCase(),
                      ) ||
                      trimmedValue.toLowerCase().contains(
                        longName.toLowerCase(),
                      )) {
                    return CityValidationResult(
                      isValid: true,
                      suggestedName: longName,
                    );
                  }
                }
              }
            }
          }
        }
      }
      return CityValidationResult(isValid: false);
    } catch (e) {
      return CityValidationResult(isValid: false);
    }
  }
}
