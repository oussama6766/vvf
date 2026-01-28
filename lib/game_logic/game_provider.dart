import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_state.dart';
import '../core/theme.dart';
import '../core/multiplayer_service.dart';
import '../core/client.dart';

enum ControlMode { swipe, joystick }

class GameProvider extends ChangeNotifier {
  static const int rows = 30;
  static const int columns = 20;
  static const int baseTickMs = 50;
  int _tickCount = 0;

  late Snake player1;
  Snake? player2;
  Food? food;
  List<PowerUp> boardPowerUps = [];
  List<Position> obstacles = [];

  Timer? _gameTimer;
  Timer? _countDownTimer;

  bool isPlaying = false;
  bool isGameActive = false;
  int remainingTime = 120;
  int initialDuration = 120;
  bool isGameOver = false;
  String? winnerMessage;

  bool _canChangeDirection = true;
  bool enableWallPassing = false;
  ControlMode controlMode = ControlMode.swipe;

  GameType currentGameType = GameType.offline;
  int startCountDown = 3;

  MultiplayerService? _multiplayerService;
  String? currentRoomId;
  bool isWaitingForPlayer = false;

  String? player1Emoji;
  String? player2Emoji;
  Timer? _emojiTimer1;
  Timer? _emojiTimer2;

  void sendEmoji(String emoji) {
    player1Emoji = emoji;
    notifyListeners();
    _emojiTimer1?.cancel();
    _emojiTimer1 = Timer(const Duration(seconds: 3), () {
      player1Emoji = null;
      notifyListeners();
    });
    if (currentGameType == GameType.online && _multiplayerService != null) {
      _multiplayerService!.broadcastEmoji(emoji);
    }
  }

  GameProvider();

  Future<void> initGame(
    GameType type, {
    String? onlineRoomId,
    bool isHost = true,
    required ControlMode startControlMode,
    required bool startWallPassing,
    required int startDuration,
    Color? playerColor,
    bool skipWaiting = false,
  }) async {
    currentGameType = type;
    controlMode = startControlMode;
    enableWallPassing = startWallPassing;
    initialDuration = startDuration;
    currentRoomId = onlineRoomId;
    isWaitingForPlayer = (type == GameType.online && !skipWaiting);

    player1 = Snake(
      type: isHost ? PlayerType.host : PlayerType.guest,
      body: isHost
          ? [const Position(5, 5), const Position(5, 4), const Position(5, 3)]
          : [
              const Position(15, 25),
              const Position(15, 26),
              const Position(15, 27),
            ],
      direction: isHost ? Direction.down : Direction.up,
      color: playerColor ?? (isHost ? AppTheme.neonGreen : AppTheme.neonRed),
      score: 0,
    );

    if (type == GameType.online) {
      player2 = Snake(
        type: isHost ? PlayerType.guest : PlayerType.host,
        body: isHost
            ? [
                const Position(15, 25),
                const Position(15, 26),
                const Position(15, 27),
              ]
            : [
                const Position(5, 5),
                const Position(5, 4),
                const Position(5, 3),
              ],
        direction: isHost ? Direction.up : Direction.down,
        color: (playerColor == AppTheme.neonRed)
            ? AppTheme.neonGreen
            : AppTheme.neonRed,
        score: 0,
      );
      remainingTime = startDuration;
      if (onlineRoomId != null) {
        _setupOnlineConnection(onlineRoomId, isHost);
      }
    } else {
      player2 = null;
      remainingTime = startDuration;
      isWaitingForPlayer = false;
      _spawnInitialElements();
    }

    isPlaying = false;
    isGameActive = false;
    isGameOver = false;
    winnerMessage = null;
    startCountDown = 3;
    _tickCount = 0;
    notifyListeners();
  }

  void _spawnInitialElements() {
    obstacles.clear();
    if (!enableWallPassing) {
      final random = Random();
      for (int i = 0; i < 5; i++) {
        int x = random.nextInt(columns);
        int y = random.nextInt(rows);
        Position p = Position(x, y);
        if (!_isPositionOccupied(p)) {
          obstacles.add(p);
        }
      }
    }
    _spawnFood();
  }

