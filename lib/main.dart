import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;


// Sett inn koordinatene til jobben din her
final double jobbLatitude = 69.684218;  
final double jobbLongitude = 18.973769; 
String _statusTekstGlobal = "Venter på GPS...";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Definer geofence-sonen
  final jobbSone = Geofence(
    id: 'jobb_parkeringsplass',
    latitude: jobbLatitude,
    longitude: jobbLongitude,
    radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
  );

  // KONFIGURASJON FOR GRATIS-KONTO: useActivityRecognition er satt til false
  final service = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    allowMockLocations: false,
    useActivityRecognition: false, 
  );

  service.addGeofence(jobbSone);
  
  service.addGeofenceStatusChangeListener((geofence, radius, status, location) async {
    if (status == GeofenceStatus.ENTER) {
      _statusTekstGlobal = "Velkommen til jobb! Sjekk parkeringen.";
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

class GeofenceSkjerm extends StatefulWidget {
  const GeofenceSkjerm({super.key});
  @override
  State<GeofenceSkjerm> createState() => _GeofenceSkjermState();
}

class _GeofenceSkjermState extends State<GeofenceSkjerm> {
  
  // Oppdatert knappefunksjon som ber om tillatelse FØR GPS-en starter
    void _startGeofencing() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        setState(() {
          _statusTekstGlobal = "Tilgang avvist av bruker.";
        });
        return;
      }
    }

    bool alleredeAktiv = await GeofenceService.instance.isRunningService;
    
    if (alleredeAktiv) {
      setState(() {
        _statusTekstGlobal = "Overvåkning er allerede aktiv og lytter!";
      });
    } else {
      GeofenceService.instance.start().then((_) {
        setState(() {
          _statusTekstGlobal = "Overvåkning startet aktivt!";
        });
      }).catchError((e) {
        setState(() {
          _statusTekstGlobal = "Feil ved oppstart av GPS: $e";
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_statusTekstGlobal),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startGeofencing,
              child: const Text("Start overvåkning"),
            ),
          ],
        ),
      ),
    );
  }
}
