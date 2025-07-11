import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(MurphWorkoutApp());
}

class MurphWorkoutApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WorkoutScreen(),
    );
  }
}

class WorkoutScreen extends StatefulWidget {
  @override
  _WorkoutScreenState createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int baseReps = 5; // Initial base reps (5 pull-ups, 10 push-ups, 15 squats)
  int currentPullUps = 0; // Track total pull-ups completed
  final int totalPullUpsGoal = 100; // New total goal of 100 pull-ups
  Timer? timer;
  int secondsElapsed = 0;
  bool isRunning = false;
  final AudioPlayer audioPlayer = AudioPlayer();
  List<String> workoutLogs = [];
  List<int> roundTimes = []; // Track time for each round
  int lastRoundTime = 0; // Time when last round was completed
  bool workoutCompleted = false;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  void startWorkout() {
    if (!isRunning) {
      setState(() {
        isRunning = true;
      });
      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          secondsElapsed++;
        });
      });
      playClickSound();
    }
  }

  Future<void> resetWorkout() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Reset'),
            content:
                Text('Are you sure? This will delete all progress and logs!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reset'),
              ),
            ],
          ),
        ) ??
        false) {
      timer?.cancel();
      setState(() {
        currentPullUps = 0;
        secondsElapsed = 0;
        isRunning = false;
        baseReps = 5;
        workoutLogs.clear();
        roundTimes.clear();
        lastRoundTime = 0;
        workoutCompleted = false;
        saveLogs();
      });
      playClickSound();
    }
  }

  void completeRound() {
    if (currentPullUps < totalPullUpsGoal) {
      int roundTime = secondsElapsed - lastRoundTime;
      roundTimes.add(roundTime);
      
      setState(() {
        currentPullUps += baseReps;
        if (currentPullUps >= totalPullUpsGoal) {
          currentPullUps = totalPullUpsGoal; // Cap at 100
          workoutCompleted = true;
          timer?.cancel();
          isRunning = false;
        }
        
        double avgRoundTime = roundTimes.isNotEmpty 
            ? roundTimes.reduce((a, b) => a + b) / roundTimes.length 
            : 0;
        
        String log = 'Round ${roundTimes.length} completed at ${formatTime(secondsElapsed)} - '
            'Reps: $baseReps/${baseReps * 2}/${baseReps * 3}, '
            'Round time: ${formatTime(roundTime)}, '
            'Avg round time: ${formatTime(avgRoundTime.round())}, '
            'Total Pull-ups: $currentPullUps/$totalPullUpsGoal';
        workoutLogs.add(log);
        
        lastRoundTime = secondsElapsed;
        saveLogs();
      });
      
      if (workoutCompleted) {
        _showCompletionDialog();
      }
      
      playClickSound();
    }
  }

  void adjustReps(int change) {
    setState(() {
      baseReps = (baseReps + change).clamp(1, 20); // Limit between 1 and 20
    });
    playClickSound();
  }

  void playClickSound() async {
    await audioPlayer.play(AssetSource('click.wav')); // Add click.wav to assets
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void saveLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('workoutLogs', workoutLogs);
  }

  void loadLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      workoutLogs = prefs.getStringList('workoutLogs') ?? [];
    });
  }

  void navigateToLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LogScreen(
        logs: workoutLogs,
        roundTimes: roundTimes,
        totalTime: secondsElapsed,
        workoutCompleted: workoutCompleted,
        baseReps: baseReps,
      )),
    );
  }

  void _showCompletionDialog() {
    double avgRoundTime = roundTimes.isNotEmpty 
        ? roundTimes.reduce((a, b) => a + b) / roundTimes.length 
        : 0;
    int totalRounds = roundTimes.length;
    int fastestRound = roundTimes.isNotEmpty ? roundTimes.reduce((a, b) => a < b ? a : b) : 0;
    int slowestRound = roundTimes.isNotEmpty ? roundTimes.reduce((a, b) => a > b ? a : b) : 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('🎉 MURPH COMPLETED! 🎉', 
                   style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Congratulations! You completed the Murph workout!', 
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Text('📊 WORKOUT STATS:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('⏱️ Total Time: ${formatTime(secondsElapsed)}'),
            Text('🔄 Total Rounds: $totalRounds'),
            Text('📈 Average Round Time: ${formatTime(avgRoundTime.round())}'),
            Text('⚡ Fastest Round: ${formatTime(fastestRound)}'),
            Text('🐌 Slowest Round: ${formatTime(slowestRound)}'),
            SizedBox(height: 10),
            Text('💪 Total Reps Completed:'),
            Text('  • Pull-ups: $currentPullUps'),
            Text('  • Push-ups: ${currentPullUps * 2}'),
            Text('  • Squats: ${currentPullUps * 3}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              navigateToLogs();
            },
            child: Text('View Detailed Logs'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Murph Workout - Cindy Method'),
        backgroundColor: Colors.lightBlue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatTime(secondsElapsed),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Pull-ups $currentPullUps of $totalPullUpsGoal'),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: currentPullUps / totalPullUpsGoal,
              backgroundColor: Colors.grey[300],
              color: Colors.lightBlue,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text('Pull-ups', style: TextStyle(color: Colors.blue)),
                    Text('$baseReps', style: TextStyle(fontSize: 24)),
                  ],
                ),
                SizedBox(width: 20),
                Column(
                  children: [
                    Text('Push-ups', style: TextStyle(color: Colors.green)),
                    Text('${baseReps * 2}', style: TextStyle(fontSize: 24)),
                  ],
                ),
                SizedBox(width: 20),
                Column(
                  children: [
                    Text('Squats', style: TextStyle(color: Colors.red)),
                    Text('${baseReps * 3}', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => adjustReps(-1),
                  child: Text('-'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => adjustReps(1),
                  child: Text('+'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: workoutCompleted 
                  ? navigateToLogs 
                  : (isRunning ? completeRound : startWorkout),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(250, 150), // Big button for easy pressing
                textStyle: TextStyle(fontSize: 25),
                backgroundColor: workoutCompleted ? Colors.green : null,
              ),
              child: Text(workoutCompleted 
                  ? 'View Logs' 
                  : (isRunning ? 'Complete Round' : 'Start Workout')),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: resetWorkout,
              child: Text('Reset'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: navigateToLogs,
              child: Text('View Logs'),
            ),
          ],
        ),
      ),
    );
  }
}

