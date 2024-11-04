import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String callId = '';
  bool isCallActive = false;
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;
  final TextEditingController _callIdController = TextEditingController();
  String? fcmToken;

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
    _getFCMToken();
  }

  Future<void> _getFCMToken() async {
    fcmToken = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $fcmToken");
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }
  void _initWebRTC() async {
    if (peerConnection == null) {
      peerConnection = await createPeerConnection(_configuration);
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': isAudioOn,
        'video': isVideoOn
            ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
            : false,
      });

      setState(() {
        _localRenderer.srcObject = localStream;
      });

      for (var track in localStream.getTracks()) {
        await peerConnection!.addTrack(track, localStream);
      }
      peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            print("Remote stream received: ${event.streams[0]}");
          });
        }
      };

      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        firestore
            .collection('calls/$callId/iceCandidates')
            .add(candidate.toMap());
      };

      peerConnection!.onIceConnectionState = (state) {
        print("ICE Connection State: $state");
      };

      _listenForOfferAndAnswer();
      _listenForIceCandidates();
    }
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
            print("ICE Candidate added: ${candidate.candidate}");
          }
        }
      }
    });
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

  Future<void> _makeCall() async {
    callId = _callIdController.text.trim();
    if (callId.isEmpty) {
      _showSnackbar(context, 'Please enter call ID');
      return;
    }
    if (callId.isEmpty) return;
    _initWebRTC();
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
    await _sendIncomingCallNotification();
    setState(() {
      isCallActive = true;
    });
  }

  Future<void> _sendIncomingCallNotification() async {
    var message = {
      "to": "/topics/incoming_calls",
      "notification": {
        "title": "Incoming Call",
        "body": "You have an incoming call",
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
      },
      "data": {
        "callId": callId,
      }
    };
    await FirebaseFirestore.instance.collection('notifications').add(message);
  }

  void _showSnackbar(BuildContext context, String text) {
    final snackBar = SnackBar(
      content: Text(text),
      backgroundColor: Colors.red,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _joinCall() async {
    callId = _callIdController.text.trim();
    if (callId.isEmpty) {
      _showSnackbar(context, 'Please enter call ID');
      return;
    }
    _initWebRTC();
    if (isCallActive) return;
    _listenForOfferAndAnswer();
    setState(() {});
  }

  void _toggleMic() {
    isAudioOn = !isAudioOn;
    localStream.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  void _toggleCamera() {
    isVideoOn = !isVideoOn;
    localStream.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  void _switchCamera() {
    isFrontCameraSelected = !isFrontCameraSelected;
    localStream.getVideoTracks().forEach((track) {
      track.switchCamera();
    });
    setState(() {});
  }

  void _leaveCall() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    localStream.dispose();
    peerConnection?.close();
    Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text(
          'Video Call',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.blue,
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
                onPressed: _joinCall,
                child: const Text('Join Call'),
              ),
              ElevatedButton(
                onPressed: _makeCall,
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
                  onPressed: _toggleMic,
                ),
                IconButton(
                  icon: const Icon(Icons.call_end),
                  iconSize: 30,
                  onPressed: _leaveCall,
                ),
                IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: _switchCamera,
                ),
                IconButton(
                  icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
                  onPressed: _toggleCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
