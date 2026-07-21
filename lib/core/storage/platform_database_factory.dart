import 'package:sqflite/sqflite.dart';

import 'platform_database_factory_stub.dart'
    if (dart.library.js_interop) 'platform_database_factory_web.dart';

DatabaseFactory get platformDatabaseFactory => createPlatformDatabaseFactory();
