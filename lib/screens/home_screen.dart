import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:video_call/screens/video_call_screen.dart';
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Video Call App")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Get.to(const VideoCallScreen());
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(builder: (context) => const VideoCallScreen()),
            // );
          },
          child: const Text("Start Call"),
        ),
      ),
    );
  }
}
