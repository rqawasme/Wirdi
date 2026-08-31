// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_database.dart';

// ignore_for_file: type=lint
class Surahs extends Table with TableInfo<Surahs, SurahRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Surahs(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _nameArabicMeta = const VerificationMeta(
    'nameArabic',
  );
  late final GeneratedColumn<String> nameArabic = GeneratedColumn<String>(
    'name_arabic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameTransliteratedMeta =
      const VerificationMeta('nameTransliterated');
  late final GeneratedColumn<String> nameTransliterated =
      GeneratedColumn<String>(
        'name_transliterated',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _nameEnglishMeta = const VerificationMeta(
    'nameEnglish',
  );
  late final GeneratedColumn<String> nameEnglish = GeneratedColumn<String>(
    'name_english',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _revelationPlaceMeta = const VerificationMeta(
    'revelationPlace',
  );
  late final GeneratedColumn<String> revelationPlace = GeneratedColumn<String>(
    'revelation_place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ayahCountMeta = const VerificationMeta(
    'ayahCount',
  );
  late final GeneratedColumn<int> ayahCount = GeneratedColumn<int>(
    'ayah_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _hasBismillahMeta = const VerificationMeta(
    'hasBismillah',
  );
  late final GeneratedColumn<int> hasBismillah = GeneratedColumn<int>(
    'has_bismillah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _orderRevealedMeta = const VerificationMeta(
    'orderRevealed',
  );
  late final GeneratedColumn<int> orderRevealed = GeneratedColumn<int>(
    'order_revealed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    number,
    nameArabic,
    nameTransliterated,
    nameEnglish,
    revelationPlace,
    ayahCount,
    hasBismillah,
    orderRevealed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'surahs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SurahRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('name_arabic')) {
      context.handle(
        _nameArabicMeta,
        nameArabic.isAcceptableOrUnknown(data['name_arabic']!, _nameArabicMeta),
      );
    } else if (isInserting) {
      context.missing(_nameArabicMeta);
    }
    if (data.containsKey('name_transliterated')) {
      context.handle(
        _nameTransliteratedMeta,
        nameTransliterated.isAcceptableOrUnknown(
          data['name_transliterated']!,
          _nameTransliteratedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameTransliteratedMeta);
    }
    if (data.containsKey('name_english')) {
      context.handle(
        _nameEnglishMeta,
        nameEnglish.isAcceptableOrUnknown(
          data['name_english']!,
          _nameEnglishMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameEnglishMeta);
    }
    if (data.containsKey('revelation_place')) {
      context.handle(
        _revelationPlaceMeta,
        revelationPlace.isAcceptableOrUnknown(
          data['revelation_place']!,
          _revelationPlaceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revelationPlaceMeta);
    }
    if (data.containsKey('ayah_count')) {
      context.handle(
        _ayahCountMeta,
        ayahCount.isAcceptableOrUnknown(data['ayah_count']!, _ayahCountMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahCountMeta);
    }
    if (data.containsKey('has_bismillah')) {
      context.handle(
        _hasBismillahMeta,
        hasBismillah.isAcceptableOrUnknown(
          data['has_bismillah']!,
          _hasBismillahMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasBismillahMeta);
    }
    if (data.containsKey('order_revealed')) {
      context.handle(
        _orderRevealedMeta,
        orderRevealed.isAcceptableOrUnknown(
          data['order_revealed']!,
          _orderRevealedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {number};
  @override
  SurahRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurahRow(
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      nameArabic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_arabic'],
      )!,
      nameTransliterated: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_transliterated'],
      )!,
      nameEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_english'],
      )!,
      revelationPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revelation_place'],
      )!,
      ayahCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_count'],
      )!,
      hasBismillah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_bismillah'],
      )!,
      orderRevealed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_revealed'],
      ),
    );
  }

  @override
  Surahs createAlias(String alias) {
    return Surahs(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SurahRow extends DataClass implements Insertable<SurahRow> {
  final int number;
  final String nameArabic;
  final String nameTransliterated;
  final String nameEnglish;
  final String revelationPlace;
  final int ayahCount;
  final int hasBismillah;
  final int? orderRevealed;
  const SurahRow({
    required this.number,
    required this.nameArabic,
    required this.nameTransliterated,
    required this.nameEnglish,
    required this.revelationPlace,
    required this.ayahCount,
    required this.hasBismillah,
    this.orderRevealed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['number'] = Variable<int>(number);
    map['name_arabic'] = Variable<String>(nameArabic);
    map['name_transliterated'] = Variable<String>(nameTransliterated);
    map['name_english'] = Variable<String>(nameEnglish);
    map['revelation_place'] = Variable<String>(revelationPlace);
    map['ayah_count'] = Variable<int>(ayahCount);
    map['has_bismillah'] = Variable<int>(hasBismillah);
    if (!nullToAbsent || orderRevealed != null) {
      map['order_revealed'] = Variable<int>(orderRevealed);
    }
    return map;
  }

  factory SurahRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurahRow(
      number: serializer.fromJson<int>(json['number']),
      nameArabic: serializer.fromJson<String>(json['name_arabic']),
      nameTransliterated: serializer.fromJson<String>(
        json['name_transliterated'],
      ),
      nameEnglish: serializer.fromJson<String>(json['name_english']),
      revelationPlace: serializer.fromJson<String>(json['revelation_place']),
      ayahCount: serializer.fromJson<int>(json['ayah_count']),
      hasBismillah: serializer.fromJson<int>(json['has_bismillah']),
      orderRevealed: serializer.fromJson<int?>(json['order_revealed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'number': serializer.toJson<int>(number),
      'name_arabic': serializer.toJson<String>(nameArabic),
      'name_transliterated': serializer.toJson<String>(nameTransliterated),
      'name_english': serializer.toJson<String>(nameEnglish),
      'revelation_place': serializer.toJson<String>(revelationPlace),
      'ayah_count': serializer.toJson<int>(ayahCount),
      'has_bismillah': serializer.toJson<int>(hasBismillah),
      'order_revealed': serializer.toJson<int?>(orderRevealed),
    };
  }

  SurahRow copyWith({
    int? number,
    String? nameArabic,
    String? nameTransliterated,
    String? nameEnglish,
    String? revelationPlace,
    int? ayahCount,
    int? hasBismillah,
    Value<int?> orderRevealed = const Value.absent(),
  }) => SurahRow(
    number: number ?? this.number,
    nameArabic: nameArabic ?? this.nameArabic,
    nameTransliterated: nameTransliterated ?? this.nameTransliterated,
    nameEnglish: nameEnglish ?? this.nameEnglish,
    revelationPlace: revelationPlace ?? this.revelationPlace,
    ayahCount: ayahCount ?? this.ayahCount,
    hasBismillah: hasBismillah ?? this.hasBismillah,
    orderRevealed: orderRevealed.present
        ? orderRevealed.value
        : this.orderRevealed,
  );
  SurahRow copyWithCompanion(SurahsCompanion data) {
    return SurahRow(
      number: data.number.present ? data.number.value : this.number,
      nameArabic: data.nameArabic.present
          ? data.nameArabic.value
          : this.nameArabic,
      nameTransliterated: data.nameTransliterated.present
          ? data.nameTransliterated.value
          : this.nameTransliterated,
      nameEnglish: data.nameEnglish.present
          ? data.nameEnglish.value
          : this.nameEnglish,
      revelationPlace: data.revelationPlace.present
          ? data.revelationPlace.value
          : this.revelationPlace,
      ayahCount: data.ayahCount.present ? data.ayahCount.value : this.ayahCount,
      hasBismillah: data.hasBismillah.present
          ? data.hasBismillah.value
          : this.hasBismillah,
      orderRevealed: data.orderRevealed.present
          ? data.orderRevealed.value
          : this.orderRevealed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurahRow(')
          ..write('number: $number, ')
          ..write('nameArabic: $nameArabic, ')
          ..write('nameTransliterated: $nameTransliterated, ')
          ..write('nameEnglish: $nameEnglish, ')
          ..write('revelationPlace: $revelationPlace, ')
          ..write('ayahCount: $ayahCount, ')
          ..write('hasBismillah: $hasBismillah, ')
          ..write('orderRevealed: $orderRevealed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    number,
    nameArabic,
    nameTransliterated,
    nameEnglish,
    revelationPlace,
    ayahCount,
    hasBismillah,
    orderRevealed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurahRow &&
          other.number == this.number &&
          other.nameArabic == this.nameArabic &&
          other.nameTransliterated == this.nameTransliterated &&
          other.nameEnglish == this.nameEnglish &&
          other.revelationPlace == this.revelationPlace &&
          other.ayahCount == this.ayahCount &&
          other.hasBismillah == this.hasBismillah &&
          other.orderRevealed == this.orderRevealed);
}

class SurahsCompanion extends UpdateCompanion<SurahRow> {
  final Value<int> number;
  final Value<String> nameArabic;
  final Value<String> nameTransliterated;
  final Value<String> nameEnglish;
  final Value<String> revelationPlace;
  final Value<int> ayahCount;
  final Value<int> hasBismillah;
  final Value<int?> orderRevealed;
  const SurahsCompanion({
    this.number = const Value.absent(),
    this.nameArabic = const Value.absent(),
    this.nameTransliterated = const Value.absent(),
    this.nameEnglish = const Value.absent(),
    this.revelationPlace = const Value.absent(),
    this.ayahCount = const Value.absent(),
    this.hasBismillah = const Value.absent(),
    this.orderRevealed = const Value.absent(),
  });
  SurahsCompanion.insert({
    this.number = const Value.absent(),
    required String nameArabic,
    required String nameTransliterated,
    required String nameEnglish,
    required String revelationPlace,
    required int ayahCount,
    required int hasBismillah,
    this.orderRevealed = const Value.absent(),
  }) : nameArabic = Value(nameArabic),
       nameTransliterated = Value(nameTransliterated),
       nameEnglish = Value(nameEnglish),
       revelationPlace = Value(revelationPlace),
       ayahCount = Value(ayahCount),
       hasBismillah = Value(hasBismillah);
  static Insertable<SurahRow> custom({
    Expression<int>? number,
    Expression<String>? nameArabic,
    Expression<String>? nameTransliterated,
    Expression<String>? nameEnglish,
    Expression<String>? revelationPlace,
    Expression<int>? ayahCount,
    Expression<int>? hasBismillah,
    Expression<int>? orderRevealed,
  }) {
    return RawValuesInsertable({
      if (number != null) 'number': number,
      if (nameArabic != null) 'name_arabic': nameArabic,
      if (nameTransliterated != null) 'name_transliterated': nameTransliterated,
      if (nameEnglish != null) 'name_english': nameEnglish,
      if (revelationPlace != null) 'revelation_place': revelationPlace,
      if (ayahCount != null) 'ayah_count': ayahCount,
      if (hasBismillah != null) 'has_bismillah': hasBismillah,
      if (orderRevealed != null) 'order_revealed': orderRevealed,
    });
  }

  SurahsCompanion copyWith({
    Value<int>? number,
    Value<String>? nameArabic,
    Value<String>? nameTransliterated,
    Value<String>? nameEnglish,
    Value<String>? revelationPlace,
    Value<int>? ayahCount,
    Value<int>? hasBismillah,
    Value<int?>? orderRevealed,
  }) {
    return SurahsCompanion(
      number: number ?? this.number,
      nameArabic: nameArabic ?? this.nameArabic,
      nameTransliterated: nameTransliterated ?? this.nameTransliterated,
      nameEnglish: nameEnglish ?? this.nameEnglish,
      revelationPlace: revelationPlace ?? this.revelationPlace,
      ayahCount: ayahCount ?? this.ayahCount,
      hasBismillah: hasBismillah ?? this.hasBismillah,
      orderRevealed: orderRevealed ?? this.orderRevealed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (nameArabic.present) {
      map['name_arabic'] = Variable<String>(nameArabic.value);
    }
    if (nameTransliterated.present) {
      map['name_transliterated'] = Variable<String>(nameTransliterated.value);
    }
    if (nameEnglish.present) {
      map['name_english'] = Variable<String>(nameEnglish.value);
    }
    if (revelationPlace.present) {
      map['revelation_place'] = Variable<String>(revelationPlace.value);
    }
    if (ayahCount.present) {
      map['ayah_count'] = Variable<int>(ayahCount.value);
    }
    if (hasBismillah.present) {
      map['has_bismillah'] = Variable<int>(hasBismillah.value);
    }
    if (orderRevealed.present) {
      map['order_revealed'] = Variable<int>(orderRevealed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurahsCompanion(')
          ..write('number: $number, ')
          ..write('nameArabic: $nameArabic, ')
          ..write('nameTransliterated: $nameTransliterated, ')
          ..write('nameEnglish: $nameEnglish, ')
          ..write('revelationPlace: $revelationPlace, ')
          ..write('ayahCount: $ayahCount, ')
          ..write('hasBismillah: $hasBismillah, ')
          ..write('orderRevealed: $orderRevealed')
          ..write(')'))
        .toString();
  }
}

class Ayahs extends Table with TableInfo<Ayahs, AyahRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Ayahs(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _surahNumberMeta = const VerificationMeta(
    'surahNumber',
  );
  late final GeneratedColumn<int> surahNumber = GeneratedColumn<int>(
    'surah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ayahNumberMeta = const VerificationMeta(
    'ayahNumber',
  );
  late final GeneratedColumn<int> ayahNumber = GeneratedColumn<int>(
    'ayah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _textUthmaniMeta = const VerificationMeta(
    'textUthmani',
  );
  late final GeneratedColumn<String> textUthmani = GeneratedColumn<String>(
    'text_uthmani',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _textSimpleMeta = const VerificationMeta(
    'textSimple',
  );
  late final GeneratedColumn<String> textSimple = GeneratedColumn<String>(
    'text_simple',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _transliterationMeta = const VerificationMeta(
    'transliteration',
  );
  late final GeneratedColumn<String> transliteration = GeneratedColumn<String>(
    'transliteration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _juzMeta = const VerificationMeta('juz');
  late final GeneratedColumn<int> juz = GeneratedColumn<int>(
    'juz',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _hizbMeta = const VerificationMeta('hizb');
  late final GeneratedColumn<int> hizb = GeneratedColumn<int>(
    'hizb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sajdahMeta = const VerificationMeta('sajdah');
  late final GeneratedColumn<int> sajdah = GeneratedColumn<int>(
    'sajdah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    surahNumber,
    ayahNumber,
    textUthmani,
    textSimple,
    translation,
    transliteration,
    juz,
    hizb,
    page,
    sajdah,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ayahs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AyahRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('surah_number')) {
      context.handle(
        _surahNumberMeta,
        surahNumber.isAcceptableOrUnknown(
          data['surah_number']!,
          _surahNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_surahNumberMeta);
    }
    if (data.containsKey('ayah_number')) {
      context.handle(
        _ayahNumberMeta,
        ayahNumber.isAcceptableOrUnknown(data['ayah_number']!, _ayahNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahNumberMeta);
    }
    if (data.containsKey('text_uthmani')) {
      context.handle(
        _textUthmaniMeta,
        textUthmani.isAcceptableOrUnknown(
          data['text_uthmani']!,
          _textUthmaniMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textUthmaniMeta);
    }
    if (data.containsKey('text_simple')) {
      context.handle(
        _textSimpleMeta,
        textSimple.isAcceptableOrUnknown(data['text_simple']!, _textSimpleMeta),
      );
    } else if (isInserting) {
      context.missing(_textSimpleMeta);
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translationMeta);
    }
    if (data.containsKey('transliteration')) {
      context.handle(
        _transliterationMeta,
        transliteration.isAcceptableOrUnknown(
          data['transliteration']!,
          _transliterationMeta,
        ),
      );
    }
    if (data.containsKey('juz')) {
      context.handle(
        _juzMeta,
        juz.isAcceptableOrUnknown(data['juz']!, _juzMeta),
      );
    } else if (isInserting) {
      context.missing(_juzMeta);
    }
    if (data.containsKey('hizb')) {
      context.handle(
        _hizbMeta,
        hizb.isAcceptableOrUnknown(data['hizb']!, _hizbMeta),
      );
    } else if (isInserting) {
      context.missing(_hizbMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    }
    if (data.containsKey('sajdah')) {
      context.handle(
        _sajdahMeta,
        sajdah.isAcceptableOrUnknown(data['sajdah']!, _sajdahMeta),
      );
    } else if (isInserting) {
      context.missing(_sajdahMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AyahRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AyahRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      surahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah_number'],
      )!,
      ayahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_number'],
      )!,
      textUthmani: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_uthmani'],
      )!,
      textSimple: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_simple'],
      )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      )!,
      transliteration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transliteration'],
      ),
      juz: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}juz'],
      )!,
      hizb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hizb'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      ),
      sajdah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sajdah'],
      )!,
    );
  }

  @override
  Ayahs createAlias(String alias) {
    return Ayahs(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AyahRow extends DataClass implements Insertable<AyahRow> {
  final int id;
  final int surahNumber;
  final int ayahNumber;
  final String textUthmani;
  final String textSimple;
  final String translation;
  final String? transliteration;
  final int juz;
  final int hizb;
  final int? page;
  final int sajdah;
  const AyahRow({
    required this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.textUthmani,
    required this.textSimple,
    required this.translation,
    this.transliteration,
    required this.juz,
    required this.hizb,
    this.page,
    required this.sajdah,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['surah_number'] = Variable<int>(surahNumber);
    map['ayah_number'] = Variable<int>(ayahNumber);
    map['text_uthmani'] = Variable<String>(textUthmani);
    map['text_simple'] = Variable<String>(textSimple);
    map['translation'] = Variable<String>(translation);
    if (!nullToAbsent || transliteration != null) {
      map['transliteration'] = Variable<String>(transliteration);
    }
    map['juz'] = Variable<int>(juz);
    map['hizb'] = Variable<int>(hizb);
    if (!nullToAbsent || page != null) {
      map['page'] = Variable<int>(page);
    }
    map['sajdah'] = Variable<int>(sajdah);
    return map;
  }

  factory AyahRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AyahRow(
      id: serializer.fromJson<int>(json['id']),
      surahNumber: serializer.fromJson<int>(json['surah_number']),
      ayahNumber: serializer.fromJson<int>(json['ayah_number']),
      textUthmani: serializer.fromJson<String>(json['text_uthmani']),
      textSimple: serializer.fromJson<String>(json['text_simple']),
      translation: serializer.fromJson<String>(json['translation']),
      transliteration: serializer.fromJson<String?>(json['transliteration']),
      juz: serializer.fromJson<int>(json['juz']),
      hizb: serializer.fromJson<int>(json['hizb']),
      page: serializer.fromJson<int?>(json['page']),
      sajdah: serializer.fromJson<int>(json['sajdah']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'surah_number': serializer.toJson<int>(surahNumber),
      'ayah_number': serializer.toJson<int>(ayahNumber),
      'text_uthmani': serializer.toJson<String>(textUthmani),
      'text_simple': serializer.toJson<String>(textSimple),
      'translation': serializer.toJson<String>(translation),
      'transliteration': serializer.toJson<String?>(transliteration),
      'juz': serializer.toJson<int>(juz),
      'hizb': serializer.toJson<int>(hizb),
      'page': serializer.toJson<int?>(page),
      'sajdah': serializer.toJson<int>(sajdah),
    };
  }

  AyahRow copyWith({
    int? id,
    int? surahNumber,
    int? ayahNumber,
    String? textUthmani,
    String? textSimple,
    String? translation,
    Value<String?> transliteration = const Value.absent(),
    int? juz,
    int? hizb,
    Value<int?> page = const Value.absent(),
    int? sajdah,
  }) => AyahRow(
    id: id ?? this.id,
    surahNumber: surahNumber ?? this.surahNumber,
    ayahNumber: ayahNumber ?? this.ayahNumber,
    textUthmani: textUthmani ?? this.textUthmani,
    textSimple: textSimple ?? this.textSimple,
    translation: translation ?? this.translation,
    transliteration: transliteration.present
        ? transliteration.value
        : this.transliteration,
    juz: juz ?? this.juz,
    hizb: hizb ?? this.hizb,
    page: page.present ? page.value : this.page,
    sajdah: sajdah ?? this.sajdah,
  );
  AyahRow copyWithCompanion(AyahsCompanion data) {
    return AyahRow(
      id: data.id.present ? data.id.value : this.id,
      surahNumber: data.surahNumber.present
          ? data.surahNumber.value
          : this.surahNumber,
      ayahNumber: data.ayahNumber.present
          ? data.ayahNumber.value
          : this.ayahNumber,
      textUthmani: data.textUthmani.present
          ? data.textUthmani.value
          : this.textUthmani,
      textSimple: data.textSimple.present
          ? data.textSimple.value
          : this.textSimple,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      transliteration: data.transliteration.present
          ? data.transliteration.value
          : this.transliteration,
      juz: data.juz.present ? data.juz.value : this.juz,
      hizb: data.hizb.present ? data.hizb.value : this.hizb,
      page: data.page.present ? data.page.value : this.page,
      sajdah: data.sajdah.present ? data.sajdah.value : this.sajdah,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AyahRow(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('textUthmani: $textUthmani, ')
          ..write('textSimple: $textSimple, ')
          ..write('translation: $translation, ')
          ..write('transliteration: $transliteration, ')
          ..write('juz: $juz, ')
          ..write('hizb: $hizb, ')
          ..write('page: $page, ')
          ..write('sajdah: $sajdah')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    surahNumber,
    ayahNumber,
    textUthmani,
    textSimple,
    translation,
    transliteration,
    juz,
    hizb,
    page,
    sajdah,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AyahRow &&
          other.id == this.id &&
          other.surahNumber == this.surahNumber &&
          other.ayahNumber == this.ayahNumber &&
          other.textUthmani == this.textUthmani &&
          other.textSimple == this.textSimple &&
          other.translation == this.translation &&
          other.transliteration == this.transliteration &&
          other.juz == this.juz &&
          other.hizb == this.hizb &&
          other.page == this.page &&
          other.sajdah == this.sajdah);
}

class AyahsCompanion extends UpdateCompanion<AyahRow> {
  final Value<int> id;
  final Value<int> surahNumber;
  final Value<int> ayahNumber;
  final Value<String> textUthmani;
  final Value<String> textSimple;
  final Value<String> translation;
  final Value<String?> transliteration;
  final Value<int> juz;
  final Value<int> hizb;
  final Value<int?> page;
  final Value<int> sajdah;
  const AyahsCompanion({
    this.id = const Value.absent(),
    this.surahNumber = const Value.absent(),
    this.ayahNumber = const Value.absent(),
    this.textUthmani = const Value.absent(),
    this.textSimple = const Value.absent(),
    this.translation = const Value.absent(),
    this.transliteration = const Value.absent(),
    this.juz = const Value.absent(),
    this.hizb = const Value.absent(),
    this.page = const Value.absent(),
    this.sajdah = const Value.absent(),
  });
  AyahsCompanion.insert({
    this.id = const Value.absent(),
    required int surahNumber,
    required int ayahNumber,
    required String textUthmani,
    required String textSimple,
    required String translation,
    this.transliteration = const Value.absent(),
    required int juz,
    required int hizb,
    this.page = const Value.absent(),
    required int sajdah,
  }) : surahNumber = Value(surahNumber),
       ayahNumber = Value(ayahNumber),
       textUthmani = Value(textUthmani),
       textSimple = Value(textSimple),
       translation = Value(translation),
       juz = Value(juz),
       hizb = Value(hizb),
       sajdah = Value(sajdah);
  static Insertable<AyahRow> custom({
    Expression<int>? id,
    Expression<int>? surahNumber,
    Expression<int>? ayahNumber,
    Expression<String>? textUthmani,
    Expression<String>? textSimple,
    Expression<String>? translation,
    Expression<String>? transliteration,
    Expression<int>? juz,
    Expression<int>? hizb,
    Expression<int>? page,
    Expression<int>? sajdah,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surahNumber != null) 'surah_number': surahNumber,
      if (ayahNumber != null) 'ayah_number': ayahNumber,
      if (textUthmani != null) 'text_uthmani': textUthmani,
      if (textSimple != null) 'text_simple': textSimple,
      if (translation != null) 'translation': translation,
      if (transliteration != null) 'transliteration': transliteration,
      if (juz != null) 'juz': juz,
      if (hizb != null) 'hizb': hizb,
      if (page != null) 'page': page,
      if (sajdah != null) 'sajdah': sajdah,
    });
  }

  AyahsCompanion copyWith({
    Value<int>? id,
    Value<int>? surahNumber,
    Value<int>? ayahNumber,
    Value<String>? textUthmani,
    Value<String>? textSimple,
    Value<String>? translation,
    Value<String?>? transliteration,
    Value<int>? juz,
    Value<int>? hizb,
    Value<int?>? page,
    Value<int>? sajdah,
  }) {
    return AyahsCompanion(
      id: id ?? this.id,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      textUthmani: textUthmani ?? this.textUthmani,
      textSimple: textSimple ?? this.textSimple,
      translation: translation ?? this.translation,
      transliteration: transliteration ?? this.transliteration,
      juz: juz ?? this.juz,
      hizb: hizb ?? this.hizb,
      page: page ?? this.page,
      sajdah: sajdah ?? this.sajdah,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (surahNumber.present) {
      map['surah_number'] = Variable<int>(surahNumber.value);
    }
    if (ayahNumber.present) {
      map['ayah_number'] = Variable<int>(ayahNumber.value);
    }
    if (textUthmani.present) {
      map['text_uthmani'] = Variable<String>(textUthmani.value);
    }
    if (textSimple.present) {
      map['text_simple'] = Variable<String>(textSimple.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (transliteration.present) {
      map['transliteration'] = Variable<String>(transliteration.value);
    }
    if (juz.present) {
      map['juz'] = Variable<int>(juz.value);
    }
    if (hizb.present) {
      map['hizb'] = Variable<int>(hizb.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (sajdah.present) {
      map['sajdah'] = Variable<int>(sajdah.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AyahsCompanion(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('textUthmani: $textUthmani, ')
          ..write('textSimple: $textSimple, ')
          ..write('translation: $translation, ')
          ..write('transliteration: $transliteration, ')
          ..write('juz: $juz, ')
          ..write('hizb: $hizb, ')
          ..write('page: $page, ')
          ..write('sajdah: $sajdah')
          ..write(')'))
        .toString();
  }
}

class Adhkar extends Table with TableInfo<Adhkar, DhikrRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Adhkar(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _textArabicMeta = const VerificationMeta(
    'textArabic',
  );
  late final GeneratedColumn<String> textArabic = GeneratedColumn<String>(
    'text_arabic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _transliterationMeta = const VerificationMeta(
    'transliteration',
  );
  late final GeneratedColumn<String> transliteration = GeneratedColumn<String>(
    'transliteration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _defaultCountMeta = const VerificationMeta(
    'defaultCount',
  );
  late final GeneratedColumn<int> defaultCount = GeneratedColumn<int>(
    'default_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _benefitsMeta = const VerificationMeta(
    'benefits',
  );
  late final GeneratedColumn<String> benefits = GeneratedColumn<String>(
    'benefits',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    textArabic,
    translation,
    transliteration,
    defaultCount,
    sourceId,
    benefits,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'adhkar';
  @override
  VerificationContext validateIntegrity(
    Insertable<DhikrRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('text_arabic')) {
      context.handle(
        _textArabicMeta,
        textArabic.isAcceptableOrUnknown(data['text_arabic']!, _textArabicMeta),
      );
    } else if (isInserting) {
      context.missing(_textArabicMeta);
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translationMeta);
    }
    if (data.containsKey('transliteration')) {
      context.handle(
        _transliterationMeta,
        transliteration.isAcceptableOrUnknown(
          data['transliteration']!,
          _transliterationMeta,
        ),
      );
    }
    if (data.containsKey('default_count')) {
      context.handle(
        _defaultCountMeta,
        defaultCount.isAcceptableOrUnknown(
          data['default_count']!,
          _defaultCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultCountMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('benefits')) {
      context.handle(
        _benefitsMeta,
        benefits.isAcceptableOrUnknown(data['benefits']!, _benefitsMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DhikrRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DhikrRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      textArabic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_arabic'],
      )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      )!,
      transliteration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transliteration'],
      ),
      defaultCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_count'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      ),
      benefits: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}benefits'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  Adhkar createAlias(String alias) {
    return Adhkar(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DhikrRow extends DataClass implements Insertable<DhikrRow> {
  final int id;
  final String textArabic;
  final String translation;
  final String? transliteration;
  final int defaultCount;
  final int? sourceId;
  final String? benefits;
  final String? notes;
  const DhikrRow({
    required this.id,
    required this.textArabic,
    required this.translation,
    this.transliteration,
    required this.defaultCount,
    this.sourceId,
    this.benefits,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['text_arabic'] = Variable<String>(textArabic);
    map['translation'] = Variable<String>(translation);
    if (!nullToAbsent || transliteration != null) {
      map['transliteration'] = Variable<String>(transliteration);
    }
    map['default_count'] = Variable<int>(defaultCount);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<int>(sourceId);
    }
    if (!nullToAbsent || benefits != null) {
      map['benefits'] = Variable<String>(benefits);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  factory DhikrRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DhikrRow(
      id: serializer.fromJson<int>(json['id']),
      textArabic: serializer.fromJson<String>(json['text_arabic']),
      translation: serializer.fromJson<String>(json['translation']),
      transliteration: serializer.fromJson<String?>(json['transliteration']),
      defaultCount: serializer.fromJson<int>(json['default_count']),
      sourceId: serializer.fromJson<int?>(json['source_id']),
      benefits: serializer.fromJson<String?>(json['benefits']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'text_arabic': serializer.toJson<String>(textArabic),
      'translation': serializer.toJson<String>(translation),
      'transliteration': serializer.toJson<String?>(transliteration),
      'default_count': serializer.toJson<int>(defaultCount),
      'source_id': serializer.toJson<int?>(sourceId),
      'benefits': serializer.toJson<String?>(benefits),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  DhikrRow copyWith({
    int? id,
    String? textArabic,
    String? translation,
    Value<String?> transliteration = const Value.absent(),
    int? defaultCount,
    Value<int?> sourceId = const Value.absent(),
    Value<String?> benefits = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => DhikrRow(
    id: id ?? this.id,
    textArabic: textArabic ?? this.textArabic,
    translation: translation ?? this.translation,
    transliteration: transliteration.present
        ? transliteration.value
        : this.transliteration,
    defaultCount: defaultCount ?? this.defaultCount,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    benefits: benefits.present ? benefits.value : this.benefits,
    notes: notes.present ? notes.value : this.notes,
  );
  DhikrRow copyWithCompanion(AdhkarCompanion data) {
    return DhikrRow(
      id: data.id.present ? data.id.value : this.id,
      textArabic: data.textArabic.present
          ? data.textArabic.value
          : this.textArabic,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      transliteration: data.transliteration.present
          ? data.transliteration.value
          : this.transliteration,
      defaultCount: data.defaultCount.present
          ? data.defaultCount.value
          : this.defaultCount,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      benefits: data.benefits.present ? data.benefits.value : this.benefits,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DhikrRow(')
          ..write('id: $id, ')
          ..write('textArabic: $textArabic, ')
          ..write('translation: $translation, ')
          ..write('transliteration: $transliteration, ')
          ..write('defaultCount: $defaultCount, ')
          ..write('sourceId: $sourceId, ')
          ..write('benefits: $benefits, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    textArabic,
    translation,
    transliteration,
    defaultCount,
    sourceId,
    benefits,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DhikrRow &&
          other.id == this.id &&
          other.textArabic == this.textArabic &&
          other.translation == this.translation &&
          other.transliteration == this.transliteration &&
          other.defaultCount == this.defaultCount &&
          other.sourceId == this.sourceId &&
          other.benefits == this.benefits &&
          other.notes == this.notes);
}

class AdhkarCompanion extends UpdateCompanion<DhikrRow> {
  final Value<int> id;
  final Value<String> textArabic;
  final Value<String> translation;
  final Value<String?> transliteration;
  final Value<int> defaultCount;
  final Value<int?> sourceId;
  final Value<String?> benefits;
  final Value<String?> notes;
  const AdhkarCompanion({
    this.id = const Value.absent(),
    this.textArabic = const Value.absent(),
    this.translation = const Value.absent(),
    this.transliteration = const Value.absent(),
    this.defaultCount = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.benefits = const Value.absent(),
    this.notes = const Value.absent(),
  });
  AdhkarCompanion.insert({
    this.id = const Value.absent(),
    required String textArabic,
    required String translation,
    this.transliteration = const Value.absent(),
    required int defaultCount,
    this.sourceId = const Value.absent(),
    this.benefits = const Value.absent(),
    this.notes = const Value.absent(),
  }) : textArabic = Value(textArabic),
       translation = Value(translation),
       defaultCount = Value(defaultCount);
  static Insertable<DhikrRow> custom({
    Expression<int>? id,
    Expression<String>? textArabic,
    Expression<String>? translation,
    Expression<String>? transliteration,
    Expression<int>? defaultCount,
    Expression<int>? sourceId,
    Expression<String>? benefits,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (textArabic != null) 'text_arabic': textArabic,
      if (translation != null) 'translation': translation,
      if (transliteration != null) 'transliteration': transliteration,
      if (defaultCount != null) 'default_count': defaultCount,
      if (sourceId != null) 'source_id': sourceId,
      if (benefits != null) 'benefits': benefits,
      if (notes != null) 'notes': notes,
    });
  }

  AdhkarCompanion copyWith({
    Value<int>? id,
    Value<String>? textArabic,
    Value<String>? translation,
    Value<String?>? transliteration,
    Value<int>? defaultCount,
    Value<int?>? sourceId,
    Value<String?>? benefits,
    Value<String?>? notes,
  }) {
    return AdhkarCompanion(
      id: id ?? this.id,
      textArabic: textArabic ?? this.textArabic,
      translation: translation ?? this.translation,
      transliteration: transliteration ?? this.transliteration,
      defaultCount: defaultCount ?? this.defaultCount,
      sourceId: sourceId ?? this.sourceId,
      benefits: benefits ?? this.benefits,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (textArabic.present) {
      map['text_arabic'] = Variable<String>(textArabic.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (transliteration.present) {
      map['transliteration'] = Variable<String>(transliteration.value);
    }
    if (defaultCount.present) {
      map['default_count'] = Variable<int>(defaultCount.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (benefits.present) {
      map['benefits'] = Variable<String>(benefits.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdhkarCompanion(')
          ..write('id: $id, ')
          ..write('textArabic: $textArabic, ')
          ..write('translation: $translation, ')
          ..write('transliteration: $transliteration, ')
          ..write('defaultCount: $defaultCount, ')
          ..write('sourceId: $sourceId, ')
          ..write('benefits: $benefits, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class Sources extends Table with TableInfo<Sources, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Sources(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _gradingMeta = const VerificationMeta(
    'grading',
  );
  late final GeneratedColumn<String> grading = GeneratedColumn<String>(
    'grading',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fullTextMeta = const VerificationMeta(
    'fullText',
  );
  late final GeneratedColumn<String> fullText = GeneratedColumn<String>(
    'full_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collection,
    reference,
    grading,
    fullText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('grading')) {
      context.handle(
        _gradingMeta,
        grading.isAcceptableOrUnknown(data['grading']!, _gradingMeta),
      );
    }
    if (data.containsKey('full_text')) {
      context.handle(
        _fullTextMeta,
        fullText.isAcceptableOrUnknown(data['full_text']!, _fullTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      )!,
      grading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grading'],
      ),
      fullText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_text'],
      ),
    );
  }

  @override
  Sources createAlias(String alias) {
    return Sources(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final int id;
  final String collection;
  final String reference;
  final String? grading;
  final String? fullText;
  const SourceRow({
    required this.id,
    required this.collection,
    required this.reference,
    this.grading,
    this.fullText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collection'] = Variable<String>(collection);
    map['reference'] = Variable<String>(reference);
    if (!nullToAbsent || grading != null) {
      map['grading'] = Variable<String>(grading);
    }
    if (!nullToAbsent || fullText != null) {
      map['full_text'] = Variable<String>(fullText);
    }
    return map;
  }

  factory SourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<int>(json['id']),
      collection: serializer.fromJson<String>(json['collection']),
      reference: serializer.fromJson<String>(json['reference']),
      grading: serializer.fromJson<String?>(json['grading']),
      fullText: serializer.fromJson<String?>(json['full_text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collection': serializer.toJson<String>(collection),
      'reference': serializer.toJson<String>(reference),
      'grading': serializer.toJson<String?>(grading),
      'full_text': serializer.toJson<String?>(fullText),
    };
  }

  SourceRow copyWith({
    int? id,
    String? collection,
    String? reference,
    Value<String?> grading = const Value.absent(),
    Value<String?> fullText = const Value.absent(),
  }) => SourceRow(
    id: id ?? this.id,
    collection: collection ?? this.collection,
    reference: reference ?? this.reference,
    grading: grading.present ? grading.value : this.grading,
    fullText: fullText.present ? fullText.value : this.fullText,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      reference: data.reference.present ? data.reference.value : this.reference,
      grading: data.grading.present ? data.grading.value : this.grading,
      fullText: data.fullText.present ? data.fullText.value : this.fullText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('collection: $collection, ')
          ..write('reference: $reference, ')
          ..write('grading: $grading, ')
          ..write('fullText: $fullText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, collection, reference, grading, fullText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.collection == this.collection &&
          other.reference == this.reference &&
          other.grading == this.grading &&
          other.fullText == this.fullText);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<int> id;
  final Value<String> collection;
  final Value<String> reference;
  final Value<String?> grading;
  final Value<String?> fullText;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.collection = const Value.absent(),
    this.reference = const Value.absent(),
    this.grading = const Value.absent(),
    this.fullText = const Value.absent(),
  });
  SourcesCompanion.insert({
    this.id = const Value.absent(),
    required String collection,
    required String reference,
    this.grading = const Value.absent(),
    this.fullText = const Value.absent(),
  }) : collection = Value(collection),
       reference = Value(reference);
  static Insertable<SourceRow> custom({
    Expression<int>? id,
    Expression<String>? collection,
    Expression<String>? reference,
    Expression<String>? grading,
    Expression<String>? fullText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collection != null) 'collection': collection,
      if (reference != null) 'reference': reference,
      if (grading != null) 'grading': grading,
      if (fullText != null) 'full_text': fullText,
    });
  }

  SourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? collection,
    Value<String>? reference,
    Value<String?>? grading,
    Value<String?>? fullText,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      collection: collection ?? this.collection,
      reference: reference ?? this.reference,
      grading: grading ?? this.grading,
      fullText: fullText ?? this.fullText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (grading.present) {
      map['grading'] = Variable<String>(grading.value);
    }
    if (fullText.present) {
      map['full_text'] = Variable<String>(fullText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('collection: $collection, ')
          ..write('reference: $reference, ')
          ..write('grading: $grading, ')
          ..write('fullText: $fullText')
          ..write(')'))
        .toString();
  }
}

class Collections extends Table with TableInfo<Collections, CollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Collections(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _nameArabicMeta = const VerificationMeta(
    'nameArabic',
  );
  late final GeneratedColumn<String> nameArabic = GeneratedColumn<String>(
    'name_arabic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameEnglishMeta = const VerificationMeta(
    'nameEnglish',
  );
  late final GeneratedColumn<String> nameEnglish = GeneratedColumn<String>(
    'name_english',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameArabic,
    nameEnglish,
    description,
    author,
    type,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name_arabic')) {
      context.handle(
        _nameArabicMeta,
        nameArabic.isAcceptableOrUnknown(data['name_arabic']!, _nameArabicMeta),
      );
    } else if (isInserting) {
      context.missing(_nameArabicMeta);
    }
    if (data.containsKey('name_english')) {
      context.handle(
        _nameEnglishMeta,
        nameEnglish.isAcceptableOrUnknown(
          data['name_english']!,
          _nameEnglishMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameEnglishMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nameArabic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_arabic'],
      )!,
      nameEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_english'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  Collections createAlias(String alias) {
    return Collections(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CollectionRow extends DataClass implements Insertable<CollectionRow> {
  final int id;
  final String nameArabic;
  final String nameEnglish;
  final String? description;
  final String? author;
  final String type;
  final int sortOrder;
  const CollectionRow({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    this.description,
    this.author,
    required this.type,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name_arabic'] = Variable<String>(nameArabic);
    map['name_english'] = Variable<String>(nameEnglish);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['type'] = Variable<String>(type);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  factory CollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionRow(
      id: serializer.fromJson<int>(json['id']),
      nameArabic: serializer.fromJson<String>(json['name_arabic']),
      nameEnglish: serializer.fromJson<String>(json['name_english']),
      description: serializer.fromJson<String?>(json['description']),
      author: serializer.fromJson<String?>(json['author']),
      type: serializer.fromJson<String>(json['type']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name_arabic': serializer.toJson<String>(nameArabic),
      'name_english': serializer.toJson<String>(nameEnglish),
      'description': serializer.toJson<String?>(description),
      'author': serializer.toJson<String?>(author),
      'type': serializer.toJson<String>(type),
      'sort_order': serializer.toJson<int>(sortOrder),
    };
  }

  CollectionRow copyWith({
    int? id,
    String? nameArabic,
    String? nameEnglish,
    Value<String?> description = const Value.absent(),
    Value<String?> author = const Value.absent(),
    String? type,
    int? sortOrder,
  }) => CollectionRow(
    id: id ?? this.id,
    nameArabic: nameArabic ?? this.nameArabic,
    nameEnglish: nameEnglish ?? this.nameEnglish,
    description: description.present ? description.value : this.description,
    author: author.present ? author.value : this.author,
    type: type ?? this.type,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CollectionRow copyWithCompanion(CollectionsCompanion data) {
    return CollectionRow(
      id: data.id.present ? data.id.value : this.id,
      nameArabic: data.nameArabic.present
          ? data.nameArabic.value
          : this.nameArabic,
      nameEnglish: data.nameEnglish.present
          ? data.nameEnglish.value
          : this.nameEnglish,
      description: data.description.present
          ? data.description.value
          : this.description,
      author: data.author.present ? data.author.value : this.author,
      type: data.type.present ? data.type.value : this.type,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionRow(')
          ..write('id: $id, ')
          ..write('nameArabic: $nameArabic, ')
          ..write('nameEnglish: $nameEnglish, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('type: $type, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameArabic,
    nameEnglish,
    description,
    author,
    type,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionRow &&
          other.id == this.id &&
          other.nameArabic == this.nameArabic &&
          other.nameEnglish == this.nameEnglish &&
          other.description == this.description &&
          other.author == this.author &&
          other.type == this.type &&
          other.sortOrder == this.sortOrder);
}

class CollectionsCompanion extends UpdateCompanion<CollectionRow> {
  final Value<int> id;
  final Value<String> nameArabic;
  final Value<String> nameEnglish;
  final Value<String?> description;
  final Value<String?> author;
  final Value<String> type;
  final Value<int> sortOrder;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.nameArabic = const Value.absent(),
    this.nameEnglish = const Value.absent(),
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.type = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  CollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String nameArabic,
    required String nameEnglish,
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    required String type,
    required int sortOrder,
  }) : nameArabic = Value(nameArabic),
       nameEnglish = Value(nameEnglish),
       type = Value(type),
       sortOrder = Value(sortOrder);
  static Insertable<CollectionRow> custom({
    Expression<int>? id,
    Expression<String>? nameArabic,
    Expression<String>? nameEnglish,
    Expression<String>? description,
    Expression<String>? author,
    Expression<String>? type,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameArabic != null) 'name_arabic': nameArabic,
      if (nameEnglish != null) 'name_english': nameEnglish,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (type != null) 'type': type,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  CollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? nameArabic,
    Value<String>? nameEnglish,
    Value<String?>? description,
    Value<String?>? author,
    Value<String>? type,
    Value<int>? sortOrder,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      nameArabic: nameArabic ?? this.nameArabic,
      nameEnglish: nameEnglish ?? this.nameEnglish,
      description: description ?? this.description,
      author: author ?? this.author,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nameArabic.present) {
      map['name_arabic'] = Variable<String>(nameArabic.value);
    }
    if (nameEnglish.present) {
      map['name_english'] = Variable<String>(nameEnglish.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('nameArabic: $nameArabic, ')
          ..write('nameEnglish: $nameEnglish, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('type: $type, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class CollectionItems extends Table
    with TableInfo<CollectionItems, CollectionItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  CollectionItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _countOverrideMeta = const VerificationMeta(
    'countOverride',
  );
  late final GeneratedColumn<int> countOverride = GeneratedColumn<int>(
    'count_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _repeatGroupMeta = const VerificationMeta(
    'repeatGroup',
  );
  late final GeneratedColumn<int> repeatGroup = GeneratedColumn<int>(
    'repeat_group',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _repeatGroupCountMeta = const VerificationMeta(
    'repeatGroupCount',
  );
  late final GeneratedColumn<int> repeatGroupCount = GeneratedColumn<int>(
    'repeat_group_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionId,
    itemType,
    itemId,
    position,
    countOverride,
    repeatGroup,
    repeatGroupCount,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('count_override')) {
      context.handle(
        _countOverrideMeta,
        countOverride.isAcceptableOrUnknown(
          data['count_override']!,
          _countOverrideMeta,
        ),
      );
    }
    if (data.containsKey('repeat_group')) {
      context.handle(
        _repeatGroupMeta,
        repeatGroup.isAcceptableOrUnknown(
          data['repeat_group']!,
          _repeatGroupMeta,
        ),
      );
    }
    if (data.containsKey('repeat_group_count')) {
      context.handle(
        _repeatGroupCountMeta,
        repeatGroupCount.isAcceptableOrUnknown(
          data['repeat_group_count']!,
          _repeatGroupCountMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      countOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count_override'],
      ),
      repeatGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_group'],
      ),
      repeatGroupCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_group_count'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  CollectionItems createAlias(String alias) {
    return CollectionItems(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CollectionItemRow extends DataClass
    implements Insertable<CollectionItemRow> {
  final int id;
  final int collectionId;
  final String itemType;
  final int itemId;
  final int position;
  final int? countOverride;
  final int? repeatGroup;
  final int? repeatGroupCount;
  final String? note;
  const CollectionItemRow({
    required this.id,
    required this.collectionId,
    required this.itemType,
    required this.itemId,
    required this.position,
    this.countOverride,
    this.repeatGroup,
    this.repeatGroupCount,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collection_id'] = Variable<int>(collectionId);
    map['item_type'] = Variable<String>(itemType);
    map['item_id'] = Variable<int>(itemId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || countOverride != null) {
      map['count_override'] = Variable<int>(countOverride);
    }
    if (!nullToAbsent || repeatGroup != null) {
      map['repeat_group'] = Variable<int>(repeatGroup);
    }
    if (!nullToAbsent || repeatGroupCount != null) {
      map['repeat_group_count'] = Variable<int>(repeatGroupCount);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  factory CollectionItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionItemRow(
      id: serializer.fromJson<int>(json['id']),
      collectionId: serializer.fromJson<int>(json['collection_id']),
      itemType: serializer.fromJson<String>(json['item_type']),
      itemId: serializer.fromJson<int>(json['item_id']),
      position: serializer.fromJson<int>(json['position']),
      countOverride: serializer.fromJson<int?>(json['count_override']),
      repeatGroup: serializer.fromJson<int?>(json['repeat_group']),
      repeatGroupCount: serializer.fromJson<int?>(json['repeat_group_count']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collection_id': serializer.toJson<int>(collectionId),
      'item_type': serializer.toJson<String>(itemType),
      'item_id': serializer.toJson<int>(itemId),
      'position': serializer.toJson<int>(position),
      'count_override': serializer.toJson<int?>(countOverride),
      'repeat_group': serializer.toJson<int?>(repeatGroup),
      'repeat_group_count': serializer.toJson<int?>(repeatGroupCount),
      'note': serializer.toJson<String?>(note),
    };
  }

  CollectionItemRow copyWith({
    int? id,
    int? collectionId,
    String? itemType,
    int? itemId,
    int? position,
    Value<int?> countOverride = const Value.absent(),
    Value<int?> repeatGroup = const Value.absent(),
    Value<int?> repeatGroupCount = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => CollectionItemRow(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    itemType: itemType ?? this.itemType,
    itemId: itemId ?? this.itemId,
    position: position ?? this.position,
    countOverride: countOverride.present
        ? countOverride.value
        : this.countOverride,
    repeatGroup: repeatGroup.present ? repeatGroup.value : this.repeatGroup,
    repeatGroupCount: repeatGroupCount.present
        ? repeatGroupCount.value
        : this.repeatGroupCount,
    note: note.present ? note.value : this.note,
  );
  CollectionItemRow copyWithCompanion(CollectionItemsCompanion data) {
    return CollectionItemRow(
      id: data.id.present ? data.id.value : this.id,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      position: data.position.present ? data.position.value : this.position,
      countOverride: data.countOverride.present
          ? data.countOverride.value
          : this.countOverride,
      repeatGroup: data.repeatGroup.present
          ? data.repeatGroup.value
          : this.repeatGroup,
      repeatGroupCount: data.repeatGroupCount.present
          ? data.repeatGroupCount.value
          : this.repeatGroupCount,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemRow(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('countOverride: $countOverride, ')
          ..write('repeatGroup: $repeatGroup, ')
          ..write('repeatGroupCount: $repeatGroupCount, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    collectionId,
    itemType,
    itemId,
    position,
    countOverride,
    repeatGroup,
    repeatGroupCount,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionItemRow &&
          other.id == this.id &&
          other.collectionId == this.collectionId &&
          other.itemType == this.itemType &&
          other.itemId == this.itemId &&
          other.position == this.position &&
          other.countOverride == this.countOverride &&
          other.repeatGroup == this.repeatGroup &&
          other.repeatGroupCount == this.repeatGroupCount &&
          other.note == this.note);
}

class CollectionItemsCompanion extends UpdateCompanion<CollectionItemRow> {
  final Value<int> id;
  final Value<int> collectionId;
  final Value<String> itemType;
  final Value<int> itemId;
  final Value<int> position;
  final Value<int?> countOverride;
  final Value<int?> repeatGroup;
  final Value<int?> repeatGroupCount;
  final Value<String?> note;
  const CollectionItemsCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
    this.countOverride = const Value.absent(),
    this.repeatGroup = const Value.absent(),
    this.repeatGroupCount = const Value.absent(),
    this.note = const Value.absent(),
  });
  CollectionItemsCompanion.insert({
    this.id = const Value.absent(),
    required int collectionId,
    required String itemType,
    required int itemId,
    required int position,
    this.countOverride = const Value.absent(),
    this.repeatGroup = const Value.absent(),
    this.repeatGroupCount = const Value.absent(),
    this.note = const Value.absent(),
  }) : collectionId = Value(collectionId),
       itemType = Value(itemType),
       itemId = Value(itemId),
       position = Value(position);
  static Insertable<CollectionItemRow> custom({
    Expression<int>? id,
    Expression<int>? collectionId,
    Expression<String>? itemType,
    Expression<int>? itemId,
    Expression<int>? position,
    Expression<int>? countOverride,
    Expression<int>? repeatGroup,
    Expression<int>? repeatGroupCount,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionId != null) 'collection_id': collectionId,
      if (itemType != null) 'item_type': itemType,
      if (itemId != null) 'item_id': itemId,
      if (position != null) 'position': position,
      if (countOverride != null) 'count_override': countOverride,
      if (repeatGroup != null) 'repeat_group': repeatGroup,
      if (repeatGroupCount != null) 'repeat_group_count': repeatGroupCount,
      if (note != null) 'note': note,
    });
  }

  CollectionItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? collectionId,
    Value<String>? itemType,
    Value<int>? itemId,
    Value<int>? position,
    Value<int?>? countOverride,
    Value<int?>? repeatGroup,
    Value<int?>? repeatGroupCount,
    Value<String?>? note,
  }) {
    return CollectionItemsCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      countOverride: countOverride ?? this.countOverride,
      repeatGroup: repeatGroup ?? this.repeatGroup,
      repeatGroupCount: repeatGroupCount ?? this.repeatGroupCount,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (countOverride.present) {
      map['count_override'] = Variable<int>(countOverride.value);
    }
    if (repeatGroup.present) {
      map['repeat_group'] = Variable<int>(repeatGroup.value);
    }
    if (repeatGroupCount.present) {
      map['repeat_group_count'] = Variable<int>(repeatGroupCount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemsCompanion(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('countOverride: $countOverride, ')
          ..write('repeatGroup: $repeatGroup, ')
          ..write('repeatGroupCount: $repeatGroupCount, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class Meta extends Table with TableInfo<Meta, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Meta(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  Meta createAlias(String alias) {
    return Meta(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ContentDatabase extends GeneratedDatabase {
  _$ContentDatabase(QueryExecutor e) : super(e);
  $ContentDatabaseManager get managers => $ContentDatabaseManager(this);
  late final Surahs surahs = Surahs(this);
  late final Ayahs ayahs = Ayahs(this);
  late final Index idxAyahsSurahAyah = Index(
    'idx_ayahs_surah_ayah',
    'CREATE UNIQUE INDEX idx_ayahs_surah_ayah ON ayahs (surah_number, ayah_number)',
  );
  late final Index idxAyahsJuz = Index(
    'idx_ayahs_juz',
    'CREATE INDEX idx_ayahs_juz ON ayahs (juz)',
  );
  late final Index idxAyahsHizb = Index(
    'idx_ayahs_hizb',
    'CREATE INDEX idx_ayahs_hizb ON ayahs (hizb)',
  );
  late final Adhkar adhkar = Adhkar(this);
  late final Sources sources = Sources(this);
  late final Collections collections = Collections(this);
  late final CollectionItems collectionItems = CollectionItems(this);
  late final Index idxCollectionItemsPosition = Index(
    'idx_collection_items_position',
    'CREATE INDEX idx_collection_items_position ON collection_items (collection_id, position)',
  );
  late final Meta meta = Meta(this);
  Selectable<String> metaValue({required String key}) {
    return customSelect(
      'SELECT value FROM meta WHERE "key" = ?1',
      variables: [Variable<String>(key)],
      readsFrom: {meta},
    ).map((QueryRow row) => row.read<String>('value'));
  }

  Selectable<SurahRow> allSurahs() {
    return customSelect(
      'SELECT * FROM surahs ORDER BY number',
      variables: [],
      readsFrom: {surahs},
    ).asyncMap(surahs.mapFromRow);
  }

  Selectable<SurahRow> surahByNumber({required int number}) {
    return customSelect(
      'SELECT * FROM surahs WHERE number = ?1',
      variables: [Variable<int>(number)],
      readsFrom: {surahs},
    ).asyncMap(surahs.mapFromRow);
  }

  Selectable<SurahRow> surahsByNumbers({required List<int> numbers}) {
    var $arrayStartIndex = 1;
    final expandednumbers = $expandVar($arrayStartIndex, numbers.length);
    $arrayStartIndex += numbers.length;
    return customSelect(
      'SELECT * FROM surahs WHERE number IN ($expandednumbers)',
      variables: [for (var $ in numbers) Variable<int>($)],
      readsFrom: {surahs},
    ).asyncMap(surahs.mapFromRow);
  }

  Selectable<AyahRow> ayahsForSurah({required int surah}) {
    return customSelect(
      'SELECT * FROM ayahs WHERE surah_number = ?1 ORDER BY ayah_number',
      variables: [Variable<int>(surah)],
      readsFrom: {ayahs},
    ).asyncMap(ayahs.mapFromRow);
  }

  Selectable<AyahRow> ayahById({required int id}) {
    return customSelect(
      'SELECT * FROM ayahs WHERE id = ?1',
      variables: [Variable<int>(id)],
      readsFrom: {ayahs},
    ).asyncMap(ayahs.mapFromRow);
  }

  Selectable<AyahRow> ayahsInRange({
    required int surah,
    required int first,
    required int last,
  }) {
    return customSelect(
      'SELECT * FROM ayahs WHERE surah_number = ?1 AND ayah_number BETWEEN ?2 AND ?3 ORDER BY ayah_number',
      variables: [
        Variable<int>(surah),
        Variable<int>(first),
        Variable<int>(last),
      ],
      readsFrom: {ayahs},
    ).asyncMap(ayahs.mapFromRow);
  }

  Selectable<AyahRow> ayahsForJuz({required int juz}) {
    return customSelect(
      'SELECT * FROM ayahs WHERE juz = ?1 ORDER BY id',
      variables: [Variable<int>(juz)],
      readsFrom: {ayahs},
    ).asyncMap(ayahs.mapFromRow);
  }

  Selectable<AyahRow> ayahsByIds({required List<int> ids}) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
      'SELECT * FROM ayahs WHERE id IN ($expandedids)',
      variables: [for (var $ in ids) Variable<int>($)],
      readsFrom: {ayahs},
    ).asyncMap(ayahs.mapFromRow);
  }

  Selectable<DhikrRow> dhikrById({required int id}) {
    return customSelect(
      'SELECT * FROM adhkar WHERE id = ?1',
      variables: [Variable<int>(id)],
      readsFrom: {adhkar},
    ).asyncMap(adhkar.mapFromRow);
  }

  Selectable<DhikrRow> adhkarByIds({required List<int> ids}) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
      'SELECT * FROM adhkar WHERE id IN ($expandedids)',
      variables: [for (var $ in ids) Variable<int>($)],
      readsFrom: {adhkar},
    ).asyncMap(adhkar.mapFromRow);
  }

  Selectable<SourceRow> sourcesByIds({required List<int> ids}) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
      'SELECT * FROM sources WHERE id IN ($expandedids)',
      variables: [for (var $ in ids) Variable<int>($)],
      readsFrom: {sources},
    ).asyncMap(sources.mapFromRow);
  }

  Selectable<CollectionRow> allCollections() {
    return customSelect(
      'SELECT * FROM collections ORDER BY sort_order, id',
      variables: [],
      readsFrom: {collections},
    ).asyncMap(collections.mapFromRow);
  }

  Selectable<CollectionRow> collectionById({required int id}) {
    return customSelect(
      'SELECT * FROM collections WHERE id = ?1',
      variables: [Variable<int>(id)],
      readsFrom: {collections},
    ).asyncMap(collections.mapFromRow);
  }

  Selectable<CollectionItemRow> itemsForCollection({required int collection}) {
    return customSelect(
      'SELECT * FROM collection_items WHERE collection_id = ?1 ORDER BY position',
      variables: [Variable<int>(collection)],
      readsFrom: {collectionItems},
    ).asyncMap(collectionItems.mapFromRow);
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    surahs,
    ayahs,
    idxAyahsSurahAyah,
    idxAyahsJuz,
    idxAyahsHizb,
    adhkar,
    sources,
    collections,
    collectionItems,
    idxCollectionItemsPosition,
    meta,
  ];
}

typedef $SurahsCreateCompanionBuilder =
    SurahsCompanion Function({
      Value<int> number,
      required String nameArabic,
      required String nameTransliterated,
      required String nameEnglish,
      required String revelationPlace,
      required int ayahCount,
      required int hasBismillah,
      Value<int?> orderRevealed,
    });
typedef $SurahsUpdateCompanionBuilder =
    SurahsCompanion Function({
      Value<int> number,
      Value<String> nameArabic,
      Value<String> nameTransliterated,
      Value<String> nameEnglish,
      Value<String> revelationPlace,
      Value<int> ayahCount,
      Value<int> hasBismillah,
      Value<int?> orderRevealed,
    });

class $SurahsFilterComposer extends Composer<_$ContentDatabase, Surahs> {
  $SurahsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameArabic => $composableBuilder(
    column: $table.nameArabic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameTransliterated => $composableBuilder(
    column: $table.nameTransliterated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEnglish => $composableBuilder(
    column: $table.nameEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revelationPlace => $composableBuilder(
    column: $table.revelationPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahCount => $composableBuilder(
    column: $table.ayahCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasBismillah => $composableBuilder(
    column: $table.hasBismillah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderRevealed => $composableBuilder(
    column: $table.orderRevealed,
    builder: (column) => ColumnFilters(column),
  );
}

class $SurahsOrderingComposer extends Composer<_$ContentDatabase, Surahs> {
  $SurahsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameArabic => $composableBuilder(
    column: $table.nameArabic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameTransliterated => $composableBuilder(
    column: $table.nameTransliterated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEnglish => $composableBuilder(
    column: $table.nameEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revelationPlace => $composableBuilder(
    column: $table.revelationPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahCount => $composableBuilder(
    column: $table.ayahCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasBismillah => $composableBuilder(
    column: $table.hasBismillah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderRevealed => $composableBuilder(
    column: $table.orderRevealed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SurahsAnnotationComposer extends Composer<_$ContentDatabase, Surahs> {
  $SurahsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get nameArabic => $composableBuilder(
    column: $table.nameArabic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameTransliterated => $composableBuilder(
    column: $table.nameTransliterated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameEnglish => $composableBuilder(
    column: $table.nameEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revelationPlace => $composableBuilder(
    column: $table.revelationPlace,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ayahCount =>
      $composableBuilder(column: $table.ayahCount, builder: (column) => column);

  GeneratedColumn<int> get hasBismillah => $composableBuilder(
    column: $table.hasBismillah,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderRevealed => $composableBuilder(
    column: $table.orderRevealed,
    builder: (column) => column,
  );
}

class $SurahsTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          Surahs,
          SurahRow,
          $SurahsFilterComposer,
          $SurahsOrderingComposer,
          $SurahsAnnotationComposer,
          $SurahsCreateCompanionBuilder,
          $SurahsUpdateCompanionBuilder,
          (SurahRow, BaseReferences<_$ContentDatabase, Surahs, SurahRow>),
          SurahRow,
          PrefetchHooks Function()
        > {
  $SurahsTableManager(_$ContentDatabase db, Surahs table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SurahsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SurahsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SurahsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> number = const Value.absent(),
                Value<String> nameArabic = const Value.absent(),
                Value<String> nameTransliterated = const Value.absent(),
                Value<String> nameEnglish = const Value.absent(),
                Value<String> revelationPlace = const Value.absent(),
                Value<int> ayahCount = const Value.absent(),
                Value<int> hasBismillah = const Value.absent(),
                Value<int?> orderRevealed = const Value.absent(),
              }) => SurahsCompanion(
                number: number,
                nameArabic: nameArabic,
                nameTransliterated: nameTransliterated,
                nameEnglish: nameEnglish,
                revelationPlace: revelationPlace,
                ayahCount: ayahCount,
                hasBismillah: hasBismillah,
                orderRevealed: orderRevealed,
              ),
          createCompanionCallback:
              ({
                Value<int> number = const Value.absent(),
                required String nameArabic,
                required String nameTransliterated,
                required String nameEnglish,
                required String revelationPlace,
                required int ayahCount,
                required int hasBismillah,
                Value<int?> orderRevealed = const Value.absent(),
              }) => SurahsCompanion.insert(
                number: number,
                nameArabic: nameArabic,
                nameTransliterated: nameTransliterated,
                nameEnglish: nameEnglish,
                revelationPlace: revelationPlace,
                ayahCount: ayahCount,
                hasBismillah: hasBismillah,
                orderRevealed: orderRevealed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SurahsProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      Surahs,
      SurahRow,
      $SurahsFilterComposer,
      $SurahsOrderingComposer,
      $SurahsAnnotationComposer,
      $SurahsCreateCompanionBuilder,
      $SurahsUpdateCompanionBuilder,
      (SurahRow, BaseReferences<_$ContentDatabase, Surahs, SurahRow>),
      SurahRow,
      PrefetchHooks Function()
    >;
typedef $AyahsCreateCompanionBuilder =
    AyahsCompanion Function({
      Value<int> id,
      required int surahNumber,
      required int ayahNumber,
      required String textUthmani,
      required String textSimple,
      required String translation,
      Value<String?> transliteration,
      required int juz,
      required int hizb,
      Value<int?> page,
      required int sajdah,
    });
typedef $AyahsUpdateCompanionBuilder =
    AyahsCompanion Function({
      Value<int> id,
      Value<int> surahNumber,
      Value<int> ayahNumber,
      Value<String> textUthmani,
      Value<String> textSimple,
      Value<String> translation,
      Value<String?> transliteration,
      Value<int> juz,
      Value<int> hizb,
      Value<int?> page,
      Value<int> sajdah,
    });

class $AyahsFilterComposer extends Composer<_$ContentDatabase, Ayahs> {
  $AyahsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textUthmani => $composableBuilder(
    column: $table.textUthmani,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textSimple => $composableBuilder(
    column: $table.textSimple,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get juz => $composableBuilder(
    column: $table.juz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hizb => $composableBuilder(
    column: $table.hizb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sajdah => $composableBuilder(
    column: $table.sajdah,
    builder: (column) => ColumnFilters(column),
  );
}

class $AyahsOrderingComposer extends Composer<_$ContentDatabase, Ayahs> {
  $AyahsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textUthmani => $composableBuilder(
    column: $table.textUthmani,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textSimple => $composableBuilder(
    column: $table.textSimple,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get juz => $composableBuilder(
    column: $table.juz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hizb => $composableBuilder(
    column: $table.hizb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sajdah => $composableBuilder(
    column: $table.sajdah,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AyahsAnnotationComposer extends Composer<_$ContentDatabase, Ayahs> {
  $AyahsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textUthmani => $composableBuilder(
    column: $table.textUthmani,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textSimple => $composableBuilder(
    column: $table.textSimple,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get juz =>
      $composableBuilder(column: $table.juz, builder: (column) => column);

  GeneratedColumn<int> get hizb =>
      $composableBuilder(column: $table.hizb, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<int> get sajdah =>
      $composableBuilder(column: $table.sajdah, builder: (column) => column);
}

class $AyahsTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          Ayahs,
          AyahRow,
          $AyahsFilterComposer,
          $AyahsOrderingComposer,
          $AyahsAnnotationComposer,
          $AyahsCreateCompanionBuilder,
          $AyahsUpdateCompanionBuilder,
          (AyahRow, BaseReferences<_$ContentDatabase, Ayahs, AyahRow>),
          AyahRow,
          PrefetchHooks Function()
        > {
  $AyahsTableManager(_$ContentDatabase db, Ayahs table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AyahsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AyahsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AyahsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> surahNumber = const Value.absent(),
                Value<int> ayahNumber = const Value.absent(),
                Value<String> textUthmani = const Value.absent(),
                Value<String> textSimple = const Value.absent(),
                Value<String> translation = const Value.absent(),
                Value<String?> transliteration = const Value.absent(),
                Value<int> juz = const Value.absent(),
                Value<int> hizb = const Value.absent(),
                Value<int?> page = const Value.absent(),
                Value<int> sajdah = const Value.absent(),
              }) => AyahsCompanion(
                id: id,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                textUthmani: textUthmani,
                textSimple: textSimple,
                translation: translation,
                transliteration: transliteration,
                juz: juz,
                hizb: hizb,
                page: page,
                sajdah: sajdah,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int surahNumber,
                required int ayahNumber,
                required String textUthmani,
                required String textSimple,
                required String translation,
                Value<String?> transliteration = const Value.absent(),
                required int juz,
                required int hizb,
                Value<int?> page = const Value.absent(),
                required int sajdah,
              }) => AyahsCompanion.insert(
                id: id,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                textUthmani: textUthmani,
                textSimple: textSimple,
                translation: translation,
                transliteration: transliteration,
                juz: juz,
                hizb: hizb,
                page: page,
                sajdah: sajdah,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AyahsProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      Ayahs,
      AyahRow,
      $AyahsFilterComposer,
      $AyahsOrderingComposer,
      $AyahsAnnotationComposer,
      $AyahsCreateCompanionBuilder,
      $AyahsUpdateCompanionBuilder,
      (AyahRow, BaseReferences<_$ContentDatabase, Ayahs, AyahRow>),
      AyahRow,
      PrefetchHooks Function()
    >;
typedef $AdhkarCreateCompanionBuilder =
    AdhkarCompanion Function({
      Value<int> id,
      required String textArabic,
      required String translation,
      Value<String?> transliteration,
      required int defaultCount,
      Value<int?> sourceId,
      Value<String?> benefits,
      Value<String?> notes,
    });
typedef $AdhkarUpdateCompanionBuilder =
    AdhkarCompanion Function({
      Value<int> id,
      Value<String> textArabic,
      Value<String> translation,
      Value<String?> transliteration,
      Value<int> defaultCount,
      Value<int?> sourceId,
      Value<String?> benefits,
      Value<String?> notes,
    });

class $AdhkarFilterComposer extends Composer<_$ContentDatabase, Adhkar> {
  $AdhkarFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textArabic => $composableBuilder(
    column: $table.textArabic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultCount => $composableBuilder(
    column: $table.defaultCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get benefits => $composableBuilder(
    column: $table.benefits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $AdhkarOrderingComposer extends Composer<_$ContentDatabase, Adhkar> {
  $AdhkarOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textArabic => $composableBuilder(
    column: $table.textArabic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultCount => $composableBuilder(
    column: $table.defaultCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get benefits => $composableBuilder(
    column: $table.benefits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AdhkarAnnotationComposer extends Composer<_$ContentDatabase, Adhkar> {
  $AdhkarAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get textArabic => $composableBuilder(
    column: $table.textArabic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultCount => $composableBuilder(
    column: $table.defaultCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get benefits =>
      $composableBuilder(column: $table.benefits, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $AdhkarTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          Adhkar,
          DhikrRow,
          $AdhkarFilterComposer,
          $AdhkarOrderingComposer,
          $AdhkarAnnotationComposer,
          $AdhkarCreateCompanionBuilder,
          $AdhkarUpdateCompanionBuilder,
          (DhikrRow, BaseReferences<_$ContentDatabase, Adhkar, DhikrRow>),
          DhikrRow,
          PrefetchHooks Function()
        > {
  $AdhkarTableManager(_$ContentDatabase db, Adhkar table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AdhkarFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AdhkarOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AdhkarAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> textArabic = const Value.absent(),
                Value<String> translation = const Value.absent(),
                Value<String?> transliteration = const Value.absent(),
                Value<int> defaultCount = const Value.absent(),
                Value<int?> sourceId = const Value.absent(),
                Value<String?> benefits = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => AdhkarCompanion(
                id: id,
                textArabic: textArabic,
                translation: translation,
                transliteration: transliteration,
                defaultCount: defaultCount,
                sourceId: sourceId,
                benefits: benefits,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String textArabic,
                required String translation,
                Value<String?> transliteration = const Value.absent(),
                required int defaultCount,
                Value<int?> sourceId = const Value.absent(),
                Value<String?> benefits = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => AdhkarCompanion.insert(
                id: id,
                textArabic: textArabic,
                translation: translation,
                transliteration: transliteration,
                defaultCount: defaultCount,
                sourceId: sourceId,
                benefits: benefits,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AdhkarProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      Adhkar,
      DhikrRow,
      $AdhkarFilterComposer,
      $AdhkarOrderingComposer,
      $AdhkarAnnotationComposer,
      $AdhkarCreateCompanionBuilder,
      $AdhkarUpdateCompanionBuilder,
      (DhikrRow, BaseReferences<_$ContentDatabase, Adhkar, DhikrRow>),
      DhikrRow,
      PrefetchHooks Function()
    >;
typedef $SourcesCreateCompanionBuilder =
    SourcesCompanion Function({
      Value<int> id,
      required String collection,
      required String reference,
      Value<String?> grading,
      Value<String?> fullText,
    });
typedef $SourcesUpdateCompanionBuilder =
    SourcesCompanion Function({
      Value<int> id,
      Value<String> collection,
      Value<String> reference,
      Value<String?> grading,
      Value<String?> fullText,
    });

class $SourcesFilterComposer extends Composer<_$ContentDatabase, Sources> {
  $SourcesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grading => $composableBuilder(
    column: $table.grading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullText => $composableBuilder(
    column: $table.fullText,
    builder: (column) => ColumnFilters(column),
  );
}

class $SourcesOrderingComposer extends Composer<_$ContentDatabase, Sources> {
  $SourcesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grading => $composableBuilder(
    column: $table.grading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullText => $composableBuilder(
    column: $table.fullText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SourcesAnnotationComposer extends Composer<_$ContentDatabase, Sources> {
  $SourcesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get grading =>
      $composableBuilder(column: $table.grading, builder: (column) => column);

  GeneratedColumn<String> get fullText =>
      $composableBuilder(column: $table.fullText, builder: (column) => column);
}

class $SourcesTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          Sources,
          SourceRow,
          $SourcesFilterComposer,
          $SourcesOrderingComposer,
          $SourcesAnnotationComposer,
          $SourcesCreateCompanionBuilder,
          $SourcesUpdateCompanionBuilder,
          (SourceRow, BaseReferences<_$ContentDatabase, Sources, SourceRow>),
          SourceRow,
          PrefetchHooks Function()
        > {
  $SourcesTableManager(_$ContentDatabase db, Sources table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SourcesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SourcesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SourcesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> collection = const Value.absent(),
                Value<String> reference = const Value.absent(),
                Value<String?> grading = const Value.absent(),
                Value<String?> fullText = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                collection: collection,
                reference: reference,
                grading: grading,
                fullText: fullText,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String collection,
                required String reference,
                Value<String?> grading = const Value.absent(),
                Value<String?> fullText = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                collection: collection,
                reference: reference,
                grading: grading,
                fullText: fullText,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SourcesProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      Sources,
      SourceRow,
      $SourcesFilterComposer,
      $SourcesOrderingComposer,
      $SourcesAnnotationComposer,
      $SourcesCreateCompanionBuilder,
      $SourcesUpdateCompanionBuilder,
      (SourceRow, BaseReferences<_$ContentDatabase, Sources, SourceRow>),
      SourceRow,
      PrefetchHooks Function()
    >;
typedef $CollectionsCreateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      required String nameArabic,
      required String nameEnglish,
      Value<String?> description,
      Value<String?> author,
      required String type,
      required int sortOrder,
    });
typedef $CollectionsUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      Value<String> nameArabic,
      Value<String> nameEnglish,
      Value<String?> description,
      Value<String?> author,
      Value<String> type,
      Value<int> sortOrder,
    });

class $CollectionsFilterComposer
    extends Composer<_$ContentDatabase, Collections> {
  $CollectionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameArabic => $composableBuilder(
    column: $table.nameArabic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEnglish => $composableBuilder(
    column: $table.nameEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $CollectionsOrderingComposer
    extends Composer<_$ContentDatabase, Collections> {
  $CollectionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameArabic => $composableBuilder(
    column: $table.nameArabic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEnglish => $composableBuilder(
    column: $table.nameEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CollectionsAnnotationComposer
    extends Composer<_$ContentDatabase, Collections> {
  $CollectionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameArabic => $composableBuilder(
    column: $table.nameArabic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameEnglish => $composableBuilder(
    column: $table.nameEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $CollectionsTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          Collections,
          CollectionRow,
          $CollectionsFilterComposer,
          $CollectionsOrderingComposer,
          $CollectionsAnnotationComposer,
          $CollectionsCreateCompanionBuilder,
          $CollectionsUpdateCompanionBuilder,
          (
            CollectionRow,
            BaseReferences<_$ContentDatabase, Collections, CollectionRow>,
          ),
          CollectionRow,
          PrefetchHooks Function()
        > {
  $CollectionsTableManager(_$ContentDatabase db, Collections table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CollectionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CollectionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CollectionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nameArabic = const Value.absent(),
                Value<String> nameEnglish = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                nameArabic: nameArabic,
                nameEnglish: nameEnglish,
                description: description,
                author: author,
                type: type,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nameArabic,
                required String nameEnglish,
                Value<String?> description = const Value.absent(),
                Value<String?> author = const Value.absent(),
                required String type,
                required int sortOrder,
              }) => CollectionsCompanion.insert(
                id: id,
                nameArabic: nameArabic,
                nameEnglish: nameEnglish,
                description: description,
                author: author,
                type: type,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CollectionsProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      Collections,
      CollectionRow,
      $CollectionsFilterComposer,
      $CollectionsOrderingComposer,
      $CollectionsAnnotationComposer,
      $CollectionsCreateCompanionBuilder,
      $CollectionsUpdateCompanionBuilder,
      (
        CollectionRow,
        BaseReferences<_$ContentDatabase, Collections, CollectionRow>,
      ),
      CollectionRow,
      PrefetchHooks Function()
    >;
typedef $CollectionItemsCreateCompanionBuilder =
    CollectionItemsCompanion Function({
      Value<int> id,
      required int collectionId,
      required String itemType,
      required int itemId,
      required int position,
      Value<int?> countOverride,
      Value<int?> repeatGroup,
      Value<int?> repeatGroupCount,
      Value<String?> note,
    });
typedef $CollectionItemsUpdateCompanionBuilder =
    CollectionItemsCompanion Function({
      Value<int> id,
      Value<int> collectionId,
      Value<String> itemType,
      Value<int> itemId,
      Value<int> position,
      Value<int?> countOverride,
      Value<int?> repeatGroup,
      Value<int?> repeatGroupCount,
      Value<String?> note,
    });

class $CollectionItemsFilterComposer
    extends Composer<_$ContentDatabase, CollectionItems> {
  $CollectionItemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countOverride => $composableBuilder(
    column: $table.countOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatGroup => $composableBuilder(
    column: $table.repeatGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatGroupCount => $composableBuilder(
    column: $table.repeatGroupCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $CollectionItemsOrderingComposer
    extends Composer<_$ContentDatabase, CollectionItems> {
  $CollectionItemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countOverride => $composableBuilder(
    column: $table.countOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatGroup => $composableBuilder(
    column: $table.repeatGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatGroupCount => $composableBuilder(
    column: $table.repeatGroupCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CollectionItemsAnnotationComposer
    extends Composer<_$ContentDatabase, CollectionItems> {
  $CollectionItemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<int> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get countOverride => $composableBuilder(
    column: $table.countOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatGroup => $composableBuilder(
    column: $table.repeatGroup,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatGroupCount => $composableBuilder(
    column: $table.repeatGroupCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $CollectionItemsTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          CollectionItems,
          CollectionItemRow,
          $CollectionItemsFilterComposer,
          $CollectionItemsOrderingComposer,
          $CollectionItemsAnnotationComposer,
          $CollectionItemsCreateCompanionBuilder,
          $CollectionItemsUpdateCompanionBuilder,
          (
            CollectionItemRow,
            BaseReferences<
              _$ContentDatabase,
              CollectionItems,
              CollectionItemRow
            >,
          ),
          CollectionItemRow,
          PrefetchHooks Function()
        > {
  $CollectionItemsTableManager(_$ContentDatabase db, CollectionItems table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CollectionItemsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CollectionItemsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CollectionItemsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> collectionId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> countOverride = const Value.absent(),
                Value<int?> repeatGroup = const Value.absent(),
                Value<int?> repeatGroupCount = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => CollectionItemsCompanion(
                id: id,
                collectionId: collectionId,
                itemType: itemType,
                itemId: itemId,
                position: position,
                countOverride: countOverride,
                repeatGroup: repeatGroup,
                repeatGroupCount: repeatGroupCount,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int collectionId,
                required String itemType,
                required int itemId,
                required int position,
                Value<int?> countOverride = const Value.absent(),
                Value<int?> repeatGroup = const Value.absent(),
                Value<int?> repeatGroupCount = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => CollectionItemsCompanion.insert(
                id: id,
                collectionId: collectionId,
                itemType: itemType,
                itemId: itemId,
                position: position,
                countOverride: countOverride,
                repeatGroup: repeatGroup,
                repeatGroupCount: repeatGroupCount,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CollectionItemsProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      CollectionItems,
      CollectionItemRow,
      $CollectionItemsFilterComposer,
      $CollectionItemsOrderingComposer,
      $CollectionItemsAnnotationComposer,
      $CollectionItemsCreateCompanionBuilder,
      $CollectionItemsUpdateCompanionBuilder,
      (
        CollectionItemRow,
        BaseReferences<_$ContentDatabase, CollectionItems, CollectionItemRow>,
      ),
      CollectionItemRow,
      PrefetchHooks Function()
    >;
typedef $MetaCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $MetaUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $MetaFilterComposer extends Composer<_$ContentDatabase, Meta> {
  $MetaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $MetaOrderingComposer extends Composer<_$ContentDatabase, Meta> {
  $MetaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MetaAnnotationComposer extends Composer<_$ContentDatabase, Meta> {
  $MetaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $MetaTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          Meta,
          MetaRow,
          $MetaFilterComposer,
          $MetaOrderingComposer,
          $MetaAnnotationComposer,
          $MetaCreateCompanionBuilder,
          $MetaUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$ContentDatabase, Meta, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $MetaTableManager(_$ContentDatabase db, Meta table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MetaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MetaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MetaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MetaProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      Meta,
      MetaRow,
      $MetaFilterComposer,
      $MetaOrderingComposer,
      $MetaAnnotationComposer,
      $MetaCreateCompanionBuilder,
      $MetaUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$ContentDatabase, Meta, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $ContentDatabaseManager {
  final _$ContentDatabase _db;
  $ContentDatabaseManager(this._db);
  $SurahsTableManager get surahs => $SurahsTableManager(_db, _db.surahs);
  $AyahsTableManager get ayahs => $AyahsTableManager(_db, _db.ayahs);
  $AdhkarTableManager get adhkar => $AdhkarTableManager(_db, _db.adhkar);
  $SourcesTableManager get sources => $SourcesTableManager(_db, _db.sources);
  $CollectionsTableManager get collections =>
      $CollectionsTableManager(_db, _db.collections);
  $CollectionItemsTableManager get collectionItems =>
      $CollectionItemsTableManager(_db, _db.collectionItems);
  $MetaTableManager get meta => $MetaTableManager(_db, _db.meta);
}
