
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:video_call/screens/call_screen.dart';
import 'package:video_call/screens/video_call_screen.dart';

class HomeScreen extends StatelessWidget {
  final TextEditingController _receiverIdController = TextEditingController();
  Future<void> _requestPermissions(BuildContext context) async {
    var cameraStatus = await Permission.camera.request();
    var microphoneStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      print("Permission Granted");
    } else {
      _showPermissionDeniedDialog(context);
    }
  }
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Permissions Denied"),
          content: Text("Camera and microphone permissions are required to start a video call."),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  final String _callerId = "user1";

  void _startCall(String receiverId) {
    String callId = Uuid().v4();
    print("UUID : $callId");

    FirebaseFirestore.instance.collection('calls').doc(callId).set({
      'callerId': _callerId,
      'receiverId': 'user2',
      'offer': '',
      'answer': '',
      'candidates': [],
      'status': 'ongoing',
    }).then((_) {
    //  Get.to(CallScreen(callId:callId,isCaller: true));
      Get.to(VideoCallScreen(callId: callId, isCaller: true));

    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Video Call App",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _receiverIdController,
                decoration: InputDecoration(labelText: 'Receiver ID'),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _requestPermissions(context);
                _startCall("receiverId");
              },
              child: const Text("Start Call"),
            ),
          ],
        ),
      ),
    );
  }
}
