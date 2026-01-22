import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smler_deferred_link/smler_deferred_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});


  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? status;
  Map<String, String> params = {};
  Map<String, dynamic>? apiResponse;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Check if the app has been initialized before
      final prefs = await SharedPreferences.getInstance();
      final hasInitialized = prefs.getBool('has_initialized') ?? false;
      
      if (hasInitialized) {
        print('App already initialized, skipping deferred link check');
        status = "Already initialized";
        setState(() {});
        return;
      }

      print('Calling inside the app and checking deferred deep link');
      if (Platform.isAndroid) {
        final info = await SmlerDeferredLink.getInstallReferrerAndroid();
        params = info.asQueryParameters;
        final pathParams = info.extractShortCodeAndDltHeader();
        // params = info.installReferrer;
        final clickId = info.getParam('clickId');
        print('Android Referrer Params: $params Click Id: $clickId');
        print('Path Params: $pathParams');
        if(clickId.isEmpty == false) {
          final apiRes = await info.trackClick();
          print('API Response: $apiRes');
          apiResponse = apiRes;
        }
        status = "Android Referrer Loaded";
      } else if (Platform.isIOS) {
        final res = await SmlerDeferredLink.getInstallReferrerIos(
          deepLinks: ["go.singh3y.dev"],
        );
        if (res != null) {
          params = res.queryParameters;
          final clickId = res.getParam('clickId');
          print('iOS Deep Link Params: $params and Click Id: $clickId');
          status = "iOS Clipboard Deep Link Loaded";
          res.trackClick();
        } else {
          print('No deep link found');
          status = "No deep link found";
        }
      }

      // Mark as initialized
      await prefs.setBool('has_initialized', true);
    } catch (e) {
      print('Error fetching referrer: $e');
      status = "Error: $e";
    }

    setState(() {});
  }

  Future<void> _clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      setState(() {
        status = "Preferences cleared. Reinitializing...";
        params = {};
        apiResponse = null;
      });
      print('Shared preferences cleared');
      // Reinitialize after clearing
      await _init();
    } catch (e) {
      print('Error clearing preferences: $e');
      setState(() {
        status = "Error clearing preferences: $e";
      });
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Smler Deferred Link")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(status ?? "Loading..."),
              const SizedBox(height: 20),
              const Text("Params:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...params.entries.map((e) => Text("${e.key}: ${e.value}")),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const Text("API Response:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (apiResponse != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(apiResponse),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                )
              else
                const Text("No API response yet"),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _clearPreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Clear Shared Preferences & Reinitialize', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}