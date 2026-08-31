import 'package:drift/drift.dart';
import 'package:wirdi/data/content_database.dart';
import 'package:wirdi/data/repositories/drift_collection_repository.dart';
import 'package:wirdi/data/repositories/drift_content_repository.dart';
import 'package:wirdi/data/repositories/drift_user_repository.dart';
import 'package:wirdi/data/user_database.dart';

/// In-memory databases seeded with structural placeholder content.
///
/// No Quranic or dhikr text appears anywhere in here. Every text field is a
/// label describing which row it is, which is all these tests need and is the
/// only kind of religious text this repository is allowed to invent — none.
///
/// The shape mirrors `content/sources/collections/example.json`, which is the
/// file that exercises every feature of the authored format:
///
///   position  item              notes
///   1         dhikr 1001        default_count 1
///   2         dhikr 1002        count_override 100 over default_count 33
///   3         ayah 2:255
///   4         ayah 2:285
///   5         surah 112         repeat_group 1, three times over
///   6         surah 113         repeat_group 1
///   7         surah 114         repeat_group 1
///   8         dhikr 1003        carries a note
class TestDatabases {
  TestDatabases._(this.content, this.user);

  final ContentDatabase content;
  final UserDatabase user;

  static Future<TestDatabases> open() async {
    final ContentDatabase content = ContentDatabase.memory();
    await seedContent(content);
    final UserDatabase user = UserDatabase.memory();
    // Force the schema to be created before the first test statement.
    await user.customSelect('SELECT 1').get();
    return TestDatabases._(content, user);
  }

  DriftContentRepository contentRepository() => DriftContentRepository(content);

  DriftCollectionRepository collectionRepository({
    DateTime Function()? clock,
  }) => DriftCollectionRepository(content: content, user: user, clock: clock);

  DriftUserRepository userRepository({DateTime Function()? clock}) =>
      DriftUserRepository(user, clock: clock);

  Future<void> close() async {
    await content.close();
    await user.close();
  }
}

/// The built-in collection that mixes all three item types.
const int mixedCollectionId = 1;

/// A second built-in, to prove `all()` returns more than one.
const int simpleCollectionId = 2;

Future<void> seedContent(ContentDatabase db) async {
  await db.batch((Batch b) {
    b.insertAll(db.meta, <MetaCompanion>[
      MetaCompanion.insert(
        key: 'schema_version',
        value: expectedContentSchemaVersion,
      ),
      MetaCompanion.insert(key: 'content_version', value: '0.0.0-test'),
    ]);

    b.insertAll(db.surahs, <SurahsCompanion>[
      _surah(1, ayahCount: 7),
      // Al-Baqarah is 286 ayahs; a surah item must not expand them.
      _surah(2, ayahCount: 286),
      _surah(112, ayahCount: 4),
      _surah(113, ayahCount: 5),
      _surah(114, ayahCount: 6, hasBismillah: true),
    ]);

    b.insertAll(db.ayahs, <AyahsCompanion>[
      // Surah 1 in full, so range queries have something to clamp against.
      for (int n = 1; n <= 7; n++) _ayah(1, n, juz: 1),
      // Only the ayahs the fixture collections reference, from a surah whose
      // declared ayah_count is far larger.
      _ayah(2, 255, juz: 3),
      _ayah(2, 285, juz: 3),
      _ayah(2, 286, juz: 3),
      for (int n = 1; n <= 4; n++) _ayah(112, n, juz: 30),
    ]);

    b.insertAll(db.sources, <SourcesCompanion>[_source(1), _source(2)]);

    b.insertAll(db.adhkar, <AdhkarCompanion>[
      // 1001 cites nothing; two of the others do, so resolution has both
      // cases to hydrate.
      _dhikr(1001, defaultCount: 1),
      _dhikr(1002, defaultCount: 33, sourceId: 1),
      _dhikr(1003, defaultCount: 3, sourceId: 2),
      _dhikr(1004, defaultCount: 7),
    ]);

    b.insertAll(db.collections, <CollectionsCompanion>[
      _collection(mixedCollectionId, type: 'wird', sortOrder: 10),
      _collection(simpleCollectionId, type: 'dhikr_set', sortOrder: 20),
    ]);

    // Deliberately inserted out of position order: `position` is
    // authoritative, and resolution must never lean on row order.
    b.insertAll(db.collectionItems, <CollectionItemsCompanion>[
      _item(mixedCollectionId, 8, 'dhikr', 1003, note: 'PLACEHOLDER item note'),
      _item(
        mixedCollectionId,
        5,
        'surah',
        112,
        repeatGroup: 1,
        repeatGroupCount: 3,
      ),
      _item(mixedCollectionId, 1, 'dhikr', 1001),
      _item(
        mixedCollectionId,
        7,
        'surah',
        114,
        repeatGroup: 1,
        repeatGroupCount: 3,
      ),
      _item(mixedCollectionId, 3, 'ayah', 2255),
      _item(
        mixedCollectionId,
        6,
        'surah',
        113,
        repeatGroup: 1,
        repeatGroupCount: 3,
      ),
      _item(mixedCollectionId, 2, 'dhikr', 1002, countOverride: 100),
      _item(mixedCollectionId, 4, 'ayah', 2285),
      _item(simpleCollectionId, 1, 'dhikr', 1004),
    ]);
  });
}

