import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'download_service.dart';
import 'card_widget.dart';
import 'skeleton_card.dart';
import 'saved_lists_screen.dart';
import 'power_leveler_screen.dart';
import 'parse_service.dart';
import 'saved_lists_manager.dart';
import 'card_search_delegate.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late CardLoader cardLoader;
  final ValueNotifier<String> progressNotifier =
      ValueNotifier<String>("Starting...");
  final ScrollController scrollController = ScrollController();
  List<Map<String, dynamic>> displayedCards = [];
  bool isLoading = true;
  bool isFetchingMore = false;
  final List<String> formats = [
    'commander',
    'modern',
    'pauper',
    'pioneer',
    'vintage',
    'standard'
  ];
  String selectedFormat = 'commander';
  static const double cardHeight = 450.0; // Fixed height for cards
  static const double minCardWidth = 220.0; // Minimum card width

  @override
  void initState() {
    super.initState();
    cardLoader = CardLoader(
        progressNotifier: progressNotifier, selectedFormat: 'commander');
    _initializeLoader();
    _loadSavedLists();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isFetchingMore) {
        _loadMoreCards();
      }
    });
  }

  Future<void> _initializeLoader() async {
    try {
      await cardLoader.initialize();
      cardLoader.applyFilter(selectedFormat);
      await _loadMoreCards();
    } catch (e) {
      progressNotifier.value = "Error: ${e.toString()}";
    } finally {
      setState(() => isLoading = false);
      FlutterNativeSplash.remove();
      progressNotifier.value = "";
    }
  }

  Future<void> _loadSavedLists() async {
    await SavedListsManager().loadLists();
  }

  Future<void> _loadMoreCards() async {
    if (!isLoading) setState(() => isFetchingMore = true);
    final newCards = await cardLoader.loadNextBatch();
    setState(() {
      displayedCards.addAll(newCards);
      isFetchingMore = false;
    });
  }

  Future<void> _updateLegalityFilter(String format) async {
    setState(() {
      isLoading = true;
      displayedCards.clear();
      selectedFormat = format;
      cardLoader.applyFilter(selectedFormat);
    });
    await _loadMoreCards();
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    progressNotifier.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 1:
        return SavedListsScreen();
      case 2:
        return PowerLevelerScreen();
      default:
        return _buildHomeScreen(context);
    }
  }

  Widget _buildHomeScreen(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = (screenWidth / minCardWidth)
        .floor()
        .clamp(1, 100); // Ensures at least 1 and max 100 columns
    double cardWidth = screenWidth / crossAxisCount;
    double aspectRatio = cardWidth / cardHeight;

    return Column(
      children: [
        ValueListenableBuilder<String>(
          valueListenable: progressNotifier,
          builder: (context, progress, child) {
            return progress.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(progress),
                  )
                : Container();
          },
        ),
        Expanded(
          child: isLoading
              ? GridView.builder(
                  itemCount: 16,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 3.0, // Horizontal space between cards
                    mainAxisSpacing: 3.0, // Vertical space between cards
                  ),
                  itemBuilder: (context, index) => SkeletonCard(),
                )
              : GridView.builder(
                  controller: scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 3.0, // Horizontal space between cards
                    mainAxisSpacing: 3.0, // Vertical space between cards
                  ),
                  itemCount: displayedCards.length,
                  itemBuilder: (context, index) => CardWidget(
                    cardData: displayedCards[index],
                    cardLoader: cardLoader, // Pass cardLoader here
                  ),
                ),
        ),
        if (isFetchingMore) Center(child: CircularProgressIndicator()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Text('Home!'),
              actions: [
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => showSearch(
                    context: context,
                    delegate: CardSearchDelegate(
                      allCards: cardLoader.allCardsFiltered,
                      cardLoader: cardLoader,
                    ),
                  ),
                ),
              ],
            )
          : null,
      drawer: _buildDrawer(context),
      body: _getSelectedScreen(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Saved Lists'),
          BottomNavigationBarItem(
              icon: Icon(Icons.flash_on), label: 'Power Leveler'),
        ],
      ),
    );
  }

  final ValueNotifier<String> statusNotifier = ValueNotifier('');
  final ValueNotifier<bool> scryfallUpdateAvailable = ValueNotifier(false);
  final ValueNotifier<bool> mtgjsonUpdateAvailable = ValueNotifier(false);

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Text(
              'Select Format',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            title: Text('Format Filter'),
            subtitle: DropdownButton<String>(
              value: selectedFormat,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  Navigator.of(context).pop();
                  _updateLegalityFilter(newValue);
                }
              },
              items: formats
                  .map<DropdownMenuItem<String>>((String value) =>
                      DropdownMenuItem<String>(
                          value: value, child: Text(value.toUpperCase())))
                  .toList(),
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.update),
            title: Text('Check for Data Updates'),
            onTap: () {
              Navigator.of(context).pop(); // Close the drawer first
              checkForUpdatesAndPrompt(
                context,
                statusNotifier,
                scryfallUpdateAvailable,
                mtgjsonUpdateAvailable,
              );
            },
          ),
        ],
      ),
    );
  }
}