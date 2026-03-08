import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // New state variables
  bool isPaused = false;
  int coins = 0;
  int lives = 0;
  int selectedBallIndex = 0;
  Color ballColor = const Color(0xFFFFF176);
  List<List<dynamic>> collectibleCoins = [];
  List<List<dynamic>> lifeCoins = [];

  @override
  void initState() {
    super.initState();
    _loadState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetGame();
      _startLoadingBar();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    gameLoop?.cancel();
    pipeSpawner?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      coins = prefs.getInt('coins') ?? 0;
      lives = prefs.getInt('lives') ?? 0;
      selectedBallIndex = prefs.getInt('selectedBallIndex') ?? 0;
      ballColor = _getBallColor(selectedBallIndex);
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', highScore);
    await prefs.setInt('coins', coins);
    await prefs.setInt('lives', lives);
    await prefs.setInt('selectedBallIndex', selectedBallIndex);
  }

  Color _getBallColor(int index) {
    // Logic to return the color based on the selected ball index
    switch (index) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.deepPurple;
      default:
        return const Color(0xFFFFF176); // Default color
    }
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
      isPaused = false;
    });

    _startGameLoops();
  }

  void _startGameLoops() {
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (gameOver || isPaused) {
        timer.cancel();
      } else {
        _updateGame();
        _checkCollision();
        _updateScore();
        setState(() {});
      }
    });

    pipeSpawner = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (gameOver || isPaused) {
        timer.cancel();
      } else {
        _addPipe();
        _addCollectible();
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
      isPaused = false;
      pipes.clear();
      collectibleCoins.clear();
      lifeCoins.clear();
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

    for (int i = 0; i < collectibleCoins.length; i++) {
      collectibleCoins[i][0] -= PIPE_SPEED;
    }
    collectibleCoins.removeWhere((coin) => coin[0] < -30);

    for (int i = 0; i < lifeCoins.length; i++) {
      lifeCoins[i][0] -= PIPE_SPEED;
    }
    lifeCoins.removeWhere((lifeCoin) => lifeCoin[0] < -30);
  }

  double _generateRandomPipeHeight() {
    return Random().nextDouble() * (screenHeight - PIPE_GAP - 100) + 50;
  }

  void _addPipe() {
    pipes.add([screenWidth, _generateRandomPipeHeight(), false]);
  }

  void _addCollectible() {
    if (pipes.isEmpty) return;

    final lastPipe = pipes.last;
    final topHeight = lastPipe[1];
    final collectibleY = topHeight + PIPE_GAP / 2 - 15; // center in gap

    final random = Random();
    final chance = random.nextInt(100);

    if (chance < 8) {
      // life coin chance reduced
      lifeCoins.add([screenWidth, collectibleY]);
    } else {
      collectibleCoins.add([screenWidth, collectibleY]);
    }
  }

  void _birdJump() {
    if (isPaused) {
      isPaused = false; // unpause
      _startGameLoops(); // resume
    }

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

    collectibleCoins.removeWhere((coin) {
      final coinX = coin[0];
      final coinY = coin[1];
      const coinSize = 30;
      if (birdX + BIRD_WIDTH > coinX &&
          birdX < coinX + coinSize &&
          birdY + BIRD_HEIGHT > coinY &&
          birdY < coinY + coinSize) {
        setState(() {
          coins++;
        });
        return true;
      }
      return false;
    });

    lifeCoins.removeWhere((lifeCoin) {
      final coinX = lifeCoin[0];
      final coinY = lifeCoin[1];
      const coinSize = 30;
      if (birdX + BIRD_WIDTH > coinX &&
          birdX < coinX + coinSize &&
          birdY + BIRD_HEIGHT > coinY &&
          birdY < coinY + coinSize) {
        setState(() {
          lives++;
        });
        return true;
      }
      return false;
    });
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
    }
    _saveState();

    setState(() {
      gameOver = true;
      gameStarted = false;
    });

    if (lives > 0) {
      _showContinueDialog();
    }
  }

  void _continueGame() {
    setState(() {
      lives--;
      gameOver = false;
      gameStarted = false;

      birdY = screenHeight / 2;
      birdVelocity = 0;

      pipes.clear();
      collectibleCoins.clear();
      lifeCoins.clear();
      pipes.add([screenWidth, _generateRandomPipeHeight(), false]);

      _saveState();
    });
  }

  void _showContinueDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.deepPurple, width: 4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Game Over',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You have $lives life(s) left.\nDo you want to continue from the beginning?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDialogButton('No, New Game', () {
                          Navigator.of(context).pop();
                          _resetGame();
                        }, color: Colors.red),
                        _buildDialogButton('Yes, Continue', () {
                          Navigator.of(context).pop();
                          _continueGame();
                        }, color: Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogButton(
    String text,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  void _togglePause() {
    if (!gameStarted || gameOver) return;
    setState(() {
      isPaused = !isPaused;
    });
    if (isPaused) {
      gameLoop?.cancel();
      pipeSpawner?.cancel();
    } else {
      _startGameLoops();
    }
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
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            if (showLoading) return;
            if (isPaused) {
              _birdJump();
            } else if (!gameOver) {
              _birdJump();
            } else {
              _resetGame();
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            // FIX: This now toggles the pause state
            _togglePause();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (showLoading) return;
          if (isPaused) {
            _birdJump();
          } else if (!gameOver) {
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
                      color: ballColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.sports_baseball,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              // FIX: Removed `&& !isPaused` from these conditions so they remain visible
              // when the game is paused.
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
                ...collectibleCoins.map((coin) {
                  return Positioned(
                    left: coin[0],
                    top: coin[1],
                    child: const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 30,
                    ),
                  );
                }),
              if (!showLoading)
                ...lifeCoins.map((lifeCoin) {
                  return Positioned(
                    left: lifeCoin[0],
                    top: lifeCoin[1],
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 30,
                    ),
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
              if (!showLoading && gameStarted)
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.deepPurple,
                      size: 40,
                    ),
                    onPressed: _togglePause,
                  ),
                ),
              if (!showLoading)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$coins',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.favorite, color: Colors.red, size: 28),
                      const SizedBox(width: 4),
                      Text(
                        '$lives',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
                            ? (lives > 0
                                  ? 'Game Over!\nUse a life to continue or Tap to Restart'
                                  : 'Game Over!\nTap or Press Space to Restart')
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
              if (isPaused)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Text(
                        'Paused\nPress Space or Tap to Continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
