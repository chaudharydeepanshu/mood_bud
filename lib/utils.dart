import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pick_or_save/pick_or_save.dart';
import 'package:tflite_text_classification/tflite_text_classification.dart';

class Utils {
  Future<String> copyAssetFileToCacheDirectory(String assetPath) async {
    // Get the cache directory path
    Directory cacheDir = await getTemporaryDirectory();

    // Create a new file in the cache directory with the same name as the asset file
    String fileName = assetPath.split('/').last;
    File cacheFile = File('${cacheDir.path}/$fileName');

    // Copy the asset file to the cache directory
    ByteData assetData = await rootBundle.load(assetPath);
    await cacheFile.writeAsBytes(assetData.buffer.asUint8List());

    // print('Asset file copied to cache directory: ${cacheFile.path}');

    return cacheFile.path;
  }

  Future<Map<String, Set<String>>> loadDictionary(String fileAssetPath) async {
    final contents = await rootBundle.loadString(fileAssetPath);

    final lines = contents.split('\n');
    final dictionary = <String, Set<String>>{};

    for (final line in lines) {
      final parts = line.split(':');
      final word = parts[0].trim();
      final associatedWords = parts[1]
          .replaceAll(RegExp(r"[{}']"), '')
          .split(',')
          .map((word) => word.trim())
          .toSet();

      dictionary[word] = associatedWords;
    }

    return dictionary;
  }

  List<String> searchDictionary(
      Map<String, Set<String>> dictionary, String soundexCode) {
    final matches = <String>[];

    for (final entry in dictionary.entries) {
      final word = entry.key;
      final associatedWords = entry.value;

      if (calculateSoundex(word) == soundexCode) {
        matches.add(word);
      }

      for (final associatedWord in associatedWords) {
        if (calculateSoundex(associatedWord) == soundexCode) {
          matches.add(associatedWord);
        }
      }
    }

    return matches;
  }

  String calculateSoundex(String word) {
    if (word == null || word.isEmpty) return '';

    final wordUpper = word.toUpperCase();

    // Step 1: Keep the first letter of the word
    var soundexCode = wordUpper[0];

    // Step 2: Replace specific letters with digits
    final replacements = {
      'BFPV': '1',
      'CGJKQSXZ': '2',
      'DT': '3',
      'L': '4',
      'MN': '5',
      'R': '6',
    };

    for (var i = 1; i < wordUpper.length; i++) {
      for (final key in replacements.keys) {
        if (key.contains(wordUpper[i])) {
          soundexCode += replacements[key]!;
          break;
        }
      }
    }

    // Step 3: Remove consecutive duplicate digits
    final codeLength = soundexCode.length;
    var cleanCode = soundexCode[0];

    for (var i = 1; i < codeLength; i++) {
      if (soundexCode[i] != soundexCode[i - 1]) {
        cleanCode += soundexCode[i];
      }
    }

    // Step 4: Pad or truncate the code to a length of 4
    final paddedCode = cleanCode.padRight(4, '0');
    final finalCode = paddedCode.substring(0, 4);

    return finalCode;
  }

  String processWhatsAppData(String chatData) {
    List<String> lines = chatData.split('\n');

    final resultLines = <String>[];

    String processedChatData;

    for (final line in lines) {
      String resultLine = line;
      int index;

      // Removing the date and time from the line
      index = line.indexOf(' - ');
      if (index != -1 && index + 2 < line.length && line[index + 2] == ' ') {
        resultLine = line.substring(index + 3);
      } else {
        resultLine = '';
      }

      // Removing the line without name
      String tempLine = resultLine;
      index = resultLine.indexOf(': ');
      if (index != -1 && index + 1 < resultLine.length) {
        final message = resultLine.substring(index + 1).trim();
        if (message.isNotEmpty) {
          resultLine = tempLine;
        } else {
          resultLine = '';
        }
      } else {
        resultLine = '';
      }

      // Removing the line with media.
      if (resultLine.contains('<Media omitted>')) {
        resultLine = '';
      }

      // Removing the line with length less than 2.
      if (resultLine.length < 2) {
        resultLine = '';
      }

      // Removing the empty lines.
      if (resultLine.isNotEmpty) {
        resultLines.add(resultLine);
      }
    }

    processedChatData = resultLines.join('\n');

    return processedChatData;
  }

