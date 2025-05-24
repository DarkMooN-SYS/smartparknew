import 'dart:async';
import 'package:flutter/material.dart';
//Maps
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart'
    as places_service;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geolocator/geolocator.dart' as geoloc;
import 'dart:convert';
import 'package:http/http.dart' as http;
//Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking_system/components/common/toast.dart';

import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:smart_parking_system/components/home/main_page.dart'
    show Parking;

class MapView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Function(Parking parking, String distanceAndDuration)
      onParkingSelected; // Modified to include distance/duration
  final Function(bool) setLoadingState;

  const MapView({
    super.key,
    required this.scaffoldKey,
    required this.onParkingSelected,
    required this.setLoadingState,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  loc.LocationData? _locationData;
  final Completer<GoogleMapController> _mapControllerCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  bool _locationPermissionGrantedForMap =
      false; // For GoogleMap's myLocationEnabled
  final Set<Marker> _markers = {};
  final TextEditingController _destinationController = TextEditingController();
  loc.PermissionStatus _permissionStatus = loc.PermissionStatus.denied;

  // Debug flag to disable markers
  static const bool _disableMarkers = false; // Set to false to enable markers

  // Debounce timer for map interactions
  Timer? _debounceTimer;
  DateTime? _lastCameraUpdate;
  static const _minCameraUpdateInterval = Duration(milliseconds: 100);

  BitmapDescriptor? _carIcon;
  bool _isIconLoaded = false;
  static const int _maxMarkersToFetch = 30;
  Timer? _refreshTimer;
  final Map<String, Marker> _markerCache = {};

  bool _isDisposed = false;
  bool _isRefreshingMarkers = false;
  bool _isMapReady = false;
  MarkerId? _selectedMarkerId; // Added to track selected marker

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    print("[MapView._initializeMap] Initializing map...");
    if (_isDisposed) return;
    widget.setLoadingState(true);

    await _loadCarIcon();
    bool locationOK = await _requestLocationPermissionAndData();

    if (_isDisposed) {
      if (mounted) widget.setLoadingState(false);
      return;
    }

    if (locationOK) {
      if (_isMapReady) {
        print("[MapView._initializeMap] Map ready, refreshing markers.");
        await _refreshMarkers();
      } else {
        print(
            "[MapView._initializeMap] Map not ready, onMapCreated will refresh markers.");
      }
      _startMarkerRefreshTimer();
    } else {
      print("[MapView._initializeMap] Location not OK.");
      if (mounted) widget.setLoadingState(false);
    }
  }

  void _startMarkerRefreshTimer() {
    _refreshTimer?.cancel();
    // Increase refresh interval to reduce load
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isDisposed && mounted && !_isRefreshingMarkers && _isMapReady) {
        print("[MapView.Timer] Refreshing markers.");
        _refreshMarkers();
      }
    });
  }

  @override
  void dispose() {
    print("[MapView.dispose] Disposing MapView.");
    _isDisposed = true;
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _destinationController.dispose();
    // _mapController?.dispose(); // GoogleMap widget handles its controller disposal
    super.dispose();
  }

  Future<void> _loadCarIcon() async {
    if (_isIconLoaded || _isDisposed) return;
    try {
      // Original custom icon:
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(100, 100)),
        'assets/Purple_ParkMe.png',
      );
      _carIcon ??=
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      _isIconLoaded = true;
    } catch (e) {
      print('[MapView.Error._loadCarIcon] $e. Using default marker.');
      _carIcon = BitmapDescriptor.defaultMarker;
      _isIconLoaded = true;
    }
    if (!_isDisposed && mounted) setState(() {});
  }

  Future<bool> _requestLocationPermissionAndData() async {
    print("[MapView._requestLocationPermissionAndData] Requesting location...");
    if (_isDisposed) return false;

    loc.Location location = loc.Location();
    bool serviceEnabled;
    loc.PermissionStatus currentPermission;

    try {
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() => _permissionStatus = loc.PermissionStatus.denied);
          }
          return false;
        }
      }

      currentPermission = await location.hasPermission();
      if (currentPermission == loc.PermissionStatus.denied) {
        currentPermission = await location.requestPermission();
      }

      if (mounted) setState(() => _permissionStatus = currentPermission);
      if (_isDisposed) return false;

      if (currentPermission == loc.PermissionStatus.granted ||
          currentPermission == loc.PermissionStatus.grantedLimited) {
        _locationPermissionGrantedForMap = true;
        loc.LocationData fetchedLocationData =
            await location.getLocation().timeout(const Duration(seconds: 10));

        if (!_isDisposed && mounted) {
          setState(() => _locationData = fetchedLocationData);
        }
        if (_isMapReady && _mapController != null && _locationData != null) {
          _animateCamera(
              LatLng(_locationData!.latitude!, _locationData!.longitude!),
              15.0);
        }
        print(
            "[MapView._requestLocationPermissionAndData] Location permission granted and data fetched.");
        return true;
      } else {
        _locationPermissionGrantedForMap = false;
        print(
            "[MapView._requestLocationPermissionAndData] Location permission denied.");
        return false;
      }
    } catch (e) {
      print("[MapView.Error._requestLocationPermissionAndData] $e");
      if (!_isDisposed && mounted) {
        setState(() {
          _permissionStatus = loc.PermissionStatus.denied;
          _locationPermissionGrantedForMap = false;
          _locationData = null;
        });
      }
      return false;
    }
  }

  Future<void> _animateCamera(LatLng position, double zoom) async {
    if (_isDisposed || _mapController == null || !_isMapReady) return;

    // Debounce camera updates
    final now = DateTime.now();
    if (_lastCameraUpdate != null &&
        now.difference(_lastCameraUpdate!) < _minCameraUpdateInterval) {
      return;
    }
    _lastCameraUpdate = now;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: position, zoom: zoom)),
      );
    } catch (e) {
      print('[MapView.Error._animateCamera] $e');
    }
  }

  Future<void> _refreshMarkers() async {
    print("[MapView._refreshMarkers] Refreshing markers...");
    if (_isDisposed || _isRefreshingMarkers || !_isMapReady || !_isIconLoaded) {
      print(
          "[MapView._refreshMarkers] Guarded out. Conditions: isDisposed: $_isDisposed, isRefreshing: $_isRefreshingMarkers, mapNotReady: ${!_isMapReady}, iconNotLoaded: ${!_isIconLoaded}");
      return;
    }

    // Early return if markers are disabled
    if (_disableMarkers) {
      print("[MapView._refreshMarkers] Markers disabled for debugging");
      if (!_isDisposed && mounted) {
        setState(() {
          _markers.clear();
        });
      }
      return;
    }

    _isRefreshingMarkers = true;
    if (mounted) widget.setLoadingState(true);

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore
          .collection('parkings')
          .limit(_maxMarkersToFetch)
          .get();

      if (_isDisposed) return;

      List<Future<void>> detectionAndUpdateFutures = [];
      Set<Marker> freshMarkers = {};

      for (var document in querySnapshot.docs) {
        if (_isDisposed) break;
        String docId = document.id;
        try {
          Map<String, dynamic> data = document.data() as Map<String, dynamic>;
          String name = data['name'] as String? ?? 'Unknown Parking';
          String price = data['price'] as String? ?? 'N/A';
          String slotsString = data['slots_available'] as String? ?? '0/0';

          double latitude = 0.0, longitude = 0.0;
          try {
            // Robust latitude/longitude parsing
            latitude = (data['latitude'] as num).toDouble();
            longitude = (data['longitude'] as num).toDouble();
          } catch (e) {
            print("[MapView.Error] Parsing lat/lng for $name: $e. Using 0,0.");
          }

          if (name == 'EPI-USE Labs') {
            // Special handling for EPI-USE Labs
            detectionAndUpdateFutures.add(_detectCarsAndUpdateMarker(
                'https://www.youtube.com/live/CH8GegCF9FI',
                docId,
                name,
                price,
                latitude,
                longitude));
          } else {
            Marker marker = _createMarker(
                docId, name, price, slotsString, latitude, longitude);
            freshMarkers.add(marker);
            _markerCache[docId] = marker;
          }
        } catch (e) {
          print('[MapView.Error._refreshMarkers] Processing doc $docId: $e');
        }
      }

      if (detectionAndUpdateFutures.isNotEmpty) {
        await Future.wait(detectionAndUpdateFutures);
        // Markers for EPI-USE Labs (or others handled by _detectCarsAndUpdateMarker) are added to _markerCache and freshMarkers inside that function.
      }

      // Add all other markers that were not part of detectionAndUpdateFutures
      // _detectCarsAndUpdateMarker already adds its marker to freshMarkers if successful
      for (var marker in _markerCache.values) {
        if (!freshMarkers.any((m) => m.markerId == marker.markerId)) {
          freshMarkers.add(marker);
        }
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(freshMarkers);
          print(
              "[MapView._refreshMarkers] Markers updated. Count: ${_markers.length}");
        });
      }
    } catch (e) {
      print('[MapView.Error._refreshMarkers] General error: $e');
    } finally {
      _isRefreshingMarkers = false;
      if (!_isDisposed && mounted) widget.setLoadingState(false);
    }
  }

  Marker _createMarker(String docId, String name, String price,
      String slotsString, double latitude, double longitude,
      {String? preCalculatedDistanceDuration}) {
    return Marker(
      markerId: MarkerId(docId),
      position: LatLng(latitude, longitude),
      icon: _carIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: name,
        snippet: '$slotsString slots Available',
      ),
      onTap: () async {
        if (_isDisposed) return;
        // Update _selectedMarkerId when a marker is tapped
        if (mounted) {
          setState(() {
            _selectedMarkerId = MarkerId(docId);
          });
        }
        _animateCamera(LatLng(latitude, longitude), 17.0);

        String distanceAndDurationStr =
            preCalculatedDistanceDuration ?? "Calculating...";
        if (preCalculatedDistanceDuration == null &&
            _locationData != null &&
            dotenv.env['PLACES_API_KEY'] != null) {
          distanceAndDurationStr =
              await _calculateDistanceAndDuration(latitude, longitude);
        } else if (preCalculatedDistanceDuration == null) {
          distanceAndDurationStr = "Location or API Key missing";
        }

        if (_isDisposed) return;

        final parkingInfo = Parking(name, price, slotsString,
            '${extractSlotsAvailable(slotsString)} slots', latitude, longitude);
        widget.onParkingSelected(parkingInfo, distanceAndDurationStr);
      },
    );
  }

  Future<String> _calculateDistanceAndDuration(
      double parkingLat, double parkingLng) async {
    if (_locationData == null || dotenv.env['PLACES_API_KEY'] == null) {
      return "N/A (Location/API Key error)";
    }
    // Distance (Geolocator)
    double distanceInMeters = geoloc.Geolocator.distanceBetween(
      _locationData!.latitude!,
      _locationData!.longitude!,
      parkingLat,
      parkingLng,
    );
    String distanceString = distanceInMeters < 1000
        ? '${distanceInMeters.toStringAsFixed(0)} m'
        : '${(distanceInMeters / 1000).toStringAsFixed(1)} km';

    // Duration (Google Matrix API)
    String apiKey = dotenv.env['PLACES_API_KEY']!;
    String url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric'
        '&origins=${_locationData!.latitude},${_locationData!.longitude}'
        '&destinations=$parkingLat,$parkingLng&key=$apiKey';
    try {
      http.Response response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (!_isDisposed && response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['rows'] != null &&
            data['rows'].isNotEmpty &&
            data['rows'][0]['elements'] != null &&
            data['rows'][0]['elements'].isNotEmpty &&
            data['rows'][0]['elements'][0]['status'] == 'OK' &&
            data['rows'][0]['elements'][0]['duration'] != null) {
          String duration = data['rows'][0]['elements'][0]['duration']['text'];
          return '$duration ($distanceString)';
        } else {
          return distanceString; // Fallback if API response is not as expected
        }
      } else if (!_isDisposed) {
        return distanceString; // Fallback on API error
      }
    } catch (e) {
      print("[MapView.Error._calculateDistanceAndDuration] $e");
      return distanceString; // Fallback on exception
    }
    return distanceString; // Should not be reached if not disposed
  }

  Future<void> _detectCarsAndUpdateMarker(
      String youtubeUrl,
      String parkingDocId,
      String name,
      String price,
      double lat,
      double lng) async {
    if (_isDisposed) return;
    const apiUrl = 'https://detectcars-syx3usysxa-uc.a.run.app';
    print("[MapView._detectCarsAndUpdateMarker] Detecting for $parkingDocId");
    String currentSlotsString = _markerCache[parkingDocId]
            ?.infoWindow
            .snippet
            ?.replaceFirst(" slots Available", "") ??
        "0/0";

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'youtube_url': youtubeUrl}),
          )
          .timeout(const Duration(seconds: 20)); // Added timeout

      if (_isDisposed) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int carCount = data['car_count'] as int? ?? 0;

        FirebaseFirestore firestore = FirebaseFirestore.instance;
        DocumentReference parkingDocRef =
            firestore.collection('parkings').doc(parkingDocId);

        int totalSlots = 5; // Assuming 5 for EPI-USE Labs as per original logic
        int availableSlots = (totalSlots - carCount).clamp(0, totalSlots);
        String newSlotsAvailableString = '$availableSlots/$totalSlots';

        await parkingDocRef
            .update({'slots_available': newSlotsAvailableString});
        currentSlotsString =
            newSlotsAvailableString; // Update for marker creation
        print(
            "[MapView._detectCarsAndUpdateMarker] Firestore updated for $parkingDocId: $newSlotsAvailableString");
      } else {
        print(
            '[MapView.Error._detectCarsAndUpdateMarker] $parkingDocId (status ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('[MapView.Exception._detectCarsAndUpdateMarker] $parkingDocId: $e');
    }

    // Create/update marker regardless of API call success, using latest known slots
    if (!_isDisposed) {
      Marker updatedMarker = _createMarker(
          parkingDocId, name, price, currentSlotsString, lat, lng);
      _markerCache[parkingDocId] = updatedMarker;
      // The marker will be added to _markers set in the main _refreshMarkers loop
      // Or, if immediate update is critical, could call setState here for just this marker.
      // For consistency, _refreshMarkers handles the final setState.
      // This function now ensures _markerCache has the most up-to-date version possible.
    }
  }

  String extractSlotsAvailable(String slotsString) {
    try {
      if (slotsString.contains('/')) return slotsString.split('/')[0].trim();
      return slotsString;
    } catch (e) {
      print("[MapView.Error.extractSlotsAvailable] $slotsString: $e");
      return "N/A";
    }
  }

  void findNearestParkingLocation() async {
    if (_isDisposed ||
        _locationData == null ||
        _markers.isEmpty ||
        !_isMapReady) {
      showToast(message: 'Current location or parking spots unavailable.');
      return;
    }
    try {
      Marker? nearestMarker;
      double minDistance = double.infinity;
      for (var marker in _markers) {
        double distance = geoloc.Geolocator.distanceBetween(
          _locationData!.latitude!,
          _locationData!.longitude!,
          marker.position.latitude,
          marker.position.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestMarker = marker;
        }
      }
      if (nearestMarker != null) {
        _animateCamera(nearestMarker.position, 19.0);
        _mapController?.showMarkerInfoWindow(nearestMarker.markerId);
      } else {
        showToast(message: 'No parking locations found.');
      }
    } catch (e) {
      print('[MapView.Error.findNearestParkingLocation] $e');
      showToast(message: 'Error finding nearest parking: ${e.toString()}');
    }
  }

  void displaySearchedPrediction(Prediction? p) async {
    if (p != null && !_isDisposed) {
      print("[MapView.displaySearchedPrediction] Prediction: ${p.description}");
      places_service.GoogleMapsPlaces placesApi =
          places_service.GoogleMapsPlaces(
              apiKey: dotenv.env['PLACES_API_KEY']!);
      try {
        places_service.PlacesDetailsResponse detail =
            await placesApi.getDetailsByPlaceId(p.placeId!);
        if (_isDisposed) return;

        final lat = detail.result.geometry?.location.lat;
        final lng = detail.result.geometry?.location.lng;

        if (lat != null && lng != null) {
          _animateCamera(LatLng(lat, lng), 15.0);
          if (mounted) {
            setState(() => _destinationController.text = p.description ?? '');
          }
        } else {
          showToast(message: 'Could not get location details.');
        }
      } catch (e) {
        print("[MapView.Error.displaySearchedPrediction] $e");
        showToast(message: 'Error fetching details: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        "[MapView.build] PermissionStatus: $_permissionStatus, MapReady: $_isMapReady, Markers: ${_markers.length}, MarkersDisabled: $_disableMarkers");

    if (_permissionStatus != loc.PermissionStatus.granted &&
        _permissionStatus != loc.PermissionStatus.grantedLimited) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                    "Location permission is required to use map features.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeMap, // Re-attempt full initialization
                  child: const Text("Grant Permission"),
                ),
                if (_permissionStatus == loc.PermissionStatus.deniedForever)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: const Text(
                        "Please enable location permission in app settings.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        GoogleMap(
          initialCameraPosition: const CameraPosition(
              target: LatLng(-29.0, 24.0), zoom: 5.0), // Centered on SA
          onMapCreated: (GoogleMapController controller) {
            print("[MapView.onMapCreated] Map created.");
            if (_isDisposed) return;
            _mapController = controller;
            if (!_mapControllerCompleter.isCompleted) {
              _mapControllerCompleter.complete(controller);
            }
            _isMapReady = true;
            if (_locationData != null) {
              // Debounce initial camera movement
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                if (!_isDisposed && mounted) {
                  _animateCamera(
                      LatLng(
                          _locationData!.latitude!, _locationData!.longitude!),
                      15.0);
                }
              });
            }
            _refreshMarkers();
          },
          myLocationEnabled: _locationPermissionGrantedForMap,
          myLocationButtonEnabled: false, // As per your new code
          markers: _markers,
          mapType: MapType.normal,
          zoomControlsEnabled: true,
          compassEnabled: true,
          onTap: (LatLng position) {
            if (!_isDisposed &&
                mounted &&
                _selectedMarkerId != null &&
                _mapController != null) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 100), () {
                if (!_isDisposed && mounted) {
                  _mapController!.hideMarkerInfoWindow(_selectedMarkerId!);
                  setState(() {
                    _selectedMarkerId = null;
                  });
                }
              });
            }
          },
        ),
        // UI Elements: Menu button and Search bar
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 15.0,
          right: 15.0,
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => widget.scaffoldKey.currentState?.openDrawer(),
                    child: const SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(Icons.menu, color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        if (_isDisposed) return;
                        Prediction? p = await PlacesAutocomplete.show(
                          context: context,
                          apiKey: dotenv.env['PLACES_API_KEY']!,
                          mode: Mode.overlay,
                          language: "en",
                          components: [
                            const places_service.Component(
                                places_service.Component.country, "mn")
                          ],
                        );
                        if (!_isDisposed) displaySearchedPrediction(p);
                      },
                      child: Container(
                        height: 50.0,
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        alignment: Alignment.centerLeft,
                        child: AbsorbPointer(
                          // Makes the TextField look interactive but tap is handled by InkWell
                          child: TextField(
                            controller: _destinationController,
                            decoration: InputDecoration(
                              hintText: 'Where are you going?',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey[700]),
                              icon: Icon(Icons.search, color: Colors.grey[600]),
                            ),
                            style: const TextStyle(
                                color: Colors.black, fontSize: 16),
                            readOnly: true, // Tap handled by InkWell
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // go me my location button
        Positioned(
          bottom: 20.0,
          left: 15.0,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              _animateCamera(
                  LatLng(_locationData!.latitude!, _locationData!.longitude!),
                  17.0);
            },
            backgroundColor: const Color(0xFF58C6A9),
            child: const Icon(Icons.location_on, color: Colors.white),
          ),
        ),

        // "Find Nearest Parking button
        Positioned(
          bottom: 20.0,
          left: 0, right: 0, // Centering trick
          child: Center(
            child: FloatingActionButton(
              onPressed: findNearestParkingLocation,
              backgroundColor: const Color(0xFF58C6A9),
              child: const Icon(Icons.near_me, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// MarkerCopyWith extension from your code, useful for updating markers partially
extension MarkerCopyWith on Marker {
  Marker copyWith({
    MarkerId? markerId,
    LatLng? position,
    InfoWindow? infoWindowParam,
    BitmapDescriptor? icon,
    Offset? anchor,
    bool? consumeTapEvents,
    bool? draggable,
    bool? flat,
    double? alpha,
    double? rotation,
    bool? visible,
    double? zIndex,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: markerId ?? this.markerId,
      position: position ?? this.position,
      infoWindow: infoWindowParam ?? infoWindow,
      icon: icon ?? this.icon,
      anchor: anchor ?? this.anchor,
      consumeTapEvents: consumeTapEvents ?? this.consumeTapEvents,
      draggable: draggable ?? this.draggable,
      flat: flat ?? this.flat,
      alpha: alpha ?? this.alpha,
      rotation: rotation ?? this.rotation,
      visible: visible ?? this.visible,
      zIndex: zIndex ?? this.zIndex,
      onTap: onTap ?? this.onTap,
    );
  }
}