  void _setupOnlineConnection(String roomId, bool isHost) {
    _multiplayerService = MultiplayerService(
      roomId: roomId,
      onOpponentMove: (pos, dir, score) {
        if (player2 != null) {
          player2!.body.insert(0, pos);
          player2!.direction = dir;
          player2!.score = score;
          int expectedLength = (score / 10).floor() + 3;
          while (player2!.body.length > expectedLength) {
            player2!.body.removeLast();
          }
          // Rival hit checking removed as per user request (snakes can pass through each other)
          if (isHost && food != null && pos == food!.position) {
            _spawnFood();
          }
          notifyListeners();
        }
      },
      onGameOver: (winner) => _endGame("Winner: $winner"),
      onStartGame: () {
        if (!isGameActive) startMatchSequence(isRemoteTrigger: true);
      },
      onFoodSpawn: (foodPos) {
        food = Food(position: foodPos);
        notifyListeners();
      },
      onPowerUpSpawn: (puPos, type) {
        boardPowerUps.add(
          PowerUp(position: puPos, type: type, spawnTime: DateTime.now()),
        );
        notifyListeners();
      },
      onReplayRequest: () {
        resetGame(isRemoteTrigger: true);
      },
      onOpponentEaten: () {
        if (isHost) _spawnFood();
      },
      onOpponentEmoji: (emoji) {
        player2Emoji = emoji;
        notifyListeners();
        _emojiTimer2?.cancel();
        _emojiTimer2 = Timer(const Duration(seconds: 3), () {
          player2Emoji = null;
          notifyListeners();
        });
      },
    );
    _multiplayerService!.isHost = isHost;
    _multiplayerService!.connect();

    SupabaseService.client
        .channel('full_sync_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_code',
            value: roomId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (isHost && newRecord['status'] == 'ready') {
              isWaitingForPlayer = false;
              notifyListeners();
            }
            if (!isHost && newRecord['status'] == 'playing' && !isGameActive) {
              isWaitingForPlayer = false;
              startMatchSequence(isRemoteTrigger: true);
            }
            if (!isHost && newRecord['food_x'] != -1) {
              food = Food(
                position: Position(
                  newRecord['food_x'] as int,
                  newRecord['food_y'] as int,
                ),
              );
              notifyListeners();
            }
          },
        )
        .subscribe();

