import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/recorder.dart';


class RecordProvider with ChangeNotifier{
  
  
  String _filePath = '/sdcard/Download/audio.wav';
    final String apiUrl = "https://api-inference.huggingface.co/models/openai/whisper-large-v2";
  final Map<String, String> headers = {"Authorization": "Bearer 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"};
  final recoder = RecorderService();
  Future<void> startRecording() async {
    print('started');
    
    recoder.record();

  }

 Future<String> query(String filename) async {
  File file = File(filename);
  List<int> data = await file.readAsBytes();
  var response = await http.post(Uri.parse(apiUrl), headers: headers, body: data);
  Map<String, dynamic> result = jsonDecode(response.body);
  return result["text"];
}



addText(String text) async{
   final data;
   String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
   final textId = FirebaseFirestore.instance
        .collection('users/${FirebaseAuth.instance.currentUser!.uid}/texts')
        .doc(currentDate);
    DocumentSnapshot snapshot = await textId.get();
    data=snapshot.data();
    String? available = data?['content'] as String?;

    String newText = (available ?? '') + text;
   textId.set({
      'id':textId,
      'content':newText
   });
  }

Future<void> stopRecording() async {

  print('stoped');
    try {
      // String outputPath = '${(await getTemporaryDirectory()).path}/output.wav';
      recoder.stopRecorder();
      //   final output = await query(outputPath);
      //  addText(output);
      //  print(output);
    } catch (e) {
      print('Failed to stop recording: $e');
    }
  }


}