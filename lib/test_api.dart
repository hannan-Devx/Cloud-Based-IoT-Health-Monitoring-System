import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String url = "https://a1sdvq1q3j.execute-api.me-central-1.amazonaws.com/prod/vitals";

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("Vitals Data: $data");
    } else {
      print("Failed with status: ${response.statusCode}");
    }
  } catch (e) {
    print("Error: $e");
  }
}