    SupabaseService.client
        .from('game_rooms')
        .select()
        .eq('room_code', roomId)
        .maybeSingle()
        .then((data) {
          if (data != null) {
            if (isHost && data['status'] == 'ready') isWaitingForPlayer = false;
            if (!isHost && data['status'] == 'playing') {
              isWaitingForPlayer = false;
              startMatchSequence(isRemoteTrigger: true);
            }
            if (!isHost && data['food_x'] != -1 && data['food_x'] != null) {
              food = Food(
                position: Position(
                  data['food_x'] as int,
                  data['food_y'] as int,
                ),
              );
            }
            notifyListeners();
          }
        });
    if (isHost) _spawnInitialElements();
  }

  void startMatchSequence({bool isRemoteTrigger = false}) async {
    isWaitingForPlayer = false;
    if (isGameActive && startCountDown < 3) return;
    isGameActive = true;
    isPlaying = false;
    startCountDown = 3;
    notifyListeners();

    if (!isRemoteTrigger && (_multiplayerService?.isHost ?? false)) {
      await SupabaseService.client
          .from('game_rooms')
          .update({'status': 'playing'})
          .eq('room_code', currentRoomId!);
      _multiplayerService!.broadcastStart();
    }

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (startCountDown > 0) {
        startCountDown--;
        notifyListeners();
      } else {
        timer.cancel();
        _startMoving();
      }
    });
  }

  void resetGame({bool isRemoteTrigger = false}) async {
    remainingTime = initialDuration;
    isGameOver = false;
    winnerMessage = null;
    if (!isRemoteTrigger && (_multiplayerService?.isHost ?? false)) {
      await SupabaseService.client
          .from('game_rooms')
          .update({'status': 'ready'})
          .eq('room_code', currentRoomId!);
      _multiplayerService!.broadcastReplay();
    }
    initGame(
      currentGameType,
      onlineRoomId: currentRoomId,
      isHost: _multiplayerService?.isHost ?? true,
      startControlMode: controlMode,
      startWallPassing: enableWallPassing,
      startDuration: initialDuration,
      skipWaiting: true,
    );
  }

  void _startMoving() {
    isPlaying = true;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: baseTickMs), (
      timer,
    ) {
      _updateGameLoop();
    });
    _countDownTimer?.cancel();
    if (remainingTime != -1) {
      _countDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingTime > 0) {
          remainingTime--;
          notifyListeners();
        } else {
          _endGameTimeUp();
        }
      });
    }
  }

  void _updateGameLoop() {
    if (isGameOver) return;
    _tickCount++;
    bool shouldMove = false;
    if (player1.hasPowerUp(PowerUpType.turbo)) {
      shouldMove = true;
    } else if (_tickCount % 3 == 0) {
      shouldMove = true;
    }

    if (shouldMove) {
      _moveSnake(player1);
      if (currentGameType == GameType.online && _multiplayerService != null) {
        _multiplayerService!.broadcastMove(
          player1.head,
          player1.direction,
          player1.score,
        );
      }
      _canChangeDirection = true;
    }
    _checkCollisions(player1);

    if ((_multiplayerService?.isHost ?? true) && _tickCount % 500 == 0) {
      _spawnPowerUp();
    }
    notifyListeners();
  }

  void _moveSnake(Snake snake) {
    if (!snake.isAlive) return;
    Position currentHead = snake.head;
    int newX = currentHead.x;
    int newY = currentHead.y;
    switch (snake.direction) {
      case Direction.up:
        newY--;
        break;
      case Direction.down:
        newY++;
        break;
      case Direction.left:
        newX--;
        break;
      case Direction.right:
        newX++;
        break;
    }
    if (enableWallPassing) {
      if (newX < 0) newX = columns - 1;
      if (newX >= columns) newX = 0;
      if (newY < 0) newY = rows - 1;
      if (newY >= rows) newY = 0;
    }
    Position newHead = Position(newX, newY);
    if (snake.hasPowerUp(PowerUpType.magnet) && food != null) {
      int dx = (newHead.x - food!.position.x).abs();
      int dy = (newHead.y - food!.position.y).abs();
      if (dx <= 2 && dy <= 2) {
        newHead = food!.position;
      }
    }
    snake.body.insert(0, newHead);
    if (food != null && newHead == food!.position) {
      if (food!.type == FoodType.gold) {
        snake.score += 50;
      } else if (food!.type == FoodType.rotten) {
        snake.score = max(0, snake.score - 20);
        int removeCount = 5;
        while (removeCount > 0 && snake.body.length > 3) {
          snake.body.removeLast();
          removeCount--;
        }
      } else {
        snake.score += 10;
      }

      if (currentGameType == GameType.offline) {
        _spawnFood();
      } else if (currentGameType == GameType.online) {
        if (_multiplayerService?.isHost ?? false) {
          _spawnFood();
        } else {
          _multiplayerService!.broadcastEaten();
          food = null;
        }
      }
    } else {
      bool atePowerUp = false;
      for (int i = 0; i < boardPowerUps.length; i++) {
        if (newHead == boardPowerUps[i].position) {
          snake.activePowerUps[boardPowerUps[i].type] = DateTime.now().add(
            const Duration(seconds: 10),
          );
          boardPowerUps.removeAt(i);
          atePowerUp = true;
          break;
        }
      }
      if (!atePowerUp) {
        if (snake.body.length > (snake.score / 10) + 3) {
          snake.body.removeLast();
        }
      }
    }
  }

  void _checkCollisions(Snake snake) {
    Position head = snake.head;
    if (!enableWallPassing) {
      if (head.x < 0 || head.x >= columns || head.y < 0 || head.y >= rows) {
        _killSnake(snake, "Hit the Wall!");
        return;
      }
    }
    if (obstacles.contains(head)) {
      _killSnake(snake, "Hit an Obstacle!");
      return;
    }
    if (!snake.hasPowerUp(PowerUpType.ghost)) {
      for (int i = 1; i < snake.body.length; i++) {
        if (snake.body[i] == head) {
          _killSnake(snake, "Collision!");
          return;
        }
      }
      // Rival collision check removed as per user request: nothing happens when snakes hit each other.
    }
  }

  void _killSnake(Snake snake, String reason) {
    if (!snake.isAlive) return;
    snake.isAlive = false;
    if (snake == player1) {
      _endGame("You Lost! ($reason)");
      if (currentGameType == GameType.online && _multiplayerService != null) {
        _multiplayerService!.broadcastGameOver(
          player1.type == PlayerType.host ? "Guest" : "Host",
        );
      }
    } else {
      _endGame("You Won!");
      if (currentGameType == GameType.online && _multiplayerService != null) {
        _multiplayerService!.broadcastGameOver(
          player1.type == PlayerType.host ? "Host" : "Guest",
        );
      }
    }
  }

  void _spawnFood() async {
    final random = Random();
    int x, y;
    do {
      x = random.nextInt(columns);
      y = random.nextInt(rows);
    } while (_isPositionOccupied(Position(x, y)));
    FoodType type = FoodType.regular;
    int r = random.nextInt(100);
    if (r < 5) {
      type = FoodType.gold;
    } else if (r < 10) {
      type = FoodType.rotten;
    }

    food = Food(position: Position(x, y), type: type);
    if (currentGameType == GameType.online &&
        (_multiplayerService?.isHost ?? false)) {
      await SupabaseService.client
          .from('game_rooms')
          .update({'food_x': food!.position.x, 'food_y': food!.position.y})
          .eq('room_code', currentRoomId!);
      _multiplayerService!.broadcastFood(food!.position);
    }
    notifyListeners();
  }

  void _spawnPowerUp() {
    final random = Random();
    int x, y;
    do {
      x = random.nextInt(columns);
      y = random.nextInt(rows);
    } while (_isPositionOccupied(Position(x, y)));
    PowerUpType type =
        PowerUpType.values[random.nextInt(PowerUpType.values.length)];
    boardPowerUps.add(
      PowerUp(position: Position(x, y), type: type, spawnTime: DateTime.now()),
    );

    if (currentGameType == GameType.online &&
        (_multiplayerService?.isHost ?? false)) {
      _multiplayerService!.broadcastPowerUp(Position(x, y), type);
    }
    notifyListeners();
  }

  bool _isPositionOccupied(Position p) {
    bool p1 = player1.body.contains(p);
    bool p2 = player2?.body.contains(p) ?? false;
    bool obs = obstacles.contains(p);
    return p1 || p2 || obs;
  }

  void changeDirection(PlayerType player, Direction newDir) {
    if (!_canChangeDirection) return;
    Snake target = player1;
    if ((target.direction == Direction.left && newDir == Direction.right) ||
        (target.direction == Direction.right && newDir == Direction.left) ||
        (target.direction == Direction.up && newDir == Direction.down) ||
        (target.direction == Direction.down && newDir == Direction.up)) {
      return;
    }
    if (target.direction == newDir) return;
    target.direction = newDir;
    _canChangeDirection = false;
  }

  void _endGame(String message) {
    if (isGameOver) return;
    isGameOver = true;
    winnerMessage = message;
    isPlaying = false;
    _gameTimer?.cancel();
    _countDownTimer?.cancel();
    notifyListeners();
  }

  void _endGameTimeUp() {
    String msg;
    if (currentGameType == GameType.offline) {
      msg = "Time's Up! Score: ${player1.score}";
    } else {
      if (player1.score > player2!.score) {
        msg = "Time's Up! You Won";
      } else if (player2!.score > player1.score) {
        msg = "Time's Up! You Lost";
      } else {
        msg = "Time's Up! Draw";
      }
    }
    _endGame(msg);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _countDownTimer?.cancel();
    _multiplayerService?.leave();
    super.dispose();
  }

  Future<bool> createRoomOnServer(
    String roomCode,
    bool allowWallPass,
    int duration,
  ) async {
    try {
      await SupabaseService.client.from('game_rooms').insert({
        'room_code': roomCode,
        'status': 'waiting',
        'allow_wall_passing': allowWallPass,
        'game_duration': duration,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> joinRoomOnServer(String roomCode) async {
    try {
      final data = await SupabaseService.client
          .from('game_rooms')
          .select()
          .eq('room_code', roomCode)
          .maybeSingle();
      if (data == null) return null;
      await SupabaseService.client
          .from('game_rooms')
          .update({'status': 'ready'})
          .eq('room_code', roomCode);
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> performMatchmaking() async {
    try {
      final availableRoom = await SupabaseService.client
          .from('game_rooms')
          .select()
          .eq('status', 'waiting')
          .limit(1)
          .maybeSingle();
      if (availableRoom != null) {
        await SupabaseService.client
            .from('game_rooms')
            .update({'status': 'ready'})
            .eq('room_code', availableRoom['room_code']);
        return {...availableRoom, 'is_host': false};
      } else {
        String newRoomCode = (1000 + Random().nextInt(9000)).toString();
        await createRoomOnServer(newRoomCode, false, 120);
        final newRoom = await SupabaseService.client
            .from('game_rooms')
            .select()
            .eq('room_code', newRoomCode)
            .single();
        return {...newRoom, 'is_host': true};
      }
    } catch (e) {
      return null;
    }
  }
}
