import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'download_service.dart';

const Set<String> stopwords = {
  'legendary',
  'a',
  'an',
  'the',
  'and',
  'or',
  'of',
  'is',
  'it',
  'you',
  'to',
  'that',
  's',
  't',
  'except',
  'isn',
  'another'
};

// allows the user to load and filter card data
class CardLoader {
  final ValueNotifier<String> progressNotifier;
  String selectedFormat = 'commander'; // Default format
  Stream<List<int>>? _fileStream;
  bool _initialized = false;
  List<Map<String, dynamic>> _allCards = [];
  List<Map<String, dynamic>> _filteredCards = [];
  int _currentIndex = 0;

  CardLoader({required this.progressNotifier, required this.selectedFormat});

  List<Map<String, dynamic>> findSynergies(Map<String, dynamic> cardFace) {
    final targetName = cardFace['name'] as String?;
    final targetSubtype = cardFace['subtypes'] as List<dynamic>? ?? [];
    final targetType = cardFace['types'] as List<dynamic>? ?? [];
    final targetSupertype = cardFace['supertypes'] as List<dynamic>? ?? [];
    final targetOracleText = cardFace['oracle_text'] as String? ?? '';
    final targetKeywords = _extractKeywords(targetOracleText);

    final relatedCards = _allCards
        .where((card) =>
            _isCardLegalInFormat(card, selectedFormat)) // Check legality
        .map((card) {
          int score = 0;
          final faces = card['faces'] as List<dynamic>? ?? [];

          for (var face in faces) {
            final cardSubtype = face['subtypes'] as List<dynamic>? ?? [];
            final cardType = face['types'] as List<dynamic>? ?? [];
            final cardSupertype = face['supertypes'] as List<dynamic>? ?? [];
            final cardOracleText = face['oracle_text'] as String? ?? '';
            final cardKeywords = _extractKeywords(cardOracleText);

            score += _calculateMatchScore(targetSubtype, cardSubtype, 5);
            score += _calculateMatchScore(targetType, cardType, 3);
            score += _calculateMatchScore(targetSupertype, cardSupertype, 2);
            score += _calculateMatchScore(targetKeywords, cardKeywords, 1);

            if (targetName != null && face['name'] == targetName) {
              score = 0; // Exclude the card itself
            }
          }
          return {
            'card': card,
            'score': score,
          };
        })
        .where((entry) => (entry['score'] as int) > 0)
        .toList();

    relatedCards
        .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return relatedCards
        .map((entry) => entry['card'] as Map<String, dynamic>)
        .toList();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    progressNotifier.value = "Locating storage directory...";
    final directory = await getApplicationSupportDirectory();
    final parsedDataPath = '${directory.path}/parsed_scryfall_data.json';
    final parsedFile = File(parsedDataPath);

    if (await parsedFile.exists()) {
      progressNotifier.value = "Loading serialized card data...";
      final jsonData = await parsedFile.readAsString();
      _allCards = List<Map<String, dynamic>>.from(jsonDecode(jsonData));
    } else {
      final scryfallPath = '${directory.path}/oracle-cards.json';
      final scryfallFile = File(scryfallPath);

      if (!await scryfallFile.exists()) {
        progressNotifier.value = "Data file missing. Downloading...";
        try {
          await downloadAndExtractData(progressNotifier);
        } catch (e) {
          progressNotifier.value = "Error downloading data: ${e.toString()}";
          throw Exception("Failed to download Scryfall data: $e");
        }
      }

      progressNotifier.value = "Opening JSON file for streaming...";
      _fileStream = scryfallFile.openRead();

      final decoder = utf8.decoder.bind(_fileStream!).transform(LineSplitter());
      var isFirstLine = true;

      await for (final line in decoder) {
        try {
          if (isFirstLine || line.trim() == ']') {
            isFirstLine = false;
            continue;
          }

          final cardJson = jsonDecode(line.replaceAll(RegExp(r',$'), ''));
          final parsedCard = _parseCardData(cardJson);

          if (parsedCard != null) {
            _allCards.add(parsedCard);
          }
        } catch (e) {
          print("Error parsing card: $e");
          continue;
        }
      }

      await _saveParsedData(parsedDataPath);
      progressNotifier.value = "Cards loaded and serialized successfully.";
    }

    applyFilter(selectedFormat);
    _initialized = true;
  }

