import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const VoiceBridgeApp());
}

class VoiceBridgeApp extends StatelessWidget {
  const VoiceBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'VoiceBridge',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: const VoiceTranslationScreen(),
    );
  }
}

class TranslationController extends GetxController {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  var speechEnabled = false.obs;
  var recognizedText = ''.obs;
  var translatedText = ''.obs;
  var isRecording = false.obs;
  var sourceLanguage = 'en'.obs;
  var targetLanguage = 'ta'.obs;
  var isTranslating = false.obs;

  final List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ta', 'name': 'Tamil'},
  ];

  @override
  void onInit() {
    super.onInit();
    _requestPermissions();
    _initSpeech();
    _initTts();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  void _initSpeech() async {
    speechEnabled.value = await _speechToText.initialize(
      onError: (error) => print('Speech error: $error'),
      onStatus: (status) => print('Speech status: $status'),
    );
  }

  void _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setLanguage('en-US'); // Default to English
  }

  void startListening() async {
    if (speechEnabled.value) {
      isRecording.value = true;
      await _speechToText.listen(
        onResult: (result) {
          recognizedText.value = result.recognizedWords;
        },
        localeId: sourceLanguage.value == 'en' ? 'en-US' : 'ta-IN',
      );
    }
  }

  void stopListening() async {
    isRecording.value = false;
    await _speechToText.stop();
    if (recognizedText.value.isNotEmpty) {
      translateText(recognizedText.value, sourceLanguage.value, targetLanguage.value);
    }
  }

  Future<void> translateText(String text, String sourceLang, String targetLang) async {
    const apiKey = 'AIzaSyDv6ObSm0MpiMyqUQ1lHkLiH4IkYGbXtVc'; // Replace with your Gemini AI API key
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';

    isTranslating.value = true;
    try {
      final response = await http.post(
        Uri.parse('$url?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'Translate the following text from $sourceLang to $targetLang and return only the translated text: "$text"',
                },
              ],
            },
          ],
        }),
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates']?.isNotEmpty == true &&
            data['candidates'][0]['content']?['parts']?.isNotEmpty == true) {
          translatedText.value = data['candidates'][0]['content']['parts'][0]['text'];
          await _speakTranslatedText(translatedText.value, targetLang);
        } else {
          translatedText.value = 'Error: Invalid response structure';
          Get.snackbar('Error', 'Invalid API response structure',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.redAccent,
              colorText: Colors.white);
        }
      } else {
        translatedText.value = 'Error: Failed to translate (Status: ${response.statusCode})';
        Get.snackbar('Error', 'Translation failed (Status: ${response.statusCode})',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white);
      }
    } catch (e) {
      print('Translation Error: $e');
      translatedText.value = 'Error: $e';
      Get.snackbar('Error', 'Translation error: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
    } finally {
      isTranslating.value = false;
    }
  }

  Future<void> _speakTranslatedText(String text, String targetLang) async {
    try {
      await _flutterTts.setLanguage(targetLang == 'en' ? 'en-US' : 'ta-IN');
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
      Get.snackbar('Error', 'TTS not supported for ${targetLang == 'en' ? 'English' : 'Tamil'} on this device',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
    }
  }
}

class VoiceTranslationScreen extends StatelessWidget {
  const VoiceTranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TranslationController());

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade300, Colors.blue.shade900],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
            Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VoiceBridge Translator',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Source Language:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Obx(
                            () => DropdownButton<String>(
                          value: controller.sourceLanguage.value,
                          isExpanded: true,
                          items: controller.languages
                              .map<DropdownMenuItem<String>>((Map<String, String> lang) {
                            return DropdownMenuItem<String>(
                              value: lang['code'],
                              child: Text(lang['name']!),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              controller.sourceLanguage.value = newValue;
                              controller.targetLanguage.value =
                              newValue == 'en' ? 'ta' : 'en';
                            }
                          },
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Target Language:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Obx(
                            () => Text(
                          controller.targetLanguage.value == 'en' ? 'English' : 'Tamil',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recognized Text:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Obx(
                                    () => Text(
                                  controller.recognizedText.value.isEmpty
                                      ? 'No text recognized'
                                      : controller.recognizedText.value,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Translated Text:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Obx(
                                    () => controller.isTranslating.value
                                    ? Center(
                                  child: LoadingAnimationWidget.waveDots(
                                    color: Colors.blue,
                                    size: 40,
                                  ),
                                )
                                    : Text(
                                  controller.translatedText.value.isEmpty
                                      ? 'No translation yet'
                                      : controller.translatedText.value,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: Obx(
    () => FloatingActionButton(
    onPressed: controller.speechEnabled.value
    ? (controller.isRecording.value
    ? controller.stopListening
        : controller.startListening)
        : null,
    backgroundColor: controller.isRecording.value ? Colors.red : Colors.blue,
    child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    child: Icon(
    controller.isRecording.value ? Icons.mic : Icons.mic_none,
    size: controller.isRecording.value ? 32 : 28,
    ),
    ),
    ),
    ),
    );
  }
}