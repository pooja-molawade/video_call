import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late MediaStream localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? peerConnection;
  final firestore = FirebaseFirestore.instance;

  //final String callId = 'test-cal';
  // late String callId;
  bool isCallActive = false;
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  final Uuid _uuid = Uuid();
  late String callId;
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  void initState() {
    super.initState();
    callId = _uuid.v4();
    //callId= DateTime.now().millisecondsSinceEpoch.toString();
    _initializeRenderers();
    _listenForIncomingCall();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  void _listenForIncomingCall() {
    final recipientUserId = '954538';
    print("Calling iid");

    firestore.collection('calls').doc(recipientUserId).snapshots().listen((snapshot) async {
      final data = snapshot.data();
      // if (data != null && data['activeCallId'] != null) {
      //   final callId = data['activeCallId'];
      //   print("Calling iid");
      //   print(callId);
      //   await _joinCall(callId);
      // }
      await _joinCall(recipientUserId);

    });
  }

  Future<void> _initWebRTC() async {
    if (peerConnection == null) {
      peerConnection = await createPeerConnection(_configuration);
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': isAudioOn,
        'video': isVideoOn
            ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
            : false,
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
        firestore
            .collection('calls/$callId/iceCandidates')
            .add(candidate.toMap());
      };

      _listenForOfferAndAnswer();
      _listenForIceCandidates();
    }
  }

  void _listenForOfferAndAnswer() {
    firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.data() == null) return;

      final data = snapshot.data()!;
      if (data['offer'] != null && !isCallActive) {
        final offer =
            RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        await peerConnection!.setRemoteDescription(offer);
        final answer = await peerConnection!.createAnswer();
        await peerConnection!.setLocalDescription(answer);

        firestore.collection('calls').doc(callId).update({
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });

        setState(() {
          isCallActive = true;
        });
      } else if (data['answer'] != null && isCallActive) {
        final answer = RTCSessionDescription(
            data['answer']['sdp'], data['answer']['type']);
        await peerConnection!.setRemoteDescription(answer);
      }
    });
  }

  void _listenForIceCandidates() {
    firestore
        .collection('calls/$callId/iceCandidates')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            final candidate = RTCIceCandidate(
                data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
            peerConnection!.addCandidate(candidate);
          }
        }
      }
    });
  }

  Future<void> _makeCal1l() async {
    await _initWebRTC();
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    setState(() {
      isCallActive = true;
    });
  }

  Future<void> _makeCall(String recipientUserId) async {
    callId = _uuid.v4(); // Generate a unique call ID
    await _initWebRTC();
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    firestore.collection('calls').doc(recipientUserId).set({
      'activeCallId': callId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'callerUserId': "9552001337",
      'timestamp': FieldValue.serverTimestamp(), // Optional for tracking
    });

    setState(() {
      isCallActive = true;
    });
  }
  Future<void> _joinCall(String callId) async {
    await _initWebRTC();
    final callDoc = await firestore.collection('calls').doc('954538').get();
    if (!callDoc.exists) {
      print('Call does not exist');
      return;
    }

    final callData = callDoc.data();
    if (callData == null || callData['offer'] == null) {
      print('No offer found in call data');
      return;
    }

    firestore
        .collection('calls')
        .doc('954538')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.data() == null) return;

      final data = snapshot.data()!;
      if (data['offer'] != null && !isCallActive) {
        final offer =
        RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        await peerConnection!.setRemoteDescription(offer);
        final answer = await peerConnection!.createAnswer();
        await peerConnection!.setLocalDescription(answer);

        firestore.collection('calls').doc(callId).update({
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });

        setState(() {
          isCallActive = true;
        });
      } else if (data['answer'] != null && isCallActive) {
        final answer = RTCSessionDescription(
            data['answer']['sdp'], data['answer']['type']);
        await peerConnection!.setRemoteDescription(answer);
      }
    });
  }

  Future<void> _joinCall1() async {
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

  _toggleMic() {
    isAudioOn = !isAudioOn;
    localStream.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    isVideoOn = !isVideoOn;
    localStream.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  _switchCamera() {
    isFrontCameraSelected = !isFrontCameraSelected;
    localStream.getVideoTracks().forEach((track) {
      track.switchCamera();
    });
    setState(() {});
  }

  _leaveCall() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Video Call',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: _joinCall1,
                child: const Text('Join Call'),
              ),
              ElevatedButton(
                onPressed: () {
                  _makeCall("954538");
                },
                child: const Text('Make Call'),
              ),
            ],
          ),
          Expanded(
            child: Stack(children: [
              RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: SizedBox(
                  height: 150,
                  width: 120,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: isFrontCameraSelected,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              )
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                  onPressed: () {
                    _toggleMic();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call_end),
                  iconSize: 30,
                  onPressed: () {
                    _leaveCall();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: () {
                    _switchCamera();
                  },
                ),
                IconButton(
                  icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
                  onPressed: () {
                    _toggleCamera();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
