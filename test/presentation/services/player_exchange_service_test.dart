import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/presentation/services/player_exchange_service.dart';

void main() {
  group('PlayerExchangeService.parsePlayersForImport', () {
    final service = PlayerExchangeService();

    test('拡張子が未設定でも JSON を読み込める', () {
      const content =
          '[{"id":"1","name":"Alice","yomigana":"ありす","gender":1,"isActive":true,"isMustRest":false}]';

      final players = service.parsePlayersForImport(content: content);

      expect(players, isNotNull);
      expect(players, hasLength(1));
      expect(players!.first.name, 'Alice');
    });

    test('UTF-8 BOM 付き JSON を読み込める', () {
      const bom = '\uFEFF';
      const content =
          '$bom[{"id":"2","name":"Bob","yomigana":"ぼぶ","gender":0,"isActive":true,"isMustRest":false}]';

      final players = service.parsePlayersForImport(
        content: content,
        extension: 'json',
      );

      expect(players, isNotNull);
      expect(players, hasLength(1));
      expect(players!.first.name, 'Bob');
    });

    test('拡張子が未設定でも CSV を読み込める', () {
      const content =
          'id,name,yomigana,gender,isActive,isMustRest,excludedPartnerId\n3,Carol,きゃろる,1,1,0,';

      final players = service.parsePlayersForImport(content: content);

      expect(players, isNotNull);
      expect(players, hasLength(1));
      expect(players!.first.name, 'Carol');
    });
  });
}
