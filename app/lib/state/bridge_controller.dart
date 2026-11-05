import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_storage.dart';
import '../data/bridge_api.dart';
import '../data/models.dart';
import '../data/pairing_link.dart';
import 'scene.dart';

enum LinkState {
  /// No PC has been paired yet.
  unpaired,

  /// Reaching the PC for the first time this session.
  connecting,

  /// Connected and receiving live updates.
  live,

  /// The PC can't be reached right now. The app keeps retrying.
  offline,

  /// The PC rejected the token. Only pairing again helps.
  unauthorized,
}

/// The app's single source of truth: the connection to the PC, the monitors it reports,
/// and what the user has saved (scenes, option names, theme).
class BridgeController extends ChangeNotifier {
  BridgeController({
    required AppStorage storage,
    required BridgeApiFactory apiFactory,
    this.retryBase = const Duration(seconds: 1),
    this.retryMax = const Duration(seconds: 10),
    this.writeGap = const Duration(milliseconds: 60),
    this.resetSettleDelay = const Duration(seconds: 4),
    this.snapshotDelay = const Duration(seconds: 2),
  }) : _storage = storage,
       _apiFactory = apiFactory;

  final AppStorage _storage;
  final BridgeApiFactory _apiFactory;
  final Duration retryBase;
  final Duration retryMax;
  final Duration writeGap;
  final Duration resetSettleDelay;
  final Duration snapshotDelay;

  final _messages = StreamController<String>.broadcast();

  PairingLink? _link;
  BridgeApi? _api;
  int _generation = 0;
  bool _disposed = false;

  LinkState _state = LinkState.unpaired;
  List<Monitor> _monitors = const [];
  String? _selectedId;

  List<Scene> _scenes = const [];
  Map<String, String> _labels = {};
  ThemeMode _themeMode = ThemeMode.system;

  /// Newest value wanted for "monitorId|code" that hasn't been sent yet.
  final Map<String, int> _desired = {};
  final Map<String, Future<void>> _pumps = {};
  final Set<int> _editing = {};
  Timer? _snapshotTimer;

  // ---------------------------------------------------------------- read side

  LinkState get linkState => _state;

  /// Controls only act while the PC is answering. Before that, the screen shows the last
  /// known values so the app doesn't open on a spinner.
  bool get canControl => _state == LinkState.live;

  PairingLink? get link => _link;

  bool get isPaired => _link != null;

  List<Monitor> get monitors => _monitors;

  List<Monitor> get usableMonitors => [
    for (final m in _monitors)
      if (m.usable) m,
  ];

  /// The monitor on screen: the chosen one, else the first that actually answered.
  Monitor? get monitor {
    for (final m in _monitors) {
      if (m.id == _selectedId) return m;
    }
    final usable = usableMonitors;
    return usable.isEmpty ? null : usable.first;
  }

  List<Scene> get scenes => List.unmodifiable(_scenes);

  ThemeMode get themeMode => _themeMode;

  /// One-line notices for the UI to show briefly ("Night applied", errors).
  Stream<String> get messages => _messages.stream;

  /// What to call [option] of [feature] on [forMonitor]: the user's own name if they set one.
  String labelFor(Monitor forMonitor, Feature feature, VcpOption option) =>
      _labels[LabelKey.of(forMonitor, feature.code, option.value)] ?? option.label;

  /// The name the user set, or null when the option still has the monitor's label.
  String? customLabel(Monitor forMonitor, int code, int value) => _labels[LabelKey.of(forMonitor, code, value)];

  // ---------------------------------------------------------------- lifecycle

  Future<void> start() async {
    _scenes = _storage.loadScenes();
    _labels = _storage.loadLabels();
    _themeMode = _storage.loadThemeMode();
    _selectedId = _storage.selectedMonitor;
    _link = await _storage.loadLink();
    if (_link != null) {
      _monitors = _storage.loadSnapshot();
      _state = LinkState.connecting;
    }
    notifyListeners();

    if (_link != null) _startLoop();
  }

