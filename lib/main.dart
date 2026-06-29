import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 1. Initialiser variabler globalt slik at både main og skjermen har tilgang
final double jobbLatitude = 59.9139;  // Bytt ut med dine faktiske koordinater
final double jobbLongitude = 10.7522; // Bytt ut med dine faktiske koordinater
String _statusTekstGlobal = "Venter på GPS...";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Definer geofence-sonen globalt under oppstart
  final jobbSone = Geofence(
    id: 'jobb_parkeringsplass',
    latitude: jobbLatitude,
    longitude: jobbLongitude,
    radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
  );

  // 3. Konfigurer tjenesten på globalt nivå (Dette hindrer iOS-krasj)
  final service = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    allowMockLocations: false,
  );

  // 4. Legg til sonen og lytteren med én gang
  service.addGeofence(jobbSone);
  
  service.addGeofenceStatusChangeListener((geofence, radius, status, location) async {
    if (status == GeofenceStatus.ENTER) {
      _statusTekstGlobal = "Velkommen til jobb! Sjekk parkeringen.";
      // Kalle varslingsmetoden din her (Må gjøres statisk/global)
    } else if (status == GeofenceStatus.EXIT) {
      _statusTekstGlobal = "Du har forlatt parkeringsplassen.";
    }
  });

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

// --- DIN SKJERM-KLASSE ---
class GeofenceSkjerm extends StatefulWidget {
  const GeofenceSkjerm({super.key});
  @override
  State<GeofenceSkjerm> createState() => _GeofenceSkjermState();
}

class _GeofenceSkjermState extends State<GeofenceSkjerm> {
  // Knappen din på skjermen trenger nå BARE å trigge selve starten av tjenesten
  void _startGeofencing() async {
    GeofenceService.instance.start().catchError((e) {
      setState(() {
        _statusTekstGlobal = "Feil ved oppstart av GPS: $e";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_statusTekstGlobal),
            ElevatedButton(
              onPressed: _startGeofencing,
              child: const Text("Start overvåking"),
            ),
          ],
        ),
      ),
    );
  }
}
