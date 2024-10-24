import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Future<void> initializeWebRTC() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    peerConnection = await createPeerConnection(config);
    localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });

    peerConnection!.addStream(localStream!);

    peerConnection!.onAddStream = (stream) {
      remoteStream = stream;
    };
    peerConnection!.onIceCandidate = (candidate) {
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    RTCSessionDescription description = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(description);
    return description;
  }

  Future<void> createAnswer(String sdp, String type) async {
    RTCSessionDescription remoteDescription = RTCSessionDescription(sdp, type);
    await peerConnection!.setRemoteDescription(remoteDescription);
    RTCSessionDescription answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);
  }

  Future<void> addIceCandidate(String candidate, String sdpMid, int sdpMLineIndex) async {
    RTCIceCandidate iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    await peerConnection!.addCandidate(iceCandidate);
  }
}
