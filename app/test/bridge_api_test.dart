import 'dart:async';
import 'dart:convert';

import 'package:benq_bridge/data/bridge_api.dart';
import 'package:benq_bridge/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/rig.dart';

const _monitorsJson = '''
[{"id":"DISPLAY4","name":"BenQ GW2490","model":"GW2490","supported":true,"ddcChannel":true,
  "features":[{"hex":"10","code":16,"name":"Brightness","category":"Picture","kind":"continuous",
               "unit":"%","writable":true,"max":100,"value":25}]}]
''';

HttpBridgeApi apiWith(MockClientHandler handler, {Duration timeout = const Duration(seconds: 2)}) =>
    HttpBridgeApi(testLink, client: MockClient(handler), timeout: timeout);

void main() {
  group('reading monitors', () {
    test('asks the PC for /api/monitors with the token', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return http.Response(_monitorsJson, 200);
      });

      final monitors = await api.monitors();

      expect(seen.method, 'GET');
      expect(seen.url.toString(), 'http://192.168.2.220:5080/api/monitors');
      expect(seen.headers['X-Api-Token'], 'abc123');
      expect(monitors.single.name, 'BenQ GW2490');
      expect(monitors.single.valueOf(VcpCodes.brightness), 25);
    });
  });

  group('writing', () {
    test('sends the value as JSON to the two-digit hex code', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      await api.writeVcp('DISPLAY4', VcpCodes.pictureMode, 15);

      expect(seen.method, 'PUT');
      expect(seen.url.path, '/api/monitors/DISPLAY4/vcp/DC');
      expect(seen.headers['X-Api-Token'], 'abc123');
      expect(seen.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(seen.body), {'value': 15});
    });

    test('pads single-digit codes', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      await api.writeVcp('DISPLAY4', VcpCodes.restoreFactoryDefaults, 1);

      expect(seen.url.path, endsWith('/vcp/04'));
    });

    test('encodes a monitor id with odd characters', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      await api.writeVcp('DISPLAY 1', VcpCodes.brightness, 5);

      expect(seen.url.toString(), contains('/api/monitors/DISPLAY%201/vcp/10'));
    });

    test('refresh posts to the refresh endpoint', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      await api.refresh('DISPLAY4');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/monitors/DISPLAY4/refresh');
    });
  });

  group('when something goes wrong', () {
    test('a rejected token is reported as unauthorized', () async {
      final api = apiWith((_) async => http.Response('{"error":"unauthorized"}', 401));

      await expectLater(
        api.monitors(),
        throwsA(isA<BridgeException>().having((e) => e.unauthorized, 'unauthorized', isTrue)),
      );
    });

    test("the PC's own error message is passed on", () async {
      final api = apiWith((_) async => http.Response('{"error":"value not in the advertised set"}', 400));

      await expectLater(
        api.writeVcp('DISPLAY4', VcpCodes.pictureMode, 99),
        throwsA(isA<BridgeException>()
            .having((e) => e.message, 'message', 'value not in the advertised set')
            .having((e) => e.unauthorized, 'unauthorized', isFalse)),
      );
    });

    test('an error without a JSON body still gets a readable message', () async {
      final api = apiWith((_) async => http.Response('<html>oops</html>', 500));

      await expectLater(
        api.monitors(),
        throwsA(isA<BridgeException>().having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('an unreachable PC says to check the Wi-Fi', () async {
      final api = apiWith((_) async => throw http.ClientException('connection refused'));

      await expectLater(
        api.monitors(),
        throwsA(isA<BridgeException>().having((e) => e.message, 'message', contains('same Wi-Fi'))),
      );
    });

    test('a PC that never answers times out with a clear message', () async {
      final api = apiWith((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 30));

      await expectLater(
        api.monitors(),
        throwsA(isA<BridgeException>().having((e) => e.message, 'message', contains("didn't answer"))),
      );
    });
  });
}
