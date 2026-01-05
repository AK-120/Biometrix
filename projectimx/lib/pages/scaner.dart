import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  bool isDetecting = false;
  FaceDetector? _faceDetector;
  bool isLoading = true;
  Timer? _timer;
  int _remainingTime = 10; // 10 seconds timer
  bool _isFaceDetected = false;
  bool showBlackScreen = false; // Controls the black screen display
  String? _matchedUser; // Holds the matched user's information

  final String _serverUrl =
      'http://192.168.175.35/generate-embedding'; // Replace with your server URL
  List<double>? _embeddings;
  String? _capturedImage;

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
          setState(() {
            _matchedUser = "No match found"; // Show message
          });
          Future.delayed(Duration(seconds: 1), () {
            Navigator.pop(context); // Go back
          });
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

  bool _isPageActive = true; // Track if the page is still active

  Future<void> _captureAndDetect() async {
    if (!_isPageActive ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        isDetecting) {
      print("CameraController is disposed, page exited, or already detecting");
      return;
    }

    isDetecting = true;

    try {
      final image = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _capturedImage = image.path;
        });
      }

      final inputImage = InputImage.fromFilePath(image.path);

      if (_faceDetector == null) {
        print("Face detector is not initialized.");
        return;
      }

      List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        setState(() {
          _isFaceDetected = true;
          _matchedUser = "Detecting...";
        });

        // Crop the face image
        File faceImage = await _cropFace(image.path, faces.first.boundingBox);

        // Send to Hugging Face API for embeddings
        List<double> embeddings = await _fetchEmbeddingsFromServer(faceImage);

        // Match the embeddings with database
        String matchedUser = await _matchEmbeddingsWithDatabase(embeddings);

        setState(() {
          _matchedUser =
              matchedUser.isNotEmpty ? matchedUser : "No match found";
        });
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      if (!_isFaceDetected) {
        isDetecting = false;
      }
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
    final croppedFilePath = '${directory.path}/cropped_face.jpg';
    File croppedFile = File(croppedFilePath)
      ..writeAsBytesSync(img.encodeJpg(croppedFace));

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

  Future<String> _matchEmbeddingsWithDatabase(List<double> embeddings) async {
    final usersCollection = FirebaseFirestore.instance.collection('users');
    final snapshot = await usersCollection.get();

    String matchedUser = "No match found"; // Default value when no match found
    double bestMatchScore = double.infinity; // Start with a very high score

    for (var doc in snapshot.docs) {
      final userEmbedding = List<double>.from(doc['embedding']);
      final userName = doc['name'];
      final userDepartment = doc['department'];
      final userType = doc['user_type'];
      final userId = doc['id'];
      final Semester =
          doc['semester']; // Assuming 'image' is the field for the user

      double similarityScore =
          _calculateCosineSimilarity(embeddings, userEmbedding);

      // Setting a threshold for a "good enough" match
      if (similarityScore < bestMatchScore && similarityScore > 0.7) {
        bestMatchScore = similarityScore;
        matchedUser = "$userName, Department: $userDepartment, $userType";
        await _recordAttendance(
            userId, userName, userDepartment, userType, Semester);
      }
    }
    setState(() {
      _matchedUser = matchedUser.isNotEmpty ? "$matchedUser" : "No match found";
    });

    Future.delayed(Duration(milliseconds: 800), () {
      Navigator.pop(context); // Navigate back after 2 seconds
    });

    return matchedUser;
  }

  double _calculateCosineSimilarity(
      List<double> embeddings1, List<double> embeddings2) {
    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < embeddings1.length; i++) {
      dotProduct += embeddings1[i] * embeddings2[i];
      magnitude1 += embeddings1[i] * embeddings1[i];
      magnitude2 += embeddings2[i] * embeddings2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0 || magnitude2 == 0) {
      return 0.0;
    }

    return dotProduct / (magnitude1 * magnitude2);
  }

  Future<List<Map<String, String>>> _fetchTimetable(
      String semester, String branch) async {
    final now = DateTime.now();
    final weekday = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday"
    ]; //[now.weekday - 1];

    final timetableCollection =
        FirebaseFirestore.instance.collection('timetable');
    final querySnapshot = await timetableCollection
        .where('day', isEqualTo: weekday)
        .where('semester', isEqualTo: semester)
        .where('branch', isEqualTo: branch)
        .get();

    List<Map<String, String>> timetable = [];

    for (var doc in querySnapshot.docs) {
      var data = doc.data();

      if (data.containsKey('periods') && data['periods'] is List) {
        List<dynamic> periods = data['periods']; // Ensure it's a list

        for (var period in periods) {
          if (period is Map<String, dynamic>) {
            // Ensure it's a map
            timetable.add({
              'subject': period['subject']?.toString() ?? 'Unknown Subject',
              'time': period['time']?.toString() ?? 'Unknown Time',
            });
          }
        }
      }
    }

    return timetable;
  }

  bool _isCurrentTimeInRange(String timeRange, DateTime now) {
    try {
      List<String> parts = timeRange.split('-');
      if (parts.length != 2) return false;

      DateTime startTime = _parseTime(parts[0], now);
      DateTime endTime = _parseTime(parts[1], now);

      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      print("Error parsing time: $e");
      return false;
    }
  }

  DateTime _parseTime(String timeStr, DateTime now) {
    try {
      // Trim and convert to lowercase for consistency
      timeStr = timeStr.trim().toLowerCase();

      // Check if it's in 12-hour format (contains "am" or "pm")
      bool isPM = timeStr.contains("PM");
      bool isAM = timeStr.contains("AM");

      // Remove AM/PM from the string
      timeStr = timeStr.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();

      List<String> timeParts = timeStr.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      // Convert 12-hour format to 24-hour format
      if (isPM && hour != 12) {
        hour += 12; // Convert PM hours (except 12 PM)
      } else if (isAM && hour == 12) {
        hour = 0; // Convert 12 AM to 00 hours
      }

      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      print("Error parsing time: $e");
      return now; // Return current time in case of an error
    }
  }

  Future<void> _recordAttendance(String userId, String userName,
      String userDepartment, String userType, String semester) async {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month}-${now.day}";
    final hour = now.hour % 12 == 0
        ? 12
        : now.hour % 12; // Convert 24-hour to 12-hour format

    final formattedTime = "${hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}";
    print("time:$formattedTime");
    // Fetch timetable
    List<Map<String, String>> timetable =
        await _fetchTimetable(semester, userDepartment);

    // Find the subject corresponding to the current time
    String currentSubject = "Unknown Subject";
    for (var period in timetable) {
      String timeRange = period['time'] ?? ''; // Example: "9:00-10:00"
      if (_isCurrentTimeInRange(timeRange, now)) {
        currentSubject = period['subject']!;
        break;
      }
    }

    final attendanceCollection =
        FirebaseFirestore.instance.collection('attendance');

    // Check if an attendance record already exists for this user on the current date
    final existingRecord = await attendanceCollection
        .where('id', isEqualTo: userId)
        .where('date', isEqualTo: formattedDate)
        .get();

    if (existingRecord.docs.isEmpty) {
      await attendanceCollection.add({
        'id': userId,
        'name': userName,
        'department': userDepartment,
        'user_type': userType,
        'semester': semester,
        'date': formattedDate,
        'time_in': formattedTime,
        'time_out': null,
        'timestamp': FieldValue.serverTimestamp(),
        'periods': null,
        'subject': currentSubject, // Store the matched subject
      });
    } else {
      final docId = existingRecord.docs.first.id;
      final existingData = existingRecord.docs.first.data();

      if (existingData['time_out'] == null) {
        await attendanceCollection.doc(docId).update({
          'time_out': formattedTime,
        });
      }
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
    _isPageActive = false;
    _disposeResources();
    super.dispose();
  }

  List<String> _timetableSubjects = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Face Detection',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera Preview
                Positioned.fill(
                  child: showBlackScreen
                      ? Container(color: Colors.black) // Black screen overlay
                      : CameraPreview(_cameraController!),
                ),

                // Timer Display
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Time Remaining: $_remainingTime s",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Animated Overlay for Loading & Detection Result
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity:
                        (showBlackScreen || _matchedUser != null) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: _matchedUser == "Detecting..."
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    strokeWidth: 5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Detecting...',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _matchedUser ?? '',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
