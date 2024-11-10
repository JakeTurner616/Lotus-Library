import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'card_search_delegate.dart';
import 'parse_service.dart';
import 'saved_lists_manager.dart';

class CardWidget extends StatelessWidget {
  final Map<String, dynamic> cardData;
  final VoidCallback? onDelete;
  final CardLoader cardLoader;

  CardWidget({
    required this.cardData,
    required this.cardLoader,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final face = cardData['faces'][0];

    return MouseRegion(
      cursor: Platform.isWindows || Platform.isMacOS || Platform.isLinux
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: () => _openCardDetail(context),
        onLongPressStart: (details) =>
            _showPopupMenu(context, details.globalPosition),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedNetworkImage(
                imageUrl: face['imageUri'] ?? '',
                height: 370,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading image: $error');
                  return Icon(Icons.error);
                },
              ),
              Divider(
                height: 2.0,
                color: Color.fromARGB(255, 37, 37, 37),
                thickness: 2.0,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      face['name'] ?? 'No Name',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      face['type_line'] ?? 'No Type',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPopupMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          child: Text('Add to List'),
          onTap: () => _showSaveToListDialog(context),
        ),
      ],
      elevation: 8.0,
    );
  }

  void _openCardDetail(BuildContext context) {
    final face = cardData['faces'][0];
    final legalities = cardData['legalities'] as Map<String, dynamic>?;

    // Fetch related cards using findSynergies
    final relatedCards = cardLoader.findSynergies(face);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (face['imageUri'] != null)
                  CachedNetworkImage(
                    imageUrl: face['imageUri'],
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                SizedBox(height: 16),
                Text(
                  face['name'] ?? 'No Name',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  face['type_line'] ?? 'No Type',
                  style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                Text(
                  face['oracle_text'] ?? 'No Description',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'Legalities:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildLegalitiesList(legalities),
                SizedBox(height: 16),
                Text(
                  'Related Cards:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildRelatedCardsList(context, relatedCards),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedCardsList(
      BuildContext context, List<Map<String, dynamic>> relatedCards) {
    if (relatedCards.isEmpty) {
      return Text(
        'No related cards found.',
        style: TextStyle(color: Colors.grey[400]),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: relatedCards.length,
        itemBuilder: (context, index) {
          final card = relatedCards[index]['faces'][0];
          final cardName = card['name'] ?? 'Unknown';

          return ListTile(
            leading: CachedNetworkImage(
              imageUrl: card['imageUri'] ?? '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey),
              errorWidget: (context, url, error) => Icon(Icons.error),
            ),
            title: Text(
              cardName,
              style: TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              debugPrint(
                  'passing card to initial query for search anchor: $cardName');
              Navigator.of(context)
                  .pop(); // Close the dialog to prevent on back press issues
              showSearch(
                context: context,
                delegate: CardSearchDelegate(
                  allCards: cardLoader.allCardsFiltered,
                  cardLoader: cardLoader,
                  initialQuery: cardName, // Pass the card name as initial query
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLegalitiesList(Map<String, dynamic>? legalities) {
    if (legalities == null) {
      return Text('No legality information available.');
    }

    final legalFormats = legalities.entries
        .where((entry) => entry.value == 'legal')
        .map((entry) => entry.key)
        .toList();

    if (legalFormats.isEmpty) {
      return Text('This card is not legal in any format.');
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: legalFormats.map((format) {
        return Chip(
          label: Text(format.toUpperCase()),
          backgroundColor: Colors.green[700],
        );
      }).toList(),
    );
  }

  void _showSaveToListDialog(BuildContext context) {
    final savedListsManager = SavedListsManager();
    final listNames = savedListsManager.savedLists.keys.toList();
    String? selectedList = listNames.isNotEmpty ? listNames[0] : null;
    final TextEditingController newListController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Save to List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (listNames.isNotEmpty)
                DropdownButton<String>(
                  value: selectedList,
                  onChanged: (value) {
                    setState(() {
                      selectedList = value;
                    });
                  },
                  items: listNames.map((listName) {
                    return DropdownMenuItem<String>(
                      value: listName,
                      child: Text(listName),
                    );
                  }).toList(),
                ),
              TextField(
                controller: newListController,
                decoration: InputDecoration(
                  labelText: 'Or create new list',
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                String? listName;
                if (newListController.text.isNotEmpty) {
                  listName = newListController.text;
                } else if (selectedList != null) {
                  listName = selectedList;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select or create a list')),
                  );
                  return;
                }
                savedListsManager.addCardToList(listName!, cardData);
                await savedListsManager.saveLists();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Card saved to "$listName"')),
                );
              },
              child: Text('Save'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
