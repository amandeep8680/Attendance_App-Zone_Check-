import 'package:attendance_aap/utility/texts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utility/routes.dart';

class Marked extends StatefulWidget{
  @override
  State<Marked> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Marked>
{
  @override

  void initState(){
    super.initState();

    Future.delayed(Duration(seconds: 1),(){
      Navigator.pushNamed(context, MyRoutes.studentDashRoute);

    });
  }
  Widget build(BuildContext context) {
    return Scaffold(
        body:
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.check_mark,size: 250,),
                  ],
                ),
            Text("Attendence Marked",style: style3(),),
        ],),


    );
  }
}