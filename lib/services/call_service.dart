import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createOffer(String callId, RTCSessionDescription offer) async {
    await _firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToOffer(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  Future<void> createAnswer(String callId, RTCSessionDescription answer) async {
    await _firestore.collection('calls').doc(callId).update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  // Listen for ICE candidates from the remote peer
  Stream<QuerySnapshot<Map<String, dynamic>>> listenToIceCandidates(String callId) {
    return _firestore.collection('calls').doc(callId).collection('candidates').snapshots();
  }

  // Add ICE candidates to Firestore
  Future<void> addIceCandidate(String callId, RTCIceCandidate candidate) async {
    await _firestore.collection('calls').doc(callId).collection('candidates').add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }
}
