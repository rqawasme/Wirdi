import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routes.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/voussoir_stripe.dart';
import 'collections_screen.dart';
import 'dhikr_screen.dart';
import 'home_screen.dart';
import 'tracker_screen.dart';

/// The app: four destinations under one bar.
///
/// The bar swaps the whole body including its app bar, instantly — no
/// cross-fade, no slide, nothing that moves. A tab is a place you already know
/// you are going to, and animating the trip there only delays arriving.
///
/// The four bodies are kept alive in an [IndexedStack] rather than rebuilt on
/// each switch, which is what gives each tab its own scroll position: coming
/// back to Collections half way down the list should land half way down the
/// list.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialTab = WirdiTab.home});

  /// Home on a cold start. Settable so a test can open the shell on the tab it
  /// is about without tapping its way there.
  final WirdiTab initialTab;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late WirdiTab _active = widget.initialTab;

  /// One scroll controller per tab.
  ///
  /// Needed because the four bodies are all alive at once. A vertical
  /// [ListView] with no controller of its own attaches to the nearest
  /// [PrimaryScrollController], which would be the [Scaffold]'s — so all four
  /// tabs would share one controller and four positions, and the scroll offset
  /// of whichever tab is on screen would be read through the same object as
  /// the three behind it. Giving each tab its own is what actually keeps their
  /// positions apart.
  late final List<ScrollController> _controllers = <ScrollController>[
    for (final WirdiTab _ in WirdiTab.values) ScrollController(),
  ];

  @override
  void dispose() {
    for (final ScrollController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: <Widget>[
          // New collections are made on the Collections tab and nowhere else:
          // it is the tab about what the app contains, and Home is the tab
          // about what today contains.
          if (_active == WirdiTab.collections)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New collection',
              onPressed: () => newCollection(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Quran',
            onPressed: () => Navigator.pushNamed(context, Routes.surahList),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(VoussoirStripe.ruleHeight),
          // The rule, and not a progress bar: it is the voussoir band that
          // runs under every app bar in the app, and it means nothing about
          // how far through anything you are.
          child: VoussoirStripe.rule(),
        ),
      ),
      body: IndexedStack(
        index: _active.index,
        children: <Widget>[
          for (final (int index, Widget body) in const <Widget>[
            HomeScreen(),
            CollectionsScreen(),
            DhikrScreen(),
            TrackerScreen(),
          ].indexed)
            PrimaryScrollController(
              controller: _controllers[index],
              child: body,
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        active: _active,
        onSelect: (WirdiTab tab) {
          if (tab == _active) return;
          setState(() => _active = tab);
        },
      ),
    );
  }

  String get _title => switch (_active) {
    // "Wird" and not "Home": the tab is called Home because that is what a
    // navigation bar calls the first destination, and the screen is called
    // Wird because that is what is on it.
    WirdiTab.home => 'Wird',
    WirdiTab.collections => 'Collections',
    WirdiTab.dhikr => 'Dhikr',
    WirdiTab.tracker => 'Tracker',
  };
}
