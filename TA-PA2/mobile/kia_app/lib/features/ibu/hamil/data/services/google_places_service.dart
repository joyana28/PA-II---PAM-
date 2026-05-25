import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────
// MODEL DATA (Bersih, hanya yang dibutuhkan UI)
// ─────────────────────────────────────────────────────────
class FaskesModel {
  final String nama;
  final String alamat;
  final double lat;
  final double lng;
  final bool isOpen;
  final double jarakMeter; // Dihitung manual oleh kita

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
// SERVICE (Berbicara dengan Google API)
// ─────────────────────────────────────────────────────────
class GooglePlacesService {
  // ⚠️ GANTI DENGAN API KEY GOOGLE PLACES KALIAN
  static const String _apiKey = 'MASUKKAN_API_KEY_DISINI'; 
  
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Fetch RS/Klinik terdekat berdasarkan Lat/Lng user
  Future<List<FaskesModel>> fetchNearbyHospitals({
    required double lat,
    required double lng,
    double radiusMeter = 5000, // Default cari radius 5 km
  }) async {
    final uri = Uri.parse('$_baseUrl?'
        'location=$lat,$lng'
        '&radius=$radiusMeter'
        '&type=hospital' // Hanya mencari Rumah Sakit
        '&key=$_apiKey');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Gagal terhubung ke Google Places API');
    }

    final body = jsonDecode(response.body);

    if (body['status'] != 'OK' && body['status'] != 'ZERO_RESULTS') {
      throw Exception('API Error: ${body['status']} - ${body['error_message'] ?? ''}');
    }

    final List results = body['results'] ?? [];
    
    // Mapping JSON kotor -> Model bersih + Hitung Jarak
    List<FaskesModel> faskesList = results.map((item) {
      final geometry = item['geometry']['location'];
      final faskesLat = geometry['lat'];
      final faskesLng = geometry['lng'];

      // Hitung jarak menggunakan Haversine Formula (dari package Geolocator)
      final jarak = Geolocator.distanceBetween(
        lat, lng, // Titik awal (User)
        faskesLat, faskesLng, // Titik tujuan (RS)
      );

      return FaskesModel(
        nama: item['name'] ?? 'Nama Tidak Diketahui',
        alamat: item['vicinity'] ?? 'Alamat Tidak Diketahui',
        lat: faskesLat,
        lng: faskesLng,
        isOpen: item['opening_hours']?['open_now'] ?? false,
        jarakMeter: jarak,
      );
    }).toList();

    // Sort berdasarkan jarak terdekat
    faskesList.sort((a, b) => a.jarakMeter.compareTo(b.jarakMeter));

    return faskesList;
  }
}