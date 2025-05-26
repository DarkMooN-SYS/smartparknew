import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking_system/components/common/custom_widgets.dart';
// import 'package:smart_parking_system/components/payment/payment_options.dart';
import 'package:smart_parking_system/components/settings/about_us.dart';
import 'package:smart_parking_system/components/settings/user_profile.dart';
import 'package:smart_parking_system/components/vehicledetails/view_vehicle.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  String _username = 'Ачаалж байна...';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPreferences();
  }

  Future<void> _loadUserDataAndPreferences() async {
    setState(() {
      _isLoading = true;
    });
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          _username = data?['username'] ?? 'User';
          final String? surname = data?['surname'];
          if (surname != null && surname.isNotEmpty) {
            _username = '$_username $surname';
          }
          _profileImageUrl = data?['profileImageUrl'] as String?;
          _notificationsEnabled = data?['notificationsEnabled'] ?? true;
        } else {
          _username = 'User not found';
        }
      } catch (e) {
        print("Error loading user data: $e");
        _username = 'Өгөгдлийг ачаалахад алдаа гарлаа';
        // Keep default _notificationsEnabled = true or set to false based on desired error behavior
      }
    } else {
      _username = 'Not logged in';
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotificationPreference(bool isEnabled) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'notificationsEnabled': isEnabled,
        });
      } catch (e) {
        print("Error updating notification preference: $e");
        // Optionally revert UI or show error to user
        if (mounted) {
          setState(() {
            _notificationsEnabled = !isEnabled; // Revert switch on error
          });
        }
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFFADADAD), fontSize: 16),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0), // Standard padding
    );
  }

  Widget _buildUserProfileSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 40, // Increased radius
              backgroundColor: Colors.grey.shade700,
              backgroundImage:
                  _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? NetworkImage(_profileImageUrl!)
                      : null,
              child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white70)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              _username,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Бүртгэлийн тохиргоо'),
        _buildSettingsTile(
          title: 'Профайлыг засах',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const UserProfilePage())),
        ),
        _buildSettingsTile(
          title: 'Миний машинууд',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ViewVehiclePage())),
        ),
        // _buildSettingsTile(
        //   title: 'My payment options',
        //   onTap: () => Navigator.of(context).push(
        //       MaterialPageRoute(builder: (_) => const PaymentMethodPage())),
        // ),
        _buildSettingsTile(
            title: 'Push notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _updateNotificationPreference(value);
              },
              activeColor: Colors.tealAccent,
              inactiveTrackColor: Colors.grey.shade600,
              inactiveThumbColor: Colors.grey.shade300,
            ),
            onTap: () {
              // Allow tapping the row to toggle switch too
              setState(() {
                _notificationsEnabled = !_notificationsEnabled;
              });
              _updateNotificationPreference(_notificationsEnabled);
            }),
      ],
    );
  }

  Widget _buildMoreSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('More'),
        _buildSettingsTile(
          title: 'About',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AboutUsPage())),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF35344A),
      // AppBar is handled by main_page.dart for the settings tab
      // If this page can be accessed directly, an AppBar might be needed here.
      body: _isLoading
          ? loadingWidget() // Uses the imported loadingWidget
          : SafeArea(
              // Ensure content is not obscured by notches, status bars
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Custom header section removed, assuming AppBar is provided by MainPage
                    // If standalone, uncomment and adapt _buildAppBar or use Scaffold AppBar.
                    _buildUserProfileSection(),
                    const Divider(
                        color: Colors.white24,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16),
                    _buildAccountSettingsSection(context),
                    const Divider(
                        color: Colors.white24,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16),
                    _buildMoreSection(context),
                    const SizedBox(height: 20), // Padding at the bottom
                  ],
                ),
              ),
            ),
      // drawer: const SideMenu(), // Drawer is typically part of the parent Scaffold in MainPage
    );
  }
}
