import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/settings_provider.dart';
import '../core/theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isNeon = settings.currentTheme == GameTheme.neon;

    return Scaffold(
      backgroundColor: isNeon ? Colors.black : AppTheme.classicBg,
      appBar: AppBar(
        title: Text(settings.getText('leaderboard')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: settings.getTopScores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No scores yet!",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final entry = snapshot.data![index];
              final color = _getRankColor(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isNeon
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                  border: isNeon
                      ? Border.all(color: color.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      "#${index + 1}",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        entry.playerName,
                        style: TextStyle(
                          color: isNeon ? Colors.white : AppTheme.classicSnake,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Text(
                      "${entry.score}",
                      style: TextStyle(
                        color: isNeon
                            ? AppTheme.neonGreen
                            : AppTheme.classicSnake,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey;
    if (index == 2) return Colors.brown;
    return Colors.blue;
  }
}
