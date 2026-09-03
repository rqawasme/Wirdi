// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_database.dart';

// ignore_for_file: type=lint
class UserCollections extends Table
    with TableInfo<UserCollections, UserCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UserCollections(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserCollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  UserCollections createAlias(String alias) {
    return UserCollections(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class UserCollectionRow extends DataClass
    implements Insertable<UserCollectionRow> {
  final String id;
  final String name;
  final String? description;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const UserCollectionRow({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  factory UserCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCollectionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'sort_order': serializer.toJson<int>(sortOrder),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
    };
  }

  UserCollectionRow copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => UserCollectionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  UserCollectionRow copyWithCompanion(UserCollectionsCompanion data) {
    return UserCollectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCollectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class UserCollectionsCompanion extends UpdateCompanion<UserCollectionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const UserCollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCollectionsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserCollectionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return UserCollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UserCollectionItems extends Table
    with TableInfo<UserCollectionItems, UserCollectionItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UserCollectionItems(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES user_collections(id)',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
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
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCollectionItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserCollectionItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCollectionItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  UserCollectionItems createAlias(String alias) {
    return UserCollectionItems(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class UserCollectionItemRow extends DataClass
    implements Insertable<UserCollectionItemRow> {
  final String id;
  final String collectionId;

  /// 'dhikr' | 'ayah' | 'surah', referencing content.db by item_id.
  final String itemType;
  final int itemId;
  final int position;
  final int? countOverride;
  final int? repeatGroup;
  final int? repeatGroupCount;

  /// A rubric shown with this item, mirroring collection_items.note. A user
  /// collection copied from a built-in keeps the built-in's notes.
  final String? note;
  final int updatedAt;
  const UserCollectionItemRow({
    required this.id,
    required this.collectionId,
    required this.itemType,
    required this.itemId,
    required this.position,
    this.countOverride,
    this.repeatGroup,
    this.repeatGroupCount,
    this.note,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['collection_id'] = Variable<String>(collectionId);
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
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  factory UserCollectionItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCollectionItemRow(
      id: serializer.fromJson<String>(json['id']),
      collectionId: serializer.fromJson<String>(json['collection_id']),
      itemType: serializer.fromJson<String>(json['item_type']),
      itemId: serializer.fromJson<int>(json['item_id']),
      position: serializer.fromJson<int>(json['position']),
      countOverride: serializer.fromJson<int?>(json['count_override']),
      repeatGroup: serializer.fromJson<int?>(json['repeat_group']),
      repeatGroupCount: serializer.fromJson<int?>(json['repeat_group_count']),
      note: serializer.fromJson<String?>(json['note']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collection_id': serializer.toJson<String>(collectionId),
      'item_type': serializer.toJson<String>(itemType),
      'item_id': serializer.toJson<int>(itemId),
      'position': serializer.toJson<int>(position),
      'count_override': serializer.toJson<int?>(countOverride),
      'repeat_group': serializer.toJson<int?>(repeatGroup),
      'repeat_group_count': serializer.toJson<int?>(repeatGroupCount),
      'note': serializer.toJson<String?>(note),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  UserCollectionItemRow copyWith({
    String? id,
    String? collectionId,
    String? itemType,
    int? itemId,
    int? position,
    Value<int?> countOverride = const Value.absent(),
    Value<int?> repeatGroup = const Value.absent(),
    Value<int?> repeatGroupCount = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? updatedAt,
  }) => UserCollectionItemRow(
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
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserCollectionItemRow copyWithCompanion(UserCollectionItemsCompanion data) {
    return UserCollectionItemRow(
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
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionItemRow(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('countOverride: $countOverride, ')
          ..write('repeatGroup: $repeatGroup, ')
          ..write('repeatGroupCount: $repeatGroupCount, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt')
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
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCollectionItemRow &&
          other.id == this.id &&
          other.collectionId == this.collectionId &&
          other.itemType == this.itemType &&
          other.itemId == this.itemId &&
          other.position == this.position &&
          other.countOverride == this.countOverride &&
          other.repeatGroup == this.repeatGroup &&
          other.repeatGroupCount == this.repeatGroupCount &&
          other.note == this.note &&
          other.updatedAt == this.updatedAt);
}

class UserCollectionItemsCompanion
    extends UpdateCompanion<UserCollectionItemRow> {
  final Value<String> id;
  final Value<String> collectionId;
  final Value<String> itemType;
  final Value<int> itemId;
  final Value<int> position;
  final Value<int?> countOverride;
  final Value<int?> repeatGroup;
  final Value<int?> repeatGroupCount;
  final Value<String?> note;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UserCollectionItemsCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
    this.countOverride = const Value.absent(),
    this.repeatGroup = const Value.absent(),
    this.repeatGroupCount = const Value.absent(),
    this.note = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCollectionItemsCompanion.insert({
    required String id,
    required String collectionId,
    required String itemType,
    required int itemId,
    required int position,
    this.countOverride = const Value.absent(),
    this.repeatGroup = const Value.absent(),
    this.repeatGroupCount = const Value.absent(),
    this.note = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       collectionId = Value(collectionId),
       itemType = Value(itemType),
       itemId = Value(itemId),
       position = Value(position),
       updatedAt = Value(updatedAt);
  static Insertable<UserCollectionItemRow> custom({
    Expression<String>? id,
    Expression<String>? collectionId,
    Expression<String>? itemType,
    Expression<int>? itemId,
    Expression<int>? position,
    Expression<int>? countOverride,
    Expression<int>? repeatGroup,
    Expression<int>? repeatGroupCount,
    Expression<String>? note,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
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
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCollectionItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? collectionId,
    Value<String>? itemType,
    Value<int>? itemId,
    Value<int>? position,
    Value<int?>? countOverride,
    Value<int?>? repeatGroup,
    Value<int?>? repeatGroupCount,
    Value<String?>? note,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserCollectionItemsCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      countOverride: countOverride ?? this.countOverride,
      repeatGroup: repeatGroup ?? this.repeatGroup,
      repeatGroupCount: repeatGroupCount ?? this.repeatGroupCount,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionItemsCompanion(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('itemType: $itemType, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('countOverride: $countOverride, ')
          ..write('repeatGroup: $repeatGroup, ')
          ..write('repeatGroupCount: $repeatGroupCount, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Progress extends Table with TableInfo<Progress, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Progress(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionRefMeta = const VerificationMeta(
    'collectionRef',
  );
  late final GeneratedColumn<String> collectionRef = GeneratedColumn<String>(
    'collection_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _stepIndexMeta = const VerificationMeta(
    'stepIndex',
  );
  late final GeneratedColumn<int> stepIndex = GeneratedColumn<int>(
    'step_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _stepRefMeta = const VerificationMeta(
    'stepRef',
  );
  late final GeneratedColumn<String> stepRef = GeneratedColumn<String>(
    'step_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _currentCountMeta = const VerificationMeta(
    'currentCount',
  );
  late final GeneratedColumn<int> currentCount = GeneratedColumn<int>(
    'current_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionRef,
    stepIndex,
    stepRef,
    currentCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_ref')) {
      context.handle(
        _collectionRefMeta,
        collectionRef.isAcceptableOrUnknown(
          data['collection_ref']!,
          _collectionRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionRefMeta);
    }
    if (data.containsKey('step_index')) {
      context.handle(
        _stepIndexMeta,
        stepIndex.isAcceptableOrUnknown(data['step_index']!, _stepIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_stepIndexMeta);
    }
    if (data.containsKey('step_ref')) {
      context.handle(
        _stepRefMeta,
        stepRef.isAcceptableOrUnknown(data['step_ref']!, _stepRefMeta),
      );
    } else if (isInserting) {
      context.missing(_stepRefMeta);
    }
    if (data.containsKey('current_count')) {
      context.handle(
        _currentCountMeta,
        currentCount.isAcceptableOrUnknown(
          data['current_count']!,
          _currentCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentCountMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionRef};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      collectionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_ref'],
      )!,
      stepIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step_index'],
      )!,
      stepRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step_ref'],
      )!,
      currentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Progress createAlias(String alias) {
    return Progress(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final String collectionRef;
  final int stepIndex;
  final String stepRef;
  final int currentCount;
  final int updatedAt;
  const ProgressRow({
    required this.collectionRef,
    required this.stepIndex,
    required this.stepRef,
    required this.currentCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_ref'] = Variable<String>(collectionRef);
    map['step_index'] = Variable<int>(stepIndex);
    map['step_ref'] = Variable<String>(stepRef);
    map['current_count'] = Variable<int>(currentCount);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  factory ProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      collectionRef: serializer.fromJson<String>(json['collection_ref']),
      stepIndex: serializer.fromJson<int>(json['step_index']),
      stepRef: serializer.fromJson<String>(json['step_ref']),
      currentCount: serializer.fromJson<int>(json['current_count']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection_ref': serializer.toJson<String>(collectionRef),
      'step_index': serializer.toJson<int>(stepIndex),
      'step_ref': serializer.toJson<String>(stepRef),
      'current_count': serializer.toJson<int>(currentCount),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  ProgressRow copyWith({
    String? collectionRef,
    int? stepIndex,
    String? stepRef,
    int? currentCount,
    int? updatedAt,
  }) => ProgressRow(
    collectionRef: collectionRef ?? this.collectionRef,
    stepIndex: stepIndex ?? this.stepIndex,
    stepRef: stepRef ?? this.stepRef,
    currentCount: currentCount ?? this.currentCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProgressRow copyWithCompanion(ProgressCompanion data) {
    return ProgressRow(
      collectionRef: data.collectionRef.present
          ? data.collectionRef.value
          : this.collectionRef,
      stepIndex: data.stepIndex.present ? data.stepIndex.value : this.stepIndex,
      stepRef: data.stepRef.present ? data.stepRef.value : this.stepRef,
      currentCount: data.currentCount.present
          ? data.currentCount.value
          : this.currentCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('collectionRef: $collectionRef, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('stepRef: $stepRef, ')
          ..write('currentCount: $currentCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(collectionRef, stepIndex, stepRef, currentCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.collectionRef == this.collectionRef &&
          other.stepIndex == this.stepIndex &&
          other.stepRef == this.stepRef &&
          other.currentCount == this.currentCount &&
          other.updatedAt == this.updatedAt);
}

class ProgressCompanion extends UpdateCompanion<ProgressRow> {
  final Value<String> collectionRef;
  final Value<int> stepIndex;
  final Value<String> stepRef;
  final Value<int> currentCount;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ProgressCompanion({
    this.collectionRef = const Value.absent(),
    this.stepIndex = const Value.absent(),
    this.stepRef = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressCompanion.insert({
    required String collectionRef,
    required int stepIndex,
    required String stepRef,
    required int currentCount,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : collectionRef = Value(collectionRef),
       stepIndex = Value(stepIndex),
       stepRef = Value(stepRef),
       currentCount = Value(currentCount),
       updatedAt = Value(updatedAt);
  static Insertable<ProgressRow> custom({
    Expression<String>? collectionRef,
    Expression<int>? stepIndex,
    Expression<String>? stepRef,
    Expression<int>? currentCount,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionRef != null) 'collection_ref': collectionRef,
      if (stepIndex != null) 'step_index': stepIndex,
      if (stepRef != null) 'step_ref': stepRef,
      if (currentCount != null) 'current_count': currentCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressCompanion copyWith({
    Value<String>? collectionRef,
    Value<int>? stepIndex,
    Value<String>? stepRef,
    Value<int>? currentCount,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProgressCompanion(
      collectionRef: collectionRef ?? this.collectionRef,
      stepIndex: stepIndex ?? this.stepIndex,
      stepRef: stepRef ?? this.stepRef,
      currentCount: currentCount ?? this.currentCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionRef.present) {
      map['collection_ref'] = Variable<String>(collectionRef.value);
    }
    if (stepIndex.present) {
      map['step_index'] = Variable<int>(stepIndex.value);
    }
    if (stepRef.present) {
      map['step_ref'] = Variable<String>(stepRef.value);
    }
    if (currentCount.present) {
      map['current_count'] = Variable<int>(currentCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressCompanion(')
          ..write('collectionRef: $collectionRef, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('stepRef: $stepRef, ')
          ..write('currentCount: $currentCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Completions extends Table with TableInfo<Completions, CompletionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Completions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _collectionRefMeta = const VerificationMeta(
    'collectionRef',
  );
  late final GeneratedColumn<String> collectionRef = GeneratedColumn<String>(
    'collection_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionRef,
    dateKey,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('collection_ref')) {
      context.handle(
        _collectionRefMeta,
        collectionRef.isAcceptableOrUnknown(
          data['collection_ref']!,
          _collectionRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionRefMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      collectionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_ref'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  Completions createAlias(String alias) {
    return Completions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CompletionRow extends DataClass implements Insertable<CompletionRow> {
  final String id;
  final String collectionRef;
  final String dateKey;
  final int completedAt;
  const CompletionRow({
    required this.id,
    required this.collectionRef,
    required this.dateKey,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['collection_ref'] = Variable<String>(collectionRef);
    map['date_key'] = Variable<String>(dateKey);
    map['completed_at'] = Variable<int>(completedAt);
    return map;
  }

  factory CompletionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletionRow(
      id: serializer.fromJson<String>(json['id']),
      collectionRef: serializer.fromJson<String>(json['collection_ref']),
      dateKey: serializer.fromJson<String>(json['date_key']),
      completedAt: serializer.fromJson<int>(json['completed_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collection_ref': serializer.toJson<String>(collectionRef),
      'date_key': serializer.toJson<String>(dateKey),
      'completed_at': serializer.toJson<int>(completedAt),
    };
  }

  CompletionRow copyWith({
    String? id,
    String? collectionRef,
    String? dateKey,
    int? completedAt,
  }) => CompletionRow(
    id: id ?? this.id,
    collectionRef: collectionRef ?? this.collectionRef,
    dateKey: dateKey ?? this.dateKey,
    completedAt: completedAt ?? this.completedAt,
  );
  CompletionRow copyWithCompanion(CompletionsCompanion data) {
    return CompletionRow(
      id: data.id.present ? data.id.value : this.id,
      collectionRef: data.collectionRef.present
          ? data.collectionRef.value
          : this.collectionRef,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletionRow(')
          ..write('id: $id, ')
          ..write('collectionRef: $collectionRef, ')
          ..write('dateKey: $dateKey, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, collectionRef, dateKey, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletionRow &&
          other.id == this.id &&
          other.collectionRef == this.collectionRef &&
          other.dateKey == this.dateKey &&
          other.completedAt == this.completedAt);
}

class CompletionsCompanion extends UpdateCompanion<CompletionRow> {
  final Value<String> id;
  final Value<String> collectionRef;
  final Value<String> dateKey;
  final Value<int> completedAt;
  final Value<int> rowid;
  const CompletionsCompanion({
    this.id = const Value.absent(),
    this.collectionRef = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletionsCompanion.insert({
    required String id,
    required String collectionRef,
    required String dateKey,
    required int completedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       collectionRef = Value(collectionRef),
       dateKey = Value(dateKey),
       completedAt = Value(completedAt);
  static Insertable<CompletionRow> custom({
    Expression<String>? id,
    Expression<String>? collectionRef,
    Expression<String>? dateKey,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionRef != null) 'collection_ref': collectionRef,
      if (dateKey != null) 'date_key': dateKey,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletionsCompanion copyWith({
    Value<String>? id,
    Value<String>? collectionRef,
    Value<String>? dateKey,
    Value<int>? completedAt,
    Value<int>? rowid,
  }) {
    return CompletionsCompanion(
      id: id ?? this.id,
      collectionRef: collectionRef ?? this.collectionRef,
      dateKey: dateKey ?? this.dateKey,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (collectionRef.present) {
      map['collection_ref'] = Variable<String>(collectionRef.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('id: $id, ')
          ..write('collectionRef: $collectionRef, ')
          ..write('dateKey: $dateKey, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ReadingPosition extends Table
    with TableInfo<ReadingPosition, ReadingPositionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ReadingPosition(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (id = 1)',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
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
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_position';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingPositionRow> instance, {
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingPositionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingPositionRow(
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  ReadingPosition createAlias(String alias) {
    return ReadingPosition(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ReadingPositionRow extends DataClass
    implements Insertable<ReadingPositionRow> {
  final int id;
  final int surahNumber;
  final int ayahNumber;
  final int updatedAt;
  const ReadingPositionRow({
    required this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['surah_number'] = Variable<int>(surahNumber);
    map['ayah_number'] = Variable<int>(ayahNumber);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  factory ReadingPositionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingPositionRow(
      id: serializer.fromJson<int>(json['id']),
      surahNumber: serializer.fromJson<int>(json['surah_number']),
      ayahNumber: serializer.fromJson<int>(json['ayah_number']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'surah_number': serializer.toJson<int>(surahNumber),
      'ayah_number': serializer.toJson<int>(ayahNumber),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  ReadingPositionRow copyWith({
    int? id,
    int? surahNumber,
    int? ayahNumber,
    int? updatedAt,
  }) => ReadingPositionRow(
    id: id ?? this.id,
    surahNumber: surahNumber ?? this.surahNumber,
    ayahNumber: ayahNumber ?? this.ayahNumber,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingPositionRow copyWithCompanion(ReadingPositionCompanion data) {
    return ReadingPositionRow(
      id: data.id.present ? data.id.value : this.id,
      surahNumber: data.surahNumber.present
          ? data.surahNumber.value
          : this.surahNumber,
      ayahNumber: data.ayahNumber.present
          ? data.ayahNumber.value
          : this.ayahNumber,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPositionRow(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, surahNumber, ayahNumber, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingPositionRow &&
          other.id == this.id &&
          other.surahNumber == this.surahNumber &&
          other.ayahNumber == this.ayahNumber &&
          other.updatedAt == this.updatedAt);
}

class ReadingPositionCompanion extends UpdateCompanion<ReadingPositionRow> {
  final Value<int> id;
  final Value<int> surahNumber;
  final Value<int> ayahNumber;
  final Value<int> updatedAt;
  const ReadingPositionCompanion({
    this.id = const Value.absent(),
    this.surahNumber = const Value.absent(),
    this.ayahNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReadingPositionCompanion.insert({
    this.id = const Value.absent(),
    required int surahNumber,
    required int ayahNumber,
    required int updatedAt,
  }) : surahNumber = Value(surahNumber),
       ayahNumber = Value(ayahNumber),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingPositionRow> custom({
    Expression<int>? id,
    Expression<int>? surahNumber,
    Expression<int>? ayahNumber,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surahNumber != null) 'surah_number': surahNumber,
      if (ayahNumber != null) 'ayah_number': ayahNumber,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReadingPositionCompanion copyWith({
    Value<int>? id,
    Value<int>? surahNumber,
    Value<int>? ayahNumber,
    Value<int>? updatedAt,
  }) {
    return ReadingPositionCompanion(
      id: id ?? this.id,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPositionCompanion(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class Settings extends Table with TableInfo<Settings, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  final int updatedAt;
  const SettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  SettingRow copyWith({String? key, String? value, int? updatedAt}) =>
      SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Commitments extends Table with TableInfo<Commitments, CommitmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Commitments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionRefMeta = const VerificationMeta(
    'collectionRef',
  );
  late final GeneratedColumn<String> collectionRef = GeneratedColumn<String>(
    'collection_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionRef,
    section,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commitments';
  @override
  VerificationContext validateIntegrity(
    Insertable<CommitmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_ref')) {
      context.handle(
        _collectionRefMeta,
        collectionRef.isAcceptableOrUnknown(
          data['collection_ref']!,
          _collectionRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionRefMeta);
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionRef};
  @override
  CommitmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommitmentRow(
      collectionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_ref'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Commitments createAlias(String alias) {
    return Commitments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CommitmentRow extends DataClass implements Insertable<CommitmentRow> {
  final String collectionRef;
  final String section;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  const CommitmentRow({
    required this.collectionRef,
    required this.section,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_ref'] = Variable<String>(collectionRef);
    map['section'] = Variable<String>(section);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  factory CommitmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommitmentRow(
      collectionRef: serializer.fromJson<String>(json['collection_ref']),
      section: serializer.fromJson<String>(json['section']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection_ref': serializer.toJson<String>(collectionRef),
      'section': serializer.toJson<String>(section),
      'sort_order': serializer.toJson<int>(sortOrder),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  CommitmentRow copyWith({
    String? collectionRef,
    String? section,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => CommitmentRow(
    collectionRef: collectionRef ?? this.collectionRef,
    section: section ?? this.section,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CommitmentRow copyWithCompanion(CommitmentsCompanion data) {
    return CommitmentRow(
      collectionRef: data.collectionRef.present
          ? data.collectionRef.value
          : this.collectionRef,
      section: data.section.present ? data.section.value : this.section,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentRow(')
          ..write('collectionRef: $collectionRef, ')
          ..write('section: $section, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(collectionRef, section, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommitmentRow &&
          other.collectionRef == this.collectionRef &&
          other.section == this.section &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CommitmentsCompanion extends UpdateCompanion<CommitmentRow> {
  final Value<String> collectionRef;
  final Value<String> section;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CommitmentsCompanion({
    this.collectionRef = const Value.absent(),
    this.section = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommitmentsCompanion.insert({
    required String collectionRef,
    required String section,
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : collectionRef = Value(collectionRef),
       section = Value(section),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CommitmentRow> custom({
    Expression<String>? collectionRef,
    Expression<String>? section,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionRef != null) 'collection_ref': collectionRef,
      if (section != null) 'section': section,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommitmentsCompanion copyWith({
    Value<String>? collectionRef,
    Value<String>? section,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CommitmentsCompanion(
      collectionRef: collectionRef ?? this.collectionRef,
      section: section ?? this.section,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionRef.present) {
      map['collection_ref'] = Variable<String>(collectionRef.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentsCompanion(')
          ..write('collectionRef: $collectionRef, ')
          ..write('section: $section, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$UserDatabase extends GeneratedDatabase {
  _$UserDatabase(QueryExecutor e) : super(e);
  $UserDatabaseManager get managers => $UserDatabaseManager(this);
  late final UserCollections userCollections = UserCollections(this);
  late final UserCollectionItems userCollectionItems = UserCollectionItems(
    this,
  );
  late final Index idxUserCollectionItemsPosition = Index(
    'idx_user_collection_items_position',
    'CREATE INDEX idx_user_collection_items_position ON user_collection_items (collection_id, position)',
  );
  late final Progress progress = Progress(this);
  late final Completions completions = Completions(this);
  late final Index idxCompletionsRefDate = Index(
    'idx_completions_ref_date',
    'CREATE UNIQUE INDEX idx_completions_ref_date ON completions (collection_ref, date_key)',
  );
  late final Index idxCompletionsDate = Index(
    'idx_completions_date',
    'CREATE INDEX idx_completions_date ON completions (date_key)',
  );
  late final ReadingPosition readingPosition = ReadingPosition(this);
  late final Settings settings = Settings(this);
  late final Commitments commitments = Commitments(this);
  late final Index idxCommitmentsSection = Index(
    'idx_commitments_section',
    'CREATE INDEX idx_commitments_section ON commitments (section, sort_order)',
  );
  Selectable<UserCollectionRow> activeUserCollections() {
    return customSelect(
      'SELECT * FROM user_collections WHERE deleted_at IS NULL ORDER BY sort_order, created_at, id',
      variables: [],
      readsFrom: {userCollections},
    ).asyncMap(userCollections.mapFromRow);
  }

  Selectable<UserCollectionRow> activeUserCollection({required String id}) {
    return customSelect(
      'SELECT * FROM user_collections WHERE id = ?1 AND deleted_at IS NULL',
      variables: [Variable<String>(id)],
      readsFrom: {userCollections},
    ).asyncMap(userCollections.mapFromRow);
  }

  Selectable<int> nextUserCollectionSortOrder() {
    return customSelect(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 AS v FROM user_collections',
      variables: [],
      readsFrom: {userCollections},
    ).map((QueryRow row) => row.read<int>('v'));
  }

  Future<int> insertUserCollection({
    required String id,
    required String name,
    String? description,
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
  }) {
    return customInsert(
      'INSERT INTO user_collections (id, name, description, sort_order, created_at, updated_at, deleted_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, NULL)',
      variables: [
        Variable<String>(id),
        Variable<String>(name),
        Variable<String>(description),
        Variable<int>(sortOrder),
        Variable<int>(createdAt),
        Variable<int>(updatedAt),
      ],
      updates: {userCollections},
    );
  }

  Future<int> renameUserCollection({
    required String name,
    required int updatedAt,
    required String id,
  }) {
    return customUpdate(
      'UPDATE user_collections SET name = ?1, updated_at = ?2 WHERE id = ?3 AND deleted_at IS NULL',
      variables: [
        Variable<String>(name),
        Variable<int>(updatedAt),
        Variable<String>(id),
      ],
      updates: {userCollections},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> softDeleteUserCollection({int? deletedAt, required String id}) {
    return customUpdate(
      'UPDATE user_collections SET deleted_at = ?1, updated_at = ?1 WHERE id = ?2 AND deleted_at IS NULL',
      variables: [Variable<int>(deletedAt), Variable<String>(id)],
      updates: {userCollections},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<UserCollectionItemRow> itemsForUserCollection({
    required String collection,
  }) {
    return customSelect(
      'SELECT * FROM user_collection_items WHERE collection_id = ?1 ORDER BY position',
      variables: [Variable<String>(collection)],
      readsFrom: {userCollectionItems},
    ).asyncMap(userCollectionItems.mapFromRow);
  }

  Selectable<int> nextItemPosition({required String collection}) {
    return customSelect(
      'SELECT COALESCE(MAX(position), 0) + 1 AS v FROM user_collection_items WHERE collection_id = ?1',
      variables: [Variable<String>(collection)],
      readsFrom: {userCollectionItems},
    ).map((QueryRow row) => row.read<int>('v'));
  }

  Future<int> insertUserCollectionItem({
    required String id,
    required String collection,
    required String itemType,
    required int itemId,
    required int position,
    int? countOverride,
    int? repeatGroup,
    int? repeatGroupCount,
    String? note,
    required int updatedAt,
  }) {
    return customInsert(
      'INSERT INTO user_collection_items (id, collection_id, item_type, item_id, position, count_override, repeat_group, repeat_group_count, note, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)',
      variables: [
        Variable<String>(id),
        Variable<String>(collection),
        Variable<String>(itemType),
        Variable<int>(itemId),
        Variable<int>(position),
        Variable<int>(countOverride),
        Variable<int>(repeatGroup),
        Variable<int>(repeatGroupCount),
        Variable<String>(note),
        Variable<int>(updatedAt),
      ],
      updates: {userCollectionItems},
    );
  }

  Future<int> deleteUserCollectionItem({
    required String id,
    required String collection,
  }) {
    return customUpdate(
      'DELETE FROM user_collection_items WHERE id = ?1 AND collection_id = ?2',
      variables: [Variable<String>(id), Variable<String>(collection)],
      updates: {userCollectionItems},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> setItemPosition({
    required int position,
    required int updatedAt,
    required String id,
    required String collection,
  }) {
    return customUpdate(
      'UPDATE user_collection_items SET position = ?1, updated_at = ?2 WHERE id = ?3 AND collection_id = ?4',
      variables: [
        Variable<int>(position),
        Variable<int>(updatedAt),
        Variable<String>(id),
        Variable<String>(collection),
      ],
      updates: {userCollectionItems},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<int> nextRepeatGroup({required String collection}) {
    return customSelect(
      'SELECT COALESCE(MAX(repeat_group), 0) + 1 AS v FROM user_collection_items WHERE collection_id = ?1',
      variables: [Variable<String>(collection)],
      readsFrom: {userCollectionItems},
    ).map((QueryRow row) => row.read<int>('v'));
  }

  Future<int> setItemRepeatGroup({
    int? group,
    int? count,
    required int updatedAt,
    required String id,
    required String collection,
  }) {
    return customUpdate(
      'UPDATE user_collection_items SET repeat_group = ?1, repeat_group_count = ?2, updated_at = ?3 WHERE id = ?4 AND collection_id = ?5',
      variables: [
        Variable<int>(group),
        Variable<int>(count),
        Variable<int>(updatedAt),
        Variable<String>(id),
        Variable<String>(collection),
      ],
      updates: {userCollectionItems},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> clearItemsRepeatGroup({
    required int updatedAt,
    required String collection,
    int? group,
  }) {
    return customUpdate(
      'UPDATE user_collection_items SET repeat_group = NULL, repeat_group_count = NULL, updated_at = ?1 WHERE collection_id = ?2 AND repeat_group = ?3',
      variables: [
        Variable<int>(updatedAt),
        Variable<String>(collection),
        Variable<int>(group),
      ],
      updates: {userCollectionItems},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<ProgressRow> progressFor({required String ref}) {
    return customSelect(
      'SELECT * FROM progress WHERE collection_ref = ?1',
      variables: [Variable<String>(ref)],
      readsFrom: {progress},
    ).asyncMap(progress.mapFromRow);
  }

  Future<int> upsertProgress({
    required String ref,
    required int stepIndex,
    required String stepRef,
    required int currentCount,
    required int updatedAt,
  }) {
    return customInsert(
      'INSERT INTO progress (collection_ref, step_index, step_ref, current_count, updated_at) VALUES (?1, ?2, ?3, ?4, ?5) ON CONFLICT (collection_ref) DO UPDATE SET step_index = excluded.step_index, step_ref = excluded.step_ref, current_count = excluded.current_count, updated_at = excluded.updated_at',
      variables: [
        Variable<String>(ref),
        Variable<int>(stepIndex),
        Variable<String>(stepRef),
        Variable<int>(currentCount),
        Variable<int>(updatedAt),
      ],
      updates: {progress},
    );
  }

  Future<int> deleteProgress({required String ref}) {
    return customUpdate(
      'DELETE FROM progress WHERE collection_ref = ?1',
      variables: [Variable<String>(ref)],
      updates: {progress},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> logCompletion({
    required String id,
    required String ref,
    required String dateKey,
    required int completedAt,
  }) {
    return customInsert(
      'INSERT INTO completions (id, collection_ref, date_key, completed_at) VALUES (?1, ?2, ?3, ?4) ON CONFLICT (collection_ref, date_key) DO NOTHING',
      variables: [
        Variable<String>(id),
        Variable<String>(ref),
        Variable<String>(dateKey),
        Variable<int>(completedAt),
      ],
      updates: {completions},
    );
  }

  Selectable<bool> completionExists({
    required String ref,
    required String dateKey,
  }) {
    return customSelect(
      'SELECT EXISTS (SELECT 1 AS _c0 FROM completions WHERE collection_ref = ?1 AND date_key = ?2) AS v',
      variables: [Variable<String>(ref), Variable<String>(dateKey)],
      readsFrom: {completions},
    ).map((QueryRow row) => row.read<bool>('v'));
  }

  Selectable<String> completionDatesBetween({
    required String from,
    required String to,
  }) {
    return customSelect(
      'SELECT DISTINCT date_key FROM completions WHERE date_key >= ?1 AND date_key <= ?2 ORDER BY date_key',
      variables: [Variable<String>(from), Variable<String>(to)],
      readsFrom: {completions},
    ).map((QueryRow row) => row.read<String>('date_key'));
  }

  Selectable<String> completionDatesDescending() {
    return customSelect(
      'SELECT DISTINCT date_key FROM completions ORDER BY date_key DESC',
      variables: [],
      readsFrom: {completions},
    ).map((QueryRow row) => row.read<String>('date_key'));
  }

  Selectable<ReadingPositionRow> currentReadingPosition() {
    return customSelect(
      'SELECT * FROM reading_position WHERE id = 1',
      variables: [],
      readsFrom: {readingPosition},
    ).asyncMap(readingPosition.mapFromRow);
  }

  Future<int> upsertReadingPosition({
    required int surahNumber,
    required int ayahNumber,
    required int updatedAt,
  }) {
    return customInsert(
      'INSERT INTO reading_position (id, surah_number, ayah_number, updated_at) VALUES (1, ?1, ?2, ?3) ON CONFLICT (id) DO UPDATE SET surah_number = excluded.surah_number, ayah_number = excluded.ayah_number, updated_at = excluded.updated_at',
      variables: [
        Variable<int>(surahNumber),
        Variable<int>(ayahNumber),
        Variable<int>(updatedAt),
      ],
      updates: {readingPosition},
    );
  }

  Selectable<String> settingValue({required String key}) {
    return customSelect(
      'SELECT value FROM settings WHERE "key" = ?1',
      variables: [Variable<String>(key)],
      readsFrom: {settings},
    ).map((QueryRow row) => row.read<String>('value'));
  }

  Future<int> upsertSetting({
    required String key,
    required String value,
    required int updatedAt,
  }) {
    return customInsert(
      'INSERT INTO settings ("key", value, updated_at) VALUES (?1, ?2, ?3) ON CONFLICT ("key") DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
      variables: [
        Variable<String>(key),
        Variable<String>(value),
        Variable<int>(updatedAt),
      ],
      updates: {settings},
    );
  }

  Selectable<CommitmentRow> allCommitments() {
    return customSelect(
      'SELECT * FROM commitments ORDER BY sort_order, created_at, collection_ref',
      variables: [],
      readsFrom: {commitments},
    ).asyncMap(commitments.mapFromRow);
  }

  Selectable<int> nextCommitmentSortOrder() {
    return customSelect(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 AS v FROM commitments',
      variables: [],
      readsFrom: {commitments},
    ).map((QueryRow row) => row.read<int>('v'));
  }

  Future<int> upsertCommitment({
    required String ref,
    required String section,
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
  }) {
    return customInsert(
      'INSERT INTO commitments (collection_ref, section, sort_order, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5) ON CONFLICT (collection_ref) DO UPDATE SET section = excluded.section, updated_at = excluded.updated_at',
      variables: [
        Variable<String>(ref),
        Variable<String>(section),
        Variable<int>(sortOrder),
        Variable<int>(createdAt),
        Variable<int>(updatedAt),
      ],
      updates: {commitments},
    );
  }

  Future<int> deleteCommitment({required String ref}) {
    return customUpdate(
      'DELETE FROM commitments WHERE collection_ref = ?1',
      variables: [Variable<String>(ref)],
      updates: {commitments},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userCollections,
    userCollectionItems,
    idxUserCollectionItemsPosition,
    progress,
    completions,
    idxCompletionsRefDate,
    idxCompletionsDate,
    readingPosition,
    settings,
    commitments,
    idxCommitmentsSection,
  ];
}

typedef $UserCollectionsCreateCompanionBuilder =
    UserCollectionsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required int sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $UserCollectionsUpdateCompanionBuilder =
    UserCollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

final class $UserCollectionsReferences
    extends BaseReferences<_$UserDatabase, UserCollections, UserCollectionRow> {
  $UserCollectionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<UserCollectionItems, List<UserCollectionItemRow>>
  _userCollectionItemsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.userCollectionItems,
        aliasName: 'user_collections__id__user_collection_items__collection_id',
      );

  $UserCollectionItemsProcessedTableManager get userCollectionItemsRefs {
    final manager = $UserCollectionItemsTableManager(
      $_db,
      $_db.userCollectionItems,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _userCollectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $UserCollectionsFilterComposer
    extends Composer<_$UserDatabase, UserCollections> {
  $UserCollectionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> userCollectionItemsRefs(
    Expression<bool> Function($UserCollectionItemsFilterComposer f) f,
  ) {
    final $UserCollectionItemsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCollectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserCollectionItemsFilterComposer(
            $db: $db,
            $table: $db.userCollectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $UserCollectionsOrderingComposer
    extends Composer<_$UserDatabase, UserCollections> {
  $UserCollectionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UserCollectionsAnnotationComposer
    extends Composer<_$UserDatabase, UserCollections> {
  $UserCollectionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> userCollectionItemsRefs<T extends Object>(
    Expression<T> Function($UserCollectionItemsAnnotationComposer a) f,
  ) {
    final $UserCollectionItemsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCollectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserCollectionItemsAnnotationComposer(
            $db: $db,
            $table: $db.userCollectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $UserCollectionsTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          UserCollections,
          UserCollectionRow,
          $UserCollectionsFilterComposer,
          $UserCollectionsOrderingComposer,
          $UserCollectionsAnnotationComposer,
          $UserCollectionsCreateCompanionBuilder,
          $UserCollectionsUpdateCompanionBuilder,
          (UserCollectionRow, $UserCollectionsReferences),
          UserCollectionRow,
          PrefetchHooks Function({bool userCollectionItemsRefs})
        > {
  $UserCollectionsTableManager(_$UserDatabase db, UserCollections table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UserCollectionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UserCollectionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UserCollectionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCollectionsCompanion(
                id: id,
                name: name,
                description: description,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required int sortOrder,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCollectionsCompanion.insert(
                id: id,
                name: name,
                description: description,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $UserCollectionsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userCollectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (userCollectionItemsRefs) db.userCollectionItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (userCollectionItemsRefs)
                    await $_getPrefetchedData<
                      UserCollectionRow,
                      UserCollections,
                      UserCollectionItemRow
                    >(
                      currentTable: table,
                      referencedTable: $UserCollectionsReferences
                          ._userCollectionItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $UserCollectionsReferences(
                            db,
                            table,
                            p0,
                          ).userCollectionItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $UserCollectionsProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      UserCollections,
      UserCollectionRow,
      $UserCollectionsFilterComposer,
      $UserCollectionsOrderingComposer,
      $UserCollectionsAnnotationComposer,
      $UserCollectionsCreateCompanionBuilder,
      $UserCollectionsUpdateCompanionBuilder,
      (UserCollectionRow, $UserCollectionsReferences),
      UserCollectionRow,
      PrefetchHooks Function({bool userCollectionItemsRefs})
    >;
typedef $UserCollectionItemsCreateCompanionBuilder =
    UserCollectionItemsCompanion Function({
      required String id,
      required String collectionId,
      required String itemType,
      required int itemId,
      required int position,
      Value<int?> countOverride,
      Value<int?> repeatGroup,
      Value<int?> repeatGroupCount,
      Value<String?> note,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $UserCollectionItemsUpdateCompanionBuilder =
    UserCollectionItemsCompanion Function({
      Value<String> id,
      Value<String> collectionId,
      Value<String> itemType,
      Value<int> itemId,
      Value<int> position,
      Value<int?> countOverride,
      Value<int?> repeatGroup,
      Value<int?> repeatGroupCount,
      Value<String?> note,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $UserCollectionItemsReferences
    extends
        BaseReferences<
          _$UserDatabase,
          UserCollectionItems,
          UserCollectionItemRow
        > {
  $UserCollectionItemsReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static UserCollections _collectionIdTable(_$UserDatabase db) =>
      db.userCollections.createAlias(
        'user_collection_items__collection_id__user_collections__id',
      );

  $UserCollectionsProcessedTableManager get collectionId {
    final $_column = $_itemColumn<String>('collection_id')!;

    final manager = $UserCollectionsTableManager(
      $_db,
      $_db.userCollections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $UserCollectionItemsFilterComposer
    extends Composer<_$UserDatabase, UserCollectionItems> {
  $UserCollectionItemsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
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

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $UserCollectionsFilterComposer get collectionId {
    final $UserCollectionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.userCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserCollectionsFilterComposer(
            $db: $db,
            $table: $db.userCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $UserCollectionItemsOrderingComposer
    extends Composer<_$UserDatabase, UserCollectionItems> {
  $UserCollectionItemsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
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

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $UserCollectionsOrderingComposer get collectionId {
    final $UserCollectionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.userCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserCollectionsOrderingComposer(
            $db: $db,
            $table: $db.userCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $UserCollectionItemsAnnotationComposer
    extends Composer<_$UserDatabase, UserCollectionItems> {
  $UserCollectionItemsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $UserCollectionsAnnotationComposer get collectionId {
    final $UserCollectionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.userCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserCollectionsAnnotationComposer(
            $db: $db,
            $table: $db.userCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $UserCollectionItemsTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          UserCollectionItems,
          UserCollectionItemRow,
          $UserCollectionItemsFilterComposer,
          $UserCollectionItemsOrderingComposer,
          $UserCollectionItemsAnnotationComposer,
          $UserCollectionItemsCreateCompanionBuilder,
          $UserCollectionItemsUpdateCompanionBuilder,
          (UserCollectionItemRow, $UserCollectionItemsReferences),
          UserCollectionItemRow,
          PrefetchHooks Function({bool collectionId})
        > {
  $UserCollectionItemsTableManager(_$UserDatabase db, UserCollectionItems table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UserCollectionItemsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UserCollectionItemsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UserCollectionItemsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> collectionId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> countOverride = const Value.absent(),
                Value<int?> repeatGroup = const Value.absent(),
                Value<int?> repeatGroupCount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCollectionItemsCompanion(
                id: id,
                collectionId: collectionId,
                itemType: itemType,
                itemId: itemId,
                position: position,
                countOverride: countOverride,
                repeatGroup: repeatGroup,
                repeatGroupCount: repeatGroupCount,
                note: note,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String collectionId,
                required String itemType,
                required int itemId,
                required int position,
                Value<int?> countOverride = const Value.absent(),
                Value<int?> repeatGroup = const Value.absent(),
                Value<int?> repeatGroupCount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserCollectionItemsCompanion.insert(
                id: id,
                collectionId: collectionId,
                itemType: itemType,
                itemId: itemId,
                position: position,
                countOverride: countOverride,
                repeatGroup: repeatGroup,
                repeatGroupCount: repeatGroupCount,
                note: note,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $UserCollectionItemsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (collectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.collectionId,
                                referencedTable: $UserCollectionItemsReferences
                                    ._collectionIdTable(db),
                                referencedColumn: $UserCollectionItemsReferences
                                    ._collectionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $UserCollectionItemsProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      UserCollectionItems,
      UserCollectionItemRow,
      $UserCollectionItemsFilterComposer,
      $UserCollectionItemsOrderingComposer,
      $UserCollectionItemsAnnotationComposer,
      $UserCollectionItemsCreateCompanionBuilder,
      $UserCollectionItemsUpdateCompanionBuilder,
      (UserCollectionItemRow, $UserCollectionItemsReferences),
      UserCollectionItemRow,
      PrefetchHooks Function({bool collectionId})
    >;
typedef $ProgressCreateCompanionBuilder =
    ProgressCompanion Function({
      required String collectionRef,
      required int stepIndex,
      required String stepRef,
      required int currentCount,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $ProgressUpdateCompanionBuilder =
    ProgressCompanion Function({
      Value<String> collectionRef,
      Value<int> stepIndex,
      Value<String> stepRef,
      Value<int> currentCount,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $ProgressFilterComposer extends Composer<_$UserDatabase, Progress> {
  $ProgressFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stepIndex => $composableBuilder(
    column: $table.stepIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepRef => $composableBuilder(
    column: $table.stepRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $ProgressOrderingComposer extends Composer<_$UserDatabase, Progress> {
  $ProgressOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stepIndex => $composableBuilder(
    column: $table.stepIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepRef => $composableBuilder(
    column: $table.stepRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProgressAnnotationComposer extends Composer<_$UserDatabase, Progress> {
  $ProgressAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stepIndex =>
      $composableBuilder(column: $table.stepIndex, builder: (column) => column);

  GeneratedColumn<String> get stepRef =>
      $composableBuilder(column: $table.stepRef, builder: (column) => column);

  GeneratedColumn<int> get currentCount => $composableBuilder(
    column: $table.currentCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $ProgressTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          Progress,
          ProgressRow,
          $ProgressFilterComposer,
          $ProgressOrderingComposer,
          $ProgressAnnotationComposer,
          $ProgressCreateCompanionBuilder,
          $ProgressUpdateCompanionBuilder,
          (ProgressRow, BaseReferences<_$UserDatabase, Progress, ProgressRow>),
          ProgressRow,
          PrefetchHooks Function()
        > {
  $ProgressTableManager(_$UserDatabase db, Progress table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProgressFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProgressOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProgressAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collectionRef = const Value.absent(),
                Value<int> stepIndex = const Value.absent(),
                Value<String> stepRef = const Value.absent(),
                Value<int> currentCount = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion(
                collectionRef: collectionRef,
                stepIndex: stepIndex,
                stepRef: stepRef,
                currentCount: currentCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionRef,
                required int stepIndex,
                required String stepRef,
                required int currentCount,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion.insert(
                collectionRef: collectionRef,
                stepIndex: stepIndex,
                stepRef: stepRef,
                currentCount: currentCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ProgressProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      Progress,
      ProgressRow,
      $ProgressFilterComposer,
      $ProgressOrderingComposer,
      $ProgressAnnotationComposer,
      $ProgressCreateCompanionBuilder,
      $ProgressUpdateCompanionBuilder,
      (ProgressRow, BaseReferences<_$UserDatabase, Progress, ProgressRow>),
      ProgressRow,
      PrefetchHooks Function()
    >;
typedef $CompletionsCreateCompanionBuilder =
    CompletionsCompanion Function({
      required String id,
      required String collectionRef,
      required String dateKey,
      required int completedAt,
      Value<int> rowid,
    });
typedef $CompletionsUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<String> id,
      Value<String> collectionRef,
      Value<String> dateKey,
      Value<int> completedAt,
      Value<int> rowid,
    });

class $CompletionsFilterComposer extends Composer<_$UserDatabase, Completions> {
  $CompletionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $CompletionsOrderingComposer
    extends Composer<_$UserDatabase, Completions> {
  $CompletionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CompletionsAnnotationComposer
    extends Composer<_$UserDatabase, Completions> {
  $CompletionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $CompletionsTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          Completions,
          CompletionRow,
          $CompletionsFilterComposer,
          $CompletionsOrderingComposer,
          $CompletionsAnnotationComposer,
          $CompletionsCreateCompanionBuilder,
          $CompletionsUpdateCompanionBuilder,
          (
            CompletionRow,
            BaseReferences<_$UserDatabase, Completions, CompletionRow>,
          ),
          CompletionRow,
          PrefetchHooks Function()
        > {
  $CompletionsTableManager(_$UserDatabase db, Completions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CompletionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CompletionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CompletionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> collectionRef = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion(
                id: id,
                collectionRef: collectionRef,
                dateKey: dateKey,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String collectionRef,
                required String dateKey,
                required int completedAt,
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion.insert(
                id: id,
                collectionRef: collectionRef,
                dateKey: dateKey,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CompletionsProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      Completions,
      CompletionRow,
      $CompletionsFilterComposer,
      $CompletionsOrderingComposer,
      $CompletionsAnnotationComposer,
      $CompletionsCreateCompanionBuilder,
      $CompletionsUpdateCompanionBuilder,
      (
        CompletionRow,
        BaseReferences<_$UserDatabase, Completions, CompletionRow>,
      ),
      CompletionRow,
      PrefetchHooks Function()
    >;
typedef $ReadingPositionCreateCompanionBuilder =
    ReadingPositionCompanion Function({
      Value<int> id,
      required int surahNumber,
      required int ayahNumber,
      required int updatedAt,
    });
typedef $ReadingPositionUpdateCompanionBuilder =
    ReadingPositionCompanion Function({
      Value<int> id,
      Value<int> surahNumber,
      Value<int> ayahNumber,
      Value<int> updatedAt,
    });

class $ReadingPositionFilterComposer
    extends Composer<_$UserDatabase, ReadingPosition> {
  $ReadingPositionFilterComposer({
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

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $ReadingPositionOrderingComposer
    extends Composer<_$UserDatabase, ReadingPosition> {
  $ReadingPositionOrderingComposer({
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

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ReadingPositionAnnotationComposer
    extends Composer<_$UserDatabase, ReadingPosition> {
  $ReadingPositionAnnotationComposer({
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

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $ReadingPositionTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          ReadingPosition,
          ReadingPositionRow,
          $ReadingPositionFilterComposer,
          $ReadingPositionOrderingComposer,
          $ReadingPositionAnnotationComposer,
          $ReadingPositionCreateCompanionBuilder,
          $ReadingPositionUpdateCompanionBuilder,
          (
            ReadingPositionRow,
            BaseReferences<_$UserDatabase, ReadingPosition, ReadingPositionRow>,
          ),
          ReadingPositionRow,
          PrefetchHooks Function()
        > {
  $ReadingPositionTableManager(_$UserDatabase db, ReadingPosition table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ReadingPositionFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ReadingPositionOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ReadingPositionAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> surahNumber = const Value.absent(),
                Value<int> ayahNumber = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ReadingPositionCompanion(
                id: id,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int surahNumber,
                required int ayahNumber,
                required int updatedAt,
              }) => ReadingPositionCompanion.insert(
                id: id,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ReadingPositionProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      ReadingPosition,
      ReadingPositionRow,
      $ReadingPositionFilterComposer,
      $ReadingPositionOrderingComposer,
      $ReadingPositionAnnotationComposer,
      $ReadingPositionCreateCompanionBuilder,
      $ReadingPositionUpdateCompanionBuilder,
      (
        ReadingPositionRow,
        BaseReferences<_$UserDatabase, ReadingPosition, ReadingPositionRow>,
      ),
      ReadingPositionRow,
      PrefetchHooks Function()
    >;
typedef $SettingsCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $SettingsUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $SettingsFilterComposer extends Composer<_$UserDatabase, Settings> {
  $SettingsFilterComposer({
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

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $SettingsOrderingComposer extends Composer<_$UserDatabase, Settings> {
  $SettingsOrderingComposer({
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

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SettingsAnnotationComposer extends Composer<_$UserDatabase, Settings> {
  $SettingsAnnotationComposer({
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

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $SettingsTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          Settings,
          SettingRow,
          $SettingsFilterComposer,
          $SettingsOrderingComposer,
          $SettingsAnnotationComposer,
          $SettingsCreateCompanionBuilder,
          $SettingsUpdateCompanionBuilder,
          (SettingRow, BaseReferences<_$UserDatabase, Settings, SettingRow>),
          SettingRow,
          PrefetchHooks Function()
        > {
  $SettingsTableManager(_$UserDatabase db, Settings table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SettingsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SettingsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SettingsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SettingsProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      Settings,
      SettingRow,
      $SettingsFilterComposer,
      $SettingsOrderingComposer,
      $SettingsAnnotationComposer,
      $SettingsCreateCompanionBuilder,
      $SettingsUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$UserDatabase, Settings, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $CommitmentsCreateCompanionBuilder =
    CommitmentsCompanion Function({
      required String collectionRef,
      required String section,
      required int sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $CommitmentsUpdateCompanionBuilder =
    CommitmentsCompanion Function({
      Value<String> collectionRef,
      Value<String> section,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $CommitmentsFilterComposer extends Composer<_$UserDatabase, Commitments> {
  $CommitmentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $CommitmentsOrderingComposer
    extends Composer<_$UserDatabase, Commitments> {
  $CommitmentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CommitmentsAnnotationComposer
    extends Composer<_$UserDatabase, Commitments> {
  $CommitmentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionRef => $composableBuilder(
    column: $table.collectionRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $CommitmentsTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          Commitments,
          CommitmentRow,
          $CommitmentsFilterComposer,
          $CommitmentsOrderingComposer,
          $CommitmentsAnnotationComposer,
          $CommitmentsCreateCompanionBuilder,
          $CommitmentsUpdateCompanionBuilder,
          (
            CommitmentRow,
            BaseReferences<_$UserDatabase, Commitments, CommitmentRow>,
          ),
          CommitmentRow,
          PrefetchHooks Function()
        > {
  $CommitmentsTableManager(_$UserDatabase db, Commitments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CommitmentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CommitmentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CommitmentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collectionRef = const Value.absent(),
                Value<String> section = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommitmentsCompanion(
                collectionRef: collectionRef,
                section: section,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionRef,
                required String section,
                required int sortOrder,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CommitmentsCompanion.insert(
                collectionRef: collectionRef,
                section: section,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CommitmentsProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      Commitments,
      CommitmentRow,
      $CommitmentsFilterComposer,
      $CommitmentsOrderingComposer,
      $CommitmentsAnnotationComposer,
      $CommitmentsCreateCompanionBuilder,
      $CommitmentsUpdateCompanionBuilder,
      (
        CommitmentRow,
        BaseReferences<_$UserDatabase, Commitments, CommitmentRow>,
      ),
      CommitmentRow,
      PrefetchHooks Function()
    >;

class $UserDatabaseManager {
  final _$UserDatabase _db;
  $UserDatabaseManager(this._db);
  $UserCollectionsTableManager get userCollections =>
      $UserCollectionsTableManager(_db, _db.userCollections);
  $UserCollectionItemsTableManager get userCollectionItems =>
      $UserCollectionItemsTableManager(_db, _db.userCollectionItems);
  $ProgressTableManager get progress =>
      $ProgressTableManager(_db, _db.progress);
  $CompletionsTableManager get completions =>
      $CompletionsTableManager(_db, _db.completions);
  $ReadingPositionTableManager get readingPosition =>
      $ReadingPositionTableManager(_db, _db.readingPosition);
  $SettingsTableManager get settings =>
      $SettingsTableManager(_db, _db.settings);
  $CommitmentsTableManager get commitments =>
      $CommitmentsTableManager(_db, _db.commitments);
}
