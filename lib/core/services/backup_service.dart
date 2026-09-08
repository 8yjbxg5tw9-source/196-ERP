import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/audit/domain/entities/audit_log_entity.dart';
import '../database/database_service.dart';
import '../storage/secure_storage_service.dart';
import 'app_directory_service.dart';
import 'audit_logger_service.dart';

/// Metadata for one archived backup file discovered in the Backups folder.
class BackupArchiveInfo {
  const BackupArchiveInfo({
    required this.fileName,
    required this.path,
    required this.companyId,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String fileName;
  final String path;
  final String companyId;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Encrypted, point-in-time backup/restore boundary.
///
/// A backup is a ZIP archive containing the active SQLite database files and
/// the target company's attachment files, compressed and then encrypted with
/// AES-256-GCM. The on-disk container layout is:
///
/// ```
/// [ 16-byte IV ][ 32-byte SHA-256 of plaintext ][ AES-256-GCM ciphertext ]
/// ```
abstract interface class BackupService {
  /// Backs up [companyId], writing `finai_backup_{companyId}_{timestamp}.enc`.
  Future<File> createBackup(String companyId);

  /// Decrypts, verifies, decompresses, and applies [backupFile] to the local
  /// store without corrupting the active database.
  Future<void> restoreBackup(File backupFile);

  /// Lists available backups, newest first.
  Future<List<BackupArchiveInfo>> listBackups();

  /// Removes a single backup archive by file name.
  Future<void> deleteBackup(String fileName);

  /// Re-validates the embedded SHA-256 digest of [backupFile] without touching
  /// the live database. Returns false for a corrupt or truncated archive.
  Future<bool> verifyBackup(File backupFile);

  /// Keeps only the newest [limit] archives, deleting older ones.
  Future<void> retainLatestBackups(int limit);
}

class BackupServiceImpl implements BackupService {
  BackupServiceImpl({
    required DatabaseService databaseService,
    required SecureStorageService secureStorage,
    required AppDirectoryService directoryService,
    AuditLoggerService? auditLogger,
  })  : _databaseService = databaseService,
        _secureStorage = secureStorage,
        _directoryService = directoryService,
        _auditLogger = auditLogger;

  static const int maxRetainedBackups = 10;
  static const int _ivLength = 16;
  static const int _hashLength = 32;
  static const String _backupPrefix = 'finai_backup_';
  static const String _backupExtension = '.enc';

  final DatabaseService _databaseService;
  final SecureStorageService _secureStorage;
  final AppDirectoryService _directoryService;
  final AuditLoggerService? _auditLogger;

  @override
  Future<File> createBackup(String companyId) async {
    final Directory backupsDir = await _directoryService.backups();

    // Flush the write-ahead log so the main database file is self-contained.
    await _checkpointDatabase();

    final Archive archive = Archive();
    await _addDatabaseFiles(archive);
    await _addAttachmentFiles(archive, companyId);

    final List<int>? encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Backup compression failed.');
    }

    final Uint8List cipherBytes = await _encrypt(Uint8List.fromList(encoded));
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String fileName =
        '$_backupPrefix${_safeSegment(companyId)}_$timestamp$_backupExtension';
    final File output = File(p.join(backupsDir.path, fileName));
    await output.writeAsBytes(cipherBytes, flush: true);

    await retainLatestBackups(maxRetainedBackups);
    await _auditLogger?.logAction(
      action: AuditAction.backupRestore,
      entityName: 'Backup',
      entityId: output.path,
      after: <String, dynamic>{
        'companyId': companyId,
        'fileName': fileName,
        'operation': 'create',
      },
    );
    debugPrint('[BackupService] Created encrypted backup: $fileName');
    return output;
  }

  @override
  Future<void> restoreBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw StateError('The selected backup file does not exist.');
    }

    final bool verified = await verifyBackup(backupFile);
    if (!verified) {
      throw StateError(
        'Backup integrity check failed: the SHA-256 digest does not match.',
      );
    }

    final Uint8List container = await backupFile.readAsBytes();
    final Uint8List ivBytes = container.sublist(0, _ivLength);
    final Uint8List cipherBytes = container.sublist(_ivLength + _hashLength);

    final Uint8List plain = await _decrypt(cipherBytes, ivBytes);

    final Archive archive = ZipDecoder().decodeBytes(plain);
    final Directory extracted = await _extractToTemp(archive);
    try {
      await _swapDatabase(extracted);
      await _restoreAttachments(extracted);
    } finally {
      try {
        await extracted.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup; the OS will reclaim the temp directory later.
      }
    }
    await _auditLogger?.logAction(
      action: AuditAction.backupRestore,
      entityName: 'Backup',
      entityId: backupFile.path,
      after: <String, dynamic>{'operation': 'restore'},
    );
    debugPrint('[BackupService] Restored backup: ${backupFile.path}');
  }

