import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/settings_provider.dart';
import '../screens/game_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/skins_screen.dart';
import '../models/game_state.dart';
import '../game_logic/game_provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ControlMode _myControlMode = ControlMode.swipe;
  final bool _hostWallPassing = false;
  final _joinCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isNeon ? Colors.black : AppTheme.classicBg,
      body: Container(
        decoration: isNeon
            ? BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [const Color(0xFF1A1A1A), Colors.black],
                ),
              )
            : null,
        child: Stack(
          children: [
            // Level HUD
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isNeon
                          ? AppTheme.neonBlue.withValues(alpha: 0.1)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isNeon
                            ? AppTheme.neonBlue
                            : AppTheme.classicSnake,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          settings.getText('level'),
                          style: TextStyle(
                            color: isNeon
                                ? AppTheme.neonBlue
                                : AppTheme.classicSnake,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${settings.level}",
                          style: TextStyle(
                            color: isNeon
                                ? Colors.white
                                : AppTheme.classicSnake,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${settings.xp % 500} / 500 ${settings.getText('xp')}",
                              style: TextStyle(
                                color: isNeon
                                    ? Colors.white70
                                    : AppTheme.classicSnake,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "TOTAL: ${settings.xp}",
                              style: TextStyle(
                                color: isNeon
                                    ? Colors.white38
                                    : AppTheme.classicSnake,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (settings.xp % 500) / 500,
                            backgroundColor: isNeon
                                ? Colors.white10
                                : Colors.black12,
                            color: isNeon
                                ? AppTheme.neonGreen
                                : AppTheme.classicSnake,
                            minHeight: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Top Header Logo
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    settings.getText('snake'),
                    style: TextStyle(
                      fontFamily: isNeon ? 'Orbitron' : 'Courier',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: isNeon ? Colors.white : AppTheme.classicSnake,
                    ),
                  ),
                  Text(
                    'RIVALS',
                    style: TextStyle(
                      fontFamily: isNeon ? 'Orbitron' : 'Courier',
                      color: isNeon ? AppTheme.neonRed : AppTheme.classicSnake,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 180),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('matchmaking'),
                        color: isNeon
                            ? Colors.orangeAccent
                            : AppTheme.classicSnake,
                        icon: Icons.flash_on,
                        isNeon: isNeon,
                        onPressed: () => _startMatchmaking(context),
                      ),
                      const SizedBox(height: 20),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('play_offline'),
                        color: isNeon
                            ? AppTheme.neonGreen
                            : AppTheme.classicSnake,
                        icon: Icons.person,
                        isNeon: isNeon,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GameScreen(
                                gameType: GameType.offline,
                                controlMode: _myControlMode,
                                enableWallPassing: _hostWallPassing,
                                duration: -1,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('create_room'),
                        color: isNeon
                            ? AppTheme.neonBlue
                            : AppTheme.classicSnake,
                        icon: Icons.add_circle_outline,
                        isNeon: isNeon,
                        onPressed: () =>
                            _showCreateRoomDialog(context, settings),
                      ),
                      const SizedBox(height: 20),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('join_room'),
                        color: isNeon
                            ? AppTheme.neonYellow
                            : AppTheme.classicSnake,
                        icon: Icons.login,
                        isNeon: isNeon,
                        onPressed: () => _showJoinRoomDialog(context, settings),
                      ),
                      const SizedBox(height: 20),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('leaderboard'),
                        color: isNeon
                            ? Colors.cyanAccent
                            : AppTheme.classicSnake,
                        icon: Icons.leaderboard,
                        isNeon: isNeon,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildResponsiveButton(
                        context,
                        label: settings.getText('skins'),
                        color: isNeon
                            ? Colors.purpleAccent
                            : AppTheme.classicSnake,
                        icon: Icons.palette,
                        isNeon: isNeon,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SkinsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      // Settings Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.settings,
                              color: isNeon
                                  ? Colors.white54
                                  : AppTheme.classicSnake,
                            ),
                            onPressed: () =>
                                _showSettingsDialog(context, settings),
                          ),
                          const SizedBox(width: 20),
                          // Quick Toggle Language
                          TextButton(
                            onPressed: () {
                              settings.setLanguage(
                                settings.currentLanguage == Language.en
                                    ? Language.ar
                                    : Language.en,
                              );
                            },
                            child: Text(
                              settings.currentLanguage == Language.en
                                  ? "العربية"
                                  : "English",
                              style: TextStyle(
                                color: isNeon
                                    ? AppTheme.neonBlue
                                    : AppTheme.classicSnake,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveButton(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isNeon,
  }) {
    return SizedBox(
      width: 280,
      child: isNeon
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shadowColor: color.withValues(alpha: 0.5),
                elevation: 10,
                backgroundColor: Colors.transparent,
              ),
              onPressed: onPressed,
              icon: Icon(icon, color: color),
              label: Text(label, style: const TextStyle(fontSize: 16)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onPressed,
              icon: Icon(icon, color: color),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Future<void> _startMatchmaking(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final p = GameProvider();
    final result = await p.performMatchmaking();
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (result != null) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gameType: GameType.online,
            roomId: result['room_code'],
            isHost: result['is_host'],
            controlMode: _myControlMode,
            enableWallPassing: result['allow_wall_passing'],
            duration: result['game_duration'],
          ),
        ),
      );
    }
  }

  void _showCreateRoomDialog(BuildContext context, SettingsProvider settings) {
    String randomCode = (1000 + Random().nextInt(9000)).toString();
    bool tempWallPass = _hostWallPassing;
    int tempDuration = 120;
    bool isLoading = false;
    final isNeon = settings.currentTheme == GameTheme.neon;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isNeon ? AppTheme.surface : AppTheme.classicBg,
            title: Text(
              settings.getText('create_room'),
              style: TextStyle(
                color: isNeon ? AppTheme.neonBlue : AppTheme.classicSnake,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    randomCode,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: isNeon
                          ? AppTheme.neonGreen
                          : AppTheme.classicSnake,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Wall Pass",
                        style: TextStyle(
                          color: isNeon ? Colors.white : AppTheme.classicSnake,
                        ),
                      ),
                      Switch(
                        value: tempWallPass,
                        onChanged: (v) => setState(() => tempWallPass = v),
                        activeThumbColor: isNeon
                            ? AppTheme.neonBlue
                            : AppTheme.classicSnake,
                        activeTrackColor: isNeon
                            ? AppTheme.neonBlue.withValues(alpha: 0.5)
                            : AppTheme.classicSnake.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<int>(
                    value: tempDuration,
                    dropdownColor: isNeon
                        ? AppTheme.surface
                        : AppTheme.classicBg,
                    style: TextStyle(
                      color: isNeon ? Colors.white : AppTheme.classicSnake,
                    ),
                    items: [
                      DropdownMenuItem(value: 60, child: Text("1 MIN")),
                      DropdownMenuItem(value: 120, child: Text("2 MIN")),
                      DropdownMenuItem(value: 180, child: Text("3 MIN")),
                      DropdownMenuItem(
                        value: -1,
                        child: Text(settings.getText('infinite')),
                      ),
                    ],
                    onChanged: (val) => setState(() => tempDuration = val!),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() => isLoading = true);
                  final p = GameProvider();
                  bool ok = await p.createRoomOnServer(
                    randomCode,
                    tempWallPass,
                    tempDuration,
                  );
                  if (ok) {
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          gameType: GameType.online,
                          roomId: randomCode,
                          isHost: true,
                          controlMode: _myControlMode,
                          enableWallPassing: tempWallPass,
                          duration: tempDuration,
                        ),
                      ),
                    );
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context, SettingsProvider settings) {
    _joinCodeController.clear();
    final isNeon = settings.currentTheme == GameTheme.neon;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isNeon ? AppTheme.surface : AppTheme.classicBg,
        title: Text(settings.getText('join_room')),
        content: TextField(
          controller: _joinCodeController,
          style: TextStyle(
            color: isNeon ? Colors.white : AppTheme.classicSnake,
          ),
          decoration: const InputDecoration(hintText: "Code"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final p = GameProvider();
              final data = await p.joinRoomOnServer(_joinCodeController.text);
              if (data != null) {
                if (!context.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      gameType: GameType.online,
                      roomId: _joinCodeController.text,
                      isHost: false,
                      controlMode: _myControlMode,
                      enableWallPassing: data['allow_wall_passing'],
                      duration: data['game_duration'],
                    ),
                  ),
                );
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, SettingsProvider settings) {
    final isNeon = settings.currentTheme == GameTheme.neon;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isNeon ? AppTheme.surface : AppTheme.classicBg,
          title: Text(settings.getText('settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(settings.getText('theme')),
                trailing: Text(
                  isNeon
                      ? settings.getText('neon')
                      : settings.getText('classic'),
                ),
                onTap: () {
                  settings.toggleTheme();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text("Controls"),
                trailing: Text(_myControlMode.name.toUpperCase()),
                onTap: () {
                  setState(() {
                    _myControlMode = _myControlMode == ControlMode.swipe
                        ? ControlMode.joystick
                        : ControlMode.swipe;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
