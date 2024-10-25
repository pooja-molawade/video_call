import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class CallScreen extends StatefulWidget {
  late final String callId;
  CallScreen({required this.callId, required bool isCaller});
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  @override
  void initState() {
    super.initState();
    _initRenderers();
    _requestPermissions();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _requestPermissions() async {
    var cameraStatus = await Permission.camera.request();
    var microphoneStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      _initWebRTC();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _initWebRTC() async {
    try {
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });

      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': true,
        'audio': true,
      });

      _localRenderer.srcObject = _localStream;

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      _peerConnection?.onTrack = (RTCTrackEvent event) {
        setState(() {
          _remoteRenderer.srcObject = event.streams.first;
        });
      };

      _peerConnection?.onIceCandidate = (candidate) {
        if (candidate != null) {
          _sendIceCandidate(candidate);
        }
      };

      _initFirestore();
    } catch (e) {
      print('Error initializing WebRTC: $e');
    }
  }

  void _showPermissionDeniedDialog() {
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

  void _initFirestore() {
    FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        if (snapshot.data()!.containsKey('offer')) {
          _handleOffer(snapshot.data()!['offer']);
        }

        if (snapshot.data()!.containsKey('answer')) {
          _handleAnswer(snapshot.data()!['answer']);
        }

        if (snapshot.data()!.containsKey('candidates')) {
          _handleIceCandidates(snapshot.data()!['candidates']);
        }
      }
    });
  }

  void _handleOffer(String offer) async {
    try {
      RTCSessionDescription description = RTCSessionDescription(offer, 'offer');
      await _peerConnection?.setRemoteDescription(description);

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection?.setLocalDescription(answer);

      FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
        'answer': answer.sdp,
      });
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  void _handleAnswer(String answer) async {
    try {
      RTCSessionDescription description = RTCSessionDescription(answer, 'answer');
      await _peerConnection?.setRemoteDescription(description);
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  void _handleIceCandidates(List<dynamic> candidates) {
    for (var candidate in candidates) {
      RTCIceCandidate iceCandidate = RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']);
      _peerConnection?.addCandidate(iceCandidate);
    }
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
      'candidates': FieldValue.arrayUnion([{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }]),
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enabled = !_isMuted;
        });
      }
    });
  }

  void _endCall() {
    _peerConnection?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    Navigator.of(context).pop(); // Go back to the previous screen
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    _localStream?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Call")),
      body: SafeArea(
        child: Stack(
          children: [
            Container(color: Colors.blueGrey),
            RTCVideoView(_remoteRenderer),
            Positioned(
              top: 20,
              right: 20,
              width: 100,
              height: 150,
              child: RTCVideoView(_localRenderer, mirror: true), // Local video view
            ),
            Positioned(
              bottom: 1,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                      onPressed: _toggleMute,
                      color: _isMuted ? Colors.red : Colors.black,
                    ),
                    SizedBox(width: 20),
                    IconButton(
                      icon: Icon(Icons.call_end),
                      onPressed: _endCall,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
