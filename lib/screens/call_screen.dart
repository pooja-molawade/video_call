import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallScreen extends StatefulWidget {
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initWebRTC();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initWebRTC() async {
    // Create peer connection
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
    _peerConnection?.addStream(_localStream!);

    _peerConnection?.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
    };

    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate != null) {
        _sendIceCandidate(candidate);
      }
    };

    _initFirestore();
  }

  void _initFirestore() {
    FirebaseFirestore.instance.collection('calls').doc('unique_call_id').snapshots().listen((snapshot) {
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
    RTCSessionDescription description = RTCSessionDescription(offer, 'offer');
    await _peerConnection?.setRemoteDescription(description);

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection?.setLocalDescription(answer);

    FirebaseFirestore.instance.collection('calls').doc('unique_call_id').update({
      'answer': answer.sdp,
    });
  }

  void _handleAnswer(String answer) async {
    RTCSessionDescription description = RTCSessionDescription(answer, 'answer');
    await _peerConnection?.setRemoteDescription(description);
  }

  void _handleIceCandidates(List<dynamic> candidates) {
    for (var candidate in candidates) {
      RTCIceCandidate iceCandidate = RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']);
      _peerConnection?.addCandidate(iceCandidate);
    }
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    FirebaseFirestore.instance.collection('calls').doc('unique_call_id').update({
      'candidates': FieldValue.arrayUnion([{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }]),
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Video Call")),
      body: Stack(
        children: [
          RTCVideoView(_remoteRenderer),
          Positioned(
            top: 20,
            right: 20,
            width: 100,
            height: 150,
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
        ],
      ),
    );
  }
}
