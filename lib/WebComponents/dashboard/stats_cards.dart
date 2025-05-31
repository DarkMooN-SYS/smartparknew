import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsCards extends StatefulWidget {
  const StatsCards({super.key});

  @override
  State<StatsCards> createState() => _StatsCardsState();
}

class _StatsCardsState extends State<StatsCards> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  bool isLatestBooking = false;
  late CollectionReference bookingsCollection;
  num totalIncome = 0;
  num todaysIncome = 0;
  num totalBookings = 0;
  num todaysBookings = 0;
  late DocumentSnapshot latestBooking;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });

    try {
      //get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("No user logged in");
      }
      // Query the parkings collection
      final parkingQuery = await _firestore.collection('parkings')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      //No parking for user
      if (parkingQuery.docs.isEmpty) {
        throw Exception("No parking spot found for this user");
      }
      //Get address name
      final address = parkingQuery.docs.first.get('name') as String?;
      //Empty address name
      if (address == null) {
        throw Exception("Parking spot name not found");
      }
      // Query the bookings collection
      QuerySnapshot bookingsQuery = await _firestore
          .collection('bookings')
          .where('address', isEqualTo: address)
          .get();
      // Query the bookings collection
      QuerySnapshot pastBookingsQuery = await _firestore
          .collection('past_bookings')
          .where('address', isEqualTo: address)
          .get();

      // Getting Total Income and Latest DateTime
      num tempTotalIncome = 0;
      num tempTodaysIncome = 0;
      num tempTotalBookings = 0;
      num tempTodaysBookings = 0;
      DateTime? latestDate;
      DocumentSnapshot? tempLatestBooking;
      bool tempIsLatestBooking = false;
      DateTime today = DateTime.now();
      for (var booking in bookingsQuery.docs) {
        final data = booking.data() as Map<String, dynamic>;

        // Calculate total income
        tempTotalIncome += data['price'] ?? 0;
        tempTotalBookings++;

        // Calculate latest booking and todays bookings
        if (data['date'] != null && data['time'] != null) {
          // Parse date and time
          DateTime bookingDateTime = DateTime.parse('${data['date']} ${data['time']}');
          // Update latestDate if the current dateTime is later
          if (latestDate == null || bookingDateTime.isAfter(latestDate)) {
            latestDate = bookingDateTime;
            tempLatestBooking = booking;
            tempIsLatestBooking = true;
          }

          // Parse date
          DateTime bookingDate = DateTime.parse(data['date']);
          // Update latestDate if the current dateTime is later
          if (bookingDate.year == today.year && bookingDate.month == today.month && bookingDate.day == today.day) {
            tempTodaysIncome += data['price'] ?? 0;
            tempTodaysBookings++;
          }
        }
      }
      for (var booking in pastBookingsQuery.docs) {
        final data = booking.data() as Map<String, dynamic>;

        // Calculate total income
        tempTotalIncome += data['price'] ?? 0;
        tempTotalBookings++;

        // Calculate todays bookings
        if (data['date'] != null && data['time'] != null) {
          // Parse date
          DateTime bookingDate = DateTime.parse(data['date']);
          // Update latestDate if the current dateTime is later
          if (bookingDate.year == today.year && bookingDate.month == today.month && bookingDate.day == today.day) {
            tempTodaysIncome += data['price'] ?? 0;
            tempTodaysBookings++;
          }
        }
      }

      setState(() {
        totalIncome = tempTotalIncome;
        latestBooking = tempLatestBooking!;
        isLatestBooking = tempIsLatestBooking;
        totalBookings = tempTotalBookings;
        todaysBookings = tempTodaysBookings;
        todaysIncome = tempTodaysIncome;
      });
    } catch (e) {
      if(kDebugMode){
        print("Error: $e");
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2, // Increase flex for income card
          child: _buildIncomeCard(context)
        ),
        const SizedBox(width: 24), // Increase spacing
        Expanded(
          flex: 3, // Increase flex for stats column
          child: _buildStatsColumn(context)
        ),
      ],
    );
  }

  Widget _buildIncomeCard(BuildContext context) {
    return Container(
      height: 300, // Fixed height for income card
      child: Card(
        color: const Color(0xFF1A1F37),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(32), // Increase padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLoading ?  const Center(child: CircularProgressIndicator()) :
                  _buildCardHeader(context, 'Нийт орлого', '$totalIncome₮'),
              const SizedBox(height: 24),
              Text(
                'СҮҮЛИЙН ЗАХИАЛГА',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: const Color(0xFFA0AEC0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              isLoading ?  const Center(child: CircularProgressIndicator()) :
                isLatestBooking
                  ? _buildLatestBookingInfo(context)
                  : const Text(
                      'Одоогоор захиалга алга',
                      style: TextStyle(color: Colors.white),
                    ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildCardHeader(BuildContext context, String title, String value) { //Done
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFE9EDF7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Icon(Icons.trending_up, color: Colors.greenAccent, size: 32),
      ],
    );
  }
  Widget _buildLatestBookingInfo(BuildContext context) { //Done
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bookmark, color: Colors.white),
      title: Text(
        'Бүс ${latestBooking['zone']} Зогсоолын захиалга',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Өнөөдөр, ${latestBooking['time']}',
        style: const TextStyle(
          color: Color(0xFFA0AEC0),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: Text(
        '${latestBooking['price']}₮',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatsColumn(BuildContext context) {
    return SizedBox(
      height: 300, // Match height with income card
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space evenly
        children: [
          _buildStatsCard(
            context,
            title: 'Нийт захиалга',
            value: totalBookings.toString(),
            icon: Icons.local_parking,
          ),
          _buildStatsCard(
            context,
            title: "Өнөөдрийн захиалга",
            value: todaysBookings.toString(),
            icon: Icons.event_available,
          ),
          _buildStatsCard(
            context,
            title: "Өнөөдрийн орлого",
            value: '$todaysIncome₮',
            icon: Icons.attach_money,
          ),
        ],
      ),
    );
  }
  Widget _buildStatsCard(BuildContext context,
      {required String title, required String value, required IconData icon}) {
    return Container(
      height: 90, // Fixed height for each stat card
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F37),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF58C6A9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF58C6A9), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58C6A9)),
                          ),
                        )
                      : Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
