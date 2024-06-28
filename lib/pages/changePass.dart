// ignore_for_file: file_names, unused_local_variable, unused_element
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/text_field.dart';

class ChangePass extends StatelessWidget {
  const ChangePass({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextEditingController useridctrl = TextEditingController();
    TextEditingController oldPass = TextEditingController();
    TextEditingController newPass = TextEditingController();
    TextEditingController confirmPass = TextEditingController();
    changePassword() async {
      var uri =
          Uri.parse('https://backend.zoomtod.com/api/user/changePassword');
      if (newPass.text == confirmPass.text) {
        var response = await http.post(
          uri,
          body: jsonEncode({
            'userId': useridctrl.text.toString(),
            'password': oldPass.text.toString(),
            'newpassword': newPass.text.toString(),
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        print(response.body);
        var message = json.decode(response.body)['message'].toString();
        if (message == 'Password Changed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirm Password and New Password do not match'),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 179, 77, 223),
        title: const Text('Change Password'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.only(bottom: 20, left: 40, right: 20, top: 60),
            child: LKTextField(
              ctrl: useridctrl,
              label: 'UserID',
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(bottom: 20, left: 40, right: 20, top: 60),
            child: LKTextField(
              ctrl: oldPass,
              label: 'Old Password',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 40, right: 20),
            child: LKTextField(
              label: 'New Password',
              ctrl: newPass,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 40, right: 20),
            child: LKTextField(
              label: 'Confirm Password',
              ctrl: confirmPass,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                  const Color.fromARGB(255, 179, 77, 223)),
            ),
            onPressed: () async {
              await changePassword();
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Change Password',
                  style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
