import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:audio_session/audio_session.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vad/flutter_vad.dart';
import 'package:intl/intl.dart';
import 'package:memory_aid/provider/summary_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:memory_aid/provider/record_provider.dart';
import 'package:provider/provider.dart';

class RecorderService {
  final recorder = AudioStreamer.instance;
  final vad = FlutterVad();

  //audio to text api
  final String apiUrl =
      "https://api-inference.huggingface.co/models/openai/whisper-large-v2";
  final Map<String, String> headers = {
    "Authorization": "Bearer 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"
  };

  // Get the info about is today summary is created

  bool is_summary_generated = false;

  // Get the path to store the downloaded model file
  Future<String> get modelPath async =>
      '${(await getApplicationSupportDirectory()).path}/our_vad.onnx';

  // Sample rate (frequency) of the audio recording in Hz
  final int sampleRate = 16000;

  // Size of the audio frame in milliseconds (80ms in this case)
  final int frameSize = 40;

  // Bits per sample used to represent the audio data (16 for typical audio)
  final int bitsPerSample = 16;

  // Number of audio channels (1 for mono, 2 for stereo)
  final int numChannels = 1;

  bool isInited = false;

  // Stores the most recent audio data
  final lastAudioData = <int>[];

  // Tracks the last time voice activity was detected
  DateTime? lastActiveTime;

  // Stream controller for processed audio data (with voice activity detection)
  final processedAudioStreamController =
      StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? recordingDataSubscription;
  StreamSubscription<List<int>>? processedAudioSubscription;

  // Buffer to hold audio frames
  final frameBuffer = <int>[];

