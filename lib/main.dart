import 'package:flutter/material.dart';
import 'package:geofencing_api/geofencing_api.dart';
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

  // Dine nøyaktige jobbkoordinater
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
    const iosSettings = DarwinInitializationSettings();
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  void _startGeofencing() async {
    // 1. Sjekk tillatelse (Siden det ikke returnerer en bool, sjekker vi om vi har tilgang)
    final permission = await GeofencingApi.instance.requestLocationPermission();
    if (!permission) {
      setState(() => _statusTekst = "Appen må ha tilgang til posisjon i innstillinger.");
      return;
    }

    // 2. Opprett sonen (Vi bruker 'Geofence' direkte med radius slik pakken vil ha det)
    final jobbSone = Geofence(
      id: 'jobb_parkeringsplass',
      latitude: jobbLatitude,
      longitude: jobbLongitude,
      radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
    );

    // 3. Start lytteren (Parameteren heter 'geofences')
    GeofencingApi.instance.setup(
      interval: 5000,
      accuracy: 100,
      statusChangeActivityType: GeofenceStatusChangeActivityType.ALWAYS,
      allowMockLocations: false,
    );

    GeofencingApi.instance.addGeofence(jobbSone);
    GeofencingApi.instance.addGeofenceStatusChangeListener((geofence, radius, status, location) {
      if (status == GeofenceStatus.ENTER) {
        setState(() => _statusTekst = "Velkommen til jobb! Sjekk parkeringen.");
        _sendParkeringsVarsel();
      } else if (status == GeofenceStatus.EXIT) {
        setState(() => _statusTekst = "Du har forlatt parkeringsplassen.");
      }
    });

    setState(() => _statusTekst = "Overvåker jobb-parkeringen aktivt... (150m sone)");
  }

  void _sendParkeringsVarsel() async {
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const notificationDetails = NotificationDetails(iOS: iosDetails);
    
    await _notificationsPlugin.show(
      id: 0,
      title: 'Husk parkering! 🚗',
      body: 'Du har ankommet jobb-parkeringen. Husk å registrere eller betale!',
      notificationDetails: notificationDetails,
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
