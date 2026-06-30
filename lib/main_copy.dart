import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;

final double jobbLatitude = 69.684218;  
final double jobbLongitude = 18.973769; 
String _statusTekstGlobal = "Venter på GPS...";

// Oppretter instansen for lokale varsler
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Funksjon som sender det faktiske varselet til iPhonens skjerm
Future<void> visPushVarsel(String tittel, String melding) async {
  const DarwinNotificationDetails iosDetaljer = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const NotificationDetails plattformDetaljer = NotificationDetails(
    iOS: iosDetaljer,
  );

  await flutterLocalNotificationsPlugin.show(
    0, // Unik ID for varselet
    tittel,
    melding,
    plattformDetaljer,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- INITIERING AV VARSLER OG FORESPØRSEL OM TILLATELSE ---
  const InitializationSettings initInnstillinger = InitializationSettings(
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false, // Vi ber om det manuelt under for full kontroll
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  
  await flutterLocalNotificationsPlugin.initialize(initInnstillinger);

  // Tvinger iOS til å vise popup-vinduet som ber om varslingstillatelse
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
  // --------------------------------------------------------

  final jobbSone = Geofence(
    id: 'jobb_parkeringsplass',
    latitude: jobbLatitude,
    longitude: jobbLongitude,
    radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
  );

    final service = GeofenceService.instance.setup(
    interval: 10000, // Sparer batteri
    accuracy: 100,
    allowMockLocations: false,
    useActivityRecognition: false,
  );

  service.addGeofence(jobbSone);
  
  service.addGeofenceStatusChangeListener((geofence, radius, status, location) async {
    if (status == GeofenceStatus.ENTER) {
      _statusTekstGlobal = "Velkommen til jobb! Sjekk parkeringen.";
      // Sender et fysisk push-varsel til iPhonens skjerm
      await visPushVarsel("Parkering", "Velkommen til jobb! Sjekk parkeringen.");
    } else if (status == GeofenceStatus.EXIT) {
      _statusTekstGlobal = "Du har forlatt parkeringsplassen.";
      // Sender et fysisk push-varsel til iPhonens skjerm
      await visPushVarsel("Parkering", "Du har forlatt parkeringsplassen.");
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
  
  void _startGeofencing() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        setState(() { _statusTekstGlobal = "Tilgang avvist av bruker."; });
        return;
      }
    }

    // Ekstra sjekk for å sikre "Alltid"-tilgang, som kreves for bakgrunns-GPS på iOS
    if (permission == geo.LocationPermission.whileInUse) {
      permission = await geo.Geolocator.requestPermission();
      if (permission != geo.LocationPermission.always) {
        setState(() { _statusTekstGlobal = "Feil: Appen MÅ ha stedsinnstillingen satt til 'Alltid'."; });
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
