import 'dart:async';
import 'package:flutter/material.dart';
//Map-related imports for _showParkingInfo and Parking class.
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For API Key in _showParkingInfo
import 'package:geolocator/geolocator.dart'; // For distance calculation in _showParkingInfo
import 'dart:convert'; // For json.decode in _showParkingInfo
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;

//Pages
import 'package:smart_parking_system/components/bookings/select_zone.dart';
import 'package:smart_parking_system/components/parking/parking_history.dart';
import 'package:smart_parking_system/components/settings/settings.dart';
import 'package:smart_parking_system/components/home/sidebar.dart';
import 'package:smart_parking_system/components/payment/payment_options.dart';
import 'package:smart_parking_system/components/home/map_view.dart';
import 'package:smart_parking_system/components/common/toast.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class Parking {
  final String name;
  final String price;
  final String slots;
  final String slotsAvailable;
  final double latitude;
  final double longitude;

  Parking(
    this.name,
    this.price,
    this.slots,
    this.slotsAvailable,
    this.latitude,
    this.longitude,
  );
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  Parking? _currentParkingInfo;

  bool _isDisposed = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      MapView(
        scaffoldKey: _scaffoldKey,
        onParkingSelected: (Parking parking, String distanceAndDurationString) {
          if (!_isDisposed && mounted) {
            setState(() {
              _currentParkingInfo = parking;
            });
            _showParkingInfo();
          }
        },
        setLoadingState: (bool isLoading) {
          if (!_isDisposed && mounted && _isLoading != isLoading) {
            setState(() {
              _isLoading = isLoading;
            });
          }
        },
      ),
      const PaymentMethodPage(),
      const ParkingHistoryPage(),
      const SettingsPage(),
    ];

    if (mounted) {
      // Initial loading state will be managed by MapView calling setLoadingState(true)
      // and then setLoadingState(false) when done.
      // Setting to true here can prevent a brief flash if MapView is quick.
      // However, MapView's own _initializeMap already calls setLoadingState(true).
      // So, it might be better to let MapView control it entirely from the start.
      // Let's assume MapView will correctly set the initial loading state.
      // setState(() {
      //   _isLoading = true;
      // });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<loc.LocationData?> _getCurrentLocationForInfo() async {
    loc.Location location = loc.Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        if (mounted) showToast(message: "Location service is disabled.");
        return null;
      }
    }

    loc.PermissionStatus permission = await location.hasPermission();
    if (permission == loc.PermissionStatus.denied ||
        permission == loc.PermissionStatus.deniedForever) {
      permission = await location.requestPermission();
      if (permission != loc.PermissionStatus.granted) {
        if (mounted) showToast(message: "Location permission denied.");
        return null;
      }
    }
    try {
      return await location.getLocation();
    } catch (e) {
      print("Error getting current location for info sheet: $e");
      if (mounted) showToast(message: "Could not get current location.");
      return null;
    }
  }

//  ! MODAL THAT POPS UP WHEN YOU CLICK ON A PARKING LOT
  void _showParkingInfo() async {
    if (_isDisposed || _currentParkingInfo == null) {
      showToast(message: "Unable to show parking info: Parking data missing.");
      return;
    }

    // Set loading true for the duration of this async operation (fetching travel time)
    if (!_isDisposed && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final currentLocation = await _getCurrentLocationForInfo();

    if (_isDisposed) {
      // Check after await
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (currentLocation == null) {
      showToast(
          message:
              "Unable to show parking info: Current location data missing.");
      if (!_isDisposed && mounted) {
        // Ensure loading is turned off
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    double distanceInMeters = Geolocator.distanceBetween(
      currentLocation.latitude!,
      currentLocation.longitude!,
      _currentParkingInfo!.latitude,
      _currentParkingInfo!.longitude,
    );

    double distanceInKm = distanceInMeters / 1000;
    String distanceString = distanceInKm < 1
        ? '${distanceInMeters.toStringAsFixed(0)} m'
        : '${distanceInKm.toStringAsFixed(1)} km';

    String apiKey = dotenv.env['PLACES_API_KEY']!;
    String url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric'
        '&origins=${currentLocation.latitude},${currentLocation.longitude}'
        '&destinations=${_currentParkingInfo!.latitude},${_currentParkingInfo!.longitude}'
        '&key=$apiKey';

    String distanceAndDurationString =
        distanceString; // Default to distance only

    try {
      http.Response response = await http.get(Uri.parse(url));
      if (_isDisposed) {
        // Check after await
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['rows'].isNotEmpty &&
            data['rows'][0]['elements'].isNotEmpty &&
            data['rows'][0]['elements'][0]['status'] == 'OK') {
          String duration = data['rows'][0]['elements'][0]['duration']['text'];
          distanceAndDurationString = '$duration ($distanceString)';
        } else {
          print(
              "Distance Matrix API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}");
          showToast(
              message: 'Could not fetch travel time. Using distance only.');
        }
      } else {
        print("HTTP Error fetching duration: ${response.statusCode}");
        showToast(message: 'Failed to fetch travel time. Using distance only.');
      }
    } catch (e) {
      print("Exception in _showParkingInfo (fetching duration): $e");
      showToast(message: 'Error showing parking details. Using distance only.');
    }

    if (!_isDisposed && mounted) {
      setState(() {
        _isLoading = false;
      }); // Turn off loading before showing sheet
      _showBottomSheetWithInfo(distanceAndDurationString);
    }
  }

  void _showBottomSheetWithInfo(String displayString) {
    if (_isDisposed || !mounted || _currentParkingInfo == null) return;
    showModalBottomSheet(
      anchorPoint: const Offset(0, 0),
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: const BoxDecoration(
            color: Color(0xFF35344A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_currentParkingInfo!.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Divider(
                  color: Color.fromARGB(255, 199, 199, 199), thickness: 1),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Cost per hour :',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('${_currentParkingInfo!.price} ₮/Hr',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Spaces Available :',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                Text(_currentParkingInfo!.slotsAvailable,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Distance to Venue :',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                Text(displayString, // Use the processed display string
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_isDisposed) return;
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ZoneSelectPage(
                          bookedAddress: _currentParkingInfo!.name,
                          price: double.tryParse(_currentParkingInfo!.price) ??
                              0.0,
                          distanceAndDurationString: // Pass the same string
                              displayString,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58C6A9),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                  ),
                  child: const Text('View Parking',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: _selectedIndex == 0,
      appBar: AppBar(
        toolbarHeight: _selectedIndex == 0 ? 0 : kToolbarHeight,
        automaticallyImplyLeading: false,
        backgroundColor:
            _selectedIndex == 0 ? Colors.transparent : const Color(0xFF35344A),
        elevation: 0,
        leading: _selectedIndex == 0
            ? null
            : Builder(builder: (context) {
                return Container(
                  margin: const EdgeInsets.only(top: 20.0),
                  child: IconButton(
                    icon:
                        const Icon(Icons.menu, color: Colors.white, size: 30.0),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                );
              }),
        title: Text(
          _selectedIndex == 1
              ? "Payment Options"
              : _selectedIndex == 2
                  ? "Parking History"
                  : _selectedIndex == 3
                      ? "Settings"
                      : "",
          style: const TextStyle(color: Colors.tealAccent),
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.1),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58C6A9)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF35344A)),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(
                      alpha:
                          0.6), // Reverted user's change here as it was likely part of their cleanup
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, -3)),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF35344A),
            currentIndex: _selectedIndex,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, size: 30),
                  label: '',
                  tooltip: 'Map'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.wallet, size: 30),
                  label: '',
                  tooltip: 'Wallet'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history, size: 30),
                  label: '',
                  tooltip: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined, size: 30),
                  label: '',
                  tooltip: 'Settings'),
            ],
            onTap: (index) {
              if (_isDisposed) return;
              setState(() {
                _selectedIndex = index;
              });
            },
            selectedItemColor: const Color(0xFF58C6A9),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: false,
            showSelectedLabels: false,
          ),
        ),
      ),
      drawer: const SideMenu(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MaterialApp(
    home: MainPage(),
    debugShowCheckedModeBanner: false,
  ));
}
