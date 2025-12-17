import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_dictionary/services/api_service.dart';

void main() {
  group('ApiService Tests', () {
    final service = ApiService();

    test('searchEnglish returns mnemonic', () async {
      // Mock search for 'gloomy' should return specific mnemonic
      final result = await service.searchEnglish("gloomy");
      expect(result.mnemonic, contains("구름이"));
    });

    test('searchEnglish returns generic mnemonic for unknown words', () async {
      final result = await service.searchEnglish("unknownword123");
      expect(result.mnemonic, contains("소리내어 3번"));
    });

    test('searchKorean returns fallback definition', () async {
      final result = await service.searchKorean("사랑");
      // Current implementation returns equivalents (translated) or fallback
      // We just check if it returns a non-null definition
      expect(result.korDefinition, isNotNull);
    });
  });
}
