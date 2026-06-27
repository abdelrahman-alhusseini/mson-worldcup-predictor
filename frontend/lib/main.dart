import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const displayGoldBgAsset = 'assets/display_gold_bg.png';
const displayGold = Color(0xFFD7A63A);
const displayGoldSoft = Color(0xFFF0D48A);
const displayDeepNavy = Color(0xFF07182E);
const displayPanelNavy = Color(0xFF0A1E38);
const primaryBlue = displayGold;
const deepBlue = displayDeepNavy;
const darkerBlue = displayDeepNavy;
const lightBlue = Color(0x332D8CFF);
const brandNavy = Color(0xFFF8FAFF);
const mutedNavy = Color(0xFFD4DBE8);
const borderBlue = Color(0x66D7A63A);
const cardBorder = Color(0x66D7A63A);
const winGreen = Color(0xFF18A66A);
const warningOrange = Color(0xFFC47A00);
const appWallpaperAsset = 'assets/app_wallpaper.png';
const appDarkBgAsset = 'assets/app_dark_bg.png';
const loginDarkBgAsset = 'assets/login_dark_bg.png';
const appWallpaperWideAsset = 'assets/app_wallpaper_wide.png';
const displayFlyerAsset = 'assets/display_flyer_bg.png';

const configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

const configuredDisplayQrUrl = String.fromEnvironment(
  'DISPLAY_QR_URL',
  defaultValue: '',
);

String get apiBaseUrl {
  final configured = configuredApiBaseUrl.trim();
  if (configured.isNotEmpty) return configured;

  final host = Uri.base.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host.isEmpty) {
    return 'http://127.0.0.1:8000';
  }

  // Production default: same origin as the hosted site.
  // The Python backend in v13 can serve the Flutter web build and the API together.
  return '';
}

String get displayQrUrl {
  final configured = configuredDisplayQrUrl.trim();
  if (configured.isNotEmpty) return configured;

  final uri = Uri.base;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port/';
}

bool get isDisplayRoute {
  final uri = Uri.base;
  final path = uri.path.toLowerCase();
  final fragment = uri.fragment.toLowerCase();
  final query = uri.queryParameters.map(
    (key, value) => MapEntry(key.toLowerCase(), value.toLowerCase()),
  );

  return path.endsWith('/display') ||
      fragment == '/display' ||
      fragment.startsWith('/display?') ||
      query['display'] == '1' ||
      query['screen'] == 'display';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: FriendlyErrorBox(
          title: 'Something went wrong',
          message:
              'Please refresh the page or contact the admin if this continues.',
        ),
      ),
    );
  };
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  runZonedGuarded(
    () => runApp(const MsonCupApp()),
    (error, stack) => debugPrint('Unhandled app error: $error'),
  );
}

class MsonCupApp extends StatefulWidget {
  const MsonCupApp({super.key});

  @override
  State<MsonCupApp> createState() => _MsonCupAppState();
}

