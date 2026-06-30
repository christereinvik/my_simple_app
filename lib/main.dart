import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;

final double jobbLatitude = 69.684218;  
final double jobbLongitude = 18.973769; 

final ValueNotifier<bool> erParkertGlobal = ValueNotifier<bool>(false);
final ValueNotifier<String> parkeringStartetTid = ValueNotifier<String>("--:--");
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> visPushVarsel(String tittel, String melding) async {
  const DarwinNotificationDetails iosDetaljer = DarwinNotificationDetails(
    presentAlert: true, presentBadge: true, presentSound: true,
  );
  const NotificationDetails plattformDetaljer = NotificationDetails(iOS: iosDetaljer);
  await flutterLocalNotificationsPlugin.show(0, tittel, melding, plattformDetaljer);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const InitializationSettings initInnstillinger = InitializationSettings(
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false,
    ),
  );
  await flutterLocalNotificationsPlugin.initialize(initInnstillinger);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  final jobbSone = Geofence(
    id: 'jobb_parkeringsplass',
    latitude: jobbLatitude,
    longitude: jobbLongitude,
    radius: [GeofenceRadius(id: 'radius_150m', length: 150.0)],
  );

  final service = GeofenceService.instance.setup(
    interval: 10000, accuracy: 100, allowMockLocations: false, useActivityRecognition: false, 
  );
  service.addGeofence(jobbSone);
  
  service.addGeofenceStatusChangeListener((geofence, radius, status, location) async {
    final na = DateTime.now();
    final tidsStempel = "${na.hour.toString().padLeft(2, '0')}:${na.minute.toString().padLeft(2, '0')}";
    if (status == GeofenceStatus.ENTER) {
      erParkertGlobal.value = true;
      parkeringStartetTid.value = tidsStempel;
      await visPushVarsel("Parkering startet", "Registrert kl. $tidsStempel.");
    } else if (status == GeofenceStatus.EXIT) {
      erParkertGlobal.value = false;
      await visPushVarsel("Parkering avsluttet", "Du har forlatt jobb.");
    }
  });
  runApp(const ParkeringsVarslerApp());
}

class ParkeringsVarslerApp extends StatelessWidget {
  const ParkeringsVarslerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const DashboardSkjerm(),
    );
  }
}

class DashboardSkjerm extends StatefulWidget {
  const DashboardSkjerm({super.key});
  @override
  State<DashboardSkjerm> createState() => _DashboardSkjermState();
}

class _DashboardSkjermState extends State<DashboardSkjerm> {
  String _knappTekst = "Aktiver overvåkning";
  bool _tjenesteKjører = false;

  @override
  void initState() {
    super.initState();
    _sjekkOmTjenesteKjører();
  }

  void _sjekkOmTjenesteKjører() async {
    bool kjører = await GeofenceService.instance.isRunningService;
    setState(() {
      _tjenesteKjører = kjører;
      _knappTekst = kjører ? "Overvåkning er aktiv" : "Aktiver overvåkning";
    });
  }
  
  void _startGeofencing() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    if (permission == geo.LocationPermission.whileInUse) {
      permission = await geo.Geolocator.requestPermission();
      if (permission != geo.LocationPermission.always) return;
    }
    if (!(await GeofenceService.instance.isRunningService)) {
      await GeofenceService.instance.start();
      setState(() { _tjenesteKjører = true; _knappTekst = "Overvåkning er aktiv"; });
    }
  }

  Widget _byggHistorikkKort(String dag, String tid, String sted, bool aktiv) {
    return Card(
      elevation: 0, color: Colors.white, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: aktiv ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(Icons.local_parking, color: aktiv ? Colors.green : Colors.grey),
        ),
        title: Text(dag, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(tid),
        trailing: Text(sted, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Parkering-Assistent", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: erParkertGlobal,
        builder: (context, erParkert, child) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: erParkert ? Colors.green : Colors.blueGrey,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(erParkert ? Icons.local_parking : Icons.drive_eta, color: Colors.white, size: 40),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                            child: Text(erParkert ? "PARKERT" : "PÅ FLYT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(erParkert ? "Du er parkert på jobb" : "Utenfor parkeringssone", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ValueListenableBuilder(
                        valueListenable: parkeringStartetTid,
                        builder: (context, tid, child) {
                          return Text(erParkert ? "Registrert ankomst kl. $tid" : "Søker etter parkeringsplass...", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: _tjenesteKjører ? null : _startGeofencing,
                    icon: Icon(_tjenesteKjører ? Icons.check_circle : Icons.power_settings_new),
                    label: Text(_knappTekst, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 35),
                const Text("Siste parkeringer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _byggHistorikkKort("I dag", "07:46 - Aktiv", "Jobb", true),
                      _byggHistorikkKort("I går", "07:50 - 16:05", "Jobb", false),
                      _byggHistorikkKort("28. Juni", "08:02 - 15:58", "Jobb", false),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
