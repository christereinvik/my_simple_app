import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/foundation.dart'; // DETTE ER VIKTIG: Gir oss tilgang til kIsWeb

// Sett inn koordinatene til jobben din her
final double jobbLatitude = 69.684218;  
final double jobbLongitude = 18.973769; 
String _statusTekstGlobal = "Venter på GPS...";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KONDISJONAL SJEKK: Hvis appen kjører på web, hopper vi over bakgrunnsoppsettet
  if (!kIsWeb) {
    // Definer geofence-sonen for mobil
    final jobbSone = Geofence(
      id: 'jobb_parkeringsplass',
      latitude: jobbLatitude,
      longitude: jobbLongitude,
      radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
    );

    // Konfigurasjon for mobil bakgrunnsdata
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
  } else {
    // Hvis vi er på web, gir vi bare en ren tekstbeskjed ved oppstart
    _statusTekstGlobal = "Klar for manuell overvåkning på web!";
  }

  runApp(const ParkeringsVarslerApp());
}
