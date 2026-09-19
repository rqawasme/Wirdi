import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/picked_item.dart';
import '../../domain/content.dart';
import '../../domain/item_ref.dart';
import '../../providers/adhkar.dart';
import '../../routes.dart';
import '../../theme/theme.dart';
import '../../widgets/banded_row.dart';
import '../../widgets/collection_dialogs.dart';
import '../../widgets/dhikr_row.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/failure_screen.dart';
import 'picker_scaffold.dart';

/// The adhkar the user wrote, to add one to a collection — and the one picker
/// that can also make what it offers.
///
/// No search field. The other dhikr picker has one because it is four hundred
/// and ninety-six rows; this is the handful somebody wrote themselves, and a
/// search over six rows is a control in the way of the six.
///
/// Pops with a one-item `List<PickedItem>`.
class UserDhikrPickerScreen extends ConsumerStatefulWidget {
  const UserDhikrPickerScreen({super.key});

  @override
  ConsumerState<UserDhikrPickerScreen> createState() =>
      _UserDhikrPickerScreenState();
}

class _UserDhikrPickerScreenState extends ConsumerState<UserDhikrPickerScreen> {
  /// Writes a new dhikr and adds it without a second question.
  ///
  /// Straight out with no count-and-note dialog behind it, unlike [_pick]: the
  /// count was just typed into the form, and asking for it again one screen
  /// later would be the app forgetting what it had been told. The item carries
  /// no override, so it says the dhikr as often as the dhikr says it does — and
  /// changing that later means changing the dhikr, which is where somebody
  /// would go looking anyway.
  Future<void> _write() async {
    final Object? saved = await Navigator.pushNamed(context, Routes.dhikrEdit);
    if (saved is! UserDhikrRef || !mounted) return;
    Navigator.pop(context, <PickedItem>[PickedItem(ref: saved)]);
  }

  /// Adds one already written, through the same count-and-note question the
  /// content pickers ask.
  Future<void> _pick(Dhikr dhikr) async {
    final PickedItem? picked = await askDhikrOptions(context, dhikr);
    if (picked == null || !mounted) return;
    Navigator.pop(context, <PickedItem>[picked]);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Dhikr>> adhkar = ref.watch(userAdhkarProvider);

    return PickerScaffold(
      title: 'Add one of yours',
      body: switch (adhkar) {
        AsyncError(:final Object error, :final StackTrace stackTrace) =>
          FailureScreen(
            title: 'Could not read your adhkar',
            error: error,
            stackTrace: stackTrace,
          ),
        AsyncData(:final List<Dhikr> value) =>
          value.isEmpty ? _empty() : _list(value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// The way in for somebody who has written none yet, which is everybody the
  /// first time. Its action is the same one the list carries at the top.
  Widget _empty() {
    return EmptyState(
      title: 'You have not written any yet',
      body:
          'Write down a dua you say and it goes straight into this '
          'collection — and stays here for the next one.',
      action: FilledButton(
        onPressed: _write,
        child: const Text('Write a dhikr'),
      ),
    );
  }

  Widget _list(List<Dhikr> adhkar) {
    // The write action rides above the rows rather than in the app bar: this
    // screen is reached from the add sheet by somebody who is already adding
    // something, and the thing they may want is not in the list yet.
    return ListView.builder(
      padding: WirdiMetrics.withSystemBottom(
        context,
        const EdgeInsets.only(bottom: WirdiMetrics.space6),
      ),
      itemCount: adhkar.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) return _WriteTile(onTap: _write);
        final Dhikr dhikr = adhkar[index - 1];
        // The banding starts at the first dhikr, not at the tile above them:
        // it is there to tell rows of Arabic apart, and the tile is not one.
        return BandedRow(
          index: index - 1,
          child: DhikrRow(dhikr: dhikr, onTap: () => _pick(dhikr)),
        );
      },
    );
  }
}

class _WriteTile extends StatelessWidget {
  const _WriteTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.add),
      title: const Text('Write a dhikr'),
      subtitle: const Text('It is added here, and kept for next time'),
      onTap: onTap,
    );
  }
}
