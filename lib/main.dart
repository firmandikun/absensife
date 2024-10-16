import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

Future<void> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
    if (!status.isGranted) {
      print('Izin kamera tidak diberikan');
    }
  }
}

Future<void> requestLocationPermission() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    status = await Permission.location.request();
    if (!status.isGranted) {
      print('Izin lokasi tidak diberikan');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestCameraPermission();
  await requestLocationPermission(); // Tambahkan ini
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebView dengan Kamera',
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
  late final WebViewController _controller;
  bool _isLoading = true;
  String _errorMessage = '';
  int _loadAttempts = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (WebViewPermissionRequest request) async {
        print('Permintaan izin diterima: ${request.types}');
        return request.grant();
      },
    );

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = '';
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectWebcamJSCheck();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Error: ${error.description}';
            });
            print('WebView error: ${error.description}');
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // Delay loading the main page
    Future.delayed(const Duration(seconds: 2), () {
      _controller.loadRequest(Uri.parse('https://absensi-upy.developer-release.my.id/'));
    });
  }

 Future<void> _injectWebcamJSCheck() async {
  await _controller.runJavaScript('''
    function checkAndLoadWebcamJS() {
      if (typeof Webcam === 'undefined') {
        console.error('webcam.js is not loaded yet');
        var script = document.createElement('script');
        script.src = 'https://absensi-upy.developer-release.my.id/js/webcam.js';
        script.onload = function() {
          console.log('webcam.js loaded manually');
        };
        script.onerror = function() {
          console.error('Failed to load webcam.js manually');
        };
        document.head.appendChild(script);
      } else {
        console.log('webcam.js is already loaded');
      }

      // Cek izin lokasi
      if (navigator.geolocation) {
  console.log('Geolocation is supported.');
  navigator.geolocation.getCurrentPosition(
    function(position) {
      console.log('Location access granted');
      console.log('Latitude: ' + position.coords.latitude);
      console.log('Longitude: ' + position.coords.longitude);
    },
    function(error) {
      console.error('Location access denied: ' + error.message);
      if (error.code === error.PERMISSION_DENIED) {
        console.log('User denied the request for Geolocation.');
        if (confirm('Izin lokasi diperlukan untuk menggunakan fitur ini. Apakah Anda ingin mengizinkannya?')) {
          alert('Silakan buka pengaturan dan izinkan lokasi.');
        } else {
          alert('Fitur ini tidak dapat digunakan tanpa izin lokasi.');
        }
      }
    }
  );
} else {
  console.error('Geolocation is not supported by this browser.');
}

    }
    
    // Cek segera
    checkAndLoadWebcamJS();
    
    // Cek lagi setelah beberapa detik
    setTimeout(checkAndLoadWebcamJS, 5000);
  ''');
}


  Future<void> _reloadWebcamJS() async {
    await _controller.runJavaScript('''        
      var existingScript = document.querySelector('script[src*="webcam.js"]');
      if (existingScript) {
        existingScript.remove();
      }
      var script = document.createElement('script');
      script.src = 'https://absensi-upy.developer-release.my.id/js/webcam.js';
      script.onload = function() {
        console.log('webcam.js reloaded');
      };
      script.onerror = function() {
        console.error('Failed to reload webcam.js');
      };
      document.head.appendChild(script);
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
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
                          _loadAttempts++;
                        });
                        if (_loadAttempts > 3) {
                          _reloadWebcamJS();
                        } else {
                          _controller.reload();
                        }
                      },
                      child: Text(_loadAttempts > 3 ? 'Muat Ulang Webcam.js' : 'Muat Ulang Halaman'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reloadWebcamJS,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