  /// Checks that the PC answers with this token, remembers it, and connects.
  /// Throws [BridgeException] with a message fit for the user when it can't.
  Future<void> pair(PairingLink newLink) async {
    final probe = _apiFactory(newLink);
    try {
      await probe.monitors();
    } finally {
      probe.close();
    }

    await _storage.saveLink(newLink);
    _stopLoop();
    _link = newLink;
    _monitors = const [];
    _selectedId = null;
    _setState(LinkState.connecting);
    _startLoop();
  }

  Future<void> unpair() async {
    _stopLoop();
    await _storage.clearLink();
    _link = null;
    _monitors = const [];
    _selectedId = null;
    _setState(LinkState.unpaired);
  }

  void selectMonitor(String id) {
    _selectedId = id;
    unawaited(_storage.saveSelectedMonitor(id));
    notifyListeners();
  }

  /// Asks the PC to re-read the monitor, then pulls the fresh values.
  Future<void> reread() async {
    final api = _api;
    final current = monitor;
    if (api == null || current == null) return;

    try {
      await api.refresh(current.id);
      _applyMonitors(await api.monitors());
    } on BridgeException catch (error) {
      _handleFailure(error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _snapshotTimer?.cancel();
    _stopLoop();
    unawaited(_messages.close());
    super.dispose();
  }

  // ---------------------------------------------------------------- writing

  /// Marks [code] as being dragged, so updates from the PC don't pull the control around
  /// under the user's finger.
  void beginEdit(int code) => _editing.add(code);

  void endEdit(int code) => _editing.remove(code);

  /// Shows [value] immediately and sends it to the monitor. Rapid calls collapse to the
  /// newest value, and writes for one control always go out in order.
  void setValue(int code, int value) {
    final current = monitor;
    if (current == null) return;

    _replaceMonitor(current.withFeatureValue(code, value));

    final key = '${current.id}|$code';
    _desired[key] = value;
    notifyListeners();

    _pumps[key] ??= _pump(current.id, code, key);
  }

  Future<void> _pump(String monitorId, int code, String key) async {
    try {
      while (_desired.containsKey(key)) {
        final value = _desired.remove(key)!;
        final api = _api;
        if (api == null) return;

        try {
          await api.writeVcp(monitorId, code, value);
        } on BridgeException catch (error) {
          _desired.remove(key);
          _handleFailure(error);
          // The screen showed a value the monitor never took. Go back to what it really has.
          unawaited(_resync());
          return;
        }

        if (_desired.containsKey(key)) await Future<void>.delayed(writeGap);
      }
    } finally {
      _pumps.remove(key);
    }
  }

  /// Completes when every write queued so far has been sent.
  Future<void> settle() async {
    while (_pumps.isNotEmpty) {
      await Future.wait(_pumps.values.toList());
    }
  }

  /// Applies [scene] to the monitor on screen. Returns how many settings it changed.
  int applyScene(Scene scene) {
    final current = monitor;
    if (current == null) return 0;

    final plan = scene.planFor(current);
    if (plan.isEmpty) {
      _say("This monitor can't use the ${scene.name} scene.");
      return 0;
    }

    plan.forEach(setValue);
    _say('${scene.name} applied');
    return plan.length;
  }

  /// Sends a one-shot command such as "restore factory defaults", then re-reads the monitor
  /// once it has had time to settle.
  Future<void> runAction(int code) async {
    final api = _api;
    final current = monitor;
    if (api == null || current == null) return;

    try {
      await api.writeVcp(current.id, code, 1);
    } on BridgeException catch (error) {
      _handleFailure(error);
      return;
    }

    _say('Sent. Re-reading your monitor…');
    await Future<void>.delayed(resetSettleDelay);
    if (!_disposed) await reread();
  }

  // ---------------------------------------------------------------- scenes

  Future<void> saveScene(Scene scene) async {
    final index = _scenes.indexWhere((s) => s.id == scene.id);
    _scenes = [..._scenes];
    if (index >= 0) {
      _scenes[index] = scene;
    } else {
      _scenes.add(scene);
    }
    notifyListeners();
    await _storage.saveScenes(_scenes);
  }

  Future<void> deleteScene(String id) async {
    _scenes = [
      for (final s in _scenes)
        if (s.id != id) s,
    ];
    notifyListeners();
    await _storage.saveScenes(_scenes);
  }

  // ---------------------------------------------------------------- names and theme

  /// Gives an option your own name, or clears it when [name] is blank.
  Future<void> setLabel(Monitor forMonitor, int code, int value, String name) async {
    final key = LabelKey.of(forMonitor, code, value);
    final trimmed = name.trim();

    _labels = {..._labels};
    if (trimmed.isEmpty) {
      _labels.remove(key);
    } else {
      _labels[key] = trimmed;
    }

    notifyListeners();
    await _storage.saveLabels(_labels);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _storage.saveThemeMode(mode);
  }

  // ---------------------------------------------------------------- connection

  void _startLoop() {
    final generation = ++_generation;
    unawaited(_run(generation));
  }

  void _stopLoop() {
    _generation++;
    _desired.clear();
    _api?.close();
    _api = null;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> _run(int generation) async {
    var attempt = 0;

    while (_isCurrent(generation)) {
      final link = _link;
      if (link == null) return;

      final api = _apiFactory(link);
      _api = api;
      if (_state != LinkState.live) _setState(attempt == 0 ? LinkState.connecting : LinkState.offline);

      try {
        final initial = await api.monitors();
        if (!_isCurrent(generation)) return;

        _applyMonitors(initial);
        _setState(LinkState.live);
        attempt = 0;

        await for (final update in api.watch()) {
          if (!_isCurrent(generation)) return;
          _applyMonitors(update);
        }
      } on BridgeException catch (error) {
        if (error.unauthorized) {
          if (_isCurrent(generation)) _setState(LinkState.unauthorized);
          return;
        }
      } catch (_) {
        // Any other failure is treated as the PC being unreachable; retry below.
      } finally {
        api.close();
      }

      if (!_isCurrent(generation)) return;
      _setState(LinkState.offline);

      final wait = retryBase * math.pow(2, attempt).toInt();
      attempt++;
      await Future<void>.delayed(wait > retryMax ? retryMax : wait);
    }
  }

  Future<void> _resync() async {
    final api = _api;
    if (api == null) return;

    try {
      _applyMonitors(await api.monitors());
    } on BridgeException catch (error) {
      _handleFailure(error, quiet: true);
    }
  }

  void _handleFailure(BridgeException error, {bool quiet = false}) {
    if (error.unauthorized) {
      _stopLoop();
      _setState(LinkState.unauthorized);
      return;
    }
    if (!quiet) _say(error.message);
  }

  /// Takes the PC's view of the world, except for controls the user is touching right now.
  void _applyMonitors(List<Monitor> incoming) {
    final merged = <Monitor>[];

    for (final fresh in incoming) {
      var result = fresh;
      for (final old in _monitors.where((m) => m.id == fresh.id)) {
        for (final feature in old.features) {
          if (_isBusy(fresh.id, feature.code) && feature.value != null && fresh.feature(feature.code) != null) {
            result = result.withFeatureValue(feature.code, feature.value!);
          }
        }
      }
      merged.add(result);
    }

    _monitors = merged;
    _reconcileSelection();
    notifyListeners();
    _scheduleSnapshot();
  }

  /// Saves what the PC reported, at most once per [snapshotDelay], for the next launch.
  void _scheduleSnapshot() {
    if (_snapshotTimer?.isActive ?? false) return;
    _snapshotTimer = Timer(snapshotDelay, () {
      if (!_disposed && _link != null) unawaited(_storage.saveSnapshot(_monitors));
    });
  }

  bool _isBusy(String monitorId, int code) {
    final key = '$monitorId|$code';
    return _desired.containsKey(key) ||
        _pumps.containsKey(key) ||
        (monitor?.id == monitorId && _editing.contains(code));
  }

  void _reconcileSelection() {
    final usable = usableMonitors;
    final stillUsable = usable.any((m) => m.id == _selectedId);
    if (stillUsable || usable.isEmpty) return;

    _selectedId = usable.first.id;
  }

  void _replaceMonitor(Monitor updated) {
    _monitors = [for (final m in _monitors) m.id == updated.id ? updated : m];
  }

  void _setState(LinkState value) {
    if (_state == value) return;
    _state = value;
    if (!_disposed) notifyListeners();
  }

  void _say(String message) {
    if (!_disposed && !_messages.isClosed) _messages.add(message);
  }
}
