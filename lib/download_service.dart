import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

Future<void> downloadAndExtractData(
    ValueNotifier<String> statusNotifier) async {
  final directory = await getApplicationSupportDirectory();
  final scryfallPath = '${directory.path}/oracle-cards.json';
  final atomicCardsPath = '${directory.path}/AtomicCards.json';

  final scryfallFile = File(scryfallPath);
  final atomicCardsFile = File(atomicCardsPath);

  if (await scryfallFile.exists() && await atomicCardsFile.exists()) {
    statusNotifier.value = 'Data files already exist, skipping download.';
    return;
  }

  await _downloadScryfallData(statusNotifier, scryfallFile);
  await _downloadMtgjsonData(statusNotifier, atomicCardsFile);
  statusNotifier.value = 'Data download complete.';
}

Future<void> checkForUpdatesAndPrompt(
  BuildContext context,
  ValueNotifier<String> statusNotifier,
  ValueNotifier<bool> scryfallUpdateAvailable,
  ValueNotifier<bool> mtgjsonUpdateAvailable,
) async {
  final directory = await getApplicationSupportDirectory();
  final scryfallFile = File('${directory.path}/oracle-cards.json');
  final atomicCardsFile = File('${directory.path}/AtomicCards.json');
  final serializedDataFile = File(
      '${directory.path}/parsed_scryfall_data.json'); // Example of serialized data file

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          _checkForScryfallUpdates(statusNotifier, scryfallUpdateAvailable);
          _checkForMtgjsonUpdates(statusNotifier, mtgjsonUpdateAvailable);
          bool scryfallAvailable = scryfallUpdateAvailable.value;
          bool mtgjsonAvailable = mtgjsonUpdateAvailable.value;

          return AlertDialog(
            title: Text('Data Updates Available'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Scryfall Oracle Cards - ${scryfallAvailable ? "New version available" : "Up-to-date"}'),
                  Text(
                      'MTGJSON Atomic Cards - ${mtgjsonAvailable ? "New version available" : "Up-to-date"}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: scryfallAvailable
                    ? () {
                        _downloadScryfallData(statusNotifier, scryfallFile);
                        setState(() {
                          scryfallAvailable = false;
                        });
                      }
                    : null,
                child: Text('Update Scryfall Data'),
              ),
              TextButton(
                onPressed: mtgjsonAvailable
                    ? () {
                        _downloadMtgjsonData(statusNotifier, atomicCardsFile);
                        setState(() {
                          mtgjsonAvailable = false;
                        });
                      }
                    : null,
                child: Text('Update MTGJSON Data'),
              ),
              TextButton(
                onPressed: () async {
                  bool confirmPurge =
                      await _showPurgeConfirmationDialog(context);
                  if (confirmPurge) {
                    if (await scryfallFile.exists()) {
                      await scryfallFile.delete();
                    }
                    if (await atomicCardsFile.exists()) {
                      await atomicCardsFile.delete();
                    }
                    if (await serializedDataFile.exists()) {
                      await serializedDataFile.delete();
                    }

                    statusNotifier.value = 'All data purged successfully.';
                    setState(() {
                      scryfallAvailable = false;
                      mtgjsonAvailable = false;
                    });
                  }
                },
                child: Text('Purge Data'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> _showPurgeConfirmationDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Confirm Purge'),
            content: Text(
                'Are you sure you want to delete all data? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirm'),
              ),
            ],
          );
        },
      ) ??
      false;
}

Future<void> _checkForScryfallUpdates(ValueNotifier<String> statusNotifier,
    ValueNotifier<bool> scryfallUpdateAvailable) async {
  final directory = await getApplicationSupportDirectory();
  final scryfallTimestampFile =
      File('${directory.path}/oracle-cards-timestamp.txt');

  final scryfallBulkDataUrl = 'https://api.scryfall.com/bulk-data';
  try {
    statusNotifier.value = 'Checking Scryfall update...';
    final response = await http.get(Uri.parse(scryfallBulkDataUrl));

    if (response.statusCode == 200) {
      final bulkData = jsonDecode(response.body);
      final oracleCardsEntry = (bulkData['data'] as List<dynamic>)
          .firstWhere((entry) => entry['type'] == 'oracle_cards');

      final scryfallUpdatedAt = DateTime.parse(oracleCardsEntry['updated_at']);

      DateTime? localScryfallTimestamp;
      if (await scryfallTimestampFile.exists()) {
        localScryfallTimestamp =
            DateTime.parse(await scryfallTimestampFile.readAsString());
      }

      scryfallUpdateAvailable.value = localScryfallTimestamp == null ||
          scryfallUpdatedAt.isAfter(localScryfallTimestamp);
    }
  } catch (e) {
    statusNotifier.value = 'Error checking Scryfall update: $e';
  }
}

Future<void> _checkForMtgjsonUpdates(ValueNotifier<String> statusNotifier,
    ValueNotifier<bool> mtgjsonUpdateAvailable) async {
  final directory = await getApplicationSupportDirectory();
  final mtgjsonShaUrl = 'https://mtgjson.com/api/v5/AtomicCards.json.sha256';

  try {
    statusNotifier.value = 'Checking MTGJSON update...';
    final response = await http.get(Uri.parse(mtgjsonShaUrl));

    if (response.statusCode == 200) {
      final remoteSha256 = response.body.trim();
      final atomicCardsFile = File('${directory.path}/AtomicCards.json');

      if (await atomicCardsFile.exists()) {
        final localSha256 = await _calculateSha256(atomicCardsFile);
        mtgjsonUpdateAvailable.value = localSha256 != remoteSha256;
      } else {
        mtgjsonUpdateAvailable.value = true;
      }
    }
  } catch (e) {
    statusNotifier.value = 'Error checking MTGJSON update: $e';
  }
}

Future<void> _downloadScryfallData(
    ValueNotifier<String> statusNotifier, File scryfallFile) async {
  final bulkDataUrl = 'https://api.scryfall.com/bulk-data';
  final directory = await getApplicationSupportDirectory();
  final scryfallTimestampFile =
      File('${directory.path}/oracle-cards-timestamp.txt');

  statusNotifier.value = 'Downloading Scryfall Oracle Cards...';
  final response = await http.get(Uri.parse(bulkDataUrl));

  if (response.statusCode == 200) {
    final bulkData = jsonDecode(response.body);
    final oracleCardsEntry = (bulkData['data'] as List<dynamic>)
        .firstWhere((entry) => entry['type'] == 'oracle_cards');

    final downloadUrl = oracleCardsEntry['download_uri'];
    final scryfallUpdatedAt = oracleCardsEntry['updated_at'];

    final downloadResponse = await http.get(Uri.parse(downloadUrl));
    if (downloadResponse.statusCode == 200) {
      await scryfallFile.writeAsBytes(downloadResponse.bodyBytes);
      await scryfallTimestampFile.writeAsString(scryfallUpdatedAt);
      statusNotifier.value = 'Scryfall Oracle Cards updated successfully.';
    }
  }
}

Future<void> _downloadMtgjsonData(
    ValueNotifier<String> statusNotifier, File atomicCardsFile) async {
  final atomicCardsUrl = 'https://mtgjson.com/api/v5/AtomicCards.json';

  statusNotifier.value = 'Downloading MTGJSON Atomic Cards...';
  final response = await http.get(Uri.parse(atomicCardsUrl));

  if (response.statusCode == 200) {
    await atomicCardsFile.writeAsBytes(response.bodyBytes);
    statusNotifier.value = 'MTGJSON Atomic Cards updated successfully.';
  }
}

Future<String> _calculateSha256(File file) async {
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}
