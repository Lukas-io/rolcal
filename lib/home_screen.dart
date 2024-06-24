import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rolcal/register_face.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String name = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.white,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 50.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Register your Face',
                          style:
                              TextStyle(color: Colors.black87, fontSize: 24.0),
                        ),
                      ),
                      TextField(
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          constraints: const BoxConstraints(maxHeight: 60.0),
                          hintText: 'Name',
                          labelStyle:
                              const TextStyle(decoration: TextDecoration.none),
                          border: OutlineInputBorder(
                              borderSide:
                                  const BorderSide(color: Colors.black87),
                              borderRadius: BorderRadius.circular(10.0)),
                        ),
                        onChanged: (value) {
                          setState(() {
                            name = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterFace(name: name),
                        ),
                      );
                    },
                    style: ButtonStyle(
                      surfaceTintColor:
                          const MaterialStatePropertyAll(Colors.grey),
                      backgroundColor:
                          MaterialStatePropertyAll(Colors.grey.shade400),
                      shape: MaterialStateProperty.resolveWith<OutlinedBorder>(
                          (_) {
                        return RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10));
                      }),
                    ),
                    child: const Text(
                      'Register',
                      style: TextStyle(fontSize: 20.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
