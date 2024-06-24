import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';

class MLService {
  Interpreter? _interpreter;
  double threshold = 0.9;
  List<double> _predictedData = [];
  List<double> get predictedData => _predictedData;

  MLService();
  Future initialize() async {
    late Delegate delegate;
    try {
      if (Platform.isAndroid) {
        delegate = GpuDelegateV2(
          options: GpuDelegateOptionsV2(
            isPrecisionLossAllowed: false,
          ),
        );
      } else if (Platform.isIOS) {
        delegate = GpuDelegate(
          options: GpuDelegateOptions(
            allowPrecisionLoss: true,
          ),
        );
      }
      var interpreterOptions = InterpreterOptions()..addDelegate(delegate);

      _interpreter = await Interpreter.fromAsset(
          'assets/models/mobilefacenet.tflite',
          options: interpreterOptions);
    } catch (e) {
      Exception(e);
    }
  }

  void setCurrentPrediction(imglib.Image image, Rect? face) {
    if (face == null) {
      return;
    }
    if (_interpreter == null) throw Exception('Interpreter is null');
    if (face == null) throw Exception('Face is null');
    List input = _preProcess(image, face);

    input = input.reshape([1, 112, 112, 3]);

    List output = List.generate(1, (index) => List.filled(192, 0));

    _interpreter?.run(input, output);
    output = output.reshape([192]);

    _predictedData = List.from(output);
  }

  // Future<Student?> predict() async {
  //   return _searchResult(_predictedData);
  // }

  List _preProcess(imglib.Image image, Rect faceDetected) {
    imglib.Image croppedImage = _cropFace(image, faceDetected);
    imglib.Image img = imglib.copyResizeCropSquare(croppedImage, 112);
    Float32List imageAsList = imageToByteListFloat32(img);
    return imageAsList;
  }

  Float32List imageToByteListFloat32(imglib.Image image) {
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 112; i++) {
      for (var j = 0; j < 112; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (imglib.getRed(pixel) - 128) / 128;
        buffer[pixelIndex++] = (imglib.getGreen(pixel) - 128) / 128;
        buffer[pixelIndex++] = (imglib.getBlue(pixel) - 128) / 128;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  imglib.Image _cropFace(imglib.Image image, Rect faceDetected) {
    // imglib.Image convertedImage = _convertCameraImage(image);
    double x = faceDetected.left - 10.0;
    double y = faceDetected.top - 10.0;
    double w = faceDetected.width + 10.0;
    double h = faceDetected.height + 10.0;
    return imglib.copyCrop(image, x.round(), y.round(), w.round(), h.round());
  }

  // Future<Student?> _searchResult(List predictedData) async {
  //   double minDist = 999;
  //   double currDist = 0.0;
  //   Student? predictedResult;
  //   print(students.length);
  //   for (Student u in students) {
  //     print(predictedData);
  //     currDist = _euclideanDistance(u.modelData, predictedData);
  //     print("curre dist is : $currDist");
  //     if (currDist <= threshold && currDist < minDist) {
  //       minDist = currDist;
  //       predictedResult = u;
  //     }
  //   }
  //   return predictedResult;
  // }

  bool compareFaces(
    List<double> initialData,
  ) {
    double currDist = 0.0;
    currDist = euclideanDistance(initialData, predictedData);
    print('SEEEEEEEEEEEEEEEEEEE CURRENT DISTANCE' + currDist.toString());

    if (currDist <= threshold) {
      return true;
    } else {
      return false;
    }
  }

  double euclideanDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding2 == null || embedding1 == null) {
      throw Exception("Null argument");
    }

    double sum = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      sum += pow(embedding1[i] - embedding2[i], 2);
    }
    return sqrt(sum);
  }

  void setPredictedData(value) {
    _predictedData = value;
  }

  dispose() {}
}
