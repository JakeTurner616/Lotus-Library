import 'package:flutter/material.dart';
import 'export_deck_screen.dart';
import 'saved_lists_manager.dart';
import 'parse_service.dart'; // Import CardLoader

class SavedListsScreen extends StatefulWidget {
  @override
  _SavedListsScreenState createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen> {
  final SavedListsManager savedListsManager =
      SavedListsManager(); // Use singleton instance
  final TextEditingController _listNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint("Loading lists from disk...");
    savedListsManager.loadLists(); // Load existing lists from disk
    debugPrint("Lists loaded: ${savedListsManager.savedLists}");
  }

  @override
  void dispose() {
    _listNameController.dispose();
    super.dispose();
  }

  void _createNewList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New List'),
        content: TextField(
          controller: _listNameController,
          decoration: InputDecoration(hintText: 'Enter list name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _listNameController.clear();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newListName = _listNameController.text.trim();
              if (newListName.isNotEmpty &&
                  !savedListsManager.savedLists.containsKey(newListName)) {
                setState(() {
                  savedListsManager.savedLists[newListName] =
                      []; // Create a new list
                });
                await savedListsManager.saveLists(); // Save to disk
                debugPrint("New list '$newListName' created and saved.");
                Navigator.of(context).pop();
                _listNameController.clear();
              } else {
                debugPrint("List name is empty or duplicate: '$newListName'");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('List name cannot be empty or duplicate')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listNames = savedListsManager.savedLists.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Lists'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: listNames.length,
              itemBuilder: (context, index) {
                final listName = listNames[index];
                return ListTile(
                  title: Text(listName),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete List'),
                          content: Text(
                              'Are you sure you want to delete "$listName"?'),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                setState(() {
                                  savedListsManager.deleteList(listName);
                                  debugPrint("List '$listName' deleted.");
                                });
                                await savedListsManager
                                    .saveLists(); // Save changes
                              },
                              child: Text('Delete'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Cancel'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListDetailScreen(
                          listName: listName,
                          cards: savedListsManager.savedLists[listName]!,
                          onListUpdated: () async {
                            setState(() {});
                            await savedListsManager
                                .saveLists(); // Save changes on update
                          },
                          cardLoader: CardLoader(
                            progressNotifier: ValueNotifier(""),
                            selectedFormat: 'commander',
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewList,
        tooltip: 'Create New List',
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}

class ListDetailScreen extends StatefulWidget {
  final String listName;
  final List<Map<String, dynamic>> cards;
  final VoidCallback onListUpdated;
  final CardLoader cardLoader;

  ListDetailScreen({
    required this.listName,
    required this.cards,
    required this.onListUpdated,
    required this.cardLoader,
  });

  @override
  _ListDetailScreenState createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final SavedListsManager savedListsManager = SavedListsManager();
  final TextEditingController _cardNameController = TextEditingController();
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _initializeCardLoader();
  }

  @override
  void dispose() {
    _cardNameController.dispose();
    super.dispose();
  }

  Future<void> _initializeCardLoader() async {
    debugPrint("Initializing CardLoader...");
    await widget.cardLoader.initialize(); // Load cards from disk
    setState(() {
      _isLoading = false; // Set loading to false once initialized
    });
    debugPrint("CardLoader initialization complete. Cards loaded.");
  }

  Future<void> _exportCurrentDeck() async {
    // Convert the current list to a formatted decklist
    final deckBuffer = StringBuffer();
    for (var card in widget.cards) {
      final cardName = card['faces'][0]['name'] ?? 'Unknown Card';
      final quantity = card['quantity'] ?? 1;
      deckBuffer.writeln('$quantity $cardName');
    }

    // Navigate to ExportDeckScreen with the decklist for the current list
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportDeckScreen(decklist: deckBuffer.toString()),
      ),
    );
  }

  Future<void> _importCardByName() async {
    final cardName = _cardNameController.text.trim();
    if (cardName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a card name')),
      );
      return;
    }

    // Search for the card in CardLoader's database
    final card = widget.cardLoader.allCardsFiltered.firstWhere(
      (card) =>
          card['faces'][0]['name'].toLowerCase() == cardName.toLowerCase(),
      orElse: () => {},
    );

    setState(() {
      savedListsManager.addCardToList(widget.listName, card);
    });
    await savedListsManager.saveLists();
    widget.onListUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Card "$cardName" imported successfully')),
    );
    _cardNameController.clear();
  }

  double minCardWidth = 220.0; // Minimum width for each card
  double cardHeight = 465; // Fixed height for cards
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = (screenWidth / minCardWidth).floor().clamp(1, 5);
    double cardWidth = screenWidth / crossAxisCount;
    double aspectRatio = cardWidth / cardHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportCurrentDeck, // Export the current deck
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cardNameController,
                    decoration: InputDecoration(
                      labelText: 'Enter card name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _importCardByName,
                  child: Text('Import'),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: aspectRatio,
              ),
              itemCount: widget.cards.length,
              itemBuilder: (context, index) {
                final card = widget.cards[index];
                final baseCardName = card['faces'][0]['name'] ?? 'No Name';
                final quantity = card['quantity'] ?? 1;
                final displayCardName =
                    quantity > 1 ? 'x$quantity $baseCardName' : baseCardName;
                final cardImage = card['faces'][0]['imageUri'];

                return GestureDetector(
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Card'),
                        content: Text(
                            'Are you sure you want to delete "$displayCardName"?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                savedListsManager.removeCardFromList(
                                    widget.listName, card);
                                savedListsManager.saveLists();
                                widget.onListUpdated();
                              });
                            },
                            child: Text('Delete'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cardImage != null
                            ? Image.network(
                                cardImage,
                                height: 330,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 250,
                                color: Colors.grey,
                                child: Icon(Icons.image_not_supported),
                              ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            displayCardName,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}
