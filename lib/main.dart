import 'package:flutter/material.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  // Sikrer at Flutter-motoren og system-bindings er startet før vi henter GPS/varslinger
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

  // Dine nøyaktige jobb-koordinater (Satt til UiT i Tromsø som eksempel)
  final double jobbLatitude = 69.6815; 
  final double jobbLongitude = 18.9725;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initVarslinger();
    _startGeofencing();
  }

  // Initialiserer varslingssystemet på iOS/iPhone
  void _initVarslinger() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  // Starter overvåkingen av parkeringsplassen
  void _startGeofencing() async {
    // Ber iPhonen om posisjonstilgang via riktig klasse (Geofencing.instance)
    bool tillatelseGitt = await Geofencing.instance.requestLocationPermission();
    if (!tillatelseGitt) {
      setState(() => _statusTekst = "Appen må ha tilgang til posisjon i innstillinger.");
      return;
    }

    // Oppretter den digitale sirkelen (150 meter radius) rundt parkeringen din
    final jobbSone = Geofence(
      id: 'jobb_parkeringsplass',
      latitude: jobbLatitude,
      longitude: jobbLongitude,
      radius: 150.0,
    );

    // Starter lytteren som passer på om du kjører inn eller ut av sonen
    Geofencing.instance.setup(
      geofences: [jobbSone],
      onStatusChanged: (geofence, status) {
        if (status == GeofenceStatus.enter) {
          // AKTIVERES NÅR DU ANKOMMER PARKERINGEN
          setState(() => _statusTekst = "Velkommen til jobb! Sjekk parkeringen.");
          _sendParkeringsVarsel();
        } else if (status == GeofenceStatus.exit) {
          // AKTIVERES NÅR DU REISER FRA JOBB
          setState(() => _statusTekst = "Du har forlatt parkeringsplassen.");
        }
      },
    );

    setState(() => _statusTekst = "Overvåker jobb-parkeringen aktivt... (150m sone)");
  }

  // Sender det synlige push-varselet til iPhonen din med oppdaterte parametere
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
