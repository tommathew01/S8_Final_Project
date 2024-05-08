import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryProvider with ChangeNotifier {
  String? _selectedDate;
  String _selectedSummary = '';
  int? _questionCount;
  int? get questionCount => _questionCount;
  String? get selectedDate => _selectedDate;
  String? get selectedSummary => _selectedSummary;

  void setselectedDate(String? value) {
    _selectedDate = value;
    notifyListeners();
  }

  void initselectedDate(String? value) {
    _selectedDate = value;
  }

  void initselectedSummary(String value) {
    _selectedSummary = value;
  }

  void setselectedSummary(String value) {
    _selectedSummary = value;
    notifyListeners();
  }

  void setQuestionCount(int questionCount) {
    _questionCount = questionCount;
    notifyListeners();
  }

  String apiUrl =
      "https://api-inference.huggingface.co/models/potsawee/t5-large-generation-squad-QuestionAnswer";
  Map<String, String> headers = {
    "Authorization": "Bearer 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",
  };

  // Future getText() async {
  //     String currentDate =
  //               DateFormat('yyyy-MM-dd').format(DateTime.now());
  //     final data;
  //     final textId = FirebaseFirestore.instance.collection(
  //                   'users/${FirebaseAuth.instance.currentUser!.uid}/text')
  //               .doc(currentDate);
  //           DocumentSnapshot snapshot = await textId.get();
  //           data = snapshot.data();
  //           String? available = data?['content'] as String?;
  //   return available;
  // }

  Future<String> questionQuery(Map<String, dynamic> payload) async {
    var output;
    do {
      var response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: jsonEncode(payload));

      print("testing imp here");
      print(response);
      print(response.body);
      output = jsonDecode(response.body);
      print(output[0]);
    } while (output[0] == null);

    return output[0]['generated_text'];
  }

  final summaryapiUrl =
      "https://api-inference.huggingface.co/models/naisel/pegasus-with-samsum-dataset";
  final summaryheaders = {
    "Authorization": "Bearer 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",
  };
  Future<String> Summaryquery(Map<String, dynamic> payload) async {
    // var text_payl = getText();
    var output;

    print("payload:${payload}");

    do {
      var response = await http.post(Uri.parse(summaryapiUrl),
          headers: summaryheaders, body: jsonEncode(payload));
      print("res:${response.body}");
      output = await jsonDecode(response.body);
      print(output[0]);
    } while (output[0] == null);
    String output_summary = output[0]['generated_text'];
    List<String> splited_summary = output_summary.split(".");
    print("testing imp here3");
    print(splited_summary);
    int j = 0;
    for (int i = 0; i < splited_summary.length - 1; i++) {
      String Qoutput = await questionQuery({
        "inputs": splited_summary[i],
      });
      print("testing imp here 2");
      print(Qoutput);
      List<String> parts = Qoutput.split("?");
      if (parts.length == 1) continue;
      String question = parts[0].trim();
      String answer = parts[1].trim();
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      FirebaseFirestore.instance
          .collection(
              'users/${FirebaseAuth.instance.currentUser!.uid}/exercise')
          .doc('${currentDate}')
          .set({'question${++j}': question, 'answer${j}': answer},
              SetOptions(merge: true));

      print("question part : " + question);
      print(answer);
    }

    setQuestionCount(j);

    print(output[0]['generated_text']);
    return output[0]['generated_text'];
  }
}
