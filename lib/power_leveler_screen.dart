import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

double roundToPrecision(double value, int precision) {
  return double.parse(value.toStringAsFixed(precision));
}

class CardData {
  final int? edhrecRank;
  final double edhrecSaltiness;

  CardData({required this.edhrecRank, required this.edhrecSaltiness});

  double get rankScore {
    if (edhrecRank == null || edhrecRank == 0) return 0.0;
    return roundToPrecision(1.0 - (1.0 / edhrecRank!), 15);
  }

  double get saltinessScore {
    return roundToPrecision(edhrecSaltiness, 15);
  }

  double get weightedScore {
    return roundToPrecision((0.5 * rankScore) + (0.5 * saltinessScore), 15);
  }
}

double calculateDeckScore(
    Map<String, int> decklist, Map<String, CardData> cardData,
    {bool debug = false}) {
  const basicLands = {'Island', 'Mountain', 'Forest', 'Plains', 'Swamp'};
  double totalScore = 0.0;
  int totalQuantity = 0;

  for (var entry in decklist.entries) {
    final cardName = entry.key;
    final quantity = entry.value;

    if (basicLands.contains(cardName)) continue;

    final card = cardData[cardName];
    if (card != null) {
      double weightedScore = card.weightedScore;
      totalScore += roundToPrecision(weightedScore * quantity, 15);
      totalQuantity += quantity;

      if (debug) {
        print(
            'Card: $cardName, Quantity: $quantity, Weighted Score: $weightedScore, Total Score: $totalScore, Total Quantity: $totalQuantity');
      }
    }
  }

  if (totalQuantity > 0) {
    double normalizedScore =
        roundToPrecision((totalScore / totalQuantity) * 9.0 + 1.0, 2);
    if (debug) {
      print('Final Deck Score (Dart): $normalizedScore');
    }
    return normalizedScore.clamp(1.0, 10.0);
  } else {
    return 1.0;
  }
}

class PowerLevelerScreen extends StatefulWidget {
  @override
  _PowerLevelerScreenState createState() => _PowerLevelerScreenState();
}

class _PowerLevelerScreenState extends State<PowerLevelerScreen> {
  final TextEditingController decklistController = TextEditingController();
  double? deckScore;
  String statusMessage =
      'Paste your decklist below and calculate the power level!';

  Future<Map<String, CardData>> loadAtomicCardData() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/AtomicCards.json');
    final data =
        jsonDecode(await file.readAsString())['data'] as Map<String, dynamic>;

    return data.map<String, CardData>((key, value) {
      final cardInfo = (value as List).first as Map<String, dynamic>;
      return MapEntry(
        key,
        CardData(
          edhrecRank: cardInfo['edhrecRank'] as int?,
          edhrecSaltiness: (cardInfo['edhrecSaltiness'] ?? 0.0) as double,
        ),
      );
    });
  }

  Map<String, int> parseDecklist(String decklistText) {
    final decklist = <String, int>{};
    final lines = decklistText.split('\n');

    for (var line in lines) {
      final match = RegExp(r'(\d+)\s+([^\n]+?)\s*(?=(//|$))').firstMatch(line);
      if (match != null) {
        final quantity = int.parse(match.group(1)!);
        final cardName = match.group(2)!.trim();
        decklist[cardName] = (decklist[cardName] ?? 0) + quantity;
      }
    }

    // Debug: print the parsed decklist
    print("Parsed Decklist (Dart):");
    decklist.forEach((card, qty) {
      print("$card: $qty");
    });

    return decklist;
  }

  Future<void> loadAndCalculateScore({bool debug = false}) async {
    setState(() {
      statusMessage = 'Loading data and calculating score...';
    });

    try {
      final cardData = await loadAtomicCardData();
      final decklistText = decklistController.text;
      final decklist = parseDecklist(decklistText);
      final score = calculateDeckScore(decklist, cardData, debug: debug);

      setState(() {
        deckScore = score;
        statusMessage =
            'Deck Custom Weighted Avg Score: ${score.toStringAsFixed(2)} / 10';
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error loading data: $e';
      });
    }
  }

  void showAlgorithmInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Power Leveler Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 16,
                        color: const Color.fromARGB(255, 255, 255, 255)),
                    children: [
                      TextSpan(
                        text:
                            'The Power Leveler checks your deck’s strength on a scale from 1 to 10. It uses data on how popular and "frustrating" each card is, based on info from EDHREC: ',
                      ),
                      TextSpan(
                        text: 'edhrec.com/top/salt',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final Uri url =
                                Uri.parse('https://edhrec.com/top/salt');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.inAppWebView,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Could not launch $url')),
                              );
                            }
                          },
                      ),
                      TextSpan(
                        text: '.',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),
                Text(
                  'How it works:',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  '1. Checking Card Popularity:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '   - Each card is checked to see how often people use it, giving it a "rank score." The more popular the card, the higher the score.',
                ),
                Text(
                  '   - Cards that don’t have a popularity rank are given a score of 0.',
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  '2. Checking Card "Saltiness":',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '   - Each card’s "saltiness" shows how frustrating or annoying it is to play against. The more annoying, the higher the saltiness score.',
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  '3. Combining Scores:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '   - For each card, we combine its popularity and saltiness scores. This gives each card a "strength score" based on how popular and frustrating it is.',
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  '4. Adding Up Card Scores:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '   - We multiply each card’s strength score by how many times it appears in your deck. Then, we add up these scores for all the cards in your deck.',
                ),
                Text(
                  '   - We also count the total number of cards in the deck (ignoring basic lands).',
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  '5. Final Deck Score:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '   - We adjust the total score to fit on a scale from 1 to 10. If there are no cards, the score is 1.',
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Result:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '   - Your deck’s final score is shown as a number from 1 to 10, based on the total popularity and saltiness of the cards you included.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Got it'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define a custom color scheme
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Power Leveler'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            tooltip: 'Algorithm Info',
            onPressed: showAlgorithmInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Message
                Text(
                  statusMessage,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        fontSize: 20,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Decklist Input
                TextField(
                  controller: decklistController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: 'Paste Decklist Here',
                    hintText:
                        'e.g.,\n1 Lightning Bolt\n2 Path to Exile\n1 Sol Ring',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                // Calculate Button
                ElevatedButton.icon(
                  onPressed: () => loadAndCalculateScore(debug: true),
                  icon: Icon(Icons.calculate),
                  label: Text('Calculate Score'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (deckScore != null)
                  // Deck Score Display
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Column(
                      children: [
                        // Final Score Emphasis
                        Text(
                          '${deckScore!.toStringAsFixed(2)} / 10',
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Deck Power Level',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
