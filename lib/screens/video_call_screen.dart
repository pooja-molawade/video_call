import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;

  VideoCallScreen({required this.callId, required this.isCaller});

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RTCPeerConnection _peerConnection;
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    initRenderers();
    _createPeerConnection();
    _setupCall();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration);

    // Get local media stream
    MediaStream localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });

    // Add local stream to the peer connection
    localStream.getTracks().forEach((track) {
      _peerConnection.addTrack(track, localStream);
    });

    // Set local renderer
    _localRenderer.srcObject = localStream;

    // Listen for remote stream
    _peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        // Ensure remote stream is set correctly
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    // Listen for ICE candidates
    _peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        // Add candidate to Firestore
        FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
          'candidates': FieldValue.arrayUnion([candidate.toMap()]),
        });
      }
    };
  }

  void _setupCall() {
    FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((document) {
      if (document.exists) {
        var data = document.data()!;

        // If the caller is making the call
        if (widget.isCaller && data['offer'] == '') {
          // Create and send the offer
          _peerConnection.createOffer().then((offer) {
            _peerConnection.setLocalDescription(offer);
            FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
              'offer': offer.toMap(),
            });
          });
        }
        // If the receiver is answering the call
        else if (!widget.isCaller && data['offer'] != '' && data['answer'] == '') {
          // Receive the offer and create an answer
          _peerConnection.setRemoteDescription(RTCSessionDescription(data['offer'], 'offer'));
          _peerConnection.createAnswer().then((answer) {
            _peerConnection.setLocalDescription(answer);
            FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
              'answer': answer.toMap(),
            });
          });
        }
        // Set remote description when answer is received
        else if (!widget.isCaller && data['answer'] != '') {
          _peerConnection.setRemoteDescription(RTCSessionDescription(data['answer'], 'answer'));
        }

        // Handle ICE candidates
        if (data['candidates'] != null) {
          for (var candidate in data['candidates']) {
            _peerConnection.addCandidate(
                RTCIceCandidate(
                    candidate['candidate'],
                    candidate['sdpMid'],
                    candidate['sdpMLineIndex']
                )
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Call")),
      body: Column(
        children: [
          Expanded(child: RTCVideoView(_localRenderer)),  // Display local video
          Expanded(child: RTCVideoView(_remoteRenderer)), // Display remote video
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection.close();
    super.dispose();
  }
}
