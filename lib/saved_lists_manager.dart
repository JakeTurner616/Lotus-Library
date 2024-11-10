import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SavedListsManager {
  Map<String, List<Map<String, dynamic>>> _savedLists = {};

  // Singleton pattern
  static final SavedListsManager _instance = SavedListsManager._internal();
  factory SavedListsManager() => _instance;
  SavedListsManager._internal();

  // Load saved lists from disk
  Future<void> loadLists() async {
    final directory = await getApplicationSupportDirectory();
    final filePath = '${directory.path}/saved_lists.json';
    final file = File(filePath);

    if (await file.exists()) {
      final content = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(content);
      _savedLists = jsonData.map((key, value) =>
          MapEntry(key, List<Map<String, dynamic>>.from(value)));
    }
  }

  // Save lists to disk
  Future<void> saveLists() async {
    final directory = await getApplicationSupportDirectory();
    final filePath = '${directory.path}/saved_lists.json';
    final file = File(filePath);

    final jsonData = _savedLists;
    final content = jsonEncode(jsonData);
    await file.writeAsString(content);
  }

  // Get the saved lists
  Map<String, List<Map<String, dynamic>>> get savedLists => _savedLists;

  // Add a card to the list with quantity tracking
  void addCardToList(String listName, Map<String, dynamic> cardData) {
    if (!_savedLists.containsKey(listName)) {
      _savedLists[listName] = [];
    }

    // Attempt to get the card name from either 'faces' or top-level 'name' field
    final cardName = (cardData['faces'] != null &&
            cardData['faces'].isNotEmpty &&
            cardData['faces'][0]['name'] != null)
        ? cardData['faces'][0]['name']
        : cardData['name']; // Fallback for single-faced cards

    if (cardName == null) {
      print("Invalid card data: Missing 'faces' or 'name' field.");
      return;
    }

    // Find if the card already exists in the list
    final existingCard = _savedLists[listName]!.firstWhere(
      (card) => card['faces'][0]['name'] == cardName,
      orElse: () => <String, dynamic>{}, // Return an empty map instead of null
    );

    if (existingCard.isNotEmpty) {
      // Increment the quantity if the card already exists
      existingCard['quantity'] = (existingCard['quantity'] ?? 1) + 1;
    } else {
      // Add the card with an initial quantity of 1 if it doesn't exist
      cardData['quantity'] = 1;
      _savedLists[listName]!.add(cardData);
    }
  }

  // Remove one instance of a card from a list
  void removeCardFromList(String listName, Map<String, dynamic> cardData) {
    if (!_savedLists.containsKey(listName)) return;

    final cardName = (cardData['faces'] != null &&
            cardData['faces'].isNotEmpty &&
            cardData['faces'][0]['name'] != null)
        ? cardData['faces'][0]['name']
        : cardData['name'];

    if (cardName == null) {
      print("Invalid card data: Missing 'faces' or 'name' field.");
      return;
    }

    // Locate the card entry
    final existingCard = _savedLists[listName]!.firstWhere(
      (card) => card['faces'][0]['name'] == cardName,
      orElse: () => <String, dynamic>{}, // Return an empty map instead of null
    );

    if (existingCard.isNotEmpty) {
      // Decrement quantity or remove if quantity reaches zero
      if ((existingCard['quantity'] ?? 1) > 1) {
        existingCard['quantity'] -= 1;
      } else {
        _savedLists[listName]!.remove(existingCard);
      }
    }
  }

  // Delete a list
  void deleteList(String listName) {
    _savedLists.remove(listName);
  }
}
