import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const double jobbLatitude = 69.684218;
const double jobbLongitude = 18.973769;
const String historikkKey = 'parkering_historikk';
const String arkivKey = 'parkering_historikk_arkiv';

final ValueNotifier<bool> erParkertGlobal = ValueNotifier<bool>(false);
final ValueNotifier<String> parkeringStartetTid = ValueNotifier<String>("--:--");
final ValueNotifier<String> bilPosisjonTekst = ValueNotifier<String>("Ukjent");
final ValueNotifier<List<ParkeringHistorikk>> historikkListeGlobal = ValueNotifier<List<ParkeringHistorikk>>([]);
final ValueNotifier<bool> geofenceKjorerGlobal = ValueNotifier<bool>(false);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ParkeringHistorikk {
  final String dato;
  final String startTid;
  final String stoppTid;
  final String sted;
  final bool aktiv;
  final bool arkivert;

  const ParkeringHistorikk({
    required this.dato,
    required this.startTid,
    required this.stoppTid,
    required this.sted,
    required this.aktiv,
    this.arkivert = false,
  });

  factory ParkeringHistorikk.fromMap(Map<String, dynamic> map) {
    return ParkeringHistorikk(
      dato: map['dato'] as String? ?? '',
      startTid: map['startTid'] as String? ?? '',
      stoppTid: map['stoppTid'] as String? ?? '',
      sted: map['sted'] as String? ?? '',
      aktiv: map['aktiv'] as bool? ?? false,
      arkivert: map['arkivert'] as bool? ?? false,
    );
  }

  factory ParkeringHistorikk.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return ParkeringHistorikk.fromMap(map);
  }

  Map<String, dynamic> toMap() {
    return {
      'dato': dato,
      'startTid': startTid,
      'stoppTid': stoppTid,
      'sted': sted,
      'aktiv': aktiv,
      'arkivert': arkivert,
    };
  }

  String toJson() => jsonEncode(toMap());

  ParkeringHistorikk copyWith({
    String? dato,
    String? startTid,
    String? stoppTid,
    String? sted,
    bool? aktiv,
    bool? arkivert,
  }) {
    return ParkeringHistorikk(
      dato: dato ?? this.dato,
      startTid: startTid ?? this.startTid,
      stoppTid: stoppTid ?? this.stoppTid,
      sted: sted ?? this.sted,
      aktiv: aktiv ?? this.aktiv,
      arkivert: arkivert ?? this.arkivert,
    );
  }

  Duration get varighetDuration {
    if (stoppTid.isEmpty) return Duration.zero;
    final start = _parseTid(startTid);
    final stopp = _parseTid(stoppTid);
    return stopp >= start ? stopp - start : Duration.zero;
  }

  String get varighetTekst {
    if (aktiv || stoppTid.isEmpty) return 'Pågår';
    final d = varighetDuration;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) return '${hours}t ${minutes}m';
    return '$minutes min';
  }

  static Duration _parseTid(String tid) {
    final deler = tid.split(':');
    final h = int.tryParse(deler[0]) ?? 0;
    final m = deler.length > 1 ? int.tryParse(deler[1]) ?? 0 : 0;
    return Duration(hours: h, minutes: m);
  }
}

Future<void> visPushVarsel(String tittel, String melding) async {
  final navigatorState = navigatorKey.currentState;

  const AndroidNotificationDetails androidDetaljer = AndroidNotificationDetails(
    'parkering_channel',
    'Parkering-varsler',
    channelDescription: 'Varsler om parkering og sonestatus',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const DarwinNotificationDetails iosDetaljer = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    tittel,
    melding,
    const NotificationDetails(android: androidDetaljer, iOS: iosDetaljer),
  );

  if (navigatorState == null || !navigatorState.mounted) return;

  showDialog(
    context: navigatorState.context,
    builder: (context) => AlertDialog(
      title: Text(tittel),
      content: Text(melding),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true, critical: true);

  final jobbSone = Geofence(
    id: 'jobb_parkeringsplass',
    latitude: jobbLatitude,
    longitude: jobbLongitude,
    radius: [GeofenceRadius(id: 'radius_300m', length: 300.0)],
  );

  final service = GeofenceService.instance.setup(
    interval: 10000,
    accuracy: 100,
    allowMockLocations: false,
    useActivityRecognition: false,
  );
  service.addGeofence(jobbSone);

  service.addGeofenceStatusChangeListener((geofence, radius, status, location) async {
    try {
      final na = DateTime.now();
      final tidsStempel = "${na.hour.toString().padLeft(2, '0')}:${na.minute.toString().padLeft(2, '0')}";
      final datoStempel = "${na.day}.${na.month}";
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(historikkKey) ?? [];
      final historikk = raw.map(ParkeringHistorikk.fromJson).toList();

      if (status == GeofenceStatus.ENTER) {
        erParkertGlobal.value = true;
        parkeringStartetTid.value = tidsStempel;
        geofenceKjorerGlobal.value = true;

        await prefs.setDouble('bil_lat', location.latitude);
        await prefs.setDouble('bil_lng', location.longitude);

        // Vis bilens posisjon
        bilPosisjonTekst.value = "Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}";

        final nyPost = ParkeringHistorikk(
          dato: datoStempel,
          startTid: tidsStempel,
          stoppTid: '',
          sted: 'Jobb',
          aktiv: true,
        );
        historikk.insert(0, nyPost);

        await prefs.setStringList(historikkKey, historikk.map((e) => e.toJson()).toList());
        historikkListeGlobal.value = List.from(historikk);

        await visPushVarsel(
          "🚨 PARKERING PÅ JOBB",
          "Husk å åpne betalingsappen nå og starte parkeringen.",
        );
      } else if (status == GeofenceStatus.EXIT) {
        erParkertGlobal.value = false;
        bilPosisjonTekst.value = "Ukjent";
        final aktivIndex = historikk.indexWhere((element) => element.aktiv);
        if (aktivIndex != -1) {
          historikk[aktivIndex] = historikk[aktivIndex].copyWith(
            stoppTid: tidsStempel,
            aktiv: false,
          );
        }

        await prefs.setStringList(historikkKey, historikk.map((e) => e.toJson()).toList());
        historikkListeGlobal.value = List.from(historikk);

        await visPushVarsel(
          "🔚 PARKERING AVSLUTTET",
          "Husk å avslutte betalingsappen nå før du kjører videre.",
        );

        await GeofenceService.instance.stop();
        geofenceKjorerGlobal.value = false;
      }
    } catch (e, st) {
      debugPrint('Feil i geofence-listener: $e\n$st');
    }
  });

  runApp(const ParkeringsVarslerApp());
}

class ParkeringsVarslerApp extends StatelessWidget {
  const ParkeringsVarslerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
    geofenceKjorerGlobal.addListener(() {
      if (!mounted) return;
      setState(() {
        _tjenesteKjorer = geofenceKjorerGlobal.value;
        _knappTekst = _tjenesteKjorer ? "Overvåkning er aktiv" : "Aktiver overvåkning";
      });
    });
    _sjekkOmTjenesteKjorer();
    _lastLagretData();
  }

  Future<void> _lagreHistorikkListe(List<ParkeringHistorikk> liste) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(historikkKey, liste.map((e) => e.toJson()).toList());
    historikkListeGlobal.value = List.from(liste);
  }

  void _lastLagretData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(historikkKey) ?? [];
    historikkListeGlobal.value = raw.map(ParkeringHistorikk.fromJson).toList();
  }

  void _sjekkOmTjenesteKjorer() async {
    bool kjorer = GeofenceService.instance.isRunningService;
    setState(() {
      _tjenesteKjorer = kjorer;
      _knappTekst = kjorer ? "Overvåkning er aktiv" : "Aktiver overvåkning";
    });
    geofenceKjorerGlobal.value = kjorer;
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
    if (!GeofenceService.instance.isRunningService) {
      await GeofenceService.instance.start();
      setState(() {
        _tjenesteKjorer = true;
        _knappTekst = "Overvåkning er aktiv";
      });
      geofenceKjorerGlobal.value = true;
    }
  }

  Future<void> _stoppGeofencing() async {
    if (GeofenceService.instance.isRunningService) {
      await GeofenceService.instance.stop();
    }
    setState(() {
      _tjenesteKjorer = false;
      _knappTekst = "Aktiver overvåkning";
    });
    geofenceKjorerGlobal.value = false;
    await visPushVarsel("🔕 OVERVÅKNING STOPPET", "Geofence-tjenesten er stoppet.");
  }

Future<void> _tomHistorikk() async {
  if (!mounted) return;

  final bekreft = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Tøm historikk'),
        content: const Text('Vil du fjerne alle parkeringslogger?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Avbryt')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tøm')),
        ],
      );
    },
  );

  if (!mounted || bekreft != true) return;

  await _lagreHistorikkListe([]);
  await visPushVarsel("🧹 Historikk tømt", "Alle parkeringslogger er fjernet.");
}

  Future<void> _arkiverFullforte() async {
    final prefs = await SharedPreferences.getInstance();
    final arkivRaw = prefs.getStringList(arkivKey) ?? [];
    final arkivert = arkivRaw.map(ParkeringHistorikk.fromJson).toList();

    final aktive = historikkListeGlobal.value.where((e) => e.aktiv).toList();
    final fullforte = historikkListeGlobal.value.where((e) => !e.aktiv).toList();
    if (fullforte.isEmpty) return;

    arkivert.insertAll(0, fullforte);
    await prefs.setStringList(arkivKey, arkivert.map((e) => e.toJson()).toList());
    await _lagreHistorikkListe(aktive);
    await visPushVarsel("🗄️ Historikk arkivert", "Fullførte parkeringsøkter er flyttet til arkiv.");
  }

  void _finnBilenKart() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('bil_lat') ?? jobbLatitude;
    final lng = prefs.getDouble('bil_lng') ?? jobbLongitude;
    final urlNative = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
    final urlGoogle = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    if (await canLaunchUrl(urlNative)) {
      await launchUrl(urlNative, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(urlGoogle)) {
      await launchUrl(urlGoogle, mode: LaunchMode.externalApplication);
    }
  }

  Widget _byggEkteHistorikkKort(ParkeringHistorikk data) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: data.aktiv ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(Icons.local_parking, color: data.aktiv ? Colors.green : Colors.grey),
        ),
        title: Text(data.dato, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Start: ${data.startTid}"),
            if (data.stoppTid.isNotEmpty) Text("Stopp: ${data.stoppTid}"),
            const SizedBox(height: 4),
            Text("Varighet: ${data.varighetTekst}", style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: Text(data.sted, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Parkering-Assistent", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
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
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 255, 255, 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              erParkert ? "PARKERT" : "PÅ FLYT",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        erParkert ? "Du er parkert på jobb" : "Utenfor parkeringssone",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder(
                        valueListenable: parkeringStartetTid,
                        builder: (context, tid, child) {
                          return Text(
                            erParkert ? "Registrert ankomst kl. $tid" : "Søker etter parkeringsplass (300m)...",
                            style: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.8), fontSize: 14),
                          );
                        },
                      ),
                      if (erParkert)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            ValueListenableBuilder(
                              valueListenable: bilPosisjonTekst,
                              builder: (context, posisjon, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "📍 $posisjon",
                                      style: const TextStyle(
                                        color: Color.fromRGBO(255, 255, 255, 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 40,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.green,
                                        ),
                                        onPressed: _finnBilenKart,
                                        icon: const Icon(Icons.map),
                                        label: const Text("Vis på kart"),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                if (!erParkert)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _finnBilenKart,
                      icon: const Icon(Icons.map, color: Colors.blue),
                      label: const Text(
                        "Finn bilen på kartet",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _tjenesteKjorer ? _stoppGeofencing : _startGeofencing,
                    icon: Icon(_tjenesteKjorer ? Icons.power_off : Icons.power_settings_new),
                    label: Text(
                      _knappTekst,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Siste parkeringer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _arkiverFullforte,
                          child: const Text("Arkiver fullførte"),
                        ),
                        TextButton(
                          onPressed: _tomHistorikk,
                          child: const Text("Tøm historikk"),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder<List<ParkeringHistorikk>>(
                    valueListenable: historikkListeGlobal,
                    builder: (context, liste, child) {
                      if (liste.isEmpty) {
                        return const Center(
                          child: Text("Ingen registrerte parkeringer ennå.", style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.builder(
                        itemCount: liste.length,
                        itemBuilder: (context, index) {
                          return _byggEkteHistorikkKort(liste[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}