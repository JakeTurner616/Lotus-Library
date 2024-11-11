import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SynergyProvider {
  static List<Map<String, dynamic>> getSynergies(
      Map<String, dynamic> cardFace, List<Map<String, dynamic>> allCards,
      {int maxResults = 8}) {
    // Added a maxResults parameter
    final targetOracleText = cardFace['oracle_text'] ?? '';
    final targetKeywords = cardFace['keywords'] ?? [];
    final targetColorIdentity = cardFace['color_identity'] ?? [];
    final targetTypeLine = cardFace['type_line'] ?? '';

    // Function to calculate relatability score
    int calculateScore(Map<String, dynamic> card) {
      int score = 0;
      final cardFaces = card['faces'] ?? [card]; // Support multifaced cards

      for (var face in cardFaces) {
        final oracleText = face['oracle_text'] ?? '';
        final keywords = face['keywords'] ?? [];
        final colorIdentity = card['color_identity'] ?? [];
        final typeLine = face['type_line'] ?? '';

        // Mechanic Match - Check if keywords and mechanics in oracle text match
        if (keywords.any(targetKeywords.contains) ||
            oracleText.contains(targetOracleText)) {
          score += 3;
        }

        // Color Match - Check if color identities match
        if (colorIdentity.toString() == targetColorIdentity.toString()) {
          score += 2;
        }

        // Type Match - Score for matching type line components
        final targetTypeComponents =
            targetTypeLine.split('—').map((s) => s.trim()).toList();
        final cardTypeComponents =
            typeLine.split('—').map((s) => s.trim()).toList();

        // Supertype match (like "Legendary")
        if (targetTypeComponents.isNotEmpty &&
            cardTypeComponents.isNotEmpty &&
            cardTypeComponents[0] == targetTypeComponents[0]) {
          score += 1;
        }

        // Type match (like "Creature")
        if (targetTypeComponents.length > 1 &&
            cardTypeComponents.length > 1 &&
            cardTypeComponents[1] == targetTypeComponents[1]) {
          score += 1;
        }

        // Subtype match (like "Elf")
        if (targetTypeComponents.length > 2 &&
            cardTypeComponents.length > 2 &&
            cardTypeComponents[2] == targetTypeComponents[2]) {
          score += 1;
        }
      }
      return score;
    }

    // Calculate scores for each card, excluding the target card
    final relatedCards =
        allCards.where((card) => card['id'] != cardFace['id']).map((card) {
      return {
        'card': card,
        'score': calculateScore(card),
      };
    }).toList();

    // Sort cards by score in descending order and limit results to maxResults
    relatedCards
        .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    // Return only top cards up to maxResults
    return relatedCards
        .take(maxResults)
        .map((entry) => entry['card'] as Map<String, dynamic>)
        .toList();
  }

  static Widget buildSynergyCards(
      Map<String, dynamic> face, List<Map<String, dynamic>> allCards) {
    List<Map<String, dynamic>> synergies = getSynergies(face, allCards);

    if (synergies.isEmpty) {
      return Text('No synergies found.');
    }

    return Column(
      children: synergies.map((synergy) {
        return ListTile(
          leading: CachedNetworkImage(
            imageUrl: synergy['faces'][0]['imageUri'] ?? '',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
          title: Text(synergy['faces'][0]['name'] ?? 'Unknown Card'),
          subtitle: Text(synergy['faces'][0]['type_line'] ?? 'No Type'),
        );
      }).toList(),
    );
  }
}
