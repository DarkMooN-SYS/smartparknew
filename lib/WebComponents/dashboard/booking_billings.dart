import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingBillings extends StatefulWidget {
  const BookingBillings({super.key});

  @override
  State<BookingBillings> createState() => _BookingBillingsState();
}

class _BookingBillingsState extends State<BookingBillings> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<QueryDocumentSnapshot> bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBookingBillings();
  }

  Future<void> fetchBookingBillings() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("No user logged in");
      }

      // Query the parkings collection
      final parkingQuery = await _firestore
          .collection('parkings')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (parkingQuery.docs.isEmpty) {
        throw Exception("No parking spot found for this user");
      }

      final address = parkingQuery.docs.first.get('name') as String?;

      if (address == null) {
        throw Exception("Parking spot name not found");
      }

      // Query the bookings collection
      QuerySnapshot bookingsQuery = await _firestore
          .collection('bookings')
          .where('address', isEqualTo: address)
          .get();

      setState(() {
        bookings = bookingsQuery.docs;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error: $e");
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F37),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Захиалга хийх тооцоо',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : bookings.isEmpty
                    ? Center(
                        child: Text(
                          "Таны захиалгын төлбөрийн дэлгэрэнгүй мэдээлэл энд харагдах болно",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : Column(
                        children: bookings.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final zone = data['zone'] ?? '';
                          final row = data['row'] ?? '';
                          final title =
                              'Бүс/Эгнээ : $zone/$row - Зогсоолын захиалга';

                          final date = data['date'] ?? ''; // e.g., "2024-11-14"
                          final time = data['time'] ?? ''; // e.g., "12:00"
                          final dateTimeString = '$date, at $time';

                          final price = data['price'] ?? 0; // e.g., 10
                          String amount = '+$price₮';

                          // Determine the amount based on booking status
                          final disabled = data['disabled'] ?? false;
                          final sent = data['sent'] ?? false;

                          if (disabled) {
                            // Booking was canceled/refunded
                            amount = '-$price₮';
                          } else if (!sent) {
                            // Booking is pending
                            amount = 'Хүлээгдэж байна';
                          }

                          return _buildBillingItem(
                              context, title, dateTimeString, amount);
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingItem(
      BuildContext context, String title, String date, String amount) {
    Color amountColor;
    IconData iconData;
    Color bgColor;

    if (amount.startsWith('+')) {
      amountColor = const Color(0xFF00D632);
      iconData = Icons.arrow_circle_up;
      bgColor = const Color(0xFF00D632).withOpacity(0.1);
    } else if (amount.startsWith('-')) {
      amountColor = const Color(0xFFFF4842);
      iconData = Icons.arrow_circle_down;
      bgColor = const Color(0xFFFF4842).withOpacity(0.1);
    } else {
      amountColor = const Color(0xFFFFAB00);
      iconData = Icons.pending;
      bgColor = const Color(0xFFFFAB00).withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D3447),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: amountColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        subtitle: Text(
          date,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
