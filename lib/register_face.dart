import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:rolcal/camera_view.dart';

import 'image_converter.dart';
import 'ml_service.dart';

class RegisterFace extends StatefulWidget {
  const RegisterFace({super.key, this.name});

  final String? name;

  @override
  State<RegisterFace> createState() => _RegisterFaceState();
}

class _RegisterFaceState extends State<RegisterFace> {
  int _cameraIndex = -1;
  CameraController? cameraController;
  List<double> userRegisteredPrediction = [];
  List<Face>? faces = [];
  MLService mlService = MLService();
  XFile? xfile;

  List<CameraDescription> cameras = [];
  CameraLensDirection cameraLensDirection = CameraLensDirection.front;
  bool changingCameraLens = false;
  bool isFlashOn = false;
  CameraImage? cameraImage;

  FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
    ),
  );

  bool canProcess = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    mlService.initialize();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    canProcess = false;
    faceDetector.close();
    mlService.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (cameras.isEmpty) {
      cameras = await availableCameras();
    }
    for (var i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == cameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      await initializeController();
    }
    cameraController?.startImageStream(_processCameraImage).then((value) {});
    setState(() {});
  }

  Future<void> initializeController() async {
    final camera = cameras[_cameraIndex];
    cameraController = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await cameraController?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> switchCamera() async {
    _cameraIndex = (_cameraIndex + 1) % cameras.length;
    isFlashOn = false;
    await cameraController!.dispose();
    await initializeController();
  }

  void toggleFlash() {
    if (_cameraIndex % 2 == 0) {
      isFlashOn = !isFlashOn;
      cameraController!
          .setFlashMode(isFlashOn ? FlashMode.torch : FlashMode.off);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cameras == []) {
      return const Center(
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: CircularProgressIndicator(
            color: Colors.lightBlue,
          ),
        ),
      );
    }
    if (cameraController == null) {
      return const Center(
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: CircularProgressIndicator(
            color: Colors.lightBlue,
          ),
        ),
      );
    }
    if (cameraController?.value.isInitialized == false) {
      return const Center(
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: CircularProgressIndicator(
            color: Colors.lightBlue,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  children: <Widget>[
                    Center(
                        child: Container(
                      width: MediaQuery.of(context).size.height *
                          cameraController!.value.aspectRatio,
                      height: MediaQuery.of(context).size.height,
                      child: CameraPreview(cameraController!),
                    )),
                    CustomPaint(
                      painter: OvalPainter(),
                      child: Container(
                        width: MediaQuery.of(context).size.height *
                            cameraController!.value.aspectRatio,
                        height: MediaQuery.of(context).size.height,
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        height: 70.0,
                        width: 70.0,
                        decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(60.0)),
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                toggleFlash();
                              });
                            },
                            icon: Icon(
                              !isFlashOn
                                  ? Icons.flash_off_rounded
                                  : Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 40.0,
                            )),
                      ),
                      Container(
                        height: 70.0,
                        width: 70.0,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(60.0)),
                        child: IconButton(
                            onPressed: () async {
                              if (faces!.isNotEmpty) {
                                imglib.Image? capturedImage =
                                    convertToImage(cameraImage!);
                                await cameraController!.pausePreview();
                                await cameraController!.stopImageStream();
                                mlService.setCurrentPrediction(
                                  capturedImage!,
                                  faces![0].boundingBox,
                                );
                                userRegisteredPrediction =
                                    mlService.predictedData;
                                final rotatedImageBytes =
                                    imglib.encodePng(capturedImage);
                                if (context.mounted &&
                                    userRegisteredPrediction.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    DialogRoute(
                                      context: context,
                                      builder: (context) => PopScope(
                                        canPop: false,
                                        onPopInvoked: (bool didPop) {
                                          if (didPop) {}
                                        },
                                        child: Dialog(
                                          elevation: 0.0,
                                          surfaceTintColor: Colors.transparent,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 30.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 100.0,
                                                  color: Colors.green,
                                                ),
                                                const Text(
                                                  'Successful',
                                                  style:
                                                      TextStyle(fontSize: 32.0),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pushReplacement(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              CameraView(
                                                                  name: widget
                                                                      .name,
                                                                  userPrediction:
                                                                      userRegisteredPrediction),
                                                        ),
                                                      );
                                                    },
                                                    style: ButtonStyle(
                                                      backgroundColor:
                                                          const MaterialStatePropertyAll(
                                                              Colors.green),
                                                      shape: MaterialStateProperty
                                                          .resolveWith<
                                                                  OutlinedBorder>(
                                                              (_) {
                                                        return RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10));
                                                      }),
                                                    ),
                                                    child: const Text(
                                                      'Continue',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 24.0),
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.camera_rear,
                              color: Colors.white,
                              size: 40.0,
                            )),
                      ),
                      Container(
                        height: 70.0,
                        width: 70.0,
                        decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(60.0)),
                        child: IconButton(
                            onPressed: () async {
                              await switchCamera();

                              setState(() {});
                            },
                            icon: Icon(
                              Platform.isIOS
                                  ? Icons.flip_camera_ios_outlined
                                  : Icons.flip_camera_android_outlined,
                              color: Colors.white,
                              size: 40.0,
                            )),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future _stopLiveFeed() async {
    await cameraController?.stopImageStream();
    await cameraController?.dispose();
    cameraController = null;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (cameraController == null) return null;

    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    cameraImage = image;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    if (!canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    faces = await faceDetector.processImage(inputImage);
    // if (faces.isNotEmpty && cameraImage != null) {
    //   await recognizeFace(cameraImage!, faces[0]);
    // }
    _isBusy = false;
  }

// Future<void> processImage(InputImage inputImage) async {
//   if (!canProcess) return;
//   if (_isBusy) return;
//   _isBusy = true;
//
//   faces = await faceDetector.processImage(inputImage);
//   // if (faces.isNotEmpty && cameraImage != null) {
//   //   await recognizeFace(cameraImage!, faces[0]);
//   // }
//   _isBusy = false;
// }
}

class OvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Method to convert degree to radians
    // num degToRad(num deg) => deg * (3.14 / 180.0);

    Path path = Path();
    //Vertical line
    path.moveTo(size.width / 2, size.height / 8);
    path.lineTo(size.width / 2, (7 * size.height / 8) - 70);

    //Horizontal Line
    path.moveTo(100, (size.height / 2) - 50);
    path.lineTo(size.width - 100, (size.height / 2) - 50);

    //Right one
    path.moveTo(size.width - 50, size.height / 4);
    path.quadraticBezierTo(
        size.width - 50, size.height / 8, size.width - 100, size.height / 8);

    //Left one
    path.moveTo(50, size.height / 4);
    path.quadraticBezierTo(50, size.height / 8, 100, size.height / 8);

    // Bottom Right
    path.moveTo(size.width - 50, (3 * size.height / 4) - 70);
    path.quadraticBezierTo(size.width - 50, (7 * size.height / 8) - 70,
        size.width - 100, (7 * size.height / 8) - 70);

    // Bottom Left
    path.moveTo(50, (3 * size.height / 4) - 70);
    path.quadraticBezierTo(
        50, (7 * size.height / 8) - 70, 100, (7 * size.height / 8) - 70);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
//
// class _ModelPainter extends StatelessWidget {
//   const _ModelPainter({
//     required this.customPainter,
//     Key? key,
//   }) : super(key: key);
//
//   final CustomPainter customPainter;
//
//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       painter: customPainter,
//     );
//   }
// }

// SizedBox(
// width: MediaQuery.of(context).size.width,
// child: Align(
// alignment: Alignment.bottomCenter,
// child: CircleAvatar(
// backgroundColor: Colors.grey,
// radius: 36,
// child: CircleAvatar(
// backgroundColor: Colors.white,
// radius: 34,
// child: ElevatedButton(
// onPressed: () {},
// child: const Icon(
// Icons.camera_alt,
// color: Colors.transparent,
// size: 34,
// ),
// style: ButtonStyle(
// elevation: MaterialStateProperty.all(0.0),
// shape:
// MaterialStateProperty.all(const CircleBorder()),
// padding: MaterialStateProperty.all(
// const EdgeInsets.all(20)),
// backgroundColor: MaterialStateProperty.all(
// Colors.white), // <-- Button color
// overlayColor:
// MaterialStateProperty.resolveWith<Color?>(
// (states) {
// if (states.contains(MaterialState.pressed)) {
// return Colors.grey.withOpacity(0.2);
// }
// return null; // <-- Splash color
// }),
// ),
// ),
// ),
// ),
// ),
// ),
