import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wirdi_data.dart';
import '../domain/repositories.dart';

/// The open databases and the repositories over them.
///
/// Deliberately synchronous. Both databases are opened once in `main`, before
/// `runApp`, and the result is handed in as an override on the root
/// [ProviderScope]. The alternative — a `FutureProvider` that opens them
/// lazily — would put an [AsyncValue] in front of every repository read in the
/// app, forever, to model a failure that can only happen at startup and that
/// the app cannot continue past anyway.
///
/// So: startup failures are handled at startup, and from here on a repository
/// is just a repository.
///
/// ```dart
/// runApp(
///   ProviderScope(
///     overrides: <Override>[wirdiDataProvider.overrideWithValue(data)],
///     child: const WirdiApp(),
///   ),
/// );
/// ```
///
/// A test overrides the same provider with [WirdiData.new] over two in-memory
/// databases.
final Provider<WirdiData> wirdiDataProvider = Provider<WirdiData>(
  (Ref ref) => throw StateError(
    'wirdiDataProvider was read without being overridden. Open the databases '
    'with WirdiData.open() and override this provider on the root '
    'ProviderScope — see main.dart.',
  ),
  name: 'wirdiData',
);

/// Read access to the bundled `content.db`: Quran, adhkar, sources.
final Provider<ContentRepository> contentRepositoryProvider =
    Provider<ContentRepository>(
      (Ref ref) => ref.watch(wirdiDataProvider).contentRepository,
      name: 'contentRepository',
    );

/// Collections, built-in and user-made, over both databases.
final Provider<CollectionRepository> collectionRepositoryProvider =
    Provider<CollectionRepository>(
      (Ref ref) => ref.watch(wirdiDataProvider).collectionRepository,
      name: 'collectionRepository',
    );

/// Progress, completions, reading position and settings.
final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
      (Ref ref) => ref.watch(wirdiDataProvider).userRepository,
      name: 'userRepository',
    );
