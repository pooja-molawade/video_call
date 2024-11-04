import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:video_call/screens/video_call_screen.dart';

class LandingScreen extends StatelessWidget {
  final TextEditingController _callIdController = TextEditingController();

  void _showSnackbar(BuildContext context,String text) {
    final snackBar = SnackBar(
      content: Text(text),
      backgroundColor: Colors.red,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _callIdController,
              decoration: const InputDecoration(
                labelText: 'Enter call ID',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  final callId = _callIdController.text.trim();
                  if (callId.isEmpty) {
                    _showSnackbar(context,'Please enter a Call ID');
                    return;
                  }
                 Get.to(VideoCallScreen(callId: callId,));
                  _callIdController.text='';

                },
                child: const Text('Join Call'),
              ),
              ElevatedButton(
                onPressed: () {
                  final callId = _callIdController.text.trim();
                  if (callId.isEmpty) {
                    _showSnackbar(context,'Please enter a Call ID');
                    return;
                  }
                  Get.to(VideoCallScreen(callId: callId,));
                  _callIdController.text='';
                },
                child: const Text('Make Call'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
