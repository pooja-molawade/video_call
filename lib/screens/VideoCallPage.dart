import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoCallPage extends StatefulWidget {
  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  late MediaStream localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? peerConnection;
  final firestore = FirebaseFirestore.instance;
  final String callId = 'test-call-123';
  bool isCallActive = false;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initWebRTC() async {
    if (peerConnection == null) {
      peerConnection = await createPeerConnection(_configuration);
      localStream = await navigator.mediaDevices.getUserMedia({
        'video': true,
        'audio': true,
      });
      _localRenderer.srcObject = localStream;

      for (var track in localStream.getTracks()) {
        await peerConnection!.addTrack(track, localStream);
      }

      peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
          });
        }
      };

      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        firestore.collection('calls/$callId/iceCandidates').add(candidate.toMap());
      };

      _listenForOfferAndAnswer();
      _listenForIceCandidates();
    }
  }

  void _listenForOfferAndAnswer() {
    firestore.collection('calls').doc(callId).snapshots().listen((snapshot) async {
      if (snapshot.data() == null) return;

      final data = snapshot.data()!;
      if (data['offer'] != null && !isCallActive) {
        final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        await peerConnection!.setRemoteDescription(offer);
        final answer = await peerConnection!.createAnswer();
        await peerConnection!.setLocalDescription(answer);

        firestore.collection('calls').doc(callId).update({
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });

        setState(() {
          isCallActive = true;
        });
      }
      else if (data['answer'] != null && isCallActive) {
        final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
        await peerConnection!.setRemoteDescription(answer);
      }
    });
  }

  void _listenForIceCandidates() {
    firestore.collection('calls/$callId/iceCandidates').snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            final candidate = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
            peerConnection!.addCandidate(candidate);
          }
        }
      }
    });
  }

  Future<void> _makeCall() async {
    await _initWebRTC();
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    // Save offer to Firestore
    firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    setState(() {
      isCallActive = true;
    });
  }

  Future<void> _joinCall() async {
    await _initWebRTC();
    if (isCallActive) return;
    _listenForOfferAndAnswer();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    localStream.dispose();
    peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Call')),
      body: Column(
        children: [
          Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
          Expanded(child: RTCVideoView(_remoteRenderer)),
          ElevatedButton(
            onPressed: _joinCall,
            child: Text('Join Call'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _makeCall,
        child: Icon(Icons.call),
      ),
    );
  }
}
