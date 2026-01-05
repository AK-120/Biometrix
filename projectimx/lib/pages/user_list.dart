import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users'),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous screen
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No users found.'));
                  }

                  final users = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index].data() as Map<String, dynamic>;
                      final docId = users[index].id;

                      return _buildUserRow(
                        context,
                        user['name'] ?? 'Unknown',
                        user['user_type'] ?? 'Unknown',
                        user['id'] ?? 'N/A',
                        user['department'] ?? 'N/A',
                        user['semester'] ?? 'N/A',
                        docId,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(BuildContext context, String name, String userType,
      String id, String department, String semester, String docId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name ($userType)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('id: $id'),
                  Text('Department: $department'),
                  Text('Semester: $semester'),
                ],
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirm = await _confirmDelete(context, name);
                  if (confirm) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(docId)
                        .delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('User $name deleted successfully')),
                    );
                  }
                },
              ),
            ],
          ),
          Divider(),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Delete User'),
              content: Text('Are you sure you want to delete $name?'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Delete User'),
            content: Text('Are you sure you want to delete $name?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text('Delete'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      ) ??
      false;
}
