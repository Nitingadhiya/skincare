import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CameraView(),
    );
  }
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static const MethodChannel _channel = MethodChannel('skincare_channel');
  Map<String, String>? _skincareData;
  String imagepath = "";
  String lightingQuality_color = "#41474D";
  String faceFrontalQuality_color = "#41474D";
  String faceAreaQuality_color = "#41474D";
  String? allSkinImage;
  String lightingQuality = "";
  String faceFrontalQuality = "";
  String faceAreaQuality = "";
  int? countDin;
  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  Image? image;
  List<Map<String, dynamic>> skinDataList = [];
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "updateSkincareData") {
        final Map<dynamic, dynamic> result = call.arguments;
        setState(() {
          _skincareData = result.map((key, value) => MapEntry(key as String, value as String));
          lightingQuality_color = _skincareData!["lightingQuality_color"]!;
          faceFrontalQuality_color = _skincareData!["faceFrontalQuality_color"]!;
          faceAreaQuality_color = _skincareData!["faceAreaQuality_color"]!;
          lightingQuality = _skincareData!["lightingQuality"]!;
          faceFrontalQuality = _skincareData!["faceFrontalQuality"]!;
          faceAreaQuality = _skincareData!["faceAreaQuality"]!;
          setState(() {});
        });
      } else if (call.method == "updateSkincareData1") {
        Map<String, int> reportDict = Map<String, int>.from(call.arguments["skincareReportDict"]);
        Map<String, String> selectedImageList = Map<String, String>.from(call.arguments["selectedSkinImageList"]);
        print("Received Skincare Report: $selectedImageList");
        final base64Image = call.arguments['imageBase64'];
        allSkinImage = call.arguments["allSkinImage"];
        final imageBytes = base64Decode(base64Image);
        image = Image.memory(
          Uint8List.fromList(imageBytes),
          height: 200,
          width: 200,
        );
        print("Received Skincare Report: $reportDict");
        skinDataList = reportDict.entries.map((entry) {
          return {
            "key": entry.key,
            "value": entry.value,
            "image": "",
          };
        }).toList();
        for (var entry in selectedImageList.entries) {
          for (var e in skinDataList) {
            if (e["key"] == entry.key) {
              e["image"] = entry.value;
            }
          }
        }
        countDin = null;
        setState(() {});
        // Get.back();
      } else if (call.method == "updateSkincareData2") {
        countDin = call.arguments["countDownValue"];
        setState(() {});
      }
    });
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Camera View"),backgroundColor: Colors.red,),
      body: Center(
        child: skinDataList.isEmpty
            ? Column(
                children: [
                  SizedBox(
                    height: 300,
                    width: 300,
                    child: UiKitView(
                      viewType: 'skincare_camera_view', // Registered in iOS native code
                      onPlatformViewCreated: (int id) async {
                        // Initialize the view using a method channel
                        const channel = MethodChannel('skincare_camera');
                        var data = await channel.invokeMethod('initializeView', {'viewId': id});
                        print("-----${data}");
                      },
                    ),
                  ),
                  if (countDin != null)
                    Text(
                      "$countDin",
                      style: const TextStyle(fontSize: 40),
                    ),
                  Row(
                    children: [
                      Text(lightingQuality.isNotEmpty ? lightingQuality : "Lighting"),
                      const SizedBox(width: 10),
                      Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: hexToColor(lightingQuality_color),
                            borderRadius: BorderRadius.circular(100),
                          ))
                    ],
                  ),
                  Row(
                    children: [
                      Text(faceFrontalQuality.isNotEmpty ? faceFrontalQuality : "Face Frontal"),
                      const SizedBox(width: 10),
                      Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: hexToColor(faceFrontalQuality_color),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Text(faceAreaQuality.isNotEmpty ? faceAreaQuality : "Face Area"),
                      const SizedBox(width: 10),
                      Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: hexToColor(faceAreaQuality_color),
                            borderRadius: BorderRadius.circular(100),
                          ))
                    ],
                  )
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 100,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                imagepath = allSkinImage ?? "";
                                setState(() {});
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("All", style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal, // Horizontal ListView
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: skinDataList.length,
                                shrinkWrap: true,
                                itemBuilder: (context, index) {
                                  var skinData = skinDataList[index];
                                  return InkWell(
                                    onTap: () {
                                      imagepath = skinData["image"];
                                      setState(() {});
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(skinData['key'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Text('${skinData['value']}', style: const TextStyle(fontSize: 20)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (image != null) image!,
                    if (imagepath.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(200),
                        child: Image.file(
                          File(imagepath),
                          height: 300,
                          width: 300,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
