import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/angelgtrr/QRMultiReader';
const _historyKey = 'scan_history';

class HistoryEntry {
  HistoryEntry(this.code, this.time);
  final String code;
  final DateTime time;

  Map<String, dynamic> toJson() => {'c': code, 't': time.toIso8601String()};
  factory HistoryEntry.fromJson(Map<String, dynamic> j) =>
      HistoryEntry(j['c'] as String, DateTime.parse(j['t'] as String));
}

Future<List<HistoryEntry>> loadHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_historyKey);
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List)
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveHistory(List<HistoryEntry> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _historyKey, jsonEncode(list.map((e) => e.toJson()).toList()));
}

void main() => runApp(const QrMultiReaderApp());

class QrMultiReaderApp extends StatelessWidget {
  const QrMultiReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRMultiReader',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
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
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    loadHistory().then((h) {
      if (mounted) setState(() => _history = h);
    });
  }

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
      _history = [HistoryEntry(code, now), ..._history];
    });
    saveHistory(_history);
    if (!_chain) _stop();
  }

  void _clear() {
    setState(() {
      _note.clear();
      _count = 0;
      _lastCode = null;
    });
  }

  Future<void> _openHistory() async {
    final updated = await Navigator.of(context).push<List<HistoryEntry>>(
      MaterialPageRoute(builder: (_) => HistoryPage(entries: _history)),
    );
    if (updated != null) {
      setState(() => _history = updated);
      saveHistory(updated);
    }
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
        title: Text(_scanning && _chain ? 'Chain scan: $_count' : 'QRMultiReader'),
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'QRMultiReader',
              applicationLegalese: 'Created by angelgtrr',
              children: [
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(_repoUrl),
                      mode: LaunchMode.externalApplication),
                  child: Text(
                    _repoUrl,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.entries});
  final List<HistoryEntry> entries;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<HistoryEntry> _entries = List.of(widget.entries);

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_entries);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('History (${_entries.length})'),
          actions: [
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed:
                  _entries.isEmpty ? null : () => setState(() => _entries = []),
            ),
          ],
        ),
        body: _entries.isEmpty
            ? const Center(child: Text('No scans yet'))
            : ListView.separated(
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  return Dismissible(
                    key: ObjectKey(e),
                    background: Container(color: Colors.red),
                    onDismissed: (_) => setState(() => _entries.removeAt(i)),
                    child: ListTile(
                      title: Text(e.code),
                      subtitle: Text(_fmt(e.time)),
                      trailing: const Icon(Icons.copy, size: 18),
                      onTap: () => _copy(e.code),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
