import 'package:flutter/material.dart';
import 'dart:core';
import 'signaling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:share/share.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';

  final String streamID;
  final String screenShare;
  final bool preview;
  final bool muted;
  final bool mirrored;

  CallSample(
      {Key key,
      @required this.streamID,
      @required this.screenShare,
      this.preview,
      this.muted,
      this.mirrored})
      : super(key: key);

  @override
  _CallSampleState createState() => _CallSampleState();
}

class _CallSampleState extends State<CallSample> {
  Signaling _signaling;
  List<dynamic> _peers;
  var _selfId;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  bool muted = false;
  bool preview = true;
  bool mirrored = true;

  // ignore: unused_element
  _CallSampleState({Key key});

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = Signaling(widget.streamID)..connect();

      _signaling.setStreamID(widget.streamID);
      _signaling.setScreenShare(widget.screenShare);

      _signaling.onSignalingStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };

      _signaling.onCallStateChange = (CallState state) {
        switch (state) {
          case CallState.CallStateNew:
            setState(() {
              _inCalling = true;
              _localRenderer.srcObject = _signaling.getLocalStream();
            });
            break;
          case CallState.CallStateBye:
            setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              _inCalling = false;
            });
            break;
          case CallState.CallStateInvite:
          case CallState.CallStateConnected:
          case CallState.CallStateRinging:
        }
      };

      _signaling.onPeersUpdate = ((event) {
        setState(() {
          _selfId = event['self'];
          _peers = event['peers'];
        });
      });

      _signaling.onLocalStream = ((stream) {
        print("LOCAL STREAM");
        _localRenderer.srcObject = stream;
        setState(() {});
      });

      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
      });

      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }

  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling.invite(peerId, 'video', useScreen);
    }
  }

  _hangUp() {
    _inCalling = false;
    _signaling.close();
    Navigator.of(context).pop();
  }

  _switchCamera() {
    _signaling.switchCamera();
  }

  _toggleMic() {
    setState(() {
      muted = !muted;
    });
    _signaling.muteMic();
  }

  _togglePreview() {
    var status = false;

    print(_localRenderer.srcObject);
    if (_localRenderer.srcObject == null) {
      _localRenderer.srcObject = _signaling.getLocalStream();
      status = true;
    } else {
      _localRenderer.srcObject = null;
      status = false;
    }

    setState(() {
      preview = status;
    });
  }

  _toggleMirror() {
    setState(() {
      mirrored = !mirrored;
    });
  }

  _info() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Text(
              "&bitrate and &codec can be used on the viewer side.",
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final vdonLink =
        "https://vdo.ninja/?view=" + widget.streamID + "&password=false";
    final key = new GlobalKey<ScaffoldState>();

    Widget callControls() {
      double buttonWidth = 70;
      List<Widget> buttons = [];

      if (widget.screenShare != 'screen') {
        buttons.add(RawMaterialButton(
          constraints: BoxConstraints(minWidth: buttonWidth),
          visualDensity: VisualDensity.comfortable,
          onPressed: () => {_toggleMic()},
          fillColor: muted ? Colors.red : Colors.green,
          child: muted ? Icon(Icons.mic_off) : Icon(Icons.mic),
          shape: CircleBorder(),
          elevation: 2,
          padding: EdgeInsets.all(15),
        ));

        buttons.add(RawMaterialButton(
          constraints: BoxConstraints(minWidth: buttonWidth),
          visualDensity: VisualDensity.comfortable,
          onPressed: () => {_togglePreview()},
          fillColor: preview ? Colors.green : Colors.red,
          child:
              preview ? Icon(Icons.personal_video) : Icon(Icons.play_disabled),
          shape: CircleBorder(),
          elevation: 2,
          padding: EdgeInsets.all(15),
        ));

        buttons.add(RawMaterialButton(
          constraints: BoxConstraints(minWidth: buttonWidth),
          visualDensity: VisualDensity.comfortable,
          onPressed: () => {_switchCamera()},
          fillColor: Theme.of(context).buttonColor,
          child: Icon(Icons.cameraswitch),
          shape: CircleBorder(),
          elevation: 2,
          padding: EdgeInsets.all(15),
        ));

        buttons.add(RawMaterialButton(
          constraints: BoxConstraints(minWidth: buttonWidth),
          visualDensity: VisualDensity.comfortable,
          onPressed: () => {_toggleMirror()},
          fillColor: Theme.of(context).buttonColor,
          child: Icon(Icons.compare_arrows),
          shape: CircleBorder(),
          elevation: 2,
          padding: EdgeInsets.all(15),
        ));
      }

      buttons.add(RawMaterialButton(
        constraints: BoxConstraints(minWidth: buttonWidth),
        visualDensity: VisualDensity.comfortable,
        onPressed: () => {_hangUp()},
        fillColor: Colors.red,
        child: Icon(Icons.call_end),
        shape: CircleBorder(),
        elevation: 2,
        padding: EdgeInsets.all(15),
      ));

      return Padding(
        padding: const EdgeInsets.all(10.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Container(
            color: Colors.black.withAlpha(100),
            child: SizedBox(
              height: 80,
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: buttons,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: key,
      appBar: AppBar(
        title: Text('Sharing'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () => _info(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(alignment: Alignment.bottomCenter, children: [
                widget.screenShare != 'screen'
                    ? RTCVideoView(
                        _localRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        mirror: mirrored,
                      )
                    : Container(
                        color: Theme.of(context).canvasColor,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                "Open the view link. Permission to share the screen will then be requested.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    color: Colors.black.withAlpha(100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Icon(
                          Icons.video_call,
                          size: 40,
                          color: Colors.white,
                        ),
                        GestureDetector(
                          onTap: () => Share.share(vdonLink),
                          child: Text(
                            "Open in OBS Browser Source: \n" + vdonLink,
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                callControls(),
              ]),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0x000000ff),
    );
  }
}
