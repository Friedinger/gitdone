import 'package:flutter/material.dart';
import 'package:gitdone/utility/token_handler.dart';
import 'package:gitdone/widgets/github_code_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/webview_page.dart';

class GitHubAuth {
  final String clientId = "Ov23li2QBbpgRa3P0GHJ";
  final tokenHandler = TokenHandler();

  Future<bool> login(BuildContext context) async {
    final response = await http.post(
      Uri.parse("https://github.com/login/device/code"),
      headers: {"Accept": "application/json"},
      body: {"client_id": clientId, "scope": "repo user"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final deviceCode = data["device_code"];
      final userCode = data["user_code"];
      final verificationUri = data["verification_uri"];
      final interval = data["interval"];
      if (context.mounted) await _showGitHubCodeDialog(context, userCode);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewPage(url: "$verificationUri?user_code=$userCode"),
        ),
      );
      return await _pollForToken(deviceCode, interval);
    }
    return false;
  }

  Future<void> _showGitHubCodeDialog(BuildContext context, String userCode) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return GithubCodeDialog(userCode: userCode);
      },
    );
  }

  Future<bool> _pollForToken(String deviceCode, int interval) async {
    bool success = false;
    while (true) {
      await Future.delayed(Duration(seconds: interval));
      http.Client _client = http.Client();
      try {
        final response = await _client.post(
          Uri.https("github.com", "/login/oauth/access_token"),
          headers: {"Accept": "application/json"},
          body: {
            "client_id": clientId,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
          },
        );
        _client.close();

        final data = jsonDecode(response.body);
        if (data.containsKey("access_token")) {
          await tokenHandler.saveToken(data["access_token"]);
          success = true;
          break;
        } else {
          if (data.containsKey("error") && data["error"] == "authorization_pending") {
            continue;
          } else {
            break;
          }
        }
      } catch (e) {
        print("Unexpected error: $e");
      }
    }
    return success;
  }
}
