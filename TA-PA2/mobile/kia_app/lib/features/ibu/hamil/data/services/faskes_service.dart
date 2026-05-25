import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────
// MODEL DATA (Tetap sama persis, UI tidak terpengaruh)
// ─────────────────────────────────────────────────────────
class FaskesModel {
  final String nama;
  final String alamat;
  final double lat;
  final double lng;
  final bool isOpen;
  final double jarakMeter;

  const FaskesModel({
    required this.nama,
    required this.alamat,
    required this.lat,
    required this.lng,
    required this.isOpen,
    required this.jarakMeter,
  });
}

// ─────────────────────────────────────────────────────────
// SERVICE (Menggunakan Overpass API - OpenStreetMap)
// ─────────────────────────────────────────────────────────
class FaskesService {
  // Endpoint publik gratis OpenStreetMap (Tanpa API Key)
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Fetch RS/Klinik terdekat berdasarkan Lat/Lng user
  Future<List<FaskesModel>> fetchNearbyHospitals({
    required double lat,
    required double lng,
    double radiusMeter = 5000,
  }) async {
    // Overpass QL: Bahasa query untuk mencari data di peta OSM
    // Kita cari amenity=hospital dan amenity=clinic dalam radius tertentu
    final query = '''
    [out:json][timeout:10];
    (
      node["amenity"="hospital"](around:$radiusMeter,$lat,$lng);
      node["amenity"="clinic"](around:$radiusMeter,$lat,$lng);
      way["amenity"="hospital"](around:$radiusMeter,$lat,$lng);
      way["amenity"="clinic"](around:$radiusMeter,$lat,$lng);
    );
    out center body;
    ''';

    final response = await http.post(
      Uri.parse(_overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal terhubung ke server OpenStreetMap');
    }

    final body = jsonDecode(response.body);
    
    // Cek apakah ada error dari OSM
    if (body['elements'] == null) {
      throw Exception('Format data tidak valid dari OpenStreetMap');
    }

    final List elements = body['elements'];

    // Mapping data OSM (kotor) -> Model App (bersih)
    List<FaskesModel> faskesList = [];

    for (var item in elements) {
      final tags = item['tags'] ?? {};
      final nama = tags['name'] ?? 'Faskes Tidak Bernama';
      
      // Gabungkan alamat dari beberapa field OSM
      String alamat = '';
      if (tags['addr:street'] != null) alamat += tags['addr:street'];
      if (tags['addr:housenumber'] != null) alamat += ' ${tags['addr:housenumber']}';
      if (tags['addr:city'] != null) alamat += ', ${tags['addr:city']}';
      if (alamat.isEmpty) alamat = 'Alamat tidak tersedia';

      // OSM memisahkan lat/lng untuk Node dan Way
      double faskesLat = 0;
      double faskesLng = 0;
      if (item['type'] == 'node') {
        faskesLat = (item['lat'] as num).toDouble();
        faskesLng = (item['lon'] as num).toDouble();
      } else if (item['type'] == 'way' && item['center'] != null) {
        faskesLat = (item['center']['lat'] as num).toDouble();
        faskesLng = (item['center']['lon'] as num).toDouble();
      } else {
        continue; // Skip jika tidak ada koordinat
      }

      // Hitung jarak menggunakan Haversine Formula
      final jarak = Geolocator.distanceBetween(lat, lng, faskesLat, faskesLng);

      faskesList.add(FaskesModel(
        nama: nama,
        alamat: alamat.trim(),
        lat: faskesLat,
        lng: faskesLng,
        isOpen: true, // OSM gratis tidak menyediakan data jam buka real-time
        jarakMeter: jarak,
      ));
    }

    // Sort berdasarkan jarak terdekat
    faskesList.sort((a, b) => a.jarakMeter.compareTo(b.jarakMeter));

    return faskesList;
  }
}