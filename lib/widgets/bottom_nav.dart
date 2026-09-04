import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'voussoir_stripe.dart';

/// The app's four destinations.
///
/// Four, and four is the ceiling: a fifth would mean the information
/// architecture is wrong, not that the bar needs another slot.
enum WirdiTab {
  // The outlined variants, because the app's glyphs are line art and a solid
  // house among three line drawings reads as the selected one whichever tab
  // is actually selected. Material Symbols Sharp at weight 400 — which is
  // what the design calls for, and an open task on this side — is line art
  // throughout, so this is the nearest the bundled Material Icons get.
  home(Icons.home_outlined, 'Home'),
  collections(Icons.format_list_bulleted, 'Collections'),
  dhikr(Icons.repeat, 'Dhikr'),
  tracker(Icons.calendar_month, 'Tracker');

  const WirdiTab(this.icon, this.label);

  final IconData icon;

  /// Always visible, and never truncated. A bar whose labels disappear at the
  /// larger accessibility sizes is a bar that stops working for exactly the
  /// people who need it to.
  final String label;
}

/// The bottom navigation bar: four tabs, flat, squared.
///
/// Built from a [Row] of [InkWell]s rather than from [NavigationBar], and the
/// reason is the one thing Material will not let go of. Material 3 marks the
/// selected destination with a stadium-shaped tonal pill behind its icon, and
/// this app drops the stadium everywhere — buttons are squared at 8dp because
/// the reference is masonry, and a capsule in the navigation bar would be the
/// one place the shape language breaks. What marks the selected tab instead is
/// a 4dp length of brick across its top edge: the same width as the voussoir
/// rule under the app bar, and the one place in the app where brick is allowed
/// to be a plain bar rather than the alternating rhythm.
///
/// Everything else stays chrome. The glyph is [ColorScheme.onSurface] when
/// selected and [ColorScheme.onSurfaceVariant] when not — never brick, never
/// gold, and never a filled-versus-outline swap, which is a distinction that
/// disappears at a glance. The weight of the label carries the rest.
///
/// Flat, and it stays flat: no elevation, no tint and no shadow when content
/// scrolls under it. There are no badges, dots or counts, because the app has
/// no notifications, and nothing floats above it, because there is no FAB.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.active, required this.onSelect});

  /// Tall enough for a 24dp glyph over a 14dp label at the OS text scale, and
  /// the tap target that comes with it.
  static const double height = 64;

  /// The mark on the selected tab. The rule's height, not a new value.
  static const double markHeight = VoussoirStripe.ruleHeight;

  static const double glyphSize = 24;

  final WirdiTab active;

  final ValueChanged<WirdiTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant,
            width: WirdiMetrics.hairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            for (final WirdiTab tab in WirdiTab.values)
              Expanded(
                child: _Tab(
                  tab: tab,
                  selected: tab == active,
                  onTap: () => onSelect(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final WirdiTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WirdiTypography type = theme.extension<WirdiTypography>()!;

    final Color ink = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          // Squared, like everything else: the splash is the shape of the tab.
          customBorder: const RoundedRectangleBorder(),
          child: SizedBox(
            height: BottomNav.height,
            child: Stack(
              children: <Widget>[
                if (selected)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: BottomNav.markHeight,
                      color: scheme.primary,
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(tab.icon, size: BottomNav.glyphSize, color: ink),
                      const SizedBox(height: WirdiMetrics.space1),
                      // The label has to fit at every OS text scale. Shrinking
                      // it is the one honest option left when the bar cannot
                      // grow: ellipsising "Collections" to "Collecti…" makes
                      // the tab unreadable, and dropping the label makes the
                      // selection signal an icon colour, which is what the
                      // 4dp mark exists to avoid.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            softWrap: false,
                            style: selected
                                ? type.navLabel.copyWith(color: ink)
                                : type.navLabel.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w400,
                                  ),
                          ),
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
    );
  }
}
