import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const QrMultiScanApp());

class QrMultiScanApp extends StatelessWidget {
  const QrMultiScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Multi Scan',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ScanPage(),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _note = TextEditingController();

  bool _scanning = false;
  bool _chain = false;
  int _count = 0;
  String? _lastCode;
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _camera.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _start({required bool chain}) async {
    setState(() {
      _chain = chain;
      _scanning = true;
      _lastCode = null;
    });
    await _camera.start();
  }

  Future<void> _stop() async {
    await _camera.stop();
    if (mounted) setState(() => _scanning = false);
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null || code.isEmpty) return;

    // Ignore the same code being re-read while it is still in front of the camera.
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastTime).inSeconds < 3) {
      _lastTime = now;
      return;
    }
    _lastCode = code;
    _lastTime = now;

    HapticFeedback.mediumImpact();
    setState(() {
      _count++;
      final sep = _note.text.isEmpty ? '' : '\n\n';
      _note.text = '${_note.text}${sep}Scan $_count\n$code';
    });
    if (!_chain) _stop();
  }

  void _clear() {
    setState(() {
      _note.clear();
      _count = 0;
      _lastCode = null;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _note.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Note copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scanning && _chain ? 'Chain scan: $_count' : 'QR Multi Scan'),
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'QR Multi Scan',
              applicationLegalese: 'Created by angelgtrr',
            ),
          ),
          IconButton(
            tooltip: 'Copy note',
            icon: const Icon(Icons.copy),
            onPressed: _note.text.isEmpty ? null : _copy,
          ),
          IconButton(
            tooltip: 'Clear note',
            icon: const Icon(Icons.delete_outline),
            onPressed: _note.text.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_scanning)
            SizedBox(
              height: 280,
              child: MobileScanner(
                controller: _camera,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Text('Camera error: ${error.errorCode.name}'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _scanning
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop),
                      label: Text(_chain ? 'Stop chain' : 'Cancel'),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _start(chain: false),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Single scan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _start(chain: true),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Start chain'),
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: _note,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Scanned codes appear here as a note…',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
