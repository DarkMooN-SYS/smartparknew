import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_system/components/help/support.dart';
import 'package:smart_parking_system/components/login/login.dart';
import 'package:smart_parking_system/components/notifications/notificationspage.dart';
import 'package:smart_parking_system/components/parking/parking_history.dart';
import 'package:smart_parking_system/components/payment/payment_options.dart';
import 'package:smart_parking_system/components/settings/settings.dart';
import 'package:smart_parking_system/components/payment/promotion_code.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  Future<String> _getUserName(String userId) async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String username = userDoc.get('username');
    String? surname = userDoc.get('surname'); // Made nullable
    return surname == null || surname.isEmpty ? username : '$username $surname';
  }

  Future<String?> _getProfileImageUrl(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.get('profileImageUrl') as String?;
    } catch (e) {
      print("Error fetching profile image URL: $e");
      return null;
    }
  }

  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF35344A),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: user != null
              ? Future.wait([
                  _getUserName(user.uid),
                  _getProfileImageUrl(user.uid),
                ]).then((results) => {
                    'username': results[0] as String,
                    'profileImageUrl': results[1],
                  })
              : Future.value(
                  {'username': 'Guest User', 'profileImageUrl': null}),
          builder: (BuildContext context,
              AsyncSnapshot<Map<String, dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            } else if (snapshot.hasError) {
              print("Error in FutureBuilder: ${snapshot.error}");
              return Column(children: [
                _buildDrawerHeader(context, 'Error Loading User', null),
                _buildNavigationList(context),
                const Spacer(),
                _buildFooterItems(context),
              ]);
            } else {
              String userName = snapshot.data?['username'] ?? 'User';
              String? profileImageUrl = snapshot.data?['profileImageUrl'];

              return Column(
                children: <Widget>[
                  _buildDrawerHeader(context, userName, profileImageUrl),
                  _buildNavigationList(context),
                  _buildFooterItems(context),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(
      BuildContext context, String userName, String? profileImageUrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2F41),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade400,
                  backgroundImage:
                      profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                  child: profileImageUrl == null || profileImageUrl.isEmpty
                      ? const Icon(Icons.person, size: 30, color: Colors.white)
                      : null,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the drawer
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            userName,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          _buildListTile(
            context,
            Icons.payment,
            'Төлбөрийн аргууд',
            const PaymentMethodPage(),
          ),
          _buildListTile(
            context,
            Icons.history,
            'Зогсоолын түүх',
            const ParkingHistoryPage(),
          ),
          _buildListTile(
            context,
            Icons.local_offer,
            'Урамшууллын код',
            const PromotionCode(),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, indent: 16, endIndent: 16),
          const SizedBox(height: 10),
          _buildListTile(
            context,
            Icons.notifications,
            'Мэдэгдэл',
            const NotificationApp(),
          ),
          _buildListTile(
            context,
            Icons.support,
            'Дэмжлэг',
            const SupportApp(),
          ),
          _buildListTile(
            context,
            Icons.settings,
            'Тохиргоо',
            const SettingsPage(),
          ),
        ],
      ),
    );
  }

  ListTile _buildListTile(
      BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer before navigating
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
    );
  }

  Widget _buildFooterItems(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2F41),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Image.asset(
              'assets/logo_small.png',
              height: 80,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Гарах',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