  Future<void> _saveParsedData(String path) async {
    final parsedFile = File(path);
    await parsedFile.writeAsString(jsonEncode(_allCards));
  }

  void applyFilter(String selectedFormat) {
    this.selectedFormat = selectedFormat;
    _filteredCards = _allCards
        .where((card) => _isCardLegalInFormat(card, selectedFormat))
        .toList();
    _currentIndex = 0;
  }

  bool _isCardLegalInFormat(Map<String, dynamic> card, String selectedFormat) {
    final legalities = card['legalities'] as Map<String, dynamic>?;
    final rarity = card['rarity'] as String?;

    if (legalities == null) return false;
    if (selectedFormat == 'pauper') {
      return legalities['pauper'] == 'legal' && rarity == 'common';
    } else {
      return legalities[selectedFormat] == 'legal';
    }
  }

  Future<List<Map<String, dynamic>>> loadNextBatch() async {
    if (_currentIndex >= _filteredCards.length) return [];

    final nextBatch = _filteredCards.sublist(
      _currentIndex,
      (_currentIndex + 100).clamp(0, _filteredCards.length),
    );

    _currentIndex += 100;
    return nextBatch;
  }

  Map<String, dynamic>? _parseCardData(Map<String, dynamic> cardJson) {
    final legalities = cardJson['legalities'] as Map<String, dynamic>?;
    final rarity = cardJson['rarity'] as String?;

    List<Map<String, dynamic>> cardFaces = [];
    bool isDualSpell = cardJson['image_uris'] != null &&
        (cardJson['card_faces']?.length ?? 0) > 1;

    if (cardJson['card_faces'] != null) {
      if (isDualSpell) {
        cardFaces.add({
          'name': cardJson['name'] ?? 'Unknown Card',
          'imageUri': cardJson['image_uris']?['normal'],
          'oracle_text': cardJson['oracle_text'] ?? 'No description available.',
          'type_line': cardJson['type_line'] ?? 'Unknown Type',
          'isDualSpell': true,
          'card_faces': List<Map<String, dynamic>>.from(cardJson['card_faces']),
        });
      } else {
        cardFaces = List<Map<String, dynamic>>.from(
            cardJson['card_faces'].map((face) => {
                  'name': face['name'] ?? 'Unknown Card',
                  'imageUri': face['image_uris']?['normal'],
                  'oracle_text':
                      face['oracle_text'] ?? 'No description available.',
                  'type_line': face['type_line'] ?? 'Unknown Type',
                  'isDualSpell': false,
                }));
      }
    } else {
      cardFaces.add({
        'name': cardJson['name'] ?? 'Unknown Card',
        'imageUri': cardJson['image_uris']?['normal'],
        'oracle_text': cardJson['oracle_text'] ?? 'No description available.',
        'type_line': cardJson['type_line'] ?? 'Unknown Type',
        'isDualSpell': false,
      });
    }

    return {
      'faces': cardFaces,
      'legalities': legalities,
      'rarity': rarity,
    };
  }

  List<Map<String, dynamic>> get allCardsFiltered => _filteredCards;

  void reset() {
    _currentIndex = 0;
  }

  List<String> _extractKeywords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((word) => word.isNotEmpty && !stopwords.contains(word))
        .toList();
  }

  int _calculateMatchScore(
      List<dynamic> targetList, List<dynamic> cardList, int weight) {
    return targetList.where((target) => cardList.contains(target)).length *
        weight;
  }
}
