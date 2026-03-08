// File: store_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int coins = 0;
  final List<Map<String, dynamic>> balls = [
    {'name': 'Default', 'color': Colors.orange, 'cost': 0, 'isUnlocked': true},
    {'name': 'Red Ball', 'color': Colors.red, 'cost': 500, 'isUnlocked': false},
    {
      'name': 'Blue Ball',
      'color': Colors.blue,
      'cost': 1000,
      'isUnlocked': false,
    },
    {
      'name': 'Purple Ball',
      'color': Colors.deepPurple,
      'cost': 2000,
      'isUnlocked': false,
    },
  ];
  int selectedBallIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStoreState();
  }

  Future<void> _loadStoreState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      coins = prefs.getInt('coins') ?? 0;
      selectedBallIndex = prefs.getInt('selectedBallIndex') ?? 0;
      for (int i = 0; i < balls.length; i++) {
        balls[i]['isUnlocked'] =
            prefs.getBool('ball_${i}_unlocked') ?? (i == 0);
      }
    });
  }

  Future<void> _saveStoreState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
    await prefs.setInt('selectedBallIndex', selectedBallIndex);
    for (int i = 0; i < balls.length; i++) {
      await prefs.setBool('ball_${i}_unlocked', balls[i]['isUnlocked']);
    }
  }

  void _buyBall(int index) {
    if (coins >= balls[index]['cost'] && !balls[index]['isUnlocked']) {
      setState(() {
        coins -= balls[index]['cost'] as int;
        balls[index]['isUnlocked'] = true;
      });
      _saveStoreState();
    }
  }

  void _selectBall(int index) {
    if (balls[index]['isUnlocked']) {
      setState(() {
        selectedBallIndex = index;
      });
      _saveStoreState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/city_bg.png', fit: BoxFit.cover),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Coins: $coins',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: balls.length,
                  itemBuilder: (context, index) {
                    final ball = balls[index];
                    final isSelected = index == selectedBallIndex;
                    final isUnlocked = ball['isUnlocked'] as bool;
                    final cost = ball['cost'] as int;
                    return GestureDetector(
                      onTap: () {
                        if (isUnlocked) {
                          _selectBall(index);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey,
                            width: isSelected ? 4 : 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sports_baseball,
                              color: ball['color'] as Color,
                              size: 80,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ball['name'] as String,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isUnlocked)
                              Text(
                                isSelected ? 'Selected' : 'Tap to Select',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.black,
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: () {
                                  if (coins >= cost) {
                                    _buyBall(index);
                                  } else {
                                    // Show a snackbar for insufficient coins
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Insufficient coins!'),
                                        duration: Duration(milliseconds: 1000),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: coins >= cost
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Buy ($cost)'),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.monetization_on, size: 18),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
