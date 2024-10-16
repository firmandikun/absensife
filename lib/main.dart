import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
    if (!status.isGranted) {
      print('Camera permission not granted');
    }
  }
}

Future<void> requestLocationPermission() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    status = await Permission.location.request();
    if (!status.isGranted) {
      print('Location permission not granted');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestCameraPermission();
  await requestLocationPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter InAppWebView',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: WebViewContainer(),
    );
  }
}

class WebViewContainer extends StatefulWidget {
  const WebViewContainer({super.key});

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late InAppWebViewController _controller;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://absensi-upy.developer-release.my.id/')),
              onWebViewCreated: (InAppWebViewController controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = '';
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                // Inject JavaScript for location access
                await _injectWebcamJSCheck();
              },
              onLoadError: (controller, url, code, message) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Error: $message';
                });
                print('WebView error: $message');
              },
              onGeolocationPermissionsShowPrompt: (InAppWebViewController controller, String origin) async {
                return GeolocationPermissionShowPromptResponse(
                  allow: true,
                  origin: origin,
                  retain: true,
                );
              },
            ),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_errorMessage.isNotEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });
                        _controller.reload();
                      },
                      child: const Text('Reload Page'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _injectWebcamJSCheck() async {
    await _controller.evaluateJavascript(source: '''
      function requestLocation() {
        if (navigator.geolocation) {
          navigator.geolocation.getCurrentPosition(
            function(position) {
              console.log('Location access granted');
              console.log('Latitude: ' + position.coords.latitude);
              console.log('Longitude: ' + position.coords.longitude);
            },
            function(error) {
              console.error('Location access denied: ' + error.message);
              if (error.code === error.PERMISSION_DENIED) {
                alert('Location permission is required to use this feature. Please open settings and allow location access.');
              }
            }
          );
        } else {
          console.error('Geolocation is not supported by this browser.');
        }
      }

      navigator.permissions.query({ name: 'geolocation' }).then(function(result) {
        if (result.state === 'granted') {
          requestLocation();
        } else if (result.state === 'prompt') {
          alert('Please allow location access.');
          requestLocation(); // Ask for location again after alert
        } else {
          alert('Location permission not granted.');
        }
      });
    ''');
  }
}
