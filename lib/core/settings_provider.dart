import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';
import 'theme.dart';

enum GameTheme { neon, classic }

enum Language { en, ar }

class LeaderboardEntry {
  final String playerName;
  final int score;
  LeaderboardEntry({required this.playerName, required this.score});
}

class SettingsProvider extends ChangeNotifier {
  GameTheme _currentTheme = GameTheme.neon;
  Language _currentLanguage = Language.en;

  int _xp = 0;
  int _level = 1;
  String _selectedSkin = 'default';

  SettingsProvider() {
    _loadSettings();
  }

  GameTheme get currentTheme => _currentTheme;
  Language get currentLanguage => _currentLanguage;
  int get xp => _xp;
  int get level => _level;
  String get selectedSkin => _selectedSkin;
  bool get isArabic => _currentLanguage == Language.ar;

  final Map<String, Color> skinColors = {
    'default': AppTheme.neonGreen,
    'lava': Colors.deepOrange,
    'cyber': Colors.cyanAccent,
    'classic': Colors.black87,
    'royal': Colors.amberAccent,
  };

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _xp = prefs.getInt('xp') ?? 0;
    _level = (_xp / 500).floor() + 1;
    _currentTheme = GameTheme.values[prefs.getInt('theme') ?? 0];
    _currentLanguage = Language.values[prefs.getInt('lang') ?? 0];
    _selectedSkin = prefs.getString('skin') ?? 'default';
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('xp', _xp);
    await prefs.setInt('theme', _currentTheme.index);
    await prefs.setInt('lang', _currentLanguage.index);
    await prefs.setString('skin', _selectedSkin);
  }

  void setSelectedSkin(String skin) {
    _selectedSkin = skin;
    _saveSettings();
    notifyListeners();
  }

  void addXP(int amount) {
    _xp += amount;
    _level = (_xp / 500).floor() + 1;
    _saveSettings();
    notifyListeners();
  }

  void toggleTheme() {
    _currentTheme = _currentTheme == GameTheme.neon
        ? GameTheme.classic
        : GameTheme.neon;
    _saveSettings();
    notifyListeners();
  }

  void setLanguage(Language lang) {
    _currentLanguage = lang;
    _saveSettings();
    notifyListeners();
  }

  // Leaderboard Logic
  Future<void> submitScore(String name, int score) async {
    try {
      await SupabaseService.client.from('leaderboard').insert({
        'player_name': name,
        'score': score,
      });
    } catch (e) {
      debugPrint("Error submitting score: $e");
    }
  }

  Future<List<LeaderboardEntry>> getTopScores() async {
    try {
      final data = await SupabaseService.client
          .from('leaderboard')
          .select()
          .order('score', ascending: false)
          .limit(10);

      return (data as List)
          .map(
            (e) => LeaderboardEntry(
              playerName: e['player_name'] as String,
              score: e['score'] as int,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint("Error fetching scores: $e");
      return [];
    }
  }

  String getText(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'play_offline': {'en': 'PLAY OFFLINE', 'ar': 'لعب بدون إنترنت'},
      'play_online': {'en': 'PLAY ONLINE', 'ar': 'لعب أونلاين'},
      'settings': {'en': 'SETTINGS', 'ar': 'الإعدادات'},
      'language': {'en': 'Language', 'ar': 'اللحظة'},
      'theme': {'en': 'Theme', 'ar': 'التصميم'},
      'neon': {'en': 'Neon', 'ar': 'نيون'},
      'classic': {'en': 'Classic', 'ar': 'كلاسيك'},
      'create_room': {'en': 'Create Room', 'ar': 'إنشاء غرفة'},
      'join_room': {'en': 'Join Room', 'ar': 'انضمام لغرفة'},
      'waiting_host': {'en': 'Waiting...', 'ar': 'بانتظار...'},
      'you': {'en': 'YOU', 'ar': 'أنت'},
      'rival': {'en': 'RIVAL', 'ar': 'الخصم'},
      'time': {'en': 'TIME', 'ar': 'الوقت'},
      'play_again': {'en': 'PLAY AGAIN', 'ar': 'العب مجدداً'},
      'game_over': {'en': 'GAME OVER', 'ar': 'انتهت اللعبة'},
      'snake': {'en': 'SNAKE', 'ar': 'ثعبان'},
      'leaderboard': {'en': 'LEADERBOARD', 'ar': 'قائمة المتصدرين'},
      'xp': {'en': 'XP', 'ar': 'خبرة'},
      'level': {'en': 'LVL', 'ar': 'مستوى'},
      'skins': {'en': 'SKINS', 'ar': 'المظاهر'},
      'matchmaking': {'en': 'QUICK MATCH', 'ar': 'بحث سريع'},
      'infinite': {'en': 'INFINITE', 'ar': 'لا نهائي'},
    };
    return localizedValues[key]?[_currentLanguage.name] ?? key;
  }
}