  // Initializes the recorder service
  Future<void> init() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      // Configure audio session for recording and playback
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      // Enable echo cancellation on iOS for voice chat
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
    isInited = true;
  }

  // Starts recording audio and processes it for voice activity detection
  Future<void> record() async {
    // assert(isInited);

    await recorder.startRecording();
    await onnxModelToLocal();
    await vad.initialize(
      modelPath: await modelPath,
      sampleRate: sampleRate,
      frameSize: frameSize,
      threshold: 0.7,
      minSilenceDurationMs: 100,
      speechPadMs: 0,
    );
    recordingDataSubscription = recorder.audioStream.listen((buffer) async {
      final data = _transformBuffer(buffer);
      printVolume(data);
      if (data.isEmpty) return;
      frameBuffer.addAll(buffer);
      while (frameBuffer.length >= frameSize * 2 * sampleRate ~/ 1000) {
        final b = frameBuffer.take(frameSize * 2 * sampleRate ~/ 1000).toList();
        frameBuffer.removeRange(0, frameSize * 2 * sampleRate ~/ 1000);
        print('here is testing b : $b');
        await _handleProcessedAudio(b);
      }
      // controller.add(data);
    });

    processedAudioSubscription =
        processedAudioStreamController.stream.listen((buffer) async {
      String outputPath = '${(await getTemporaryDirectory()).path}/output.wav';
      saveAsWav(buffer, outputPath);
      final output = await query(outputPath);
      addText(output);
      print(output);
      print('saved');
    });
  }

  Future<String> query(String filename) async {
    File file = File(filename);
    List<int> data = await file.readAsBytes();
    Map<String, dynamic> result;
    print('data is $data');
    do{
      var response =
        await http.post(Uri.parse(apiUrl), headers: headers, body: data);
    result = jsonDecode(response.body);
    
    }while(result==null);
    return result["text"];
  }

  addText(String text) async {
    final data;
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final textId = FirebaseFirestore.instance
        .collection('users/${FirebaseAuth.instance.currentUser!.uid}/texts')
        .doc(currentDate);

    DocumentSnapshot snapshot = await textId.get();

    if (snapshot.exists) {
      data = snapshot.data();
      String? available = data?['content'] as String?;

      String newText = (available ?? '') + text;
      textId.set({
        'is_summarized': data?['is_summarized'],
        'id': textId,
        'content': newText
      });
    } else {
      data = snapshot.data();
      String? available = data?['content'] as String?;
      String newText = (available ?? '') + text;
      textId.set({'is_summarized': false, 'id': textId, 'content': newText});
    }
  }

  // Stops recording audio and cancels subscriptions
  Future<void> stopRecorder() async {
    await recorder.stopRecording();
    if (recordingDataSubscription != null) {
      await recordingDataSubscription?.cancel();
      recordingDataSubscription = null;
      await processedAudioSubscription?.cancel();
      processedAudioSubscription = null;
    }
  }

  // Converts a byte buffer to a short integer list
  Int16List _transformBuffer(List<int> buffer) {
    final bytes = Uint8List.fromList(buffer);
    return Int16List.view(bytes.buffer);
  }

  // Prints the volume level of the audio data
  void printVolume(List<int> data) {
    // Calculates and prints the root mean square (RMS) of the audio data
    double sum = 0;
    for (var i = 0; i < data.length; i += 2) {
      final int16 =
          data[i] + (data[i + 1] << 8); // Combine bytes for 16-bit value
      final double sample = int16 / (1 << 15); // Normalize to -1 to 1 range
      sum += sample * sample; // Square the sample value
    }

    final double rms = sqrt(sum / (data.length / 2)); // Calculate RMS
    final double volume = 20 * log(rms) / ln10; // Convert to decibels (dB)

    print('Volume: $volume dB');
  }

  // Threshold for voice activity detection (adjustable based on noise level)
  static const threshold = 900;

  // Buffer time in milliseconds to store recent audio before saving
  static const bufferTimeInMilliseconds = 5000;

  // Buffer to store audio data for processing
  final audioDataBuffer = <int>[];

  // Processes a buffer of audio data for voice activity detection
  Future<void> _handleProcessedAudio(List<int> buffer) async {
    print('inside handle process');
    final transformedBuffer = _transformBuffer(buffer);
    final transformedBufferFloat =
        transformedBuffer.map((e) => e / 32768).toList(); // Convert to float

    // Use the voice activity detection (VAD) model to predict voice activity
    var isActivated =
        await vad.predict(Float32List.fromList(transformedBufferFloat));
    print('here is printing : $isActivated');

    // checking for if the time for summarisation is reached or not

    //  we are checking for 3 conditions
    // 1. user's sleep time is reached
    // 2. user is not speaking for a long time(5s)
    // 3. user is not speaking right now

    // var user_sleep_time_hour = 18;
    // if (!is_summary_generated && DateTime.now().hour == user_sleep_time_hour) {
    //   if (isActivated != true && lastActiveTime == null) {
    //     // checking wheather already summarized or not

    //     final data;
    //     String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    //     final textId = FirebaseFirestore.instance
    //         .collection('users/${FirebaseAuth.instance.currentUser!.uid}/texts')
    //         .doc(currentDate);
    //     DocumentSnapshot snapshot = await textId.get();

    //     if (snapshot.exists) {
    //       data = snapshot.data();
    //       is_summary_generated = data?['is_summarized'];

    //       // checking wheather already summarized or not
    //       if (!is_summary_generated) {
    //         print("its time for summary");

    //         // final provider = RecordProvider();
    //         print("stoping listening");

    //         // call the summary functions
    //         String? available = data?['content'] as String?;

    //         final provider = SummaryProvider();
    //         final summary = await provider.Summaryquery({"inputs": available});
    //         print("summary is : $summary");
    //         final summaryId = FirebaseFirestore.instance
    //             .collection(
    //                 'users/${FirebaseAuth.instance.currentUser!.uid}/summary')
    //             .doc(currentDate);
    //         summaryId.set(
    //             {'id': summaryId, 'summary': summary, 'date': currentDate});

    //         is_summary_generated = true;
    //         print("the truth value :");
    //         print(is_summary_generated);

    //         // updating the is_summary in the firebase

    //         textId.update({
    //           'is_summarized':
    //               is_summary_generated, // Update the value of 'is_summarized'
    //         });

    //         print("Resuming listening im waiting");
    //       }
    //     }
    //     // checking wheather already summarized or not
    //   }
    // }

    print("current time = ");
    print(DateTime.now().hour == 14);
    print('time diff :');
    if (lastActiveTime != null)
      print(DateTime.now().difference(lastActiveTime!));
    else
      print(null);

    if (isActivated == true) {
      // Voice detected, update last active time and audio buffer
      lastActiveTime = DateTime.now();
      audioDataBuffer.addAll(lastAudioData);
      lastAudioData.clear();
      audioDataBuffer.addAll(buffer);
    } else if (lastActiveTime != null) {
      // No voice detected but voice was previously active, keep buffering
      audioDataBuffer.addAll(buffer);
      print(DateTime.now().difference(lastActiveTime!));

      // Save audio data if a certain amount of time has passed since last activity
      if (DateTime.now().difference(lastActiveTime!) >
          const Duration(milliseconds: bufferTimeInMilliseconds)) {
        processedAudioStreamController.add([...audioDataBuffer]);
        audioDataBuffer.clear();
        lastActiveTime = null;
      }
    } else {
      // No voice currently detected, store recent audio data in a buffer
      lastAudioData.addAll(buffer);

      // Limit the size of the recent audio data buffer
      if (lastAudioData.length > sampleRate * 500 ~/ 1000) {
        lastAudioData.removeRange(
            0, lastAudioData.length - sampleRate * 500 ~/ 1000);
      }
    }
  }

  // Saves a list of integers as a WAV audio file
  void saveAsWav(List<int> buffer, String filePath) {
    // Convert the audio data to appropriate WAV format

    final bytes = Uint8List.fromList(buffer);
    final pcmData = Int16List.view(bytes.buffer);
    final byteBuffer = ByteData(pcmData.length * 2);

    for (var i = 0; i < pcmData.length; i++) {
      byteBuffer.setInt16(i * 2, pcmData[i],
          Endian.little); // Write each sample to the byte buffer
    }

    final ByteData wavHeader = ByteData(44);
    final pcmBytes = byteBuffer.buffer.asUint8List();

    // Define the WAV header structure

    // RIFF Chunk
    wavHeader.setUint8(0x00, 0x52); // 'R'
    wavHeader.setUint8(0x01, 0x49); // 'I'
    wavHeader.setUint8(0x02, 0x46); // 'F'
    wavHeader.setUint8(0x03, 0x46); // 'F'
    wavHeader.setUint32(
        4, 36 + pcmBytes.length, Endian.little); // ChunkSize (including data)
    wavHeader.setUint8(0x08, 0x57); // 'W'
    wavHeader.setUint8(0x09, 0x41); // 'A'
    wavHeader.setUint8(0x0A, 0x56); // 'V'
    wavHeader.setUint8(0x0B, 0x45); // 'E'
    wavHeader.setUint8(0x0C, 0x66); // 'f'
    wavHeader.setUint8(0x0D, 0x6D); // 'm'
    wavHeader.setUint8(0x0E, 0x74); // 't'
    wavHeader.setUint8(0x0F, 0x20); // ' '
    wavHeader.setUint32(
        16, 16, Endian.little); // Subchunk1Size (size of format block)
    wavHeader.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    wavHeader.setUint16(22, numChannels, Endian.little); // NumChannels
    wavHeader.setUint32(24, sampleRate, Endian.little); // SampleRate
    wavHeader.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8,
        Endian.little); // ByteRate (data transfer rate)
    wavHeader.setUint16(32, numChannels * bitsPerSample ~/ 8,
        Endian.little); // BlockAlign (number of bytes per audio frame)
    wavHeader.setUint16(34, bitsPerSample, Endian.little); // BitsPerSample

    // data Chunk
    wavHeader.setUint8(0x24, 0x64); // 'd'
    wavHeader.setUint8(0x25, 0x61); // 'a'
    wavHeader.setUint8(0x26, 0x74); // 't'
    wavHeader.setUint8(0x27, 0x61); // 'a'
    wavHeader.setUint32(40, pcmBytes.length,
        Endian.little); // Subchunk2Size (size of audio data)

    final File wavFile = File(filePath);
    wavFile.writeAsBytesSync(wavHeader.buffer.asUint8List() + pcmBytes);
  }

  // Copies the ONNX model file from assets to the application directory
  Future<void> onnxModelToLocal() async {
    final data = await rootBundle.load('assets/vad_model/our_vad.onnx');
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    File(await modelPath).writeAsBytesSync(bytes);
  }
}
