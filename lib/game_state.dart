class GameState {
  static int highScore = 0;
  static int coins = 0;
  static int lives = 0;
  static int selectedBallIndex = 0;

  // Store logic: ball index -> unlocked status
  static Map<int, bool> unlockedBalls = {0: true, 1: false, 2: false, 3: false};
}
