import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/bridge_api.dart';
import '../data/pairing_link.dart';

/// Builds the camera view. Swapped out in tests, where there is no camera.
typedef ScannerBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onCode);

Widget cameraScanner(BuildContext context, ValueChanged<String> onCode) =>
    _CameraScanner(onCode: onCode);

/// First-run screen, and the way to switch PCs later: scan the QR code on the PC's
/// "Pair your phone" page, or type the address and token.
class PairScreen extends StatefulWidget {
  const PairScreen({
    super.key,
    this.canClose = false,
    this.scannerBuilder = cameraScanner,
  });

  /// Show a back button. Off on first run, when there is nothing to go back to.
  final bool canClose;
  final ScannerBuilder scannerBuilder;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _address = TextEditingController();
  final _token = TextEditingController();

  bool _busy = false;
  bool _manual = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  void _onCode(String raw) {
    if (_busy) return;

    final link = PairingLink.tryParseQr(raw);
    if (link == null) {
      setState(
        () => _error =
            "That QR code isn't from BenQ Bridge. Scan the one on your PC's pairing page.",
      );
      return;
    }

    _connect(link);
  }

  void _submitManual() {
    final link = PairingLink.fromManualEntry(_address.text, _token.text);
    if (link == null) {
      setState(() => _error = 'Enter your PC\'s address and the token.');
      return;
    }

    _connect(link);
  }

  Future<void> _connect(PairingLink link) async {
    final controller = BridgeScope.read(context);
    final navigator = Navigator.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await controller.pair(link);
      if (mounted && widget.canClose && navigator.canPop()) navigator.pop();
    } on BridgeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: widget.canClose ? AppBar() : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Pair your PC',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Start BenQ Bridge on your PC. Its browser page shows a QR code. Scan it here.',
              style: TextStyle(color: c.muted, fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: c.surface,
                          child: widget.scannerBuilder(context, _onCode),
                        ),
                        if (_busy)
                          ColoredBox(
                            color: Colors.black54,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  'Connecting…',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.badSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: c.bad, fontSize: 14, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _manual = !_manual),
              child: Text(
                _manual
                    ? 'Hide manual entry'
                    : 'Enter the address and token instead',
              ),
            ),
            if (_manual) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'PC address',
                  hintText: '192.168.1.20:5080',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  hintText: 'From the PC\'s pairing page',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submitManual,
                child: const Text('Connect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CameraScanner extends StatelessWidget {
  const _CameraScanner({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return MobileScanner(
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null) {
            onCode(raw);
            return;
          }
        }
      },
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? "Camera access is off. Allow it in your phone's settings, or enter the details instead."
                : "The camera isn't available. Enter the details instead.",
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 15, height: 1.4),
          ),
        ),
      ),
    );
  }
}
