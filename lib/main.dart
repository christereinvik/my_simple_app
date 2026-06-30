import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final double jobbLatitude = 69.684218;  
final double jobbLongitude = 18.973769; 

final ValueNotifier<bool> erParkertGlobal = ValueNotifier<bool>(false);
final ValueNotifier<String> parkeringStartetTid = ValueNotifier<String>("--:--");
final ValueNotifier<List<String>> historikkListeGlobal = ValueNotifier<List<String>>([]);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> visPushVarsel(String tittel, String melding) async {
  const DarwinNotificationDetails iosDetaljer = DarwinNotificationDetails(
    presentAlert: true, presentBadge: true, presentSound: true,
  );
  await flutterLocalNotificationsPlugin.show(0, tittel, melding, const NotificationDetails(iOS: iosDetaljer));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const InitializationSettings initSettings = InitializationSettings(
    iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);

  final jobbSone = Geofence(
    id: 'jobb_parkeringsplass',
    latitude: jobbLatitude,
    longitude: jobbLongitude,
    radius: [GeofenceRadius(id: 'radius_300m', length: 300.0)],
  );

  final service = GeofenceService.instance.setup(interval: 10000, accuracy: 100, allowMockLocations: false, useActivityRecognition: false);
  service.addGeofence(jobbSone);
  
  service.addGeofenceStatusChangeListener((geofence, radius, status, location) async {
    final na = DateTime.now();
    final tidsStempel = "${na.hour.toString().padLeft(2, '0')}:${na.minute.toString().padLeft(2, '0')}";
    final datoStempel = "${na.day}.${na.month}";
    final prefs = await SharedPreferences.getInstance();
    List<String> h = prefs.getStringList('parkering_historikk') ?? [];

    if (status == GeofenceStatus.ENTER) {
      erParkertGlobal.value = true;
      parkeringStartetTid.value = tidsStempel;
      h.insert(0, "$datoStempel|$tidsStempel - Aktiv|Jobb|1");
      await prefs.setStringList('parkering_historikk', h);
      historikkListeGlobal.value = h;
      await visPushVarsel("Parkering startet", "Registrert kl. $tidsStempel.");
    } else if (status == GeofenceStatus.EXIT) {
      erParkertGlobal.value = false;
      if (h.isNotEmpty) {
        final deler = h.first.split('|');
        if (deler.length >= 4 && deler[3] == "1") {
          h[0] = "${deler[0]}|${deler[1].split(' ').first} - $tidsStempel|${deler[2]}|0";
        }
      }
      if (location != null) {
        await prefs.setDouble('bil_lat', location.latitude);
        await prefs.setDouble('bil_lng', location.longitude);
      } else {
        await prefs.setDouble('bil_lat', jobbLatitude);
        await prefs.setDouble('bil_lng', jobbLongitude);
      }
      await prefs.setStringList('parkering_historikk', h);
      historikkListeGlobal.value = h;
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
  bool _tjenesteKjorer = false;

  @override
  void initState() {
    super.initState();
    _sjekkOmTjenesteKjorer();
    _lastLagretData();
  }

  void _lastLagretData() async {
    final prefs = await SharedPreferences.getInstance();
    historikkListeGlobal.value = prefs.getStringList('parkering_historikk') ?? [];
  }

  void _sjekkOmTjenesteKjorer() async {
    bool kjorer = await GeofenceService.instance.isRunningService;
    setState(() {
      _tjenesteKjorer = kjorer;
      _knappTekst = kjorer ? "Overvåkning er aktiv" : "Aktiver overvåkning";
    });
  }
  
  void _startGeofencing() async {
    geo.LocationPermission p = await geo.Geolocator.checkPermission();
    if (p == geo.LocationPermission.denied) {
      p = await geo.Geolocator.requestPermission();
      if (p == geo.LocationPermission.denied) return;
    }
    if (p == geo.LocationPermission.whileInUse) {
      p = await geo.Geolocator.requestPermission();
      if (p != geo.LocationPermission.always) return;
    }
    if (!(await GeofenceService.instance.isRunningService)) {
      await GeofenceService.instance.start();
      setState(() { _tjenesteKjorer = true; _knappTekst = "Overvåkning er aktiv"; });
    }
  }

  void _finnBilenKart() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('bil_lat') ?? jobbLatitude;
    final lng = prefs.getDouble('bil_lng') ?? jobbLongitude;
    final url = Uri.parse("https://apple.com");
    if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
  }

  Widget _byggEkteHistorikkKort(String data) {
    final deler = data.split('|');
    if (deler.length < 3) return const SizedBox();
    final aktiv = deler.length == 4 && deler[3] == "1";
    return Card(
      elevation: 0, color: Colors.white, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: aktiv ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(Icons.local_parking, color: aktiv ? Colors.green : Colors.grey),
        ),
        title: Text(deler[0], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(deler[1]),
        trailing: Text(deler[2], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text("Parkering-Assistent", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
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
                  decoration: BoxDecoration(color: erParkert ? Colors.green : Colors.blueGrey, borderRadius: BorderRadius.circular(24)),
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
                          return Text(erParkert ? "Registrert ankomst kl. $tid" : "Søker etter parkeringsplass (300m)...", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                if (!erParkert)
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: _finnBilenKart,
                      icon: const Icon(Icons.map, color: Colors.blue),
                      label: const Text("Finn bilen på kartet", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: _tjenesteKjorer ? null : _startGeofencing,
                    icon: Icon(_tjenesteKjorer ? Icons.check_circle : Icons.power_settings_new),
                    label: Text(_knappTekst, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 35),
                const Text("Siste parkeringer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: historikkListeGlobal,
                    builder: (context, liste, child) {
                      if (liste.isEmpty) { return const Center(child: Text("Ingen registrerte parkeringer ennå.", style: TextStyle(color: Colors.grey))); }
                      return ListView.builder(
                        itemCount: liste.length,
                        itemBuilder: (context, index) { return _byggEkteHistorikkKort(liste[index]); },
                      );
                    },
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
