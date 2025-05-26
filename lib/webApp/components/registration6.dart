import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking_system/components/common/common_functions.dart';
import 'package:smart_parking_system/components/common/toast.dart';



class Registration6 extends StatefulWidget {
  final Function onRegisterComplete;
  // final ParkingSpot ps;

  const Registration6({super.key, required this.onRegisterComplete});

  @override
  // ignore: library_private_types_in_public_api
  _Registration6State createState() => _Registration6State();
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

class _Registration6State extends State<Registration6> {
  final TextEditingController _billingNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountTypeController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  bool _isLoading = false;

  final Map<String, String> _validBanks = {
    "GOLOMT BANK": "Absa Bank",
    "CAPITEC": "Capitec Bank",
    "KHAAN BANK": "First National Bank",
    "INVESTEC": "Investec Bank",
    "NEDBANK": "Nedbank",
    "STANDARD BANK": "Standard Bank",
    "AFRICAN BANK": "African Bank",
    "BIDVEST": "Bidvest Bank",
    "DISCOVERY": "Discovery Bank",
    "TYMEBANK": "TymeBank",
    "AL BARAKA": "Al Baraka Bank",
    "GROBANK": "Grobank",
    "SASFIN": "Sasfin Bank",
    "UBANK": "UBank",
    "MERCANTILE": "Mercantile Bank",
    "HBZ": "HBZ Bank",
    "ZERO": "Bank Zero",
    "CITIBANK": "Citibank South Africa",
    "SBI": "State Bank of India South Africa",
    "BANK OF CHINA": "Bank of China South Africa",
    "FIRSTRAND": "FirstRand Bank"
  };

  Future<void> _saveCardDetails() async {
    setState((){
      _isLoading = true;
    });
    User? user = FirebaseAuth.instance.currentUser;

    final String billingName = _billingNameController.text;
    final String accountNumber = _accountNumberController.text.replaceAll(RegExp(r'\s+'), '');
    final String accountType = _accountTypeController.text;
    final String bank = _bankController.text;

    if(!isValidString(accountNumber, r'^[0-9]{8,12}$')){showToast(message: "Дансны дугаар буруу. 8-12 оронтой байх ёстой."); setState(() => _isLoading = false); return;}
    if(!isValidString(billingName, r'^[a-zA-Z/\s]+$')){showToast(message: "Эзэмшигчийн нэр буруу"); setState(() => _isLoading = false); return;}
    if(!isValidString(accountType, r'^[a-zA-Z/\s]+$')){showToast(message: "Invalid Holder Name"); setState(() => _isLoading = false); return;}
   
    bool isValidBank = _validBanks.keys.map((k) => k.toLowerCase()).contains(bank.toLowerCase()) ||_validBanks.values.map((v) => v.toLowerCase()).contains(bank.toLowerCase());

    if (!isValidBank) {
      showToast(message: "Банкны нэр буруу. Монголын хүчинтэй банк оруулна уу.");
      setState(() => _isLoading = false);
      return;
    }
  
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('client_cards').add({
          'userId': user.uid,
          'billingName': billingName,
          'accountNumber': accountNumber,
          'accountType': accountType,
          'bank': bank,
        });
        
        widget.onRegisterComplete();
      } catch (e) {
        showToast(message: 'Картын дэлгэрэнгүй мэдээллийг хадгалж чадсангүй: $e');
      }
    }
    setState((){
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const SizedBox(height: 40),
        _buildLabeledTextField('Төлбөр төлөгчийн нэр *', 'Нэрээ оруулна уу', _billingNameController),
        const SizedBox(height: 15),
        _buildLabeledTextField('Дансны дугаар *', 'Дугаараа оруулна уу', _accountNumberController),
        const SizedBox(height: 15),
        _buildLabeledTextField('Дансны төрөл *', 'Төрлөө оруулна уу', _accountTypeController),
        const SizedBox(height: 15),
        _buildLabeledTextField('Банк *', 'Банкны нэрийг оруулна уу', _bankController),
        const SizedBox(height: 25),
          Center(
            child: SizedBox(
              width: 200,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  // Handle the submission or navigation to the next step
                  _saveCardDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58C6A9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  )
                : const Text(
                  'Join',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledTextField(String label, String hintText, TextEditingController controller, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: const Color(0xFF58C6A9),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF58C6A9)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        )
      ],
    );
  }
}
