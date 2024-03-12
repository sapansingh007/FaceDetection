import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:ai_face_authentication/locator.dart';
import 'package:ai_face_authentication/pages/db/databse_helper.dart';
import 'package:ai_face_authentication/pages/home.dart';
import 'package:ai_face_authentication/pages/models/user.model.dart';
import 'package:ai_face_authentication/pages/widgets/FacePainter.dart';
import 'package:ai_face_authentication/pages/widgets/app_button.dart';
import 'package:ai_face_authentication/pages/widgets/app_text_field.dart';
import 'package:ai_face_authentication/pages/widgets/auth-action-button.dart';
import 'package:ai_face_authentication/pages/widgets/camera_header.dart';
import 'package:ai_face_authentication/services/camera.service.dart';
import 'package:ai_face_authentication/services/ml_service.dart';
import 'package:ai_face_authentication/services/face_detector_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  SignUpState createState() => SignUpState();
}

class SignUpState extends State<SignUp> {
  String? imagePath;
  Face? faceDetected;
  Size? imageSize;

  bool _detectingFaces = false;
  bool pictureTaken = false;

  bool _initializing = false;

  bool _saving = false;
  bool _bottomSheetVisible = false;

  // service injection
  FaceDetectorService _faceDetectorService = locator<FaceDetectorService>();
  CameraService _cameraService = locator<CameraService>();
  MLService _mlService = locator<MLService>();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  _start() async {
    setState(() => _initializing = true);
    await _cameraService.initialize();
    setState(() => _initializing = false);

    _frameFaces();
  }
  final FlutterTts flutterTts = FlutterTts();

  Future<bool> onShot() async {
    try{
      if (faceDetected == null) {
        setState(() {
          flutterTts.speak('No face detected!');
        });
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('No face detected!'),
            );
          },
        );

        return false;
      } else {
        _saving = true;
        await Future.delayed(Duration(milliseconds: 500));
        // await _cameraService.cameraController?.stopImageStream();
        await Future.delayed(Duration(milliseconds: 200));
        XFile? file = await _cameraService.takePicture();
        imagePath = file?.path;
        setState(() {
          _bottomSheetVisible = true;
          pictureTaken = true;
        });
        setState(() {
          flutterTts.speak('Please register your face');
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Call showModalBottomSheet here to open the bottom sheet
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return signSheet(context);
            },
          ).whenComplete(() {
            // ttsState = TtsState.stopped;
            _reload();
          });
        });
        setState(() {

        });
        return true;
      }
    }catch(e){
      print('e::::  $e');
      return true;
    }
  }

  _frameFaces() {
    imageSize = _cameraService.getImageSize();
    _cameraService.cameraController?.startImageStream((image) async {
      if (_cameraService.cameraController != null) {
        if (_detectingFaces) return;
        _detectingFaces = true;
        try {
          await _faceDetectorService.detectFacesFromImage(image);
          if (_faceDetectorService.faces.isNotEmpty) {
            setState(() {
              faceDetected = _faceDetectorService.faces[0];
              onShot();
            });
            if (_saving) {
              _mlService.setCurrentPrediction(image, faceDetected);
              setState(() {
                _saving = false;
              });
            }
          } else {
            print('face is null');
            setState(() {
              flutterTts.speak('face not found!');
            });
            setState(() {
              faceDetected = null;
            });
          }

          _detectingFaces = false;
        } catch (e) {
          print('Error _faceDetectorService face => $e');
          _detectingFaces = false;
        }
      }
    });
  }

  _onBackPressed() {
    Navigator.of(context).pop();
    setState(() {
      faceDetected = null;
    });
  }

  _reload() {
    setState(() {
      _bottomSheetVisible = false;
      pictureTaken = false;
    });
    this._start();
  }

  @override
  Widget build(BuildContext context) {
    final double mirror = math.pi;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    late Widget body;
    if (_initializing) {
      body = Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_initializing && pictureTaken) {
      body = Container(
        width: width,
        height: height,
        child: Transform(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: Image.file(File(imagePath!)),
            ),
            transform: Matrix4.rotationY(mirror)),
      );
    }

    if (!_initializing && !pictureTaken) {
      body = Transform.scale(
        scale: 1.0,
        child: AspectRatio(
          aspectRatio: MediaQuery.of(context).size.aspectRatio,
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              child: Container(
                width: width,
                height:
                    width * _cameraService.cameraController!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CameraPreview(_cameraService.cameraController!),
                    CustomPaint(
                      painter: FacePainter(
                          face: faceDetected, imageSize: imageSize!),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
        body: Stack(
          children: [
            body,
            CameraHeader(
              "SIGN UP",
              onBackPressed: _onBackPressed,
            )
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        /*floatingActionButton: !_bottomSheetVisible
            ? AuthActionButton(
                onPressed: onShot,
                isLogin: false,
                reload: _reload,
              )
            : Container()*/);
  }


  final TextEditingController _userTextEditingController = TextEditingController(text: '');
  final TextEditingController _passwordTextEditingController = TextEditingController(text: '');

  signSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            child: Column(
              children: [
                 AppTextField(
                  controller: _userTextEditingController,
                  labelText: "Your Name",
                ),
                SizedBox(height: 10),
                AppTextField(
                  controller: _passwordTextEditingController,
                  labelText: "Password",
                  isPassword: true,
                ),
                SizedBox(height: 10),
                Divider(),
                AppButton(
                  text: 'SIGN UP',
                  onPressed: () async {
                    await _signUp(context);
                  },
                  icon: Icon(
                    Icons.person_add,
                    color: Colors.white,
                  ),
                )

              ],
            ),
          ),
        ],
      ),
    );
  }


  Future _signUp(context) async {
    DatabaseHelper _databaseHelper = DatabaseHelper.instance;
    List predictedData = _mlService.predictedData;
    String user = _userTextEditingController.text;
    String password = _passwordTextEditingController.text;
    User userToSave = User(
      user: user,
      password: password,
      modelData: predictedData,
    );
    await _databaseHelper.insert(userToSave);
    this._mlService.setPredictedData([]);
    setState(() {
      flutterTts.speak('register successfully');
    });
    Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => MyHomePage()));
  }

}
