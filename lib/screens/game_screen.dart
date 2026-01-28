import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../game_logic/game_provider.dart';
import '../models/game_state.dart';
import '../core/theme.dart';
import '../core/settings_provider.dart';

class GameScreen extends StatelessWidget {
  final GameType gameType;
  final String? roomId;
  final bool isHost;
  final ControlMode controlMode;
  final bool enableWallPassing;
  final int duration;

  const GameScreen({
    super.key,
    required this.gameType,
    this.roomId,
    this.isHost = true,
    required this.controlMode,
    required this.enableWallPassing,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider()
        ..initGame(
          gameType,
          onlineRoomId: roomId,
          isHost: isHost,
          startControlMode: controlMode,
          startWallPassing: enableWallPassing,
          startDuration: duration,
          playerColor:
              Provider.of<SettingsProvider>(
                context,
                listen: false,
              ).skinColors[Provider.of<SettingsProvider>(
                context,
                listen: false,
              ).selectedSkin],
        ),
      child: const GameScreenContent(),
    );
  }
}

class GameScreenContent extends StatelessWidget {
  const GameScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    return Scaffold(
      backgroundColor: isNeon ? Colors.black : AppTheme.classicBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: game.controlMode == ControlMode.swipe
            ? (details) {
                if (details.delta.dy > 5) {
                  game.changeDirection(PlayerType.host, Direction.down);
                } else if (details.delta.dy < -5) {
                  game.changeDirection(PlayerType.host, Direction.up);
                }
              }
            : null,
        onHorizontalDragUpdate: game.controlMode == ControlMode.swipe
            ? (details) {
                if (details.delta.dx > 5) {
                  game.changeDirection(PlayerType.host, Direction.right);
                } else if (details.delta.dx < -5) {
                  game.changeDirection(PlayerType.host, Direction.left);
                }
              }
            : null,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const GameHUD(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isNeon ? Colors.black : AppTheme.classicBg,
                          border: Border.all(
                            color: isNeon
                                ? AppTheme.neonBlue.withValues(alpha: 0.5)
                                : AppTheme.classicSnake,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(isNeon ? 12 : 0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isNeon ? 10 : 0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cellWidth =
                                  constraints.maxWidth / GameProvider.columns;
                              final cellHeight =
                                  constraints.maxHeight / GameProvider.rows;

                              return CustomPaint(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                painter: GamePainter(
                                  game,
                                  settings,
                                  cellWidth,
                                  cellHeight,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const GameControls(),
                ],
              ),

              // Active Powerup Indicators
              Positioned(
                top: 80,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: PowerUpType.values
                      .where((t) => game.player1.hasPowerUp(t))
                      .map((t) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _getPowerUpColor(t)),
                          ),
                          child: Text(
                            t.name.toUpperCase(),
                            style: TextStyle(
                              color: _getPowerUpColor(t),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),

              if (game.controlMode == ControlMode.joystick &&
                  game.isGameActive &&
                  !game.isGameOver)
                Positioned(
                  bottom: 40,
                  right: 40,
                  child: Theme(
                    data: ThemeData(
                      colorScheme: ColorScheme.dark(
                        surface: isNeon
                            ? AppTheme.neonBlue.withValues(alpha: 0.1)
                            : AppTheme.classicSnake.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Opacity(
                      opacity: 0.5,
                      child: Joystick(
                        mode: JoystickMode.all,
                        listener: (details) {
                          if (details.y < -0.5) {
                            game.changeDirection(PlayerType.host, Direction.up);
                          } else if (details.y > 0.5) {
                            game.changeDirection(
                              PlayerType.host,
                              Direction.down,
                            );
                          } else if (details.x < -0.5) {
                            game.changeDirection(
                              PlayerType.host,
                              Direction.left,
                            );
                          } else if (details.x > 0.5) {
                            game.changeDirection(
                              PlayerType.host,
                              Direction.right,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),

              if (game.isGameActive &&
                  !game.isPlaying &&
                  game.startCountDown > 0)
                Center(
                  child: Text(
                    "${game.startCountDown}",
                    style: const TextStyle(
                      fontSize: 100,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (game.isWaitingForPlayer)
                Container(
                  color: isNeon
                      ? Colors.black87
                      : AppTheme.classicBg.withValues(alpha: 0.9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: isNeon
                              ? AppTheme.neonGreen
                              : AppTheme.classicSnake,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          settings.getText('waiting_host'),
                          style: TextStyle(
                            color: isNeon
                                ? Colors.white
                                : AppTheme.classicSnake,
                            fontSize: 18,
                          ),
                        ),
                        if (game.currentRoomId != null)
                          Text(
                            "CODE: ${game.currentRoomId}",
                            style: TextStyle(
                              color: isNeon
                                  ? AppTheme.neonYellow
                                  : AppTheme.classicSnake,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Emoji Selection Button
              if (game.isGameActive && !game.isGameOver)
                Positioned(
                  bottom: 100,
                  left: 20,
                  child: Column(
                    children: [
                      if (game.player1Emoji != null)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            game.player1Emoji!,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      const SizedBox(height: 10),
                      IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () => _showEmojiPicker(context, game),
                      ),
                    ],
                  ),
                ),

              // Rival Emoji
              if (game.player2Emoji != null)
                Positioned(
                  top: 150,
                  right: 50,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      game.player2Emoji!,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, GameProvider game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: GridView.count(
          crossAxisCount: 5,
          children: ["😎", "😈", "😂", "😡", "😱", "🍎", "🔥", "💨", "💀", "👑"]
              .map((e) {
                return InkWell(
                  onTap: () {
                    game.sendEmoji(e);
                    Navigator.pop(ctx);
                  },
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ),
                );
              })
              .toList(),
        ),
      ),
    );
  }

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.turbo:
        return Colors.orange;
      case PowerUpType.ghost:
        return Colors.white;
      case PowerUpType.magnet:
        return Colors.blue;
    }
  }
}

class GameHUD extends StatelessWidget {
  const GameHUD({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isNeon ? AppTheme.surface : AppTheme.classicBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildScoreCard(
            settings.getText('you'),
            game.player1.score,
            isNeon ? AppTheme.neonGreen : AppTheme.classicSnake,
            isNeon,
          ),
          Column(
            children: [
              Text(
                settings.getText('time'),
                style: TextStyle(
                  color: isNeon ? Colors.white54 : AppTheme.classicSnake,
                  fontSize: 10,
                ),
              ),
              Text(
                game.remainingTime == -1 ? "∞" : "${game.remainingTime}",
                style: TextStyle(
                  color: isNeon ? Colors.white : AppTheme.classicSnake,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          game.currentGameType == GameType.online
              ? _buildScoreCard(
                  settings.getText('rival'),
                  game.player2?.score ?? 0,
                  isNeon ? AppTheme.neonRed : AppTheme.classicSnake,
                  isNeon,
                )
              : const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, Color color, bool isNeon) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          "$score",
          style: TextStyle(
            color: isNeon ? Colors.white : AppTheme.classicSnake,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class GameControls extends StatelessWidget {
  const GameControls({super.key});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    if (!game.isGameActive && !game.isGameOver && !game.isWaitingForPlayer) {
      final isHost =
          game.currentGameType == GameType.offline ||
          (game.player1.type == PlayerType.host);
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: isHost
            ? ElevatedButton(
                onPressed: game.startMatchSequence,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNeon
                      ? AppTheme.neonGreen
                      : AppTheme.classicSnake,
                ),
                child: Text(
                  "START",
                  style: TextStyle(
                    color: isNeon ? Colors.black : AppTheme.classicBg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Text(settings.getText('waiting_host')),
      );
    }

    if (game.isGameOver) {
      final isHost =
          game.currentGameType == GameType.offline ||
          (game.player1.type == PlayerType.host);
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              game.winnerMessage ?? settings.getText('game_over'),
              style: TextStyle(
                color: isNeon ? AppTheme.neonRed : AppTheme.classicSnake,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (isHost)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: game.resetGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNeon
                          ? AppTheme.neonGreen
                          : AppTheme.classicSnake,
                    ),
                    child: Text(
                      settings.getText('play_again'),
                      style: TextStyle(
                        color: isNeon ? Colors.black : AppTheme.classicBg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _showSubmitScoreDialog(
                      context,
                      settings,
                      game.player1.score,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                    ),
                    child: const Text(
                      "SUBMIT",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              )
            else
              Text(settings.getText('waiting_host')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showSubmitScoreDialog(
    BuildContext context,
    SettingsProvider settings,
    int score,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Submit Score"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Your Name"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await settings.submitScore(controller.text, score);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Score submitted!")),
                );
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final GameProvider game;
  final SettingsProvider settings;
  final double cellWidth;
  final double cellHeight;

  GamePainter(this.game, this.settings, this.cellWidth, this.cellHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final isNeon = settings.currentTheme == GameTheme.neon;
    final gridPaint = Paint()
      ..color = isNeon
          ? Colors.white.withValues(alpha: 0.05)
          : AppTheme.classicSnake.withValues(alpha: 0.1);

    for (int i = 0; i <= GameProvider.columns; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        gridPaint,
      );
    }
    for (int i = 0; i <= GameProvider.rows; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        gridPaint,
      );
    }

    // Draw Obstacles
    final obsPaint = Paint()
      ..color = isNeon ? Colors.grey : AppTheme.classicSnake;
    for (var obs in game.obstacles) {
      canvas.drawRect(
        Rect.fromLTWH(
          obs.x * cellWidth + 2,
          obs.y * cellHeight + 2,
          cellWidth - 4,
          cellHeight - 4,
        ),
        obsPaint,
      );
      if (isNeon) {
        canvas.drawLine(
          Offset(obs.x * cellWidth, obs.y * cellHeight),
          Offset((obs.x + 1) * cellWidth, (obs.y + 1) * cellHeight),
          Paint()..color = Colors.white24,
        );
      }
    }

    // Draw Power-ups
    for (var pu in game.boardPowerUps) {
      final puPaint = Paint()..color = _getPUColor(pu.type);
      canvas.drawCircle(
        Offset(
          pu.position.x * cellWidth + cellWidth / 2,
          pu.position.y * cellHeight + cellHeight / 2,
        ),
        cellWidth / 2.5,
        puPaint,
      );
    }

    if (game.food != null) {
      final foodPaint = Paint()..color = _getFoodColor(game.food!.type, isNeon);
      canvas.drawRect(
        Rect.fromLTWH(
          game.food!.position.x * cellWidth + 2,
          game.food!.position.y * cellHeight + 2,
          cellWidth - 4,
          cellHeight - 4,
        ),
        foodPaint,
      );
    }

    _drawSnake(canvas, game.player1, isNeon);
    if (game.currentGameType == GameType.online && game.player2 != null) {
      _drawSnake(canvas, game.player2!, isNeon);
    }
  }

  Color _getPUColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.turbo:
        return Colors.orange;
      case PowerUpType.ghost:
        return Colors.white;
      case PowerUpType.magnet:
        return Colors.blue;
    }
  }

  Color _getFoodColor(FoodType type, bool isNeon) {
    if (!isNeon) return AppTheme.classicFood;
    switch (type) {
      case FoodType.regular:
        return AppTheme.neonYellow;
      case FoodType.gold:
        return Colors.amber;
      case FoodType.rotten:
        return Colors.purpleAccent;
    }
  }

  void _drawSnake(Canvas canvas, Snake snake, bool isNeon) {
    if (!snake.isAlive) return;
    double opacity = snake.hasPowerUp(PowerUpType.ghost) ? 0.5 : 1.0;
    final paint = Paint()
      ..color = (isNeon ? snake.color : AppTheme.classicSnake).withValues(
        alpha: opacity,
      );
    for (var pos in snake.body) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pos.x * cellWidth + 1,
            pos.y * cellHeight + 1,
            cellWidth - 2,
            cellHeight - 2,
          ),
          Radius.circular(isNeon ? 4 : 0),
        ),
        paint,
      );
    }
    if (isNeon) _drawEyes(canvas, snake);
  }

  void _drawEyes(Canvas canvas, Snake snake) {
    final head = snake.head;
    final eyeSize = cellWidth * 0.2;
    double lx = 0, ly = 0, rx = 0, ry = 0;
    switch (snake.direction) {
      case Direction.up:
        lx = head.x * cellWidth + cellWidth * 0.2;
        ly = head.y * cellHeight + cellHeight * 0.2;
        rx = head.x * cellWidth + cellWidth * 0.8;
        ry = head.y * cellHeight + cellHeight * 0.2;
        break;
      case Direction.down:
        lx = head.x * cellWidth + cellWidth * 0.8;
        ly = head.y * cellHeight + cellHeight * 0.8;
        rx = head.x * cellWidth + cellWidth * 0.2;
        ry = head.y * cellHeight + cellHeight * 0.8;
        break;
      case Direction.left:
        lx = head.x * cellWidth + cellWidth * 0.2;
        ly = head.y * cellHeight + cellHeight * 0.8;
        rx = head.x * cellWidth + cellWidth * 0.2;
        ry = head.y * cellHeight + cellHeight * 0.2;
        break;
      case Direction.right:
        lx = head.x * cellWidth + cellWidth * 0.8;
        ly = head.y * cellHeight + cellHeight * 0.2;
        rx = head.x * cellWidth + cellWidth * 0.8;
        ry = head.y * cellHeight + cellHeight * 0.8;
        break;
    }
    canvas.drawCircle(Offset(lx, ly), eyeSize, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(rx, ry), eyeSize, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
