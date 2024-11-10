import 'package:flutter/material.dart';
import 'card_widget.dart';
import 'parse_service.dart';

class CardSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> allCards;
  final CardLoader cardLoader;
  final String? initialQuery;

  bool searchInName = true;
  bool searchInText = true;
  bool searchInType = true;

  CardSearchDelegate({
    required this.allCards,
    required this.cardLoader,
    this.initialQuery,
  }) {
    query = initialQuery ?? ''; // Set the query with initialQuery
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.filter_list),
        onPressed: () {
          _showFilterOptions(context);
        },
      ),
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  void _showFilterOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Categories'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text('Name'),
              value: searchInName,
              onChanged: (value) {
                if (value != null) {
                  searchInName = value;
                  Navigator.of(context).pop();
                  _showFilterOptions(context);
                }
              },
            ),
            CheckboxListTile(
              title: Text('Oracle Text'),
              value: searchInText,
              onChanged: (value) {
                if (value != null) {
                  searchInText = value;
                  Navigator.of(context).pop();
                  _showFilterOptions(context);
                }
              },
            ),
            CheckboxListTile(
              title: Text('Type Line'),
              value: searchInType,
              onChanged: (value) {
                if (value != null) {
                  searchInType = value;
                  Navigator.of(context).pop();
                  _showFilterOptions(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (initialQuery != null && query != initialQuery) {
      query = initialQuery!;
    }
    final results = _fuzzySearch(allCards, query);
    return _buildResultList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (initialQuery != null && query != initialQuery) {
      query = initialQuery!;
    }
    final suggestions = _fuzzySearch(allCards, query);
    return _buildResultList(suggestions);
  }

  Widget _buildResultList(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No legal cards found in your selected format.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Screen width-based grid configuration
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double minCardWidth = 220.0; // Minimum width for each card
        double cardHeight = 465; // Fixed height for cards

        int crossAxisCount = (screenWidth / minCardWidth).floor().clamp(1, 5);
        double cardWidth = screenWidth / crossAxisCount;
        double aspectRatio = cardWidth / cardHeight;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final cardData = results[index];
            return CardWidget(
              cardData: cardData,
              cardLoader: cardLoader,
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _fuzzySearch(
      List<Map<String, dynamic>> cards, String query) {
    if (query.isEmpty) {
      return cards;
    }

    final lowerQuery = query.toLowerCase();
    final List<Map<String, dynamic>> filteredCards = [];

    for (var card in cards) {
      bool matches = false;

      if (searchInName) {
        final cardName = (card['faces'][0]['name'] as String).toLowerCase();
        if (cardName.contains(lowerQuery)) {
          matches = true;
        }
      }

      if (!matches && searchInText) {
        final cardText =
            (card['faces'][0]['oracle_text'] as String?)?.toLowerCase() ?? "";
        if (cardText.contains(lowerQuery)) {
          matches = true;
        }
      }

      if (!matches && searchInType) {
        final cardType =
            (card['faces'][0]['type_line'] as String?)?.toLowerCase() ?? "";
        if (cardType.contains(lowerQuery)) {
          matches = true;
        }
      }

      if (matches) {
        filteredCards.add(card);
      }
    }

    return filteredCards;
  }
}