class LogScreen extends StatelessWidget {
  final List<String> logs;
  final List<int> roundTimes;
  final int totalTime;
  final bool workoutCompleted;
  final int baseReps;

  LogScreen({
    required this.logs,
    this.roundTimes = const [],
    this.totalTime = 0,
    this.workoutCompleted = false,
    this.baseReps = 5,
  });

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    double avgRoundTime = roundTimes.isNotEmpty 
        ? roundTimes.reduce((a, b) => a + b) / roundTimes.length 
        : 0;
    int totalRounds = roundTimes.length;
    int fastestRound = roundTimes.isNotEmpty ? roundTimes.reduce((a, b) => a < b ? a : b) : 0;
    int slowestRound = roundTimes.isNotEmpty ? roundTimes.reduce((a, b) => a > b ? a : b) : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(workoutCompleted ? 'Workout Complete! 🎉' : 'Workout Logs'),
        backgroundColor: workoutCompleted ? Colors.green : Colors.lightBlue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (workoutCompleted && roundTimes.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🏆 FINAL STATISTICS', 
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⏱️ Total Time: ${formatTime(totalTime)}'),
                              Text('🔄 Rounds: $totalRounds'),
                              Text('📈 Avg Round: ${formatTime(avgRoundTime.round())}'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⚡ Fastest: ${formatTime(fastestRound)}'),
                              Text('🐌 Slowest: ${formatTime(slowestRound)}'),
                              Text('💪 Pull-ups: 100'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                      backgroundColor: Colors.lightBlue.shade100,
                    ),
                    title: Text(logs[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
