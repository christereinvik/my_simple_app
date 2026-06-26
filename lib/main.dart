import 'package:flutter/material.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() => runApp(const ParkeringsVarslerApp());

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

  // 🔴 BYTT UT DISSE TO TALLENE MED DINE FRA GOOGLE MAPS:
  final double jobbLatitude = 69.6815;  // <-- Ditt første tall her (Breddegrad)
  final double jobbLongitude = 18.9725; // <-- Ditt andre tall her (Lengdegrad)

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
    bool tillatelseGitt = await GeofencingApi.instance.requestLocationPermission();
    if (!tillatelseGitt) {
      setState(() => _statusTekst = "Appen må ha tilgang til posisjon i innstillinger.");
      return;
    }

    final jobbSone = Geofence(
      id: 'jobb_parkeringsplass',
      latitude: jobbLatitude,
      longitude: jobbLongitude,
      radius: 150.0, // Varsler deg innenfor 150 meter fra punktet
    );

    GeofencingApi.instance.setup(
      geofences: [jobbSone],
      onStatusChanged: (geofence, status) {
        if (status == GeofenceStatus.enter) {
          setState(() => _statusTekst = "Velkommen til jobb! Sjekk parkeringen.");
          _sendParkeringsVarsel();
        } else if (status == GeofenceStatus.exit) {
          setState(() => _statusTekst = "Du har forlatt parkeringsplassen.");
        }
      },
    );

    setState(() => _statusTekst = "Overvåker jobb-parkeringen aktivt... (150m sone)");
  }

  void _sendParkeringsVarsel() async {
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const notificationDetails = NotificationDetails(iOS: iosDetails);
    
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
