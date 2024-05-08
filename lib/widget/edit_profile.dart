import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memory_aid/models/user_model.dart';
import 'package:memory_aid/provider/profile_provider.dart';
import 'package:memory_aid/widget/textField.dart';
import 'package:provider/provider.dart';

class EditProfile extends StatelessWidget {
  const EditProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    var collection = FirebaseFirestore.instance.collection('users');
   
    
    TextEditingController phno = TextEditingController();
    TextEditingController age = TextEditingController();
    TextEditingController ct_phno = TextEditingController();
    TextEditingController ct_email = TextEditingController();
    TextEditingController ct_name = TextEditingController();
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: collection
                    .doc('${FirebaseAuth.instance.currentUser!.uid}')
                    .snapshots(),
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error = ${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    var output = snapshot.data!.data();
                    var currentUser = UserProfile(
                        uid: '',
                        age: '',
                        phNo: '',
                        ctname: '',
                        ctphno: '',
                        ctemail: '');
                    currentUser = UserProfile(
                        uid: output!['uid'],
                        age: output['age'],
                        phNo: output['phno'],
                        ctname: output['ct_name'],
                        ctphno: output['ct_phno'],
                        ctemail: output['ct_email']);
                    age.text = currentUser.age;
                    phno.text = currentUser.phNo;
                    ct_name.text = currentUser.ctname;
                    ct_phno.text = currentUser.ctphno;
                    ct_email.text = currentUser.ctemail;
                    print("here is : ");
                    print(currentUser.age);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Textfield(controller: phno, label: 'User phno'),
                        const SizedBox(
                          height: 10,
                        ),
                        Textfield(controller: age, label: 'User age'),
                        const SizedBox(
                          height: 10,
                        ),
                        Textfield(controller: ct_name, label: 'CareTaker name'),
                        const SizedBox(
                          height: 10,
                        ),
                        Textfield(controller: ct_phno, label: 'CareTaker phno'),
                        const SizedBox(
                          height: 10,
                        ),
                        Textfield(
                            controller: ct_email, label: 'CareTaker email'),
                        const SizedBox(
                          height: 10,
                        ),
                      ],
                    );
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              ),
              ElevatedButton(
                  onPressed: () {
                    Provider.of<ProfileProvider>(context, listen: false)
                        .addProfile(UserProfile(
                            uid: '${FirebaseAuth.instance.currentUser!.uid}',
                            age: age.text,
                            phNo: phno.text,
                            ctname: ct_name.text,
                            ctphno: ct_phno.text,
                            ctemail: ct_email.text));
                    Navigator.of(context).pop();
                  },
                  child: const Text("Save"))
            ],
          ),
        ),
      ),
    );
  }
}
