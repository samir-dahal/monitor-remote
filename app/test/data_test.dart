import 'dart:convert';

import 'package:benq_bridge/data/models.dart';
import 'package:benq_bridge/data/pairing_link.dart';
import 'package:flutter_test/flutter_test.dart';

// Trimmed from a real /api/monitors response.
const _serverJson = '''
[
  {"id":"DISPLAY1","device":"\\\\\\\\.\\\\DISPLAY1","name":"Generic PnP Monitor","model":"Generic PnP Monitor",
   "primary":true,"ddcChannel":true,"supported":false,"width":1536,"height":864,"physicalMonitors":1,
   "categories":["Picture"],"features":[]},
  {"id":"DISPLAY4","device":"\\\\\\\\.\\\\DISPLAY4","name":"BenQ GW2490","model":"GW2490","primary":false,
   "ddcChannel":true,"supported":true,"width":1920,"height":1080,"mccsVersion":"2.2","physicalMonitors":1,
   "categories":["Picture","Eye Care"],
   "features":[
     {"hex":"10","code":16,"name":"Brightness","category":"Picture","kind":"continuous","unit":"%","writable":true,"max":100,"value":25},
     {"hex":"19","code":25,"name":"Low Blue Light","category":"Eye Care","kind":"discrete","writable":true,"max":5,"value":1,
      "options":[{"value":0,"label":"Off"},{"value":1,"label":"Level 1"}]},
     {"hex":"04","code":4,"name":"Restore Factory Defaults","category":"System","kind":"action","writable":true,"max":0},
     {"hex":"C1","code":193,"name":"Firmware","category":"Advanced","kind":"info","writable":false,"max":0,"value":71}
   ]}
]
''';

void main() {
  group('Monitor.fromJson', () {
    final monitors = [
      for (final item in jsonDecode(_serverJson) as List<dynamic>) Monitor.fromJson(item as Map<String, dynamic>),
    ];

    test('reads what the bridge sends', () {
      expect(monitors, hasLength(2));

      final benq = monitors[1];
      expect(benq.name, 'BenQ GW2490');
      expect(benq.model, 'GW2490');
      expect(benq.features, hasLength(4));
    });

    test('tells continuous, discrete, action and info features apart', () {
      final benq = monitors[1];

      expect(benq.feature(VcpCodes.brightness)!.kind, FeatureKind.continuous);
      expect(benq.feature(VcpCodes.lowBlueLight)!.kind, FeatureKind.discrete);
      expect(benq.feature(VcpCodes.restoreFactoryDefaults)!.isAction, isTrue);
      expect(benq.feature(0xC1)!.kind, FeatureKind.info);
    });

    test('keeps option lists and units', () {
      final benq = monitors[1];

      expect(benq.feature(VcpCodes.brightness)!.unit, '%');
      expect(benq.feature(VcpCodes.lowBlueLight)!.optionFor(1)!.label, 'Level 1');
      expect(benq.feature(VcpCodes.lowBlueLight)!.hasOption(3), isFalse);
    });

    test('only a monitor that answered with features is usable', () {
      expect(monitors[0].usable, isFalse, reason: 'laptop panel has no DDC/CI');
      expect(monitors[1].usable, isTrue);
    });

    test('formats the VCP code as the two-digit hex the API expects', () {
      expect(monitors[1].feature(VcpCodes.restoreFactoryDefaults)!.hex, '04');
      expect(monitors[1].feature(0xC1)!.hex, 'C1');
    });

    test('withFeatureValue changes one value and leaves the rest', () {
      final changed = monitors[1].withFeatureValue(VcpCodes.brightness, 60);

      expect(changed.valueOf(VcpCodes.brightness), 60);
      expect(changed.valueOf(VcpCodes.lowBlueLight), 1);
      expect(monitors[1].valueOf(VcpCodes.brightness), 25, reason: 'original is unchanged');
    });

    test('tolerates unknown kinds and missing fields', () {
      final feature = Feature.fromJson({'code': 1, 'name': 'Odd', 'kind': 'something-new'});

      expect(feature.kind, FeatureKind.info);
      expect(feature.options, isEmpty);
      expect(feature.value, isNull);
    });
  });

  group('PairingLink.tryParseQr', () {
    test('reads the link in the pairing QR code', () {
      final link = PairingLink.tryParseQr('http://192.168.2.220:5080/#t=9f2c41ab');

      expect(link, isNotNull);
      expect(link!.baseUrl.toString(), 'http://192.168.2.220:5080');
      expect(link.token, '9f2c41ab');
      expect(link.address, '192.168.2.220:5080');
    });

    test('uses the default port when the link has none', () {
      expect(PairingLink.tryParseQr('http://192.168.1.5/#t=abc')!.baseUrl.port, PairingLink.defaultPort);
    });

    test('keeps a custom port', () {
      expect(PairingLink.tryParseQr('http://192.168.1.5:6000/#t=abc')!.baseUrl.port, 6000);
    });

    test('decodes a percent-encoded token', () {
      expect(PairingLink.tryParseQr('http://10.0.0.2:5080/#t=a%2Bb')!.token, 'a+b');
    });

    test('ignores surrounding whitespace', () {
      expect(PairingLink.tryParseQr('  http://10.0.0.2:5080/#t=abc \n'), isNotNull);
    });

    test('rejects anything that is not a BenQ Bridge pairing link', () {
      for (final raw in [
        '',
        'hello',
        'https://example.com',
        'http://192.168.1.5:5080/',
        'http://192.168.1.5:5080/#t=',
        'http://192.168.1.5:5080/#x=abc',
        'ftp://192.168.1.5/#t=abc',
        'WIFI:S:home;T:WPA;P:secret;;',
      ]) {
        expect(PairingLink.tryParseQr(raw), isNull, reason: raw);
      }
    });
  });

  group('PairingLink.fromManualEntry', () {
    test('accepts a bare address and fills in the default port', () {
      final link = PairingLink.fromManualEntry('192.168.2.220', ' abc ');

      expect(link!.baseUrl.toString(), 'http://192.168.2.220:5080');
      expect(link.token, 'abc');
    });

    test('accepts host:port and a full URL', () {
      expect(PairingLink.fromManualEntry('192.168.2.220:6001', 'abc')!.baseUrl.port, 6001);
      expect(PairingLink.fromManualEntry('http://pc.local:5080/', 'abc')!.host, 'pc.local');
    });

    test('needs both an address and a token', () {
      expect(PairingLink.fromManualEntry('', 'abc'), isNull);
      expect(PairingLink.fromManualEntry('192.168.2.220', '  '), isNull);
    });
  });

  test('two links to the same PC with the same token are equal', () {
    final a = PairingLink.tryParseQr('http://10.0.0.2:5080/#t=abc')!;
    final b = PairingLink.fromManualEntry('10.0.0.2', 'abc')!;

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
