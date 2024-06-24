import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:rolcal/ml_service.dart';

import 'face_detector_painter.dart';
import 'image_converter.dart';

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    this.name,
    required this.userPrediction,
  }) : super(key: key);

  final String? name;
  final List<double> userPrediction;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;
  bool _isFlashOn = false;
  bool faceMatched = false;
  CameraImage? cameraImage;
  CameraLensDirection initialCameraLensDirection = CameraLensDirection.front;
  FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  MLService mlService = MLService();

  @override
  void initState() {
    super.initState();
    _initialize();
    mlService.initialize();
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _stopLiveFeed();
    _canProcess = false;
    faceDetector.close();
    mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _liveFeedBody(),
      backgroundColor: Colors.black87,
    );
  }

  double getScale() {
    final size = MediaQuery.of(context).size;
    double scale;
    if (_controller!.value.isInitialized) {
      scale = size.aspectRatio * _controller!.value.aspectRatio;
      if (scale < 1) scale = 1 / scale;
    } else {
      scale = size.aspectRatio;
    }
    return scale;
  }

  void _toggleFlash() {
    if (_cameraIndex == 0) {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      });
    }
  }

  Widget _liveFeedBody() {
    if (_cameras == []) {
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
    if (_controller == null) {
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
    if (_controller?.value.isInitialized == false) {
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
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Transform.scale(
              scale: getScale(),
              child: CameraPreview(
                _controller!,
                child: _customPaint,
              ),
            ),
          ),
          _settings(),
          Positioned(
            bottom: 50.0,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _flashControl(),
                  _switchLiveCameraToggle(),
                ],
              ),
            ),
          ),
          _more()
          // _zoomControl(),
          // _exposureControl(),
        ],
      ),
    );
  }

  Widget _settings() => Positioned(
        top: 40,
        left: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: () => null,
            backgroundColor: Colors.white.withOpacity(0.4),
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.black87,
              size: 30.0,
            ),
          ),
        ),
      );

  Widget _more() => Positioned(
        top: 40,
        right: 8,
        child: SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            heroTag: Object(),
            onPressed: () => null,
            backgroundColor: Colors.white.withOpacity(0.4),
            child: SvgPicture.asset('assets/list.svg',
                height: 30.0, semanticsLabel: 'list'),
          ),
        ),
      );

  Widget _switchLiveCameraToggle() => SizedBox(
        height: 70.0,
        width: 70.0,
        child: FloatingActionButton(
          heroTag: Object(),
          onPressed: _switchLiveCamera,
          backgroundColor: Colors.white.withOpacity(0.25),
          child: Icon(
            Platform.isIOS
                ? Icons.flip_camera_ios_outlined
                : Icons.flip_camera_android_outlined,
            size: 50,
            color: Colors.black87,
          ),
        ),
      );

  Widget _flashControl() => SizedBox(
        height: 70.0,
        width: 70.0,
        child: FloatingActionButton(
          heroTag: Object(),
          onPressed: _toggleFlash,
          backgroundColor: Colors.white.withOpacity(0.25),
          child: Icon(
            !_isFlashOn ? Icons.flash_off_rounded : Icons.flash_on_rounded,
            size: 50,
            color: Colors.black87,
          ),
        ),
      );

  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.startImageStream(_processCameraImage).then((value) {});
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _isFlashOn = false;
    await _stopLiveFeed();
    await _startLiveFeed();
  }

  void _processCameraImage(CameraImage image) {
    cameraImage = image;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    processImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
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

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    List<Face> faces = await faceDetector.processImage(inputImage);
    if (faces.isNotEmpty && cameraImage != null) {
      await recognizeFace(cameraImage!, faces[0]);
    }
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        name: widget.name,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        initialCameraLensDirection,
        faceMatched: faceMatched,
      );
      _customPaint = CustomPaint(painter: painter);
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> recognizeFace(CameraImage cameraImage, Face face) async {
    imglib.Image? capturedImage = convertToImage(cameraImage);
    mlService.setCurrentPrediction(
      capturedImage,
      face.boundingBox,
    );
    faceMatched = mlService.compareFaces(widget.userPrediction);
  }
}
