import 'dart:developer';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:pick_or_save/pick_or_save.dart';

import 'package:mood_bud/utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Hinglish Classification',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              colorScheme: lightDynamic ?? const ColorScheme.light(),
              useMaterial3: true),
          darkTheme: ThemeData(
              colorScheme: darkDynamic ?? const ColorScheme.dark(),
              useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Utils utils = Utils();

  bool isPicking = false;
  String unprocessedWhatsAppChat = '';
  String processedWhatsAppChat = '';
  Map<String, List<String>> processedChatMap = {};
  bool isClassifying = false;
  Map<String, List<String>> predictedChatMap = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hinglish Classification"),
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              "Note: This app is just created for testing out the Tensorflow "
              "Lite model generated using Tensorflow Model Maker Library. "
              "It is not a full fledged app and currently only supports "
              "WhatsApp chat data.",
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 16),
            StageCard(
              icon: Icons.looks_one_rounded,
              stageTitle: 'For Loading Data',
              content: FilledButton(
                onPressed: isPicking
                    ? null
                    : () async {
                        setState(() {
                          isPicking = true;
                        });

                        final params = FilePickerParams(
                          localOnly: true,
                          getCachedFilePath: true,
                          allowedExtensions: ['txt'],
                          mimeTypesFilter: ['text/plain'],
                        );

                        List<String>? result = await utils.filePicker(params);

                        setState(() {
                          isPicking = false;
                        });

                        if (mounted) {
                          if (result == null) {
                            utils.callSnackBar(
                                context: context, text: result.toString());
                          } else {
                            // For getting unprocessed data from file.
                            File file = File(result.first);
                            unprocessedWhatsAppChat = await file.readAsString();
                            setState(() {});

                            // For getting processed data from unprocessed data.
                            processedWhatsAppChat = utils
                                .processWhatsAppData(unprocessedWhatsAppChat);
                            // processedChatMap = utils
                            //     .whatsAppChatDataToMap(processedWhatsAppChat!);

                            setState(() {});
                          }
                        }
                      },
                child: const Text("Pick WhatsApp Chat"),
              ),
            ),
            const SizedBox(height: 16),
            StageCard(
              icon: Icons.looks_two_rounded,
              stageTitle: 'Unprocessed Data',
              content: SizedBox(
                height: 150,
                child: SingleChildScrollView(
                  child: Text(
                    unprocessedWhatsAppChat.isNotEmpty
                        ? unprocessedWhatsAppChat
                        : "No File Selected",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StageCard(
              icon: Icons.looks_3_rounded,
              stageTitle: 'Processed Data',
              content: SizedBox(
                height: 150,
                child: SingleChildScrollView(
                  child: Text(
                    processedWhatsAppChat.isNotEmpty
                        ? processedWhatsAppChat
                        : "No File Selected",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StageCard(
              icon: Icons.looks_4_rounded,
              stageTitle: 'Classify Data',
              content: !isClassifying
                  ? FilledButton(
                      onPressed: processedWhatsAppChat.isNotEmpty
                          ? () async {
                              setState(() {
                                isClassifying = true;
                              });

                              // copy file to cache in flutter
                              String modelCacheFilepath =
                                  // await copyAssetFileToCacheDirectory(
                                  //     'assets/average_word_vec.tflite');
                                  await utils.copyAssetFileToCacheDirectory(
                                      'assets/mobilebert.tflite');

                              List<String> lines =
                                  processedWhatsAppChat.split('\n');

                              for (final line in lines) {
                                if (isClassifying == false) {
                                  break;
                                }
                                final index = line.indexOf(':');
                                final name = line.substring(0, index);
                                var message = line.substring(index + 1).trim();

                                // Would need a little more tweaks to work properly.
                                // So commented out for now.
                                // // Normalise the message.
                                // message = await utils.normalizedText(message);

                                // Classify the message.
                                String predictedLabel = await utils
                                    .classifyData(message, modelCacheFilepath);

                                if (processedChatMap.containsKey(name)) {
                                  processedChatMap[name]?.add(message);

                                  predictedChatMap[name]?.add(predictedLabel);
                                } else {
                                  processedChatMap[name] = [message];

                                  predictedChatMap[name] = [predictedLabel];
                                }

                                // Log predicted label with message.
                                log("Predicted Label: $predictedLabel, Message: $message");

                                // log(predictedChatMap.toString());

                                setState(() {});
                              }

                              setState(() {
                                isClassifying = false;
                              });
                            }
                          : null,
                      child: const Text("Classify WhatsApp Chat"),
                    )
                  : Column(
                      children: [
                        const CircularProgressIndicator(),
                        Text(
                            "Processing Message ${predictedChatMap.values.fold<int>(0, (previousValue, element) => previousValue + element.length)} out of ${processedWhatsAppChat.split('\n').length}"),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              isClassifying = false;
                            });
                          },
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            StageCard(
              icon: Icons.looks_5_rounded,
              stageTitle: 'Predictions',
              content: predictedChatMap.isEmpty
                  ? const Text("Classify to get predictions")
                  : PredictionCardContent(
                      predictedChatMap: predictedChatMap,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            isPicking = false;
            unprocessedWhatsAppChat = '';
            processedWhatsAppChat = '';
            processedChatMap = {};
            isClassifying = false;
            predictedChatMap = {};
          });
        },
        tooltip: 'Reset',
        child: const Icon(Icons.clear_all),
      ),
    );
  }
}

class StageCard extends StatelessWidget {
  const StageCard(
      {Key? key,
      required this.icon,
      required this.stageTitle,
      required this.content})
      : super(key: key);

  final IconData icon;
  final String stageTitle;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const SizedBox(
            height: 8,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon),
              Text(stageTitle),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: content,
          ),
          const SizedBox(
            height: 8,
          ),
        ],
      ),
    );
  }
}

class PredictionCardContent extends StatelessWidget {
  const PredictionCardContent({Key? key, required this.predictedChatMap})
      : super(key: key);

  final Map<String, List<String>> predictedChatMap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        for (var entry in predictedChatMap.entries)
          UserEmotionsCard(user: entry.key, emotions: entry.value),
      ],
    );
  }
}

class UserEmotionsCard extends StatelessWidget {
  const UserEmotionsCard({Key? key, required this.user, required this.emotions})
      : super(key: key);

  final String user;
  final List<String> emotions;

  Map<String, int> calculateEmotionCount(List<String> emotions) {
    Map<String, int> emotionCount = {
      'Anger': 0,
      'Disgust': 0,
      'Fear': 0,
      'Happiness': 0,
      'Neutral': 0,
      'Sadness': 0,
      'Surprise': 0,
    };

    for (var emotion in emotions) {
      if (emotionCount.containsKey(emotion)) {
        emotionCount[emotion] = emotionCount[emotion]! + 1;
      }
    }

    return emotionCount;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> emotionCount = calculateEmotionCount(emotions);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              user,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Table(
            border: TableBorder(
              verticalInside: BorderSide(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  style: BorderStyle.solid),
              top: BorderSide(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  style: BorderStyle.solid),
            ),
            columnWidths: const <int, TableColumnWidth>{
              0: FixedColumnWidth(90),
              1: FixedColumnWidth(40),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(
              emotionCount.entries.length,
              (index) {
                final entry = emotionCount.entries.elementAt(index);
                return TableRow(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        entry.value.toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
