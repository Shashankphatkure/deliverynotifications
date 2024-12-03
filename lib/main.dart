import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// Conditionally import web-specific libraries
import 'web_view_stub.dart' if (dart.library.html) 'web_view_web.dart';

// Your Supabase configuration
const supabaseUrl = 'https://tffjhjefttkhiiebwlhj.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRmZmpoamVmdHRraGlpZWJ3bGhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzExOTY3ODksImV4cCI6MjA0Njc3Mjc4OX0.jAhFewyVHbn_SWiLqMcID9Lu4k-sCXbeFOJptbp5a-s';

// Your OneSignal App ID
const oneSignalAppId = 'a9308328-24d7-479b-b830-65530fa31331';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize OneSignal only for mobile platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
      defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(oneSignalAppId);
      
      // Request permission through OneSignal (iOS)
      OneSignal.Notifications.requestPermission(true);

      // Handle notification opened app
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data != null) {
          // Handle different notification types
          switch (data['type']) {
            case 'order':
              print('Order notification: ${data['notification_id']}');
              // Handle order notification
              break;
            case 'payment':
              print('Payment notification: ${data['notification_id']}');
              // Handle payment notification
              break;
            case 'penalty':
              print('Penalty notification: ${data['notification_id']}');
              // Handle penalty notification
              break;
            case 'system':
              print('System notification: ${data['notification_id']}');
              // Handle system notification
              break;
          }
        }
      });

      // Handle notification received in foreground
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print("Notification received: ${event.notification.additionalData}");
        // Display the notification
        event.notification.display();
      });
    } catch (e) {
      print("Error initializing OneSignal: $e");
    }
  }

  // Initialize WebView platform
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      WebViewPlatform.instance = WebKitWebViewPlatform();
    }
  }

  runApp(const MyApp());
}

// Get Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fruit Affairs Delivery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStreamSubscription;

  Future<String> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
      }
      return '${position.latitude},${position.longitude}';
    } catch (e) {
      print('Error getting address: $e');
      return '${position.latitude},${position.longitude}';
    }
  }

  Future<void> _startLocationTracking() async {
    // Request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions denied');
        return;
      }
    }

    // Start periodic location updates
    _locationTimer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Get address from coordinates
        String address = await _getAddressFromLatLng(position);
        
        // Update location in Supabase
        if (_user != null) {
          await supabase.from('users').update({
            'location': address,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('auth_id', _user!.id);
          
          print('Location updated: $address');
        }
      } catch (e) {
        print('Error updating location: $e');
      }
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _positionStreamSubscription?.cancel();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location,
    ].request();

    statuses.forEach((permission, status) {
      print('$permission: $status');
    });
  }

  @override
  void initState() {
    super.initState();
    _user = supabase.auth.currentUser;
    
    // Request permissions when app starts
    _requestPermissions();

    supabase.auth.onAuthStateChange.listen((event) {
      setState(() {
        _user = event.session?.user;
        
        if (_user != null) {
          _startLocationTracking();
        } else {
          _stopLocationTracking();
        }
      });
    });
    
    if (_user != null) {
      _startLocationTracking();
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _user == null ? const LoginPage() : const DeliveryWebView();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!kIsWeb && response.user != null) {
        // Set external user ID in OneSignal
        await OneSignal.login(response.user!.id);
        
        // Set user type tag
        await OneSignal.User.addTagWithKey("user_type", "driver");
        
        // Subscribe to realtime notifications
        supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('recipient_type', 'driver')
          .eq('recipient_id', response.user!.id)
          .listen((List<Map<String, dynamic>> data) {
            // Handle new notifications in realtime
            if (data.isNotEmpty) {
              final notification = data.first;
              print('New notification: ${notification['title']}');
            }
          });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryWebView extends StatefulWidget {
  const DeliveryWebView({super.key});

  @override
  State<DeliveryWebView> createState() => _DeliveryWebViewState();
}

class _DeliveryWebViewState extends State<DeliveryWebView> {
  late final WebViewController controller;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      initWebView();
    }
  }

  Future<void> initWebView() async {
    try {
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final WebViewController webViewController =
          WebViewController.fromPlatformCreationParams(params);

      await webViewController
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = true;
                  hasError = false;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                  hasError = true;
                });
              }
              print('WebView error: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse('https://deliveryapp-tan.vercel.app/orders'));

      if (mounted) {
        setState(() {
          controller = webViewController;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
      print('Error initializing WebView: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return getWebView(); // This will be defined in web_view_web.dart
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (!hasError && controller != null)
              WebViewWidget(controller: controller),
            if (isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ),
            if (hasError)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Failed to load page',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            hasError = false;
                          });
                          initWebView();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> pickImage() async {
  final ImagePicker picker = ImagePicker();
  try {
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      // Handle the image file
      print('Image path: ${image.path}');
    }
  } catch (e) {
    print('Error picking image: $e');
  }
}

Future<void> pickFile() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      // Handle the picked file
      print('File path: ${result.files.single.path}');
    }
  } catch (e) {
    print('Error picking file: $e');
  }
}