  @override
  Future<List<BackupArchiveInfo>> listBackups() async {
    final Directory backupsDir = await _directoryService.backups();
    final List<BackupArchiveInfo> results = <BackupArchiveInfo>[];
    await for (final FileSystemEntity entity in backupsDir.list()) {
      if (entity is! File) {
        continue;
      }
      final String fileName = p.basename(entity.path);
      final BackupArchiveInfo? info = _parseFileName(
        fileName,
        entity.path,
        await entity.length(),
      );
      if (info != null) {
        results.add(info);
      }
    }
    results.sort(
      (BackupArchiveInfo left, BackupArchiveInfo right) =>
          right.createdAt.compareTo(left.createdAt),
    );
    return results;
  }

  @override
  Future<void> deleteBackup(String fileName) async {
    final Directory backupsDir = await _directoryService.backups();
    final String safeName = p.basename(fileName);
    if (!safeName.startsWith(_backupPrefix) ||
        !safeName.endsWith(_backupExtension)) {
      throw ArgumentError.value(fileName, 'fileName', 'not a backup archive');
    }
    final File target = File(p.join(backupsDir.path, safeName));
    if (await target.exists()) {
      await target.delete();
    }
  }

  @override
  Future<bool> verifyBackup(File backupFile) async {
    try {
      if (!await backupFile.exists()) {
        return false;
      }
      final Uint8List container = await backupFile.readAsBytes();
      if (container.length < _ivLength + _hashLength) {
        return false;
      }
      final Uint8List ivBytes = container.sublist(0, _ivLength);
      final Uint8List storedDigest =
          container.sublist(_ivLength, _ivLength + _hashLength);
      final Uint8List cipherBytes = container.sublist(_ivLength + _hashLength);

      final Uint8List plain = await _decrypt(cipherBytes, ivBytes);
      final Digest computedDigest = sha256.convert(plain);
      return _constantTimeEquals(computedDigest.bytes, storedDigest);
    } on Object {
      return false;
    }
  }

  /// Keeps only the newest [limit] backups, deleting older archives.
  @override
  Future<void> retainLatestBackups(int limit) async {
    final List<BackupArchiveInfo> backups = await listBackups();
    if (backups.length <= limit) {
      return;
    }
    final List<BackupArchiveInfo> stale = backups.sublist(limit);
    for (final BackupArchiveInfo backup in stale) {
      await deleteBackup(backup.fileName);
      debugPrint('[BackupService] Pruned stale backup: ${backup.fileName}');
    }
  }

