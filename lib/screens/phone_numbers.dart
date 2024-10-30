import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_call/screens/video_call_ppage_new.dart';

class PhoneNumberScreen extends StatelessWidget {
  final List<String> contacts = ['9552', '9545381643', '1234', '5678'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final number = contacts[index];
          return ListTile(
            title: Text(number),
            onTap: () async {
              // Generate a unique call ID
              final callerId = '9552'; // This would be your caller ID
              final callDocId = '$callerId$number';

              // Initiate a new call in Firestore
              await FirebaseFirestore.instance.collection('calls').doc(callDocId).set({
                'callerId': callerId,
                'receiverId': number,
                'status': 'calling',
                'offer': null,
              });

              // Navigate to the Video Call Page and start the call
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallPage(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
