import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client.dart';
import '../models/game_state.dart';

class MultiplayerService {
  late RealtimeChannel _channel;
  final String roomId;
  final Function(Position remoteHead, Direction remoteDir, int score)
  onOpponentMove;
  final Function(String winner) onGameOver;
  final VoidCallback onStartGame;
  final Function(Position foodPos) onFoodSpawn;
  final Function(Position puPos, PowerUpType type) onPowerUpSpawn;
  final VoidCallback onReplayRequest;
  final VoidCallback onOpponentEaten;
  final Function(String emoji) onOpponentEmoji;

  bool isHost = false;

  MultiplayerService({
    required this.roomId,
    required this.onOpponentMove,
    required this.onGameOver,
    required this.onStartGame,
    required this.onFoodSpawn,
    required this.onPowerUpSpawn,
    required this.onReplayRequest,
    required this.onOpponentEaten,
    required this.onOpponentEmoji,
  });

  Future<void> connect() async {
    _channel = SupabaseService.client.channel('game_room_$roomId');

    _channel
        .onBroadcast(
          event: 'movement',
          callback: (p) {
            if (p['sender'] != (isHost ? 'host' : 'guest')) {
              onOpponentMove(
                Position(p['x'], p['y']),
                Direction.values[p['dir']],
                p['score'],
              );
            }
          },
        )
        .onBroadcast(
          event: 'game_over',
          callback: (p) {
            onGameOver(p['winner']);
          },
        )
        .onBroadcast(
          event: 'start_game',
          callback: (_) {
            onStartGame();
          },
        )
        .onBroadcast(
          event: 'food_spawn',
          callback: (p) {
            onFoodSpawn(Position(p['x'], p['y']));
          },
        )
        .onBroadcast(
          event: 'powerup_spawn',
          callback: (p) {
            onPowerUpSpawn(
              Position(p['x'], p['y']),
              PowerUpType.values[p['type']],
            );
          },
        )
        .onBroadcast(
          event: 'replay_match',
          callback: (_) {
            if (!isHost) {
              onReplayRequest();
            }
          },
        )
        .onBroadcast(
          event: 'i_ate_food',
          callback: (_) {
            if (isHost) {
              onOpponentEaten();
            }
          },
        )
        .onBroadcast(
          event: 'emoji',
          callback: (p) {
            if (p['sender'] != (isHost ? 'host' : 'guest')) {
              onOpponentEmoji(p['emoji']);
            }
          },
        )
        .subscribe();
  }

  Future<void> broadcastMove(
    Position head,
    Direction dir,
    int currentScore,
  ) async {
    await _channel.sendBroadcastMessage(
      event: 'movement',
      payload: {
        'sender': isHost ? 'host' : 'guest',
        'x': head.x,
        'y': head.y,
        'dir': dir.index,
        'score': currentScore,
      },
    );
  }

  Future<void> broadcastStart() async =>
      await _channel.sendBroadcastMessage(event: 'start_game', payload: {});
  Future<void> broadcastFood(Position pos) async =>
      await _channel.sendBroadcastMessage(
        event: 'food_spawn',
        payload: {'x': pos.x, 'y': pos.y},
      );

  Future<void> broadcastPowerUp(Position pos, PowerUpType type) async {
    await _channel.sendBroadcastMessage(
      event: 'powerup_spawn',
      payload: {'x': pos.x, 'y': pos.y, 'type': type.index},
    );
  }

  Future<void> broadcastEaten() async =>
      await _channel.sendBroadcastMessage(event: 'i_ate_food', payload: {});
  Future<void> broadcastReplay() async =>
      await _channel.sendBroadcastMessage(event: 'replay_match', payload: {});
  Future<void> broadcastGameOver(String winner) async => await _channel
      .sendBroadcastMessage(event: 'game_over', payload: {'winner': winner});

  Future<void> broadcastEmoji(String emoji) async {
    await _channel.sendBroadcastMessage(
      event: 'emoji',
      payload: {'sender': isHost ? 'host' : 'guest', 'emoji': emoji},
    );
  }

  Future<void> leave() async {
    await SupabaseService.client.removeChannel(_channel);
  }
}
