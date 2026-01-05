import 'package:flutter/material.dart';
import 'cameraS.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:math';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String id = '';
  String dept = 'Computer Engineering'; // Default department
  String userType = 'Student'; // Default user type
  String sem = 'Sem 1'; // Default semester
  File? _faceImage;
  List<double>? _faceEmbeddings;
  bool isLoading = false;

  Future<void> _openCamera() async {
    setState(() {
      isLoading = true;
    });

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CameraScreen()),
    );

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      setState(() {
        _faceImage = result['image'];
        _faceEmbeddings = result['embeddings'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face detected successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face not detected! Please try again.')),
      );
    }
  }

  Future<void> _saveUserData() async {
    if (_faceImage == null || _faceEmbeddings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture an image with a face')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Fetch existing embeddings from Firestore
      final querySnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      for (var doc in querySnapshot.docs) {
        List<double> storedEmbedding = (doc['embedding'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();

        // Check if the embeddings are similar (you may need a proper comparison function)
        double similarity =
            _calculateSimilarity(storedEmbedding, _faceEmbeddings!);
        if (similarity > 0.9) {
          // Assuming 0.9 as the threshold
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Face already registered!')),
          );

          // Reset form
          _formKey.currentState?.reset();
          setState(() {
            name = '';
            id = '';
            dept = 'Computer Engineering';
            userType = 'Student';
            sem = 'Sem 1';
            _faceImage = null;
            _faceEmbeddings = null;
          });

          return;
        }
      }

      // Upload image and save user data if no duplication
      String imageUrl = '';
      final ref =
          FirebaseStorage.instance.ref().child('user_images').child('$id.jpg');
      await ref.putFile(_faceImage!);
      imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'id': id,
        'department': dept,
        'user_type': userType,
        'semester': sem,
        'photo_url': imageUrl,
        'embedding': _faceEmbeddings,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User Registered Successfully')),
      );

      _formKey.currentState?.reset();
      setState(() {
        name = '';
        id = '';
        dept = 'Computer Engineering';
        userType = 'Student';
        sem = 'Sem 1';
        _faceImage = null;
        _faceEmbeddings = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

// Dummy function for embedding similarity check (Replace with actual function)
  double _calculateSimilarity(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name Field
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Name'),
                        onSaved: (value) => name = value!,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please enter your name'
                            : null,
                      ),

                      SizedBox(height: 16),

                      // User Type Dropdown
                      DropdownButtonFormField<String>(
                        value: userType,
                        decoration: InputDecoration(labelText: 'User Type'),
                        items: ['Student', 'Faculty'].map((String userType) {
                          return DropdownMenuItem<String>(
                            value: userType,
                            child: Text(userType),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            userType = value!;
                            sem = userType == 'Faculty' ? '' : 'Sem 1';
                          });
                        },
                      ),

                      SizedBox(height: 16),

                      // Semester Dropdown (Only for Students)
                      if (userType == 'Student')
                        DropdownButtonFormField<String>(
                          value: sem,
                          decoration: InputDecoration(labelText: 'Semester'),
                          items: [
                            'Sem 1',
                            'Sem 2',
                            'Sem 3',
                            'Sem 4',
                            'Sem 5',
                            'Sem 6',
                          ].map((String sem) {
                            return DropdownMenuItem<String>(
                              value: sem,
                              child: Text(sem),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => sem = value!),
                          validator: (value) => (userType == 'Student' &&
                                  (value == null || value.isEmpty))
                              ? 'Please select your semester'
                              : null,
                        ),

                      SizedBox(height: 16),

                      // Faculty ID / Admission Number
                      TextFormField(
                        decoration: InputDecoration(
                          labelText:
                              userType == 'Faculty' ? 'Fac ID' : 'Adm No',
                        ),
                        onSaved: (value) => id = value!,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please enter your ${userType == 'Faculty' ? 'Fac ID' : 'Adm No'}'
                            : null,
                      ),

                      SizedBox(height: 16),

                      // Department Dropdown
                      DropdownButtonFormField<String>(
                        value: dept,
                        decoration: InputDecoration(labelText: 'Department'),
                        items: [
                          'Computer Engineering',
                          'Electronics Engineering',
                          'Printing Technology',
                        ].map((String department) {
                          return DropdownMenuItem<String>(
                            value: department,
                            child: Text(department),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => dept = value!),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Please select your department'
                            : null,
                      ),

                      SizedBox(height: 20),

                      // Face Capture Button & Image Preview
                      Center(
                        child: _faceImage == null
                            ? OutlinedButton.icon(
                                onPressed: _openCamera,
                                icon: Icon(Icons.camera_alt),
                                label: Text('Capture Face'),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _faceImage!,
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),

                      SizedBox(height: 20),

                      // Sign Up Button with Loading Indicator
                      Center(
                        child: isLoading
                            ? CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    _formKey.currentState?.save();
                                    _saveUserData();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
