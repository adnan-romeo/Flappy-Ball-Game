import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FlappyBirdApp());
}

class FlappyBirdApp extends StatelessWidget {
  const FlappyBirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Constants
  static const double GRAVITY = 0.6;
  static const double JUMP = -12;
  static const double PIPE_SPEED = 4;
  static const double PIPE_GAP = 300;
  static const double PIPE_WIDTH = 60;
  static const double BIRD_WIDTH = 40;
  static const double BIRD_HEIGHT = 40;

  // Game state
  double birdY = 0;
  double birdVelocity = 0;
  int score = 0;
  int highScore = 0;
  bool gameStarted = false;
  bool gameOver = false;
  List<List<dynamic>> pipes = []; // [x, topHeight, scored]

  // Cached screen values
  double screenWidth = 0;
  double screenHeight = 0;
  double birdX = 0;

  Timer? gameLoop;
  Timer? pipeSpawner;

  // Loading bar state
  bool showLoading = true;
  double loadingValue = 0;

  // Keyboard control
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetGame();
      _startLoadingBar();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', highScore);
  }

  void _startLoadingBar() {
    setState(() {
      showLoading = true;
      loadingValue = 0;
    });
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (loadingValue >= 100) {
        timer.cancel();
        setState(() {
          showLoading = false;
        });
      } else {
        setState(() {
          loadingValue += 1;
        });
      }
    });
  }

  void _startGame() {
    if (gameStarted || gameOver) return;

    setState(() {
      gameStarted = true;
      gameOver = false;
    });

    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (gameOver) {
        timer.cancel();
      } else {
        _updateGame();
        _checkCollision();
        _updateScore();
        setState(() {});
      }
    });

    pipeSpawner = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (gameOver) {
        timer.cancel();
      } else {
        _addPipe();
        setState(() {});
      }
    });
  }

  void _resetGame() {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    birdX = screenWidth / 2 - BIRD_WIDTH / 2;

    setState(() {
      birdY = screenHeight / 2;
      birdVelocity = 0;
      score = 0;
      gameStarted = false;
      gameOver = false;
      pipes.clear();
      pipes.add([screenWidth, _generateRandomPipeHeight(), false]);
    });
  }

  void _updateGame() {
    birdVelocity += GRAVITY;
    birdY += birdVelocity;

    for (int i = 0; i < pipes.length; i++) {
      pipes[i][0] -= PIPE_SPEED;
    }
    pipes.removeWhere((pipe) => pipe[0] < -PIPE_WIDTH);
  }

  double _generateRandomPipeHeight() {
    return Random().nextDouble() * 300 + 50;
  }

  void _addPipe() {
    pipes.add([screenWidth, _generateRandomPipeHeight(), false]);
  }

  void _birdJump() {
    if (!gameStarted) {
      _startGame();
    }
    birdVelocity = JUMP;
  }

  void _checkCollision() {
    if (birdY < 0 || birdY + BIRD_HEIGHT > screenHeight) {
      _endGame();
      return;
    }

    for (var pipe in pipes) {
      final pipeX = pipe[0];
      final topHeight = pipe[1];
      final bottomY = topHeight + PIPE_GAP;

      if (birdX + BIRD_WIDTH > pipeX && birdX < pipeX + PIPE_WIDTH) {
        if (birdY < topHeight || birdY + BIRD_HEIGHT > bottomY) {
          _endGame();
          return;
        }
      }
    }
  }

  void _updateScore() {
    for (var pipe in pipes) {
      if (!pipe[2] && pipe[0] + PIPE_WIDTH < birdX) {
        pipe[2] = true;
        score++;
      }
    }
  }

  void _endGame() {
    gameLoop?.cancel();
    pipeSpawner?.cancel();

    if (score > highScore) {
      highScore = score;
      _saveHighScore();
    }

    setState(() {
      gameOver = true;
      gameStarted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    birdX = screenWidth / 2 - BIRD_WIDTH / 2;

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.space)) {
          if (showLoading) return;
          if (!gameOver) {
            _birdJump();
          } else {
            _resetGame();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (showLoading) return;
          if (!gameOver) {
            _birdJump();
          } else {
            _resetGame();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset('assets/city_bg.png', fit: BoxFit.cover),
              ),
              if (!showLoading)
                Positioned(
                  top: 32,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'High: $highScore',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!showLoading)
                Positioned(
                  left: birdX,
                  top: birdY,
                  child: Container(
                    width: BIRD_WIDTH,
                    height: BIRD_HEIGHT,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF176), Color(0xFFFFA000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: const Icon(
                      Icons.sports_baseball,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                ),
              if (!showLoading)
                ...pipes.map((pipe) {
                  return PipeWidget(
                    x: pipe[0],
                    topHeight: pipe[1],
                    pipeGap: PIPE_GAP,
                    pipeWidth: PIPE_WIDTH,
                    screenHeight: screenHeight,
                  );
                }),
              if (!showLoading)
                Positioned(
                  top: 36,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        score.toString(),
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showLoading)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 200,
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: LinearProgressIndicator(
                                value: loadingValue / 100,
                                minHeight: 30,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF7F7FD5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Loading: ${loadingValue.toInt()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: loadingValue >= 100
                                ? () {
                                    setState(() {
                                      showLoading = false;
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7F7FD5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Start'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!gameStarted && !showLoading)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Text(
                        gameOver
                            ? 'Game Over!\nTap or Press Space to Restart'
                            : 'Tap or Press Space to Play!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PipeWidget extends StatelessWidget {
  final double x;
  final double topHeight;
  final double pipeGap;
  final double pipeWidth;
  final double screenHeight;

  const PipeWidget({
    super.key,
    required this.x,
    required this.topHeight,
    required this.pipeGap,
    required this.pipeWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: 0,
      child: Column(
        children: [
          Container(
            width: pipeWidth,
            height: topHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 2),
          ),
          SizedBox(height: pipeGap),
          Container(
            width: pipeWidth,
            height: screenHeight - topHeight - pipeGap,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            margin: const EdgeInsets.only(top: 2),
          ),
        ],
      ),
    );
  }
}
