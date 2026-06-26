import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParkeringsVarslerApp());
}

class ParkeringsVarslerApp extends StatelessWidget {
  const ParkeringsVarslerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: GeofenceSkjerm(),
    );
  }
}

class GeofenceSkjerm extends StatefulWidget {
  const GeofenceSkjerm({super.key});

  @override
  State<GeofenceSkjerm> createState() => _GeofenceSkjermState();
}

class _GeofenceSkjermState extends State<GeofenceSkjerm> {
  String _statusTekst = "Søker etter GPS-signal...";

  // Koordinater (Satt til UiT i Tromsø)
  final double jobbLatitude = 69.6815; 
  final double jobbLongitude = 18.9725;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initVarslinger();
    _startGeofencing();
  }

  void _initVarslinger() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _startGeofencing() async {
    final jobbSone = Geofence(
      id: 'jobb_parkeringsplass',
      latitude: jobbLatitude,
      longitude: jobbLongitude,
      radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
    );

    // Initialiserer overvåkingen (statusChangeActivityType fjernet for v6.0.0+)
    final service = GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      allowMockLocations: false,
    );

    service.addGeofence(jobbSone);
    
    service.addGeofenceStatusChangeListener((geofence, radius, status, location) {
      if (status == GeofenceStatus.ENTER) {
        setState(() => _statusTekst = "Velkommen til jobb! Sjekk parkeringen.");
        _sendParkeringsVarsel();
      } else if (status == GeofenceStatus.EXIT) {
        setState(() => _statusTekst = "Du har forlatt parkeringsplassen.");
      }
    });

    service.start().catchError((e) {
      setState(() => _statusTekst = "Feil ved oppstart av GPS: $e");
    });

    setState(() => _statusTekst = "Overvåker jobb-parkeringen aktivt... (150m sone)");
  }

  void _sendParkeringsVarsel() async {
    const androidDetails = AndroidNotificationDetails(
      'parking_channel',
      'Parking Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    // Oppdatert til 4 påkrevde posisjonelle argumenter (id, title, body, notificationDetails)
    await _notificationsPlugin.show(
      0,
      'Husk parkering! 🚗',
      'Du har ankommet jobb-parkeringen. Husk å registrere eller betale!',
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parkeringsassistent'), 
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_parking, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                _statusTekst,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