class _MsonCupAppState extends State<MsonCupApp> {
  final api = ApiClient();
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await api.loadToken();
    if (api.token != null) {
      try {
        user = await api.me();
      } catch (_) {
        await api.logout();
      }
    }
    setState(() => loading = false);
  }

  Future<void> _signedIn(Map<String, dynamic> auth) async {
    setState(() => user = auth['user'] as Map<String, dynamic>);
  }

  Future<void> _logout() async {
    await api.logout();
    setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Michael & Son Cup',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: displayGold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: displayDeepNavy,
        fontFamily: 'Arial',
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: brandNavy,
              displayColor: brandNavy,
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: displayDeepNavy.withOpacity(.92),
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: displayPanelNavy,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: TextStyle(
            color: Colors.white.withOpacity(.82),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: displayGold.withOpacity(.38)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: displayGold,
            foregroundColor: displayDeepNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: displayGoldSoft,
            side: BorderSide(color: displayGold.withOpacity(.58)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: displayGoldSoft,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: displayPanelNavy.withOpacity(.78),
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(.76),
            fontWeight: FontWeight.w800,
          ),
          hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: displayGold.withOpacity(.32)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: displayGold.withOpacity(.32)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: displayGold, width: 1.5),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: displayGold,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? displayDeepNavy : Colors.white.withOpacity(.82),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? displayDeepNavy : displayGoldSoft,
            );
          }),
        ),
      ),
      home: isDisplayRoute
          ? DisplayScreen(api: api)
          : loading
              ? const LoadingScreen()
              : user == null
                  ? AuthScreen(api: api, onSignedIn: _signedIn)
                  : AppShell(api: api, user: user!, onLogout: _logout),
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  String? token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
  }

  Future<void> saveToken(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', value);
  }

  Future<void> logout() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final uri = apiBaseUrl.isEmpty
        ? Uri.base.resolve(path)
        : Uri.parse('$apiBaseUrl$path');
    late http.Response response;

    if (method == 'GET') {
      response = await http.get(uri, headers: _headers);
    } else if (method == 'POST') {
      response =
          await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
    } else if (method == 'PATCH') {
      response = await http.patch(uri,
          headers: _headers, body: jsonEncode(body ?? {}));
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: _headers);
    } else {
      throw ApiException('Unsupported request method');
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 400) {
      final detail = decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Request failed';
      throw ApiException(detail);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> register(
      String fullName, String password) async {
    final auth = await _request('POST', '/auth/register', body: {
      'full_name': fullName,
      'password': password,
    }) as Map<String, dynamic>;
    await saveToken(auth['token'] as String);
    return auth;
  }

  Future<Map<String, dynamic>> login(String fullName, String password) async {
    final auth = await _request('POST', '/auth/login', body: {
      'full_name': fullName,
      'password': password,
    }) as Map<String, dynamic>;
    await saveToken(auth['token'] as String);
    return auth;
  }

  Future<Map<String, dynamic>> me() async {
    return await _request('GET', '/me') as Map<String, dynamic>;
  }

  Future<List<dynamic>> matches({String scope = 'all'}) async {
    return await _request('GET', '/matches?scope=$scope') as List<dynamic>;
  }

  Future<void> predict(int matchId, String prediction) async {
    await _request('POST', '/predictions', body: {
      'match_id': matchId,
      'prediction': prediction,
    });
  }

  Future<void> unlockPrediction(int matchId) async {
    await _request('DELETE', '/predictions/$matchId');
  }

  Future<List<dynamic>> leaderboard() async {
    return await _request('GET', '/leaderboard') as List<dynamic>;
  }

  Future<List<dynamic>> publicLeaderboard({int limit = 10}) async {
    return await _request('GET', '/public/leaderboard?limit=$limit')
        as List<dynamic>;
  }

  Future<List<dynamic>> myPredictions() async {
    return await _request('GET', '/my-predictions') as List<dynamic>;
  }

  Future<void> createMatch(String teamA, String teamB, String kickoffAt,
      String voteDeadlineAt, String stage) async {
    await _request('POST', '/admin/matches', body: {
      'team_a': teamA,
      'team_b': teamB,
      'kickoff_at': kickoffAt,
      'vote_deadline_at': voteDeadlineAt,
      'stage': stage,
    });
  }

  Future<void> updateMatch(
      int matchId,
      String teamA,
      String teamB,
      String kickoffAt,
      String voteDeadlineAt,
      String stage,
      String status) async {
    await _request('PATCH', '/admin/matches/$matchId', body: {
      'team_a': teamA,
      'team_b': teamB,
      'kickoff_at': kickoffAt,
      'vote_deadline_at': voteDeadlineAt,
      'stage': stage,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> setResult(int matchId, String result) async {
    return await _request('PATCH', '/admin/matches/$matchId/result', body: {
      'final_result': result,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminMatchPredictions(int matchId) async {
    return await _request('GET', '/admin/matches/$matchId/predictions')
        as Map<String, dynamic>;
  }

  Future<void> deleteMatch(int matchId) async {
    await _request('DELETE', '/admin/matches/$matchId');
  }

  Future<void> seedDemo() async {
    await _request('POST', '/admin/seed-demo');
  }

  Future<List<dynamic>> adminUsers() async {
    return await _request('GET', '/admin/users') as List<dynamic>;
  }

  Future<void> deleteUser(int userId) async {
    await _request('DELETE', '/admin/users/$userId');
  }

  Future<void> resetUserPassword(int userId, String newPassword) async {
    await _request('PATCH', '/admin/users/$userId/password', body: {
      'new_password': newPassword,
    });
  }

  Future<void> setUserManualPoints(int userId, int manualPoints) async {
    await _request('PATCH', '/admin/users/$userId/manual-points', body: {
      'manual_points': manualPoints,
    });
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppScreenBackground(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late Future<List<dynamic>> future;
  Timer? timer;
  DateTime? lastUpdated;

  @override
  void initState() {
    super.initState();
    future = _load();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) refresh();
    });
  }

  Future<List<dynamic>> _load() async {
    final data = await widget.api.publicLeaderboard(limit: 10);
    if (mounted) setState(() => lastUpdated = DateTime.now());
    return data;
  }

  void refresh() {
    setState(() => future = _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String get _updatedText {
    final updated = lastUpdated;
    if (updated == null) return 'Updating live';
    final hh = updated.hour.toString().padLeft(2, '0');
    final mm = updated.minute.toString().padLeft(2, '0');
    return 'Last updated: $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: displayDeepNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;

          final leaderboard = DisplayLeaderboardBlock(
            future: future,
            onRefresh: refresh,
            updatedText: _updatedText,
          );

          const qr = DisplayQrBlock();

          if (compact) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const DisplayGoldBackground(),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            leaderboard,
                            const SizedBox(height: 16),
                            qr,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final leaderboardWidth = (w * .36).clamp(470.0, 600.0).toDouble();
          final qrWidth = (w * .20).clamp(260.0, 320.0).toDouble();
          final sidePadding = (w * .045).clamp(40.0, 72.0).toDouble();
          final bottomPadding = (h * .06).clamp(28.0, 56.0).toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              const DisplayGoldBackground(),
              Positioned(
                left: sidePadding,
                bottom: bottomPadding,
                width: leaderboardWidth,
                child: leaderboard,
              ),
              Positioned(
                right: sidePadding,
                bottom: bottomPadding,
                width: qrWidth,
                child: qr,
              ),
            ],
          );
        },
      ),
    );
  }
}

class DisplayGoldBackground extends StatelessWidget {
  const DisplayGoldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          displayGoldBgAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(.06),
                  Colors.transparent,
                  Colors.black.withOpacity(.14),
                ],
                stops: const [0.0, .58, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DisplayQrBlock extends StatelessWidget {
  const DisplayQrBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: displayGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final qrSize =
              (constraints.maxWidth - 40).clamp(180.0, 245.0).toDouble();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SCAN TO JOIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: displayDeepNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD9DDE4),
                    width: 1.5,
                  ),
                ),
                child: QrImageView(
                  data: displayQrUrl,
                  version: QrVersions.auto,
                  size: qrSize,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Create your account\nand start predicting!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: displayDeepNavy,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DisplayLeaderboardBlock extends StatelessWidget {
  const DisplayLeaderboardBlock({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.updatedText,
  });

  final Future<List<dynamic>> future;
  final VoidCallback onRefresh;
  final String updatedText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: displayPanelNavy.withOpacity(.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: displayGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.30),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOP 10 LEADERBOARD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: displayGold, size: 22),
                splashRadius: 20,
                tooltip: 'Refresh',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              updatedText,
              style: TextStyle(
                color: Colors.white.withOpacity(.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 10),
            color: displayGold.withOpacity(.22),
          ),
          FutureBuilder<List<dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const FriendlyErrorBox(
                  title: 'Leaderboard updating',
                  message: 'The latest scores will appear here automatically.',
                );
              }

              final rows = (snapshot.data ?? []).cast<Map<String, dynamic>>();

              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'No scores yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children:
                    rows.map((row) => DisplayLeaderboardRow(row: row)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DisplayLeaderboardRow extends StatelessWidget {
  const DisplayLeaderboardRow({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final rank = row['rank'] ?? '-';
    final points = row['points'] ?? 0;
    final name = row['full_name']?.toString() ?? 'Player';

    final leading = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: rank == 1 ? displayGold.withOpacity(.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              leading,
              style: TextStyle(
                color: rank is int && rank > 3 ? Colors.white : displayGoldSoft,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$points pts',
            style: const TextStyle(
              color: displayGoldSoft,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AppScreenBackground extends StatelessWidget {
  const AppScreenBackground({
    super.key,
    required this.child,
    this.veilOpacity = 0,
    this.imageAlignment = Alignment.center,
    this.showWallpaper = true,
  });

  final Widget child;
  final double veilOpacity;
  final Alignment imageAlignment;
  final bool showWallpaper;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: displayDeepNavy,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showWallpaper)
            Positioned.fill(
              child: Image.asset(
                appDarkBgAsset,
                fit: BoxFit.cover,
                alignment: imageAlignment,
                filterQuality: FilterQuality.high,
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.08 + veilOpacity),
                    Colors.black.withOpacity(.24 + veilOpacity),
                    Colors.black.withOpacity(.42 + veilOpacity),
                  ],
                  stops: const [0.0, .56, 1.0],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PageLane extends StatelessWidget {
  const PageLane({
    super.key,
    required this.child,
    this.maxContentWidth = 720,
    this.topPadding = 125,
  });

  final Widget child;
  final double maxContentWidth;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final horizontal = w >= 1400
            ? 72.0
            : w >= 900
                ? 36.0
                : 18.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, topPadding, horizontal, 110),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onSignedIn});

  final ApiClient api;
  final ValueChanged<Map<String, dynamic>> onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = isLogin
          ? await widget.api.login(nameController.text, passwordController.text)
          : await widget.api
              .register(nameController.text, passwordController.text);
      widget.onSignedIn(auth);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: displayDeepNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            loginDarkBgAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.05),
                    Colors.black.withOpacity(.18),
                    Colors.black.withOpacity(.40),
                  ],
                  stops: const [0.0, .55, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AuthCard(
                    isLogin: isLogin,
                    busy: busy,
                    error: error,
                    nameController: nameController,
                    passwordController: passwordController,
                    onModeChanged: (value) => setState(() {
                      isLogin = value;
                      error = null;
                    }),
                    onSubmit: submit,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginIntroText extends StatelessWidget {
  const LoginIntroText({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(color: brandNavy),
      child: Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            'World Cup 2026\nPredictor',
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: compact ? 34 : 38,
              height: .98,
              fontWeight: FontWeight.w700,
              letterSpacing: -.7,
              color: brandNavy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Predict the match result, lock your pick,\nand climb the Michael & Son leaderboard.',
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              height: 1.38,
              fontWeight: FontWeight.w800,
              color: mutedNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.isLogin,
    required this.busy,
    required this.error,
    required this.nameController,
    required this.passwordController,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final bool isLogin;
  final bool busy;
  final String? error;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: displayDeepNavy.withOpacity(.88),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: displayGold.withOpacity(.88), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.46),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: displayGold.withOpacity(.13),
            blurRadius: 34,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: displayGold, size: 54),
          const SizedBox(height: 12),
          const Text(
            'MICHAEL & SON',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: displayGoldSoft,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'WORLD CUP PREDICTOR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AuthModeButton(
                    label: 'Login',
                    active: isLogin,
                    onTap: () => onModeChanged(true),
                  ),
                ),
                Expanded(
                  child: _AuthModeButton(
                    label: 'Create account',
                    active: !isLogin,
                    onTap: () => onModeChanged(false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isLogin ? 'Welcome Back' : 'Create Your Account',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLogin
                ? 'Sign in to continue your predictions'
                : 'Join the competition and start predicting',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(.72),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
            decoration: _darkInputDecoration(
              label: 'Full name',
              hint: 'First name and last name',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: true,
            onSubmitted: (_) => onSubmit(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
            decoration: _darkInputDecoration(
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE1E1).withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0xFFFF8A8A).withOpacity(.40)),
              ),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFB3B3),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: displayGold,
                foregroundColor: displayDeepNavy,
                disabledBackgroundColor: displayGold.withOpacity(.45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: displayDeepNavy,
                      ),
                    )
                  : Text(
                      isLogin ? 'LOG IN' : 'CREATE ACCOUNT',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Predict. Compete. Win.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: displayGoldSoft.withOpacity(.86),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: active ? displayGold : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? displayDeepNavy : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _darkInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: displayGoldSoft),
    labelStyle: TextStyle(
      color: Colors.white.withOpacity(.70),
      fontWeight: FontWeight.w800,
    ),
    hintStyle: TextStyle(
      color: Colors.white.withOpacity(.42),
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: Colors.black.withOpacity(.20),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(.16)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(.16)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: displayGold, width: 1.5),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell(
      {super.key,
      required this.api,
      required this.user,
      required this.onLogout});

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  bool get isAdmin => widget.user['role'] == 'admin';

  String get initials {
    final parts =
        widget.user['full_name'].toString().trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second =
        parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HubPage(api: widget.api),
      LeaderboardPage(api: widget.api),
      MyPicksPage(api: widget.api),
      if (isAdmin) AdminPage(api: widget.api),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
          icon: Icon(Icons.sports_soccer), label: 'Hub'),
      const NavigationDestination(
          icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
      const NavigationDestination(icon: Icon(Icons.history), label: 'My Picks'),
      if (isAdmin)
        const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: displayDeepNavy,
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: displayGold, size: 26),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'MICHAEL & SON CUP',
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: displayGold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: displayDeepNavy,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: displayDeepNavy.withOpacity(.90),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.24),
              shape: BoxShape.circle,
              border: Border.all(color: displayGold.withOpacity(.55)),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: displayGoldSoft,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: displayGold),
            label: const Text(
              'Logout',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppScreenBackground(
        imageAlignment: Alignment.center,
        child: pages[index],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        decoration: BoxDecoration(
          color: displayDeepNavy.withOpacity(.90),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: displayGold.withOpacity(.34)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.transparent,
            indicatorColor: displayGold.withOpacity(.95),
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

class HubPage extends StatefulWidget {
  const HubPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  late Future<List<dynamic>> future;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    future = widget.api.matches();
    refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  void refresh() => setState(() => future = widget.api.matches());

  Future<void> lockPrediction(
      Map<String, dynamic> match, String prediction) async {
    final label = predictionLabel(match, prediction);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock prediction?'),
        content: Text(
            'You selected $label. You can still unlock and change it before the voting deadline.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lock it in')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.api.predict(match['id'] as int, prediction);
      if (mounted) {
        showSnack(context, 'Prediction locked');
        refresh();
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> unlockPrediction(Map<String, dynamic> match) async {
    final myPrediction = match['my_prediction'] as Map<String, dynamic>?;
    final currentPick = myPrediction == null
        ? 'your prediction'
        : predictionLabel(match, myPrediction['prediction'].toString());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock prediction?'),
        content: Text(
            'This will remove $currentPick. You can choose again before the voting deadline closes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unlock')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.api.unlockPrediction(match['id'] as int);
      if (mounted) {
        showSnack(
            context, 'Prediction unlocked. Choose again before the deadline.');
        refresh();
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return PageLane(
              child: ErrorState(
                  message: snapshot.error.toString(), onRetry: refresh),
            );
          }
          final matches = snapshot.data ?? [];
          return PageLane(
            maxContentWidth: 820,
            topPadding: 165,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Match Centre',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: brandNavy)),
                          SizedBox(height: 6),
                          Text(
                              'Predict before kickoff. Votes become visible after the match starts.',
                              style: TextStyle(
                                  color: mutedNavy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    FilledButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh')),
                  ],
                ),
                const SizedBox(height: 18),
                if (matches.isEmpty)
                  const EmptyState(
                    title: 'No matches yet',
                    message:
                        'Matches will appear here as soon as they are added.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final cardWidth = width >= 700 ? (width - 18) / 2 : width;
                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: matches
                            .cast<Map<String, dynamic>>()
                            .map((match) => SizedBox(
                                  width: cardWidth,
                                  child: MatchCard(
                                      match: match,
                                      onPrediction: lockPrediction,
                                      onUnlockPrediction: unlockPrediction),
                                ))
                            .toList(),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MatchCard extends StatefulWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.onPrediction,
    required this.onUnlockPrediction,
  });

  final Map<String, dynamic> match;
  final Future<void> Function(Map<String, dynamic> match, String prediction)
      onPrediction;
  final Future<void> Function(Map<String, dynamic> match) onUnlockPrediction;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  String? selected;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final kickoff = DateTime.parse(match['kickoff_at']).toLocal();
    final deadline = DateTime.parse(
            (match['vote_deadline_at'] ?? match['kickoff_at']).toString())
        .toLocal();
    final localHasStarted = !kickoff.isAfter(DateTime.now());
    final localPredictionsClosed = !deadline.isAfter(DateTime.now());
    final hasStarted = match['has_started'] == true || localHasStarted;
    final predictionsClosed =
        match['predictions_closed'] == true || localPredictionsClosed;
    final isFinished = match['is_finished'] == true;
    final myPrediction = match['my_prediction'] as Map<String, dynamic>?;
    final canPredict =
        myPrediction == null && !predictionsClosed && !isFinished;
    final canUnlock = myPrediction != null && !predictionsClosed && !isFinished;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (match['stage'] ?? 'Match').toString().toUpperCase(),
                  style: const TextStyle(
                      color: mutedNavy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
              StatusPill(isFinished: isFinished, hasStarted: hasStarted),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.event, size: 18, color: mutedNavy),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Match starts: ${formatKickoff(kickoff)}',
                  style: const TextStyle(
                      color: mutedNavy, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DeadlineText(deadline: deadline, isFinished: isFinished),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TeamName(
                  name: match['team_a'].toString(),
                  flag: flagEmojiForTeam(match['team_a'].toString()),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('VS',
                    style: TextStyle(
                        fontSize: 18,
                        color: mutedNavy,
                        fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: TeamName(
                  name: match['team_b'].toString(),
                  flag: flagEmojiForTeam(match['team_b'].toString()),
                  alignRight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (myPrediction != null) ...[
            LockedPrediction(
                match: match,
                prediction: myPrediction['prediction'].toString()),
            if (canUnlock) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          await widget.onUnlockPrediction(match);
                          if (mounted) setState(() => busy = false);
                        },
                  icon: const Icon(Icons.lock_open),
                  label: Text(busy ? 'Unlocking...' : 'Unlock / change pick'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ] else if (canPredict)
            PredictionPicker(
              match: match,
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            )
          else
            Text(
              isFinished ? 'Match finished' : 'Predictions closed',
              style: const TextStyle(
                  color: mutedNavy, fontWeight: FontWeight.bold),
            ),
          if (canPredict) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selected == null || busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await widget.onPrediction(match, selected!);
                        if (mounted) setState(() => busy = false);
                      },
                icon: const Icon(Icons.lock),
                label: Text(busy ? 'Locking...' : 'Lock prediction'),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (match['stats_visible'] == true && match['stats'] != null)
            StatsView(match: match)
          else
            const Text('Vote percentages hidden until the voting deadline',
                style: TextStyle(color: mutedNavy, fontSize: 13)),
          if (match['final_result'] != null) ...[
            const SizedBox(height: 12),
            Text(
                'Final result: ${predictionLabel(match, match['final_result'].toString())}',
                style: const TextStyle(
                    color: warningOrange, fontWeight: FontWeight.w900)),
          ],
        ],
      ),
    );
  }
}

class DeadlineText extends StatefulWidget {
  const DeadlineText(
      {super.key, required this.deadline, required this.isFinished});
  final DateTime deadline;
  final bool isFinished;

  @override
  State<DeadlineText> createState() => _DeadlineTextState();
}

class _DeadlineTextState extends State<DeadlineText> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFinished) {
      return const Text('Final result confirmed',
          style: TextStyle(color: mutedNavy, fontWeight: FontWeight.w700));
    }
    final remaining = widget.deadline.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return const Text('Voting closed • percentages are visible',
          style: TextStyle(color: warningOrange, fontWeight: FontWeight.w900));
    }
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes =
        remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final prefix = days > 0 ? '${days}d ' : '';
    return Text(
      'Voting closes in $prefix$hours:$minutes:$seconds',
      style: const TextStyle(color: brandNavy, fontWeight: FontWeight.w900),
    );
  }
}

class TeamName extends StatelessWidget {
  const TeamName({
    super.key,
    required this.name,
    required this.flag,
    this.alignRight = false,
  });

  final String name;
  final String flag;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            flag,
            style: const TextStyle(fontSize: 25),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name.toUpperCase(),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class PredictionPicker extends StatelessWidget {
  const PredictionPicker(
      {super.key,
      required this.match,
      required this.selected,
      required this.onChanged});
  final Map<String, dynamic> match;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: ['A', 'DRAW', 'B'].map((value) {
            final active = selected == value;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: () => onChanged(value),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: active ? primaryBlue : borderBlue),
                    backgroundColor: active
                        ? displayGold
                        : displayPanelNavy.withOpacity(.72),
                    foregroundColor: active ? displayDeepNavy : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text(
                    predictionLabel(match, value),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class LockedPrediction extends StatelessWidget {
  const LockedPrediction(
      {super.key, required this.match, required this.prediction});
  final Map<String, dynamic> match;
  final String prediction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: winGreen.withOpacity(.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: winGreen.withOpacity(.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: winGreen),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Locked: ${predictionLabel(match, prediction)}',
                  style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key, required this.match});
  final Map<String, dynamic> match;

  @override
  Widget build(BuildContext context) {
    final stats = match['stats'] as Map<String, dynamic>;
    final percentages = stats['percentages'] as Map<String, dynamic>;
    final total = stats['total'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups, size: 18, color: mutedNavy),
            const SizedBox(width: 6),
            Text('$total predictions',
                style: const TextStyle(
                    color: mutedNavy, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        StatBar(
            label: predictionLabel(match, 'A'),
            percent: (percentages['A'] ?? 0) as int),
        const SizedBox(height: 8),
        StatBar(label: 'Draw', percent: (percentages['DRAW'] ?? 0) as int),
        const SizedBox(height: 8),
        StatBar(
            label: predictionLabel(match, 'B'),
            percent: (percentages['B'] ?? 0) as int),
      ],
    );
  }
}

class StatBar extends StatelessWidget {
  const StatBar({super.key, required this.label, required this.percent});
  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 118,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: mutedNavy, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: Color(0x1A0B4FA3),
              color: primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
            width: 38,
            child: Text('$percent%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.leaderboard();
  }

  void refresh() => setState(() => future = widget.api.leaderboard());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        return PageLane(
          maxContentWidth: 760,
          topPadding: 165,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Leaderboard',
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w900))),
                  FilledButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: const [
                    Icon(Icons.update, color: mutedNavy, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Points update after final results are confirmed by admin.',
                        style: TextStyle(
                            color: mutedNavy, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                ErrorState(message: snapshot.error.toString(), onRetry: refresh)
              else if ((snapshot.data ?? []).isEmpty)
                const EmptyState(
                    title: 'No users yet',
                    message:
                        'Leaderboard will appear after employees create accounts.')
              else
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(displayGold.withOpacity(.18)),
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Points')),
                        DataColumn(label: Text('Correct')),
                        DataColumn(label: Text('Predictions')),
                      ],
                      rows: (snapshot.data ?? [])
                          .cast<Map<String, dynamic>>()
                          .map((row) {
                        return DataRow(cells: [
                          DataCell(Text(row['rank'].toString())),
                          DataCell(Text(row['full_name'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          DataCell(Text(row['points'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900))),
                          DataCell(Text(row['correct_predictions'].toString())),
                          DataCell(Text(row['total_predictions'].toString())),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MyPicksPage extends StatefulWidget {
  const MyPicksPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<MyPicksPage> createState() => _MyPicksPageState();
}

class _MyPicksPageState extends State<MyPicksPage> {
  late Future<List<dynamic>> future;
  int? unlockingMatchId;

  @override
  void initState() {
    super.initState();
    future = widget.api.myPredictions();
  }

  void refresh() => setState(() => future = widget.api.myPredictions());

  Future<void> unlockFromMyPicks(Map<String, dynamic> row) async {
    final matchId = row['match_id'];
    if (matchId == null) {
      showSnack(
        context,
        'Please open Match Centre to change this prediction.',
        isError: true,
      );
      return;
    }

    final fakeMatch = {'team_a': row['team_a'], 'team_b': row['team_b']};
    final currentPick =
        predictionLabel(fakeMatch, row['prediction'].toString());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock prediction?'),
        content: Text(
          'This will remove $currentPick. You can choose again before the voting deadline closes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => unlockingMatchId = matchId as int);
      await widget.api.unlockPrediction(matchId as int);
      if (mounted) {
        showSnack(
          context,
          'Prediction unlocked. Go to Match Centre and choose again.',
        );
        refresh();
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => unlockingMatchId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        return PageLane(
          maxContentWidth: 700,
          topPadding: 165,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My Picks',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                ErrorState(message: snapshot.error.toString(), onRetry: refresh)
              else if ((snapshot.data ?? []).isEmpty)
                const EmptyState(
                  title: 'No predictions yet',
                  message: 'Your locked predictions will appear here.',
                )
              else
                Column(
                  children: (snapshot.data ?? [])
                      .cast<Map<String, dynamic>>()
                      .map((row) {
                    final fakeMatch = {
                      'team_a': row['team_a'],
                      'team_b': row['team_b'],
                    };

                    final deadlineValue =
                        (row['vote_deadline_at'] ?? row['kickoff_at'])
                            .toString();
                    final deadline = DateTime.parse(deadlineValue).toLocal();
                    final isFinished = row['status'] == 'finished';
                    final canUnlock =
                        !isFinished && deadline.isAfter(DateTime.now());
                    final matchId = row['match_id'];
                    final isUnlocking =
                        matchId != null && unlockingMatchId == matchId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row['team_a']} vs ${row['team_b']}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Pick: ${predictionLabel(fakeMatch, row['prediction'].toString())}',
                                        style:
                                            const TextStyle(color: mutedNavy),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Voting deadline: ${formatKickoff(deadline)}',
                                        style: const TextStyle(
                                          color: mutedNavy,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  row['status'] == 'finished'
                                      ? '${row['points']} pt'
                                      : 'Pending',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: brandNavy,
                                  ),
                                ),
                              ],
                            ),
                            if (canUnlock) ...[
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: isUnlocking
                                    ? null
                                    : () => unlockFromMyPicks(row),
                                icon: const Icon(Icons.lock_open),
                                label: Text(
                                  isUnlocking
                                      ? 'Unlocking...'
                                      : 'Unlock / change pick',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryBlue,
                                  side: const BorderSide(color: primaryBlue),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AdminDateTimePicker extends StatelessWidget {
  const AdminDateTimePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? helperText;

  int get _hour12 {
    if (value.hour == 0) return 12;
    if (value.hour > 12) return value.hour - 12;
    return value.hour;
  }

  String get _ampm => value.hour >= 12 ? 'PM' : 'AM';

  DateTime _updated({int? hour12, int? minute, String? ampm, DateTime? date}) {
    final selectedHour12 = hour12 ?? _hour12;
    final selectedMinute = minute ?? value.minute;
    final selectedAmPm = ampm ?? _ampm;
    int hour24 = selectedHour12 % 12;
    if (selectedAmPm == 'PM') hour24 += 12;

    final selectedDate = date ?? value;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour24,
      selectedMinute,
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null) {
      onChanged(_updated(date: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 460,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: displayPanelNavy.withOpacity(.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: displayGold.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: brandNavy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickDate(context),
            icon: const Icon(Icons.calendar_month),
            label: Text(formatDateOnly(value)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 92,
                child: DropdownButtonFormField<int>(
                  value: _hour12,
                  decoration: const InputDecoration(labelText: 'Hour'),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) onChanged(_updated(hour12: value));
                  },
                ),
              ),
              SizedBox(
                width: 102,
                child: DropdownButtonFormField<int>(
                  value: value.minute,
                  menuMaxHeight: 260,
                  decoration: const InputDecoration(labelText: 'Min'),
                  items: List.generate(
                    60,
                    (index) => DropdownMenuItem<int>(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    ),
                  ),
                  onChanged: (minute) {
                    if (minute != null) onChanged(_updated(minute: minute));
                  },
                ),
              ),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  value: _ampm,
                  decoration: const InputDecoration(labelText: 'AM/PM'),
                  items: const [
                    DropdownMenuItem(value: 'AM', child: Text('AM')),
                    DropdownMenuItem(value: 'PM', child: Text('PM')),
                  ],
                  onChanged: (value) {
                    if (value != null) onChanged(_updated(ampm: value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Will show as: ${formatKickoff(value)}',
            style: const TextStyle(
              color: mutedNavy,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText!,
              style: const TextStyle(
                color: mutedNavy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final teamA = TextEditingController();
  final teamB = TextEditingController();
  final stage = TextEditingController(text: 'World Cup 2026');
  late DateTime newKickoffLocal;
  late DateTime newDeadlineLocal;
  late Future<List<dynamic>> matchesFuture;
  late Future<List<dynamic>> usersFuture;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    newKickoffLocal = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      tomorrow.hour,
      0,
    );
    newDeadlineLocal = newKickoffLocal.subtract(const Duration(hours: 1));
    matchesFuture = widget.api.matches();
    usersFuture = widget.api.adminUsers();
  }

  String _toUtcIso(DateTime value) => value.toUtc().toIso8601String();

  void refreshAll() {
    setState(() {
      matchesFuture = widget.api.matches();
      usersFuture = widget.api.adminUsers();
    });
  }

  Future<void> createMatch() async {
    setState(() => busy = true);
    try {
      await widget.api.createMatch(
        teamA.text,
        teamB.text,
        _toUtcIso(newKickoffLocal),
        _toUtcIso(newDeadlineLocal),
        stage.text,
      );
      teamA.clear();
      teamB.clear();
      if (mounted) {
        showSnack(context, 'Match added');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> seedDemo() async {
    setState(() => busy = true);
    try {
      await widget.api.seedDemo();
      if (mounted) {
        showSnack(context, '1 AM matches added');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setResult(Map<String, dynamic> match, String result) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Set final result?',
      message:
          'Result will be ${predictionLabel(match, result)}. Prediction points will be recalculated automatically.',
      confirmLabel: 'Save result',
    );
    if (!confirm) return;

    try {
      final data = await widget.api.setResult(match['id'] as int, result);
      if (mounted) {
        showSnack(context,
            'Updated ${data['updated_predictions']} predictions, ${data['correct_predictions']} correct');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  Future<void> viewPredictions(Map<String, dynamic> match) async {
    Future<Map<String, dynamic>> future =
        widget.api.adminMatchPredictions(match['id'] as int);

    Future<void> applyResult(
      BuildContext dialogContext,
      StateSetter setDialogState,
      String result,
    ) async {
      final confirm = await showConfirmDialog(
        dialogContext,
        title: 'Apply result and points?',
        message:
            'Final result will be ${predictionLabel(match, result)}. Correct predictions get +1 point and wrong predictions get 0.',
        confirmLabel: 'Apply points',
      );
      if (!confirm) return;

      try {
        final data = await widget.api.setResult(match['id'] as int, result);
        if (!mounted) return;
        showSnack(
          context,
          'Scored ${data['updated_predictions']} predictions, ${data['correct_predictions']} correct',
        );
        refreshAll();
        setDialogState(() {
          future = widget.api.adminMatchPredictions(match['id'] as int);
        });
      } catch (e) {
        if (mounted) showErrorDialog(context, e.toString());
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text('${match['team_a']} vs ${match['team_b']}'),
            content: SizedBox(
              width: 780,
              child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return FriendlyErrorBox(
                      title: 'Could not load predictions',
                      message: snapshot.error.toString(),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final rows = (data['rows'] as List? ?? [])
                      .cast<Map<String, dynamic>>();
                  final matchInfo =
                      (data['match'] as Map? ?? {}).cast<String, dynamic>();
                  final finalLabel =
                      matchInfo['final_result_label']?.toString() ?? 'Not set';
                  final total = data['total_predictions'] ?? rows.length;
                  final correct = data['correct_predictions'] ?? 0;
                  final wrong = data['wrong_predictions'] ?? 0;

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Total: $total')),
                            Chip(label: Text('Correct: $correct')),
                            Chip(label: Text('Wrong: $wrong')),
                            Chip(label: Text('Current result: $finalLabel')),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Apply final result:',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: brandNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => applyResult(
                                  dialogContext, setDialogState, 'A'),
                              child: Text('${match['team_a']} won'),
                            ),
                            OutlinedButton(
                              onPressed: () => applyResult(
                                  dialogContext, setDialogState, 'DRAW'),
                              child: const Text('Draw'),
                            ),
                            FilledButton(
                              onPressed: () => applyResult(
                                  dialogContext, setDialogState, 'B'),
                              child: Text('${match['team_b']} won'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (rows.isEmpty)
                          const Text(
                            'No predictions for this match yet.',
                            style: TextStyle(
                              color: mutedNavy,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          Column(
                            children: rows
                                .map((row) => PredictionReviewRow(row: row))
                                .toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> deleteMatch(Map<String, dynamic> match) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete match?',
      message:
          'This will remove ${match['team_a']} vs ${match['team_b']} and all predictions for it.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirm) return;

    try {
      await widget.api.deleteMatch(match['id'] as int);
      if (mounted) {
        showSnack(context, 'Match deleted');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  Future<void> editMatch(Map<String, dynamic> match) async {
    final teamAController =
        TextEditingController(text: match['team_a'].toString());
    final teamBController =
        TextEditingController(text: match['team_b'].toString());
    final stageController =
        TextEditingController(text: match['stage'].toString());
    DateTime kickoffLocal = DateTime.parse(match['kickoff_at']).toLocal();
    DateTime deadlineLocal = DateTime.parse(
      (match['vote_deadline_at'] ?? match['kickoff_at']).toString(),
    ).toLocal();
    String status = match['status'].toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit match'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                      controller: teamAController,
                      decoration: const InputDecoration(labelText: 'Team A')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: teamBController,
                      decoration: const InputDecoration(labelText: 'Team B')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: stageController,
                      decoration: const InputDecoration(labelText: 'Stage')),
                  const SizedBox(height: 14),
                  AdminDateTimePicker(
                    label: 'Match start date & time',
                    value: kickoffLocal,
                    helperText:
                        'This is what users will see on the match card.',
                    onChanged: (value) =>
                        setDialogState(() => kickoffLocal = value),
                  ),
                  const SizedBox(height: 12),
                  AdminDateTimePicker(
                    label: 'Voting deadline date & time',
                    value: deadlineLocal,
                    helperText:
                        'Users can predict, unlock, and change picks until this time.',
                    onChanged: (value) =>
                        setDialogState(() => deadlineLocal = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status == 'finished' ? 'finished' : 'scheduled',
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'scheduled', child: Text('Scheduled')),
                      DropdownMenuItem(
                          value: 'finished', child: Text('Finished')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? 'scheduled'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await widget.api.updateMatch(
        match['id'] as int,
        teamAController.text,
        teamBController.text,
        _toUtcIso(kickoffLocal),
        _toUtcIso(deadlineLocal),
        stageController.text,
        status,
      );
      if (mounted) {
        showSnack(context, 'Match updated');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  Future<void> editUser(Map<String, dynamic> user) async {
    final pointsController =
        TextEditingController(text: user['manual_points'].toString());
    final passwordController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage ${user['full_name']}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('Username: ${user['normalized_name']}'),
              const SizedBox(height: 6),
              const Text('Password: hidden securely. You can reset it below.',
                  style: TextStyle(color: mutedNavy)),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Manual leaderboard points'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration:
                    const InputDecoration(labelText: 'New password (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (saved != true) return;
    try {
      await widget.api.setUserManualPoints(
          user['id'] as int, int.parse(pointsController.text.trim()));
      if (passwordController.text.trim().isNotEmpty) {
        await widget.api.resetUserPassword(
            user['id'] as int, passwordController.text.trim());
      }
      if (mounted) {
        showSnack(context, 'User updated');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete user?',
      message:
          'This will delete ${user['full_name']} and all of their predictions.',
      confirmLabel: 'Delete user',
      danger: true,
    );
    if (!confirm) return;

    try {
      await widget.api.deleteUser(user['id'] as int);
      if (mounted) {
        showSnack(context, 'User deleted');
        refreshAll();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageLane(
      maxContentWidth: 980,
      topPadding: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Admin Dashboard',
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900))),
              FilledButton.icon(
                  onPressed: refreshAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'Manage matches, voting deadlines, users, passwords, and leaderboard points.',
              style: TextStyle(color: mutedNavy, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add match',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                  'Choose the date and local time exactly as you want users to see it. The app saves the correct UTC time automatically.',
                  style:
                      TextStyle(color: mutedNavy, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                        width: 190,
                        child: TextField(
                            controller: teamA,
                            decoration:
                                const InputDecoration(labelText: 'Team A'))),
                    SizedBox(
                        width: 190,
                        child: TextField(
                            controller: teamB,
                            decoration:
                                const InputDecoration(labelText: 'Team B'))),
                    SizedBox(
                        width: 190,
                        child: TextField(
                            controller: stage,
                            decoration:
                                const InputDecoration(labelText: 'Stage'))),
                    AdminDateTimePicker(
                      label: 'Match start date & time',
                      value: newKickoffLocal,
                      helperText:
                          'This time will be shown on the user match card.',
                      onChanged: (value) =>
                          setState(() => newKickoffLocal = value),
                    ),
                    AdminDateTimePicker(
                      label: 'Voting deadline date & time',
                      value: newDeadlineLocal,
                      helperText:
                          'Users can unlock/change their prediction until this time.',
                      onChanged: (value) =>
                          setState(() => newDeadlineLocal = value),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                        onPressed: busy ? null : createMatch,
                        icon: const Icon(Icons.add),
                        label: const Text('Add match')),
                    OutlinedButton.icon(
                        onPressed: busy ? null : seedDemo,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Add 1 AM matches')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<dynamic>>(
            future: matchesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: snapshot.error.toString(), onRetry: refreshAll);
              }
              final matches = snapshot.data ?? [];
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Matches',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (matches.isEmpty)
                      const Text('No matches yet.',
                          style: TextStyle(color: mutedNavy))
                    else
                      ...matches
                          .cast<Map<String, dynamic>>()
                          .map((match) => AdminMatchRow(
                                match: match,
                                onEdit: () => editMatch(match),
                                onDelete: () => deleteMatch(match),
                                onSetResult: (result) =>
                                    setResult(match, result),
                                onViewPredictions: () => viewPredictions(match),
                              )),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<dynamic>>(
            future: usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: snapshot.error.toString(), onRetry: refreshAll);
              }
              final users = snapshot.data ?? [];
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Users & Leaderboard Control',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text(
                        'Passwords are not viewable because they are stored securely. Admin can reset passwords here.',
                        style: TextStyle(
                            color: mutedNavy, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (users.isEmpty)
                      const Text('No users yet.',
                          style: TextStyle(color: mutedNavy))
                    else
                      ...users
                          .cast<Map<String, dynamic>>()
                          .map((user) => AdminUserRow(
                                user: user,
                                onEdit: () => editUser(user),
                                onDelete: user['role'] == 'admin'
                                    ? null
                                    : () => deleteUser(user),
                              )),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminMatchRow extends StatelessWidget {
  const AdminMatchRow({
    super.key,
    required this.match,
    required this.onEdit,
    required this.onDelete,
    required this.onSetResult,
    required this.onViewPredictions,
  });

  final Map<String, dynamic> match;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onSetResult;
  final VoidCallback onViewPredictions;

  @override
  Widget build(BuildContext context) {
    final kickoff = DateTime.parse(match['kickoff_at']).toLocal();
    final deadline = DateTime.parse(
      (match['vote_deadline_at'] ?? match['kickoff_at']).toString(),
    ).toLocal();
    final stats = (match['stats'] as Map?)?.cast<String, dynamic>();
    final totalPredictions = stats?['total'] ?? 0;
    final finalResult = match['final_result'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: displayPanelNavy.withOpacity(.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: displayGold.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${flagEmojiForTeam(match['team_a'].toString())} ${match['team_a']} vs ${flagEmojiForTeam(match['team_b'].toString())} ${match['team_b']}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB00020),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${match['stage']}',
            style:
                const TextStyle(color: mutedNavy, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event, size: 17, color: primaryBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Match starts: ${formatKickoff(kickoff)}',
                  style: const TextStyle(
                    color: brandNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.lock_clock, size: 17, color: warningOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Voting deadline: ${formatKickoff(deadline)}',
                  style: const TextStyle(
                    color: mutedNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Predictions: $totalPredictions • Result: ${finalResult == null ? 'Not set' : predictionLabel(match, finalResult.toString())}',
            style: const TextStyle(
              color: brandNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onViewPredictions,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View predictions'),
              ),
              OutlinedButton(
                onPressed: () => onSetResult('A'),
                child: Text('${match['team_a']} won'),
              ),
              OutlinedButton(
                onPressed: () => onSetResult('DRAW'),
                child: const Text('Draw'),
              ),
              OutlinedButton(
                onPressed: () => onSetResult('B'),
                child: Text('${match['team_b']} won'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PredictionReviewRow extends StatelessWidget {
  const PredictionReviewRow({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final isCorrect = row['is_correct'];
    final points = row['points'] ?? 0;

    Color badgeColor;
    String badgeText;

    if (isCorrect == true) {
      badgeColor = winGreen;
      badgeText = 'Correct +1';
    } else if (isCorrect == false) {
      badgeColor = warningOrange;
      badgeText = 'Wrong +0';
    } else {
      badgeColor = mutedNavy;
      badgeText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: displayPanelNavy.withOpacity(.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: displayGold.withOpacity(.28)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['full_name']?.toString() ?? 'Player',
                  style: const TextStyle(
                    color: brandNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row['username']?.toString() ?? '',
                  style: const TextStyle(color: mutedNavy, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row['prediction_label']?.toString() ?? '-',
              style: const TextStyle(
                color: brandNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withOpacity(.35)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              '$points pts',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUserRow extends StatelessWidget {
  const AdminUserRow(
      {super.key, required this.user, required this.onEdit, this.onDelete});
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: displayPanelNavy.withOpacity(.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: displayGold.withOpacity(.28))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['full_name'].toString(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    'Username: ${user['normalized_name']} • Role: ${user['role']}',
                    style: const TextStyle(color: mutedNavy)),
                Text(
                    'Manual points: ${user['manual_points']} • Prediction points: ${user['prediction_points'] ?? 0} • Predictions: ${user['total_predictions'] ?? 0}',
                    style: const TextStyle(
                        color: mutedNavy, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.manage_accounts),
              label: const Text('Manage')),
          if (onDelete != null)
            IconButton(
                onPressed: onDelete,
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFB00020))),
        ],
      ),
    );
  }
}

class FriendlyErrorBox extends StatelessWidget {
  const FriendlyErrorBox(
      {super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: displayGold.withOpacity(.28)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 24,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB00020), size: 38),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: brandNavy)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: mutedNavy, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

Future<bool> showConfirmDialog(BuildContext context,
    {required String title,
    required String message,
    required String confirmLabel,
    bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
              backgroundColor: danger ? const Color(0xFFB00020) : primaryBlue),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

Future<void> showErrorDialog(BuildContext context, String message) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Something went wrong'),
      content: Text(message.replaceFirst('Exception: ', '')),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(22)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: displayPanelNavy.withOpacity(.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: displayGold.withOpacity(.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: displayGold.withOpacity(.05),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
      {super.key, required this.isFinished, required this.hasStarted});
  final bool isFinished;
  final bool hasStarted;

  @override
  Widget build(BuildContext context) {
    final label = isFinished
        ? 'Finished'
        : hasStarted
            ? 'Live / Closed'
            : 'Open';
    final color = isFinished
        ? mutedNavy
        : hasStarted
            ? warningOrange
            : winGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(.15),
          borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.sports_soccer,
                    size: 32, color: primaryBlue),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: mutedNavy, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 42, color: Color(0xFFB00020)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String predictionLabel(Map<String, dynamic> match, String value) {
  if (value == 'A') return '${match['team_a']} Win';
  if (value == 'B') return '${match['team_b']} Win';
  return 'Draw';
}

String formatDateOnly(DateTime dt) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatKickoff(DateTime dt) {
  final hour12 = dt.hour == 0
      ? 12
      : dt.hour > 12
          ? dt.hour - 12
          : dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${formatDateOnly(dt)} • $hour12:$minute $ampm';
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? const Color(0xFFB00020) : primaryBlue,
    ),
  );
}

String flagEmojiForTeam(String team) {
  final key = team.trim().toLowerCase();
  const flags = {
    'argentina': '🇦🇷',
    'australia': '🇦🇺',
    'austria': '🇦🇹',
    'belgium': '🇧🇪',
    'brazil': '🇧🇷',
    'cameroon': '🇨🇲',
    'canada': '🇨🇦',
    'chile': '🇨🇱',
    'china': '🇨🇳',
    'colombia': '🇨🇴',
    'costa rica': '🇨🇷',
    'croatia': '🇭🇷',
    'czech republic': '🇨🇿',
    'denmark': '🇩🇰',
    'ecuador': '🇪🇨',
    'egypt': '🇪🇬',
    'england': '🏴\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}',
    'france': '🇫🇷',
    'germany': '🇩🇪',
    'ghana': '🇬🇭',
    'greece': '🇬🇷',
    'haiti': '🇭🇹',
    'hungary': '🇭🇺',
    'india': '🇮🇳',
    'iran': '🇮🇷',
    'iraq': '🇮🇶',
    'ireland': '🇮🇪',
    'italy': '🇮🇹',
    'japan': '🇯🇵',
    'jordan': '🇯🇴',
    'kuwait': '🇰🇼',
    'mexico': '🇲🇽',
    'morocco': '🇲🇦',
    'netherlands': '🇳🇱',
    'new zealand': '🇳🇿',
    'nigeria': '🇳🇬',
    'norway': '🇳🇴',
    'panama': '🇵🇦',
    'paraguay': '🇵🇾',
    'peru': '🇵🇪',
    'poland': '🇵🇱',
    'portugal': '🇵🇹',
    'qatar': '🇶🇦',
    'saudi arabia': '🇸🇦',
    'scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
    'senegal': '🇸🇳',
    'serbia': '🇷🇸',
    'south africa': '🇿🇦',
    'south korea': '🇰🇷',
    'spain': '🇪🇸',
    'sweden': '🇸🇪',
    'switzerland': '🇨🇭',
    'tunisia': '🇹🇳',
    'turkey': '🇹🇷',
    'ukraine': '🇺🇦',
    'united arab emirates': '🇦🇪',
    'uae': '🇦🇪',
    'uruguay': '🇺🇾',
    'usa': '🇺🇸',
    'united states': '🇺🇸',
    'wales': '🏴',
    'uk': '🇬🇧',
    'united kingdom': '🇬🇧',
    'dr congo': '🇨🇩',
    'congo': '🇨🇩',
    'democratic republic of congo': '🇨🇩',
    'congo dr': '🇨🇩',
    'algeria': '🇩🇿',
    'uzbekistan': '🇺🇿',
    'uzebakistan': '🇺🇿',
    'uzbakistan': '🇺🇿',
  };
  return flags[key] ?? '⚽';
}
