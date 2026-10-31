import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collection_editing.dart';
import '../domain/collection_id.dart';
import '../domain/commitment.dart';
import '../providers/collections.dart';
import '../providers/editing.dart';
import '../providers/home.dart';
import '../providers/refresh.dart';
import '../providers/reminders.dart';
import '../providers/settings.dart';
import '../routes.dart';
import '../widgets/collection_dialogs.dart';

/// What can be done to a collection, wherever it is done from.
///
/// These were the bodies of the four buttons on every row of the collections
/// list. The buttons are gone — a row opens its collection, and the collection
/// page is where the actions are, each with its name on it — but the list
/// still makes collections and the page still copies them, so the flows live
/// here rather than in either screen.

/// Opens [id]'s page: what is in it, and everything that can be done to it.
Future<void> openCollection(
  BuildContext context,
  WidgetRef ref,
  CollectionId id,
) async {
  await Navigator.pushNamed(
    context,
    Routes.collectionContents,
    arguments: CollectionContentsArguments(collectionId: id),
  );
  // The page has a Recite button, and a return here can have a finished wird
  // behind it. Refreshing costs a handful of indexed reads.
  if (context.mounted) {
    ref.invalidate(collectionListingsProvider);
    ref.invalidate(homeViewProvider);
  }
}

/// Opens the page of a series' parts, by the name they share.
///
/// Nothing to refresh on the way back: each part on that page is opened
/// through [openCollection], which refreshes on its own way back.
Future<void> openSeries(BuildContext context, String name) =>
    Navigator.pushNamed(
      context,
      Routes.collectionSeries,
      arguments: CollectionSeriesArguments(name: name),
    );

/// Opens [id] in the player.
Future<void> reciteCollection(
  BuildContext context,
  WidgetRef ref,
  CollectionId id,
) async {
  await Navigator.pushNamed(
    context,
    Routes.player,
    arguments: PlayerArguments(collectionId: id),
  );
  // The player is where completions and progress happen, so everything that
  // shows either is stale the moment it comes back — the list, the home
  // screen, and the page's own Resume.
  if (context.mounted) {
    ref.invalidate(collectionListingsProvider);
    ref.invalidate(homeViewProvider);
    ref.invalidate(resumeStepProvider(id));
  }
}

/// Commits [id] to the day, or changes when an already-committed one falls —
/// the same sheet either way, since "commit" and "change when" are the same
/// question asked at different times.
Future<void> commitCollection(
  BuildContext context,
  WidgetRef ref, {
  required CollectionId id,
  required String name,
  Commitment? current,
}) async {
  final CommitmentChoice? choice = await showCommitmentSheet(
    context,
    name: name,
    reminders: ref.read(reminderSchedulerProvider),
    remindersEnabled:
        ref.read(settingsProvider).value?.remindersEnabled ?? true,
    current: current == null
        ? null
        : CommitmentChoice(
            section: current.section,
            days: current.days,
            reminder: current.reminder,
          ),
  );
  if (choice == null || !context.mounted) return;
  // The reminders follow on their own: the sync watches the commitments this
  // invalidates.
  await ref
      .read(homeCommitmentsProvider)
      .commit(id, choice.section, days: choice.days, reminder: choice.reminder);
}

/// Opens the editor on a collection of the user's own.
Future<void> editCollection(BuildContext context, UserCollectionId id) =>
    Navigator.pushNamed(
      context,
      Routes.collectionEdit,
      arguments: CollectionEditArguments(collectionId: id),
    );

/// Deletes a collection of the user's own once the user has said so, and
/// reports whether it went.
Future<bool> deleteCollection(
  BuildContext context,
  WidgetRef ref, {
  required UserCollectionId id,
  required String name,
}) async {
  final bool confirmed = await confirmDeleteCollection(context, name: name);
  if (!confirmed || !context.mounted) return false;
  final bool deleted = await runCollectionEdit(
    context,
    ref,
    () => ref.read(collectionEditorProvider).delete(id),
  );
  if (!deleted) return false;
  // A deleted collection cannot stay committed: the home screen drops a
  // commitment whose collection is gone, but the row should go with it rather
  // than waiting for the next read.
  await ref.read(homeCommitmentsProvider).uncommit(id);
  return true;
}

/// Makes an empty collection and opens it, because an empty collection is not
/// somewhere to be left standing.
Future<void> newCollection(BuildContext context, WidgetRef ref) async {
  final CollectionForm? form = await showCollectionForm(
    context,
    title: 'New collection',
    submitLabel: 'Create',
  );
  if (form == null || !context.mounted) return;

  UserCollectionId? created;
  await runCollectionEdit(context, ref, () async {
    created = await ref
        .read(collectionEditorProvider)
        .create(form.name, description: form.description);
  });

  if (!context.mounted) return;
  await _openCreated(context, ref, created);
}

/// Copies [source] into a collection of the user's own, and opens it.
///
/// The copy lands in the editor rather than in the list: somebody who asked
/// for a copy they can edit asked to edit it.
Future<void> duplicateCollectionFlow(
  BuildContext context,
  WidgetRef ref, {
  required CollectionId source,
  required String name,
}) async {
  final CollectionForm? form = await showCollectionForm(
    context,
    title: 'Make a copy',
    submitLabel: 'Copy',
    initialName: copyOf(name),
  );
  if (form == null || !context.mounted) return;

  UserCollectionId? created;
  await runCollectionEdit(context, ref, () async {
    created = await ref
        .read(collectionEditorProvider)
        .duplicate(source, name: form.name, description: form.description);
  });

  if (!context.mounted) return;
  await _openCreated(context, ref, created);
}

/// Turns the Collections tab to Yours, where [created] now is, and opens it in
/// the editor.
Future<void> _openCreated(
  BuildContext context,
  WidgetRef ref,
  UserCollectionId? created,
) async {
  if (created == null) return;
  ref.read(collectionShelfProvider.notifier).select(CollectionShelf.yours);
  await editCollection(context, created);
}

/// Runs an edit, refreshing what it touched and saying what went wrong.
///
/// True when the edit went through.
Future<bool> runCollectionEdit(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() edit,
) async {
  // Before the await: see [refreshAfterUserWrite] on why not `ref` after it.
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  try {
    await edit();
    // Creating, copying or deleting a collection. Deleting one also changes
    // the count on every dhikr of the user's own it held.
    refreshAfterUserWrite(container);
    return true;
  } on CollectionEditingError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
    return false;
  }
}
