import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';

// --- Models ---

class Pipe {
  double x;
  double topHeight;
  bool scored;

  Pipe({required this.x, required this.topHeight, this.scored = false});
}

class Coin {
  double x;
  double y;
  bool isLife; // true for heart, false for coin

  Coin({required this.x, required this.y, this.isLife = false});
}

// --- Game Screen ---

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  // Constants
  static const double GRAVITY = 0.6;
  static const double JUMP = -12.0;
  static const double PIPE_SPEED = 4.0; // pixels per frame (approx 60fps)
  static const double PIPE_GAP = 300.0; // large gap for easier gameplay
  static const double PIPE_WIDTH = 60.0;
  static const double BIRD_WIDTH = 40.0;
  static const double BIRD_HEIGHT = 40.0;
  static const double PIPE_SPAWN_INTERVAL = 2.0; // seconds

  // Game state
  double birdY = 0;
  double birdVelocity = 0;
  int score = 0;
  int highScore = 0;
  bool gameStarted = false;
  bool gameOver = false;

  // Typed Lists
  List<Pipe> pipes = [];
  List<Coin> coinsObjects = [];

  // Cached screen values
  double screenWidth = 0;
  double screenHeight = 0;
  double birdX = 0;

  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _timeSinceLastPipe = 0;
  double _timeAccumulator = 0.0;

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
  Color ballColor = Colors.orange; // Default matches StoreScreen

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadState();

    // Defer initialization requiring context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Calculate birdX based on screen size
      final size = MediaQuery.of(context).size;
      screenWidth = size.width;
      screenHeight = size.height;
      birdX = screenWidth / 2 - BIRD_WIDTH / 2;

      _resetGame();
      _startLoadingBar();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    if (!mounted) return;
    setState(() {
      highScore = GameState.highScore;
      coins = GameState.coins;
      lives = GameState.lives;
      selectedBallIndex = GameState.selectedBallIndex;
      ballColor = _getBallColor(selectedBallIndex);
    });
  }

  Future<void> _saveState() async {
    GameState.highScore = highScore;
    GameState.coins = coins;
    GameState.lives = lives;
    GameState.selectedBallIndex = selectedBallIndex;
  }

  Color _getBallColor(int index) {
    switch (index) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.deepPurple;
      case 0:
      default:
        return Colors.orange; // Consistent with StoreScreen
    }
  }

  void _startLoadingBar() {
    setState(() {
      showLoading = true;
      loadingValue = 0;
    });
    // Use a simple timer for loading animation (UI only)
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (loadingValue >= 100) {
        timer.cancel();
        setState(() {
          showLoading = false;
        });
      } else {
        setState(() {
          loadingValue += 2; // Faster loading
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
      _lastTick = Duration.zero;
      _timeSinceLastPipe = 0;
      _timeAccumulator = 0.0;
    });

    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _resetGame() {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    birdX = screenWidth / 2 - BIRD_WIDTH / 2;

    _ticker.stop();

    setState(() {
      birdY = screenHeight / 2;
      birdVelocity = 0;
      score = 0;
      gameStarted = false;
      gameOver = false;
      isPaused = false;

      pipes.clear();
      coinsObjects.clear();

      // Initialize with one pipe
      pipes.add(Pipe(x: screenWidth, topHeight: _generateRandomPipeHeight()));

      _lastTick = Duration.zero;
      _timeSinceLastPipe = 0;
      _timeAccumulator = 0.0;
    });
  }

  void _onTick(Duration elapsed) {
    if (gameOver || isPaused || !gameStarted) return;

    double dt = 0.016;
    if (_lastTick != Duration.zero) {
      dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    }
    _lastTick = elapsed;

    // Fixed time step update (60 FPS)
    _timeAccumulator += dt;
    const double step = 1 / 60.0;

    while (_timeAccumulator >= step) {
      _updateGame();
      _checkCollision();
      _updateScore();
      _timeAccumulator -= step;

      // Pipe spawning logic inside the fixed loop to track game time
      _timeSinceLastPipe += step;
      if (_timeSinceLastPipe >= PIPE_SPAWN_INTERVAL) {
        _addPipe();
        _addCollectible();
        _timeSinceLastPipe = 0;
      }
    }

    setState(() {});
  }

  void _updateGame() {
    birdVelocity += GRAVITY;
    birdY += birdVelocity;

    // Move pipes
    for (var pipe in pipes) {
      pipe.x -= PIPE_SPEED;
    }
    pipes.removeWhere((pipe) => pipe.x < -PIPE_WIDTH);

    // Move coins
    for (var coin in coinsObjects) {
      coin.x -= PIPE_SPEED;
    }
    coinsObjects.removeWhere((coin) => coin.x < -30);
  }

  double _generateRandomPipeHeight() {
    // Ensure pipes are within screen bounds with some margin
    final double minHeight = 50.0;
    final double maxHeight = screenHeight - PIPE_GAP - minHeight;
    // Safety check if screen is too small
    if (maxHeight <= minHeight) return minHeight;

    return Random().nextDouble() * (maxHeight - minHeight) + minHeight;
  }

  void _addPipe() {
    pipes.add(Pipe(x: screenWidth, topHeight: _generateRandomPipeHeight()));
  }

  void _addCollectible() {
    if (pipes.isEmpty) return;

    final lastPipe = pipes.last;
    final topHeight = lastPipe.topHeight;
    final collectibleY = topHeight + PIPE_GAP / 2 - 15; // center in gap

    final random = Random();
    final chance = random.nextInt(100);

    // 8% chance for life, else normal coin
    bool isLife = (chance < 8);

    coinsObjects.add(
      Coin(
        x:
            screenWidth +
            (PIPE_WIDTH / 2) -
            15, // Center horizontally in pipe? or just after? Original code: screenWidth.
        y: collectibleY,
        isLife: isLife,
      ),
    );
  }

  void _birdJump() {
    if (showLoading) return;

    if (isPaused) {
      _togglePause();
      return;
    }

    if (!gameStarted) {
      _startGame();
    }
    birdVelocity = JUMP;
  }

  void _checkCollision() {
    // Floor/Ceiling collision
    if (birdY < 0 || birdY + BIRD_HEIGHT > screenHeight) {
      _endGame();
      return;
    }

    // Pipe collision
    final birdRect = Rect.fromLTWH(birdX, birdY, BIRD_WIDTH, BIRD_HEIGHT);

    for (var pipe in pipes) {
      final pipeX = pipe.x;
      final topHeight = pipe.topHeight;
      final bottomY = topHeight + PIPE_GAP;

      // Top pipe rect
      final topPipeRect = Rect.fromLTWH(pipeX, 0, PIPE_WIDTH, topHeight);
      // Bottom pipe rect
      final bottomPipeRect = Rect.fromLTWH(
        pipeX,
        bottomY,
        PIPE_WIDTH,
        screenHeight - bottomY,
      );

      if (birdRect.overlaps(topPipeRect) || birdRect.overlaps(bottomPipeRect)) {
        _endGame();
        return;
      }
    }

    // Coin collection
    coinsObjects.removeWhere((coin) {
      final coinRect = Rect.fromLTWH(coin.x, coin.y, 30, 30);
      if (birdRect.overlaps(coinRect)) {
        if (coin.isLife) {
          setState(() {
            lives++;
          });
        } else {
          setState(() {
            coins++;
          });
        }
        return true; // Remove collected coin
      }
      return false;
    });
  }

  void _updateScore() {
    for (var pipe in pipes) {
      if (!pipe.scored && pipe.x + PIPE_WIDTH < birdX) {
        pipe.scored = true;
        score++;
      }
    }
  }

  void _endGame() {
    _ticker.stop();

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
      gameStarted = false; // Need to jump to start?

      birdY = screenHeight / 2;
      birdVelocity = 0;

      pipes.clear();
      coinsObjects.clear();

      // Add initial pipe
      pipes.add(Pipe(x: screenWidth, topHeight: _generateRandomPipeHeight()));

      _saveState();

      // Restart ticker
      // _ticker.start(); // Wait for user to tap to start?
      // Original logic seemed to wait for tap.
    });
    // If we want immediate continue:
    // _startGame();
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
                      'You have $lives life(s) left.\nDo you want to continue?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDialogButton('No', () {
                          Navigator.of(context).pop();
                          _resetGame();
                        }, color: Colors.red),
                        _buildDialogButton('Yes', () {
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
      _ticker.stop();
    } else {
      _lastTick = Duration.zero; // Reset tick tracking to avoid jump
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only update screen dimensions if context is valid and layout ready
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            if (gameOver) {
              if (lives <= 0) _resetGame(); // Allow restart if no lives dialog
            } else {
              _birdJump();
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            _togglePause();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (gameOver) {
            if (lives <= 0) _resetGame();
          } else {
            _birdJump();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              // Background
              Positioned.fill(
                child: Image.asset('assets/city_bg.png', fit: BoxFit.cover),
              ),

              // Pipes
              if (!showLoading)
                ...pipes.map((pipe) {
                  return Positioned(
                    left: pipe.x,
                    top: 0,
                    bottom: 0, // Ensure strictly positioned
                    width: PIPE_WIDTH,
                    child: PipeWidget(
                      topHeight: pipe.topHeight,
                      pipeGap: PIPE_GAP,
                      pipeWidth: PIPE_WIDTH,
                      screenHeight: screenHeight,
                    ),
                  );
                }),

              // Coins & Lives
              if (!showLoading)
                ...coinsObjects.map((coin) {
                  return Positioned(
                    left: coin.x,
                    top: coin.y,
                    child: Icon(
                      coin.isLife ? Icons.favorite : Icons.monetization_on,
                      color: coin.isLife ? Colors.red : Colors.amber,
                      size: 30,
                    ),
                  );
                }),

              // Bird
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

              // Score
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

              // UI Overlay (Lives/Coins)
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

              // High Score
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

              // Pause Button
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

              // Loading Screen
              if (showLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
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
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Game Over / Start Screen
              if (!gameStarted &&
                  !showLoading &&
                  !showLoading) // showLoading check repeated for clarity
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
                                  ? 'Use a life to continue' // Dialog shows up anyway
                                  : 'Game Over!\nTap to Restart')
                            : 'Tap to Play!',
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

              // Paused Overlay
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
                        'Paused',
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
  final double topHeight;
  final double pipeGap;
  final double pipeWidth;
  final double screenHeight;

  const PipeWidget({
    super.key,
    required this.topHeight,
    required this.pipeGap,
    required this.pipeWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
        ),
        SizedBox(height: pipeGap),
        Expanded(
          child: Container(
            width: pipeWidth,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
