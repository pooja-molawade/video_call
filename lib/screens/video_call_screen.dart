import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  const VideoCallScreen({Key? key, required this.callId}) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late MediaStream localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? peerConnection;
  final firestore = FirebaseFirestore.instance;
  bool isCallActive = false;
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;
  String? fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _getFCMToken();
    _initWebRTC();
    print(widget.callId);
  }

  Future<void> _getFCMToken() async {
    fcmToken = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $fcmToken");
  }

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
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
      //_localRenderer.srcObject = localStream;
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
          });
        }
      };
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        firestore
            .collection('calls/${widget.callId}/iceCandidates')
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
        .collection('calls/${widget.callId}/iceCandidates')
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

  void _listenForOfferAndAnswer() {
    firestore.collection('calls').doc(widget.callId).snapshots().listen((snapshot) async {
      if (snapshot.data() == null) return;

      final data = snapshot.data()!;
      if (data['offer'] != null && !isCallActive) {
        final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        await peerConnection!.setRemoteDescription(offer);
        final answer = await peerConnection!.createAnswer();
        await peerConnection!.setLocalDescription(answer);

        firestore.collection('calls').doc(widget.callId).update({
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });
        setState(() {
          isCallActive = true;
        });
      } else if (data['answer'] != null && isCallActive) {
        final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
        await peerConnection!.setRemoteDescription(answer);
      }
    });
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
        title: const Text('Video Call',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
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
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                onPressed: _toggleMic,
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
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
        ],
      ),
    );
  }
}