  Map<String, List<String>> whatsAppChatDataToMap(String chatData) {
    List<String> lines = chatData.split('\n');

    Map<String, List<String>> chatMap = {};

    // Now store the result in the chatMap
    for (final line in lines) {
      final index = line.indexOf(':');
      final name = line.substring(0, index);
      final message = line.substring(index + 1).trim();

      if (chatMap.containsKey(name)) {
        chatMap[name]!.add(message);
      } else {
        chatMap[name] = [message];
      }
    }

    return chatMap;
  }

  String? getPredictedEmotion(ClassificationResult result) {
    String? predictedEmotion;

    double maxScore = 0.0;
    for (var category in result.categories) {
      if (category.score > maxScore) {
        maxScore = category.score;
        predictedEmotion = category.label;
      }
    }

    return predictedEmotion;
  }

  final _tfliteTextClassificationPlugin = TfliteTextClassification();

  Future<ClassificationResult?> classifyText(
      TextClassifierParams params) async {
    ClassificationResult? result;
    try {
      result =
          await _tfliteTextClassificationPlugin.classifyText(params: params);
    } on PlatformException catch (e) {
      log(e.toString());
    } catch (e) {
      log(e.toString());
    }
    return result;
  }

  Future<String> classifyData(String message, String modelCacheFilepath) async {
    ClassificationResult? result = await classifyText(
      TextClassifierParams(
        text: message.toLowerCase(),
        // aaj me bahut khush hu
        modelPath: modelCacheFilepath,
        // modelType: ModelType.wordVec,
        modelType: ModelType.mobileBert,
        delegate: 0,
      ),
    );
    String prediction =
        result == null ? 'neutral' : getPredictedEmotion(result) ?? 'neutral';

    return prediction;
  }

  Future<Map<String, List<String>>> classifyAllChats(
      Map<String, List<String>> chatMap,
      String modelPath,
      ModelType modelType) async {
    Map<String, List<String>> classifiedData = {};

    for (var entry in chatMap.entries) {
      String user = entry.key;
      List<String> messages = entry.value;

      List<String> classifications = [];

      for (var message in messages) {
        ClassificationResult? result = await classifyText(
          TextClassifierParams(
            text: message.toLowerCase(),
            // aaj me bahut khush hu
            modelPath: modelPath,
            // modelType: ModelType.wordVec,
            modelType: modelType,
            delegate: 0,
          ),
        );

        String? prediction =
            result == null ? 'neutral' : getPredictedEmotion(result);

        classifications.add(prediction ?? 'neutral');
      }

      classifiedData[user] = classifications;
    }

    print(classifiedData);
    return classifiedData;
  }

  final pickOrSavePlugin = PickOrSave();

  Future<List<String>?> filePicker(FilePickerParams params) async {
    List<String>? result;
    try {
      result = await pickOrSavePlugin.filePicker(params: params);
    } on PlatformException catch (e) {
      log(e.toString());
    } catch (e) {
      log(e.toString());
    }

    return result;
  }

  callSnackBar({required BuildContext context, required String? text}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text.toString()),
    ));
  }

  Future<String> normalizedText(String text) async {
    // Removing the punctuations and converting to lower case.
    final cleanText = text.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();

    // Applying the soundex algorithm to the line.
    // Split the sentence into words
    final words = cleanText.split(' ');

    // Apply Soundex to each word and collect matches
    final correctedWords = <String>[];
    for (final word in words) {
      final soundexCode = calculateSoundex(word);
      final matches = searchDictionary(
          await loadDictionary('assets/dictionary.txt'), soundexCode);

      if (matches.isNotEmpty) {
        print('Matches for $word: $matches');
        correctedWords.add(matches.first);
      } else {
        correctedWords.add(word);
      }
    }

    // Construct the corrected sentence
    final normalizedSentence = correctedWords.join(' ');

    // Print the corrected sentence.
    log('Normalized sentence: $normalizedSentence');
    // Print the original sentence.
    log('Original sentence: $text');
    return normalizedSentence;
  }
}