  Future<void> _checkpointDatabase() async {
    final Database database = await _databaseService.database;
    await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> _addDatabaseFiles(Archive archive) async {
    final String? databasePath = _databaseService.databasePath;
    if (databasePath == null) {
      throw StateError('The database has not been initialized yet.');
    }
    final String dbName = p.basename(databasePath);
    final Directory dbDir = Directory(p.dirname(databasePath));
    for (final String suffix in const <String>['', '-wal', '-shm']) {
      final File file = File(p.join(dbDir.path, '$dbName$suffix'));
      if (await file.exists()) {
        archive.addFile(
          ArchiveFile(
            'database/$dbName$suffix',
            await file.length(),
            await file.readAsBytes(),
          ),
        );
      }
    }
  }

  Future<void> _addAttachmentFiles(Archive archive, String companyId) async {
    final Directory storageRoot = await _directoryService.storageRoot();
    final Directory companyStorage = await _directoryService.storage(companyId);
    if (!await companyStorage.exists()) {
      return;
    }
    await for (final FileSystemEntity entity in companyStorage.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String relative = p.relative(entity.path, from: storageRoot.path);
      archive.addFile(
        ArchiveFile(
          'storage/$relative',
          await entity.length(),
          await entity.readAsBytes(),
        ),
      );
    }
  }

  Future<Uint8List> _encrypt(Uint8List plain) async {
    final enc.Key key = await _encryptionKey();
    final enc.IV iv = enc.IV.fromSecureRandom(_ivLength);
    final enc.Encrypter encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm),
    );
    final enc.Encrypted encrypted = encrypter.encryptBytes(plain, iv: iv);
    final Digest digest = sha256.convert(plain);
    final BytesBuilder builder = BytesBuilder();
    builder.add(iv.bytes);
    builder.add(digest.bytes);
    builder.add(encrypted.bytes);
    return builder.toBytes();
  }

  Future<Uint8List> _decrypt(Uint8List cipherBytes, Uint8List ivBytes) async {
    final enc.Key key = await _encryptionKey();
    final enc.Encrypter encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm),
    );
    final List<int> decrypted = encrypter.decryptBytes(
      enc.Encrypted(cipherBytes),
      iv: enc.IV(ivBytes),
    );
    return Uint8List.fromList(decrypted);
  }

  Future<enc.Key> _encryptionKey() async {
    final String? stored = await _secureStorage.read(
      SecureStorageKeys.databaseEncryptionKey,
    );
    if (stored != null && stored.isNotEmpty) {
      return enc.Key.fromBase64(stored);
    }
    final enc.Key generated = enc.Key.fromSecureRandom(32);
    await _secureStorage.write(
      SecureStorageKeys.databaseEncryptionKey,
      generated.base64,
    );
    return generated;
  }

  Future<Directory> _extractToTemp(Archive archive) async {
    final Directory temp = await Directory.systemTemp.createTemp('finai_restore_');
    for (final ArchiveFile file in archive) {
      if (!file.isFile) {
        continue;
      }
      final String safeRelative = _sanitizeRelative(file.name);
      final File target = File(p.join(temp.path, safeRelative));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(_entryBytes(file), flush: true);
    }
    return temp;
  }

  Future<void> _swapDatabase(Directory extracted) async {
    final String? databasePath = _databaseService.databasePath;
    if (databasePath == null) {
      throw StateError('The database has not been initialized yet.');
    }
    final String dbDir = p.dirname(databasePath);
    final String dbName = p.basename(databasePath);

    await _databaseService.close();

    final String safetyDir = p.join(
      dbDir,
      'pre_restore_${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
    await Directory(safetyDir).create(recursive: true);

    for (final String suffix in const <String>['', '-wal', '-shm']) {
      final File existing = File(p.join(dbDir, '$dbName$suffix'));
      if (await existing.exists()) {
        await existing.rename(p.join(safetyDir, '$dbName$suffix'));
      }
    }

    try {
      for (final String suffix in const <String>['', '-wal', '-shm']) {
        final File restored = File(
          p.join(extracted.path, 'database', '$dbName$suffix'),
        );
        if (await restored.exists()) {
          await restored.copy(p.join(dbDir, '$dbName$suffix'));
        }
      }
      await _databaseService.initialize();
    } on Object {
      // Roll the previous database back into place and reconnect.
      for (final String suffix in const <String>['', '-wal', '-shm']) {
        final File placed = File(p.join(dbDir, '$dbName$suffix'));
        if (await placed.exists()) {
          await placed.delete();
        }
        final File safety = File(p.join(safetyDir, '$dbName$suffix'));
        if (await safety.exists()) {
          await safety.rename(p.join(dbDir, '$dbName$suffix'));
        }
      }
      await _databaseService.initialize();
      rethrow;
    }
  }

  Future<void> _restoreAttachments(Directory extracted) async {
    final Directory storageRoot = await _directoryService.storageRoot();
    final Directory storageSource = Directory(p.join(extracted.path, 'storage'));
    if (!await storageSource.exists()) {
      return;
    }
    await for (final FileSystemEntity entity in storageSource.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String relative = p.relative(entity.path, from: storageSource.path);
      final String safeRelative = _sanitizeRelative(relative);
      final File target = File(p.join(storageRoot.path, safeRelative));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }

  Uint8List _entryBytes(ArchiveFile file) {
    final Object? content = file.content;
    if (content is Uint8List) {
      return content;
    }
    if (content is List<int>) {
      return Uint8List.fromList(content);
    }
    throw StateError('Unsupported archive entry: ${file.name}');
  }

  String _sanitizeRelative(String name) {
    final String normalized = p.normalize(name.replaceAll('\\', '/'));
    if (normalized == '..' ||
        normalized.startsWith('../') ||
        p.isAbsolute(normalized)) {
      throw StateError('Backup contains an unsafe path: $name');
    }
    return normalized;
  }

  BackupArchiveInfo? _parseFileName(String fileName, String path, int size) {
    if (!fileName.startsWith(_backupPrefix) ||
        !fileName.endsWith(_backupExtension)) {
      return null;
    }
    final String stem = fileName.substring(
      _backupPrefix.length,
      fileName.length - _backupExtension.length,
    );
    final int separator = stem.lastIndexOf('_');
    if (separator <= 0 || separator == stem.length - 1) {
      return null;
    }
    final String companyId = stem.substring(0, separator);
    final String stamp = stem.substring(separator + 1);
    if (stamp.length != 15 || stamp[8] != '_') {
      return null;
    }
    final DateTime? createdAt = DateTime.tryParse(
      '${stamp.substring(0, 4)}-${stamp.substring(4, 6)}-${stamp.substring(6, 8)}'
      ' ${stamp.substring(9, 11)}:${stamp.substring(11, 13)}:${stamp.substring(13, 15)}',
    );
    if (createdAt == null) {
      return null;
    }
    return BackupArchiveInfo(
      fileName: fileName,
      path: path,
      companyId: companyId,
      createdAt: createdAt,
      sizeBytes: size,
    );
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    int diff = 0;
    for (int index = 0; index < left.length; index++) {
      diff |= left[index] ^ right[index];
    }
    return diff == 0;
  }

  String _safeSegment(String value) {
    final String sanitized = value.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }
}
