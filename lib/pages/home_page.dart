import 'package:flutter/material.dart';
import '../utility/routes.dart';

class MyHomePage extends StatefulWidget{
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override

  void initState(){
    super.initState();

    Future.delayed(Duration(seconds: 1),(){
      Navigator.pushNamed(context, MyRoutes.loginRoute);

    });
  }
  Widget build(BuildContext context) {
    return Scaffold(
        body:
        Center(
          child:
              Image.asset("assets/images/logo1bg.png")
        )
    );
  }
}