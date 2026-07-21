import 'package:sqflite/sqflite.dart';

abstract final class WorkspaceDatabaseSchema {
  static const version = 1;
  static Future<void> create(Database db, int _) async {
    await db.execute(
      '''CREATE TABLE profiles(
      id TEXT PRIMARY KEY, display_name TEXT NOT NULL, unit TEXT NOT NULL CHECK(unit IN ('kg','lb')),
      global_tm_ratio_basis_points INTEGER NOT NULL, rounding_increment_centi_units INTEGER NOT NULL)''',
    );
    await db.execute('''CREATE TABLE movement_maxes(
      profile_id TEXT NOT NULL REFERENCES profiles(id), movement_id TEXT NOT NULL,
      input_type TEXT NOT NULL CHECK(input_type IN ('oneRepMax','repMax','trainingMax')),
      weight_centi_units INTEGER NOT NULL, repetitions INTEGER, tm_ratio_basis_points INTEGER,
      PRIMARY KEY(profile_id, movement_id))''');
    await db.execute(
      '''CREATE TABLE gyms(id TEXT PRIMARY KEY, name TEXT NOT NULL)''',
    );
    await db.execute('''CREATE TABLE bars(
      id TEXT PRIMARY KEY, gym_id TEXT NOT NULL REFERENCES gyms(id), unit TEXT NOT NULL,
      weight_centi_units INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE plates(
      gym_id TEXT NOT NULL REFERENCES gyms(id), unit TEXT NOT NULL,
      weight_centi_units INTEGER NOT NULL, pair_count INTEGER NOT NULL,
      PRIMARY KEY(gym_id, unit, weight_centi_units))''');
    await db.execute('''CREATE TABLE generation_drafts(
      id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id),
      request_json TEXT NOT NULL, updated_at TEXT NOT NULL)''');
  }
}
