import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call'),
      ),
      body: Stack(
        children: [
          RTCVideoView(_remoteRenderer),
          Positioned(
            top: 10,
            right: 10,
            width: 100,
            height: 150,
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
        ],
      ),
    );
  }
}
