import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Standardized on-disk layout for all FinAI Studio local artifacts.
///
/// On Windows the tree is rooted at `%APPDATA%\FinAIStudio` (i.e.
/// `AppData\Roaming\FinAIStudio`); on macOS/Linux it falls back to the
/// platform application-support directory so the same relative layout is
/// preserved everywhere.
///
/// ```
/// FinAIStudio/
/// ├── Databases/                      Active SQLite .db files.
/// ├── Storage/{company_id}/{year}/{month}/   Invoice scans & receipts.
/// ├── Backups/                        Compressed & encrypted backup archives.
/// └── Exports/                        Generated PDFs, Excel, and Tax XML.
/// ```
abstract interface class AppDirectoryService {
  /// The FinAIStudio root directory.
  Future<Directory> root();

  /// Where active SQLite database files live.
  Future<Directory> databases();

  /// The attachment root (`Storage`), shared by all companies.
  Future<Directory> storageRoot();

  /// `Storage/{company_id}`, or the year/month subfolder when provided.
  Future<Directory> storage(
    String companyId, {
    int? year,
    int? month,
  });

  /// The company/year/month folder for attachments dated [date].
  Future<Directory> attachments(String companyId, DateTime date);

  /// Where compressed, encrypted backup archives are written.
  Future<Directory> backups();

  /// Where generated reports (PDF, Excel, Tax XML) are written.
  Future<Directory> exports();
}

class AppDirectoryServiceImpl implements AppDirectoryService {
  const AppDirectoryServiceImpl();

  @override
  Future<Directory> root() async {
    final String basePath;
    if (!kIsWeb && Platform.isWindows) {
      final String? appData = Platform.environment['APPDATA'];
      basePath = appData != null && appData.isNotEmpty
          ? p.join(appData, 'FinAIStudio')
          : p.join((await getApplicationSupportDirectory()).path, 'FinAIStudio');
    } else {
      basePath = p.join((await getApplicationSupportDirectory()).path, 'FinAIStudio');
    }

    final Directory directory = Directory(basePath);
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Directory> databases() async {
    final Directory directory = Directory(
      p.join((await root()).path, 'Databases'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Directory> storageRoot() async {
    final Directory directory = Directory(
      p.join((await root()).path, 'Storage'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Directory> storage(
    String companyId, {
    int? year,
    int? month,
  }) async {
    final List<String> segments = <String>[
      (await root()).path,
      'Storage',
      _safeSegment(companyId),
    ];
    if (year != null) {
      segments.add(year.toString().padLeft(4, '0'));
    }
    if (month != null) {
      segments.add(month.toString().padLeft(2, '0'));
    }

    final Directory directory = Directory(p.joinAll(segments));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Directory> attachments(String companyId, DateTime date) {
    return storage(companyId, year: date.year, month: date.month);
  }

  @override
  Future<Directory> backups() async {
    final Directory directory = Directory(
      p.join((await root()).path, 'Backups'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Directory> exports() async {
    final Directory directory = Directory(
      p.join((await root()).path, 'Exports'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static String _safeSegment(String value) {
    final String sanitized = value.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'unknown';
    }
    return sanitized;
  }
}
