import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  LatLng currentLocation = const LatLng(24.8607, 67.0011); // Default: Karachi
  Set<Marker> markers = {};

  // Static hospital data
  final List<Hospital> hospitals = [
    Hospital(
      id: 1,
      name: 'Aga Khan University Hospital Karachi',
      latitude: 24.8935,
      longitude: 67.0725,
      address: 'Stadium Road, Karachi',
      phone: '+92-21-34864000',
      facilities: ['Emergency', 'ICU', 'Cardiology'],
    ),
    Hospital(
      id: 2,
      name: 'Liaquat National Hospital Karachi',
      latitude: 24.8820,
      longitude: 67.0647,
      address: 'Karachi',
      phone: '+92-21-35859911',
      facilities: ['Emergency', 'General Surgery', 'Pediatrics'],
    ),
    Hospital(
      id: 3,
      name: 'SIUT Karachi',
      latitude: 24.8615,
      longitude: 67.0581,
      address: 'Karachi',
      phone: '+92-21-35855500',
      facilities: ['Urology', 'Transplant', 'Emergency'],
    ),
    Hospital(
      id: 4,
      name: 'Civil Hospital Karachi',
      latitude: 24.8609,
      longitude: 67.0097,
      address: 'Baba-e-Urdu Road, Karachi',
      phone: '+92-21-99215740',
      facilities: ['Emergency', 'General Ward', 'ICU'],
    ),
    Hospital(
      id: 5,
      name: 'Ziauddin Hospital North Nazimabad Karachi',
      latitude: 24.8136,
      longitude: 67.0295,
      address: 'Clifton, Karachi',
      phone: '+92-21-35862000',
      facilities: ['Emergency', 'Cardiology', 'Orthopedics'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Request location permission
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Location permission denied');
      _addHospitalMarkers();
      return;
    }

    // Get current location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      print('Current location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error getting location: $e');
    }

    _addHospitalMarkers();
  }

  void _addHospitalMarkers() {
    setState(() {
      markers.clear();

      // Add current location marker (blue)
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocation,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );

      // Add hospital markers (red)
      for (var hospital in hospitals) {
        markers.add(
          Marker(
            markerId: MarkerId('hospital_${hospital.id}'),
            position: LatLng(hospital.latitude, hospital.longitude),
            infoWindow: InfoWindow(
              title: hospital.name,
              snippet: '${_calculateDistance(hospital.latitude, hospital.longitude).toStringAsFixed(2)} km away',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () {
              _showHospitalDetails(hospital);
            },
          ),
        );
      }
    });
  }

  double _calculateDistance(double lat, double lng) {
    const double p = 0.017453292519943295;
    double a = 0.5 -
        cos((lat - currentLocation.latitude) * p) / 2 +
        cos(currentLocation.latitude * p) *
            cos(lat * p) *
            (1 - cos((lng - currentLocation.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _showHospitalDetails(Hospital hospital) {
    double distance = _calculateDistance(hospital.latitude, hospital.longitude);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hospital.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Facilities
            const Text(
              'Facilities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hospital.facilities.map((facility) {
                return Chip(
                  label: Text(facility),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.blue),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Phone
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hospital.phone,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      mapController.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(hospital.latitude, hospital.longitude),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('View on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _navigateToHospital(hospital);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _navigateToHospital(Hospital hospital) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${currentLocation.latitude},${currentLocation.longitude}'
        '&destination=${Uri.encodeComponent(hospital.name)}'
        '&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(
        Uri.parse(googleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch Google Maps'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospitals'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 4,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: currentLocation,
              zoom: 13,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),

          // Hospital list button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () {
                _showHospitalListSheet();
              },
              icon: const Icon(Icons.list),
              label: const Text('View Hospital List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHospitalListSheet() {
    // Sort hospitals by distance
    List<Hospital> sortedHospitals = hospitals.toList();
    sortedHospitals.sort((a, b) {
      double distA = _calculateDistance(a.latitude, a.longitude);
      double distB = _calculateDistance(b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nearby Hospitals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: sortedHospitals.length,
                itemBuilder: (context, index) {
                  Hospital hospital = sortedHospitals[index];
                  double distance = _calculateDistance(
                    hospital.latitude,
                    hospital.longitude,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.redAccent,
                        ),
                      ),
                      title: Text(hospital.name),
                      subtitle: Text(
                        '${distance.toStringAsFixed(2)} km away',
                        style: const TextStyle(color: Colors.green),
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.pop(context);
                        _showHospitalDetails(hospital);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

// Hospital model
class Hospital {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final List<String> facilities;

  Hospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone,
    required this.facilities,
  });
}