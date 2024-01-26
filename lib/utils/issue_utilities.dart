import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String> getApiUrl() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? storedApiUrl = prefs.getString('jiraApiUrl');
  return (storedApiUrl != null && !storedApiUrl.endsWith('/')) ? '$storedApiUrl/' : storedApiUrl ?? '';
}

Future<void> openIssueUrl(String issueKey) async {
  try {
    final apiUrl = await getApiUrl();
    final issueUrl = Uri.parse('${apiUrl}browse/${issueKey}');
    if (await canLaunchUrl(issueUrl)) {
      await launchUrl(issueUrl);
    } else {
      // Handle the error or show a message
      throw "Could not launch $issueUrl";
    }
  } catch (e) {
    // Handle any exceptions
    throw "Error: $e";
  }
}
