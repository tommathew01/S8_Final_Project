import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchProvider with ChangeNotifier {
  bool _search = true;
  bool get search => _search;

  var _res = "";
  String get res => _res;

  void setres(String value) {
    _res = value;
    notifyListeners();
  }

  void setsearch(bool value) {
    _search = value;
    notifyListeners();
  }

  String apiUrl =
      "https://api-inference.huggingface.co/models/atharvamundada99/bert-large-question-answering-finetuned-legal";
  Map<String, String> headers = {
    "Authorization": "Bearer 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",
  };

  Future<String> questionQuery(Map<String, dynamic> payload) async {
    var output;
    do {
      var response = await http.post(Uri.parse(apiUrl),
          headers: headers, body: jsonEncode(payload));
      print(response.body);
      output = jsonDecode(response.body);
      print("here is testing imp10");
      print(output);
    } while (output['error'] != null);
    return output['answer'];
  }
}