SurahsCompanion _surah(
  int number, {
  required int ayahCount,
  bool hasBismillah = true,
}) {
  return SurahsCompanion.insert(
    number: Value<int>(number),
    nameArabic: 'PLACEHOLDER surah $number arabic',
    nameTransliterated: 'PLACEHOLDER surah $number transliterated',
    nameEnglish: 'PLACEHOLDER surah $number english',
    revelationPlace: number.isEven ? 'madinah' : 'makkah',
    ayahCount: ayahCount,
    hasBismillah: hasBismillah ? 1 : 0,
    orderRevealed: Value<int>(number),
  );
}

AyahsCompanion _ayah(int surah, int ayah, {required int juz}) {
  return AyahsCompanion.insert(
    // The invariant the whole data layer leans on.
    id: Value<int>(surah * 1000 + ayah),
    surahNumber: surah,
    ayahNumber: ayah,
    textUthmani: 'PLACEHOLDER ayah $surah:$ayah uthmani',
    textSimple: 'PLACEHOLDER ayah $surah:$ayah simple',
    translation: 'PLACEHOLDER ayah $surah:$ayah translation',
    juz: juz,
    hizb: juz * 2 - 1,
    sajdah: 0,
  );
}

AdhkarCompanion _dhikr(int id, {required int defaultCount, int? sourceId}) {
  return AdhkarCompanion.insert(
    id: Value<int>(id),
    textArabic: 'PLACEHOLDER dhikr $id arabic',
    translation: 'PLACEHOLDER dhikr $id translation',
    defaultCount: defaultCount,
    sourceId: Value<int?>(sourceId),
  );
}

SourcesCompanion _source(int id) {
  return SourcesCompanion.insert(
    id: Value<int>(id),
    collection: 'PLACEHOLDER source $id collection',
    reference: 'PLACEHOLDER source $id reference',
    grading: Value<String>('PLACEHOLDER source $id grading'),
  );
}

CollectionsCompanion _collection(
  int id, {
  required String type,
  required int sortOrder,
}) {
  return CollectionsCompanion.insert(
    id: Value<int>(id),
    nameArabic: 'PLACEHOLDER collection $id arabic',
    nameEnglish: 'PLACEHOLDER collection $id english',
    description: Value<String>('PLACEHOLDER collection $id description'),
    author: Value<String>('PLACEHOLDER collection $id author'),
    type: type,
    sortOrder: sortOrder,
  );
}

CollectionItemsCompanion _item(
  int collectionId,
  int position,
  String itemType,
  int itemId, {
  int? countOverride,
  int? repeatGroup,
  int? repeatGroupCount,
  String? note,
}) {
  return CollectionItemsCompanion.insert(
    // collection_items.id is collection_id * 1000 + position, as the build
    // computes it.
    id: Value<int>(collectionId * 1000 + position),
    collectionId: collectionId,
    itemType: itemType,
    itemId: itemId,
    position: position,
    countOverride: Value<int?>(countOverride),
    repeatGroup: Value<int?>(repeatGroup),
    repeatGroupCount: Value<int?>(repeatGroupCount),
    note: Value<String?>(note),
  );
}

/// Inserts a user collection row directly, bypassing the repository.
///
/// Used where a test needs a shape the repository API cannot build yet — a
/// repeat group, say, which `CollectionRepository.addItem` has no parameter
/// for.
Future<String> insertUserCollection(
  UserDatabase db, {
  required String id,
  required String name,
  String? description,
  int sortOrder = 1,
  DateTime? createdAt,
  DateTime? deletedAt,
}) async {
  final int now = (createdAt ?? DateTime(2026, 1, 1)).millisecondsSinceEpoch;
  await db
      .into(db.userCollections)
      .insert(
        UserCollectionsCompanion.insert(
          id: id,
          name: name,
          description: Value<String?>(description),
          sortOrder: sortOrder,
          createdAt: now,
          updatedAt: now,
          deletedAt: Value<int?>(deletedAt?.millisecondsSinceEpoch),
        ),
      );
  return id;
}

/// Inserts a user collection item row directly. Returns its id.
Future<String> insertUserItem(
  UserDatabase db, {
  required String id,
  required String collectionId,
  required int position,
  required String itemType,
  required int itemId,
  int? countOverride,
  int? repeatGroup,
  int? repeatGroupCount,
  String? note,
}) async {
  await db
      .into(db.userCollectionItems)
      .insert(
        UserCollectionItemsCompanion.insert(
          id: id,
          collectionId: collectionId,
          itemType: itemType,
          itemId: itemId,
          position: position,
          countOverride: Value<int?>(countOverride),
          repeatGroup: Value<int?>(repeatGroup),
          repeatGroupCount: Value<int?>(repeatGroupCount),
          note: Value<String?>(note),
          updatedAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        ),
      );
  return id;
}

/// A stable, valid-looking UUID for fixtures that need a specific id.
String testUuid(int n) {
  final String tail = n.toString().padLeft(12, '0');
  return '00000000-0000-4000-8000-$tail';
}
