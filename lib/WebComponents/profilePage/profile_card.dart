import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  String fullName = '';
  String email = '';
  String address = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    var document = FirebaseFirestore.instance.collection('clients').doc(currentUser!.uid);
    var snapshot = await document.get();
    if (snapshot.exists) {
      setState(() {
        fullName = snapshot.data()?['accountHolder'] ?? 'N/A';
        email = snapshot.data()?['email'] ?? 'N/A';
        address = snapshot.data()?['company'] ?? 'N/A';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.3,
      height: MediaQuery.of(context).size.height * 0.85, // Add fixed height
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24), // Increased padding
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F37),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Changed to spaceEvenly
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF58C6A9), width: 2),
            ),
            child: const CircleAvatar(
              radius: 60, // Increased radius
              backgroundImage: AssetImage('assets/logo1.png'),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 40), // Increased spacing
          Expanded( // Wrapped in Expanded
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Added spaceEvenly
                children: [
                  _buildInfoCard('Company', address, Icons.business),
                  _buildInfoCard('Full Name', fullName, Icons.person),
                  _buildInfoCard('Email', email, Icons.email),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12), // Increased margin
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // Increased padding
      decoration: BoxDecoration(
        color: const Color(0xFF242A4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF58C6A9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF58C6A9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF58C6A9), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF58C6A9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}