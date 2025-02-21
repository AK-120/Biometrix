import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool isDetecting = false;
  FaceDetector? _faceDetector;
  bool isLoading = true;
  Timer? _timer;
  int _remainingTime = 10; // 10 seconds timer
  bool _isFaceDetected = false;
  bool showBlackScreen = false; // Controls the black screen display

  final String _serverUrl =
      'http://192.168.199.36:7860/generate-embedding'; // Replace with your server URL
  List<double>? _embeddings;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadFaceDetector();
    _startTimer();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);

    _cameraController = CameraController(frontCamera, ResolutionPreset.high);
    await _cameraController!.initialize();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    // Start face detection automatically
    _startFaceDetection();
  }

  Future<void> _loadFaceDetector() async {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _timer?.cancel();
        if (!_isFaceDetected) {
          Navigator.of(context)
              .pop(null); // Return with no result if no face detected
        }
      }
    });
  }

  void _startFaceDetection() {
    // Periodically check for faces every 1 second
    Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!isDetecting) {
        await _captureAndDetect();
      }
    });
  }

  Future<void> _captureAndDetect() async {
    if (_isFaceDetected) return; // Skip detection if a face is already detected

    isDetecting = true;

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        setState(() {
          _isFaceDetected = true;
          showBlackScreen = true; // Display black screen
        });

        // Crop the face image
        File faceImage = await _cropFace(image.path, faces.first.boundingBox);

        // Send to Hugging Face server for embeddings
        List<double> embeddings = await _fetchEmbeddingsFromServer(faceImage);

        // Clean up resources before navigating back
        _disposeResources();

        // Return data to the previous screen
        Navigator.of(context).pop({
          'image': faceImage,
          'embeddings': embeddings,
        });
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      if (!_isFaceDetected) isDetecting = false; // Continue detecting
    }
  }

  Future<File> _cropFace(String imagePath, Rect boundingBox) async {
    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) return File(imagePath);

    img.Image croppedFace = img.copyCrop(
      image,
      boundingBox.left.toInt(),
      boundingBox.top.toInt(),
      boundingBox.width.toInt(),
      boundingBox.height.toInt(),
    );

    final directory = Directory.systemTemp;
    final croppedFilePath =
        '${directory.path}/cropped_face_${DateTime.now().millisecondsSinceEpoch}.jpg';

    File croppedFile = File(croppedFilePath);
    await croppedFile.writeAsBytes(img.encodeJpg(croppedFace));

    return croppedFile;
  }

  Future<List<double>> _fetchEmbeddingsFromServer(File faceImage) async {
    try {
      // Convert the image to base64
      List<int> imageBytes = await faceImage.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Prepare the JSON body
      final Map<String, dynamic> payload = {
        "image": base64Image, // Pass the image in base64 format
      };

      // Send the POST request with JSON body
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {
          "Content-Type": "application/json", // Ensure correct content type
        },
        body: jsonEncode(payload), // Convert the payload to JSON
      );

      // Check the response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<double>.from(data['embedding']);
      } else {
        throw Exception(
            'Failed to fetch embeddings: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching embeddings');
    }
  }

  /// Helper function to clean up resources
  void _disposeResources() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _timer?.cancel();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Face Detection')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (!showBlackScreen) CameraPreview(_cameraController!),
                if (showBlackScreen)
                  Container(
                    color: const Color.fromARGB(0, 148, 139, 139),
                    child: Center(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )),
                  ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_remainingTime > 0 && !_isFaceDetected)
                        Text(
                          'Detecting... $_remainingTime seconds left',
                          style: TextStyle(fontSize: 18),
                        ),
                      if (_isFaceDetected)
                        Icon(Icons.check_circle, color: Colors.green, size: 50),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
