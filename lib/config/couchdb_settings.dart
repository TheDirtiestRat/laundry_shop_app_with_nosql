import 'package:shared_preferences/shared_preferences.dart';

class CouchDbSettings {
  const CouchDbSettings({required this.baseUrl, required this.database});

  static const defaultDatabase = 'laundry_db';
  static const _baseUrlKey = 'couchdb_base_url';
  static const _databaseKey = 'couchdb_database';

  final String baseUrl;
  final String database;

  static Future<CouchDbSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return CouchDbSettings(
      baseUrl: preferences.getString(_baseUrlKey) ?? '',
      database: preferences.getString(_databaseKey) ?? defaultDatabase,
    );
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, baseUrl.trim());
    await preferences.setString(_databaseKey, database.trim());
  }
}
