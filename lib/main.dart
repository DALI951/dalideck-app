import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'sync.dart';
import 'i18n.dart';
import 'ui/home.dart';

const _bg = Color(0xFF0B0D10);
const _panel = Color(0xFF15181E);
const _accent = Color(0xFFDC2626);
const _muted = Color(0xFF9AA3AD);

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: _accent,
        surface: _panel,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        filled: true,
        fillColor: _panel,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _panel,
        indicatorColor: _accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: Colors.white70, fontSize: 12),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? _accent : _muted)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

const kMuted = _muted;
const kAccent = _accent;
const kPanel = _panel;
const kBg = _bg;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await loadStore();
  final sync = SyncEngine(store);
  store.syncRequested = sync.markSaved;
  runApp(DalideckApp(store: store, sync: sync));
}

class DalideckApp extends StatefulWidget {
  final Store store;
  final SyncEngine sync;
  const DalideckApp({super.key, required this.store, required this.sync});

  @override
  State<DalideckApp> createState() => _DalideckAppState();
}

class _DalideckAppState extends State<DalideckApp> {
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _lang = widget.store.s.settings.lang == 'ar' ? 'ar' : 'en';
    widget.sync.load();
  }

  @override
  Widget build(BuildContext context) {
    final ar = _lang == 'ar';
    L.lang = _lang;
    return MaterialApp(
      title: 'DaliDeck',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      builder: (context, child) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeShell(store: widget.store, sync: widget.sync, lang: _lang),
    );
  }
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}