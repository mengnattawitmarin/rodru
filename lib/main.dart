import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'pages/emergency_page.dart';
import 'pages/home_page.dart';
import 'pages/map_page.dart';
import 'pages/me_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/ready_page.dart';
import 'pages/sky_page.dart';
import 'pages/sos_page.dart';
import 'services/storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.open();
  final state = AppState(storage);
  runApp(RodruApp(state: state));
  await state.init();
}

class RodruApp extends StatelessWidget {
  const RodruApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'RODRU รอดรู้',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Large-text setting (C4): multiplies the phone's own text scale.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final s = AppScope.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear((mq.textScaler.scale(1) * s.textScale).clamp(0.8, 2.0))),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _Root(),
      ),
    );
  }
}

/// Chooses the first screen: onboarding (first run) → emergency mode (if on) → tabs.
class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.onboarded) return const OnboardingPage();
    if (s.emergencyMode) return const EmergencyPage(asHome: true);
    return const MainShell();
  }
}

/// Lets any page switch bottom-nav tabs (e.g. "view on map").
class ShellController extends InheritedWidget {
  const ShellController({super.key, required this.goTo, required super.child});
  final void Function(int index) goTo;

  static void go(BuildContext context, int index) =>
      context.getInheritedWidgetOfExactType<ShellController>()?.goTo(index);

  @override
  bool updateShouldNotify(ShellController oldWidget) => false;
}

class Tabs {
  static const home = 0, map = 1, ready = 2, sky = 3, me = 4;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int index = 0;
  Timer? _autoRefresh;

  // C2: keep data fresh — on return to the app and every 15 minutes while open.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoRefresh = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) AppScope.read(context).refreshIfStale(maxAge: const Duration(minutes: 14));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) AppScope.read(context).refreshIfStale();
  }
  // Pages are built lazily the first time their tab is opened, then kept alive.
  final _built = <int>{0};

  Widget _page(int i) => switch (i) {
        Tabs.home => const HomePage(),
        Tabs.map => const MapPage(),
        Tabs.ready => const ReadyPage(),
        Tabs.sky => const SkyPage(),
        _ => const MePage(),
      };

  void goTo(int i) => setState(() {
        index = i;
        _built.add(i);
      });

  @override
  Widget build(BuildContext context) {
    return ShellController(
      goTo: goTo,
      child: Scaffold(
        // Always-reachable SOS (hidden on the map tab, which has its own SOS button).
        floatingActionButton: index == Tabs.map
            ? null
            : FloatingActionButton.extended(
                heroTag: 'sos',
                backgroundColor: red,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage())),
                icon: const Icon(Icons.sos),
                label: const Text('SOS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
        body: SafeArea(
          child: IndexedStack(
            index: index,
            children: [for (var i = 0; i < 5; i++) _built.contains(i) ? _page(i) : const SizedBox.shrink()],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: navBar,
          indicatorColor: blue.withValues(alpha: .18),
          selectedIndex: index,
          onDestinationSelected: goTo,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'หน้าหลัก'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'แผนที่'),
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'เตรียมพร้อม'),
            NavigationDestination(icon: Icon(Icons.wb_twilight_outlined), selectedIcon: Icon(Icons.wb_twilight), label: 'ท้องฟ้า'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'ฉัน'),
          ],
        ),
      ),
    );
  }
}
