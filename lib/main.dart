import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import "package:googleapis_auth/auth_io.dart";
import 'dart:convert';
import 'package:googleapis/texttospeech/v1.dart' as tts;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: ".env");
  final visionApiKey = dotenv.env['SPEAK_CLOTHES_API'];
  final ttsApiKey = dotenv.env['SPEAK_CLOTHES_API'];

  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData(
      ),
      home: CameraScreen(
        camera: firstCamera,
        visionApiKey: visionApiKey,
        ttsApiKey: ttsApiKey,
      ),
    ),
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    Key? key,
    required this.camera,
    required this.visionApiKey,
    required this.ttsApiKey,
  }) : super(key: key);

  final CameraDescription camera;
  final String? visionApiKey;
  final String? ttsApiKey;

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late auth.AuthClient _authClient;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  late FlutterTts flutterTts;
  String _analysisResult = '';
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    flutterTts = FlutterTts();

    _initializeAuthClient();

    Timer.periodic(Duration(seconds: 7), (_) {
      _takePictureAndProcess();
    });
  }

  Future<void> _initializeAuthClient() async {
    final credentials = auth.ServiceAccountCredentials.fromJson({
      "type": "service_account",
      "project_id": "unique-terminus-394917",
      "private_key_id": "b6e6dbbc49a60dfc6f111df53960c9a8cfcfac6e",
      "private_key":
      "-----BEGIN PRIVATE KEY-----"
          "\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC1+PySt1PXa0rZ"
          "\nGl6pEwxJZ2+TRqDoROEFSRE4zHmUqaVzQSsabKK+sziFF45JyoAPR/QgbF2+qZQC"
          "\nH9b7InTrhtwH95uh3IahQQjVVhI6i1ZnMiQ21+crm2skzTeuKwhVnnZrH8cxoV2H"
          "\nTSHA/zZS8RwIcX/ghqoyVpbk5AeczoAvW3MHxXcJLZm9uhCdnlanfjbN2Er/VZ/k"
          "\nFhlfUoniLMs67g6hBF8cYMLMYgQqR4RGfBHfllI3bEV1tOsHeutZn6LHgAaA9Cc8"
          "\nIYbbmc1eZ97Vyo+pF5OKM5ii+2ARrvs9FOOEbZyKbgSSAAQ0ppa18t2VbpNVMUKT"
          "\nI2/+bgmvAgMBAAECggEANDDr2/aZpNzAdGEUSkDM0tbIUQC+UK/ErBvnRRecPU+k"
          "\nxNgpkSQcTz6e1MlLRY2/SeK0uYHrJy6C5VMVeSTKTOz6eYyCRhu2P1SkQG+1vbXN"
          "\n+74NVe95fW/PfJghQqJT+x5+Tz4nhuwFo7MzHaP1BDfj9uX6q75j3RkpoQ9nwYia"
          "\npkpG/HmwqlAXBUd0TA6Q8SrRUPH6UtGQKmuyzxVJ7S2EKK5xQi+ChMCQBYOJ9d9a"
          "\nqJ66oeRs1XYBxwp9Q65LjNQitYiK+N9hUHTt815iIFXuWpK4MmGRa1cwhKW55Pah"
          "\ncX9rFuMGjDGCIGZbUWObSExPiiIKGpUxtfHriV4D0QKBgQDf1d81OLaaa5Ke114S"
          "\n8sXfL2QogUMCaPTuoSwuyihT4xro3yFmgGN++Uj23a2UsDKIkpgOU91iHkAnxqXr"
          "\nYnwKhnTVo65giTfnSAyTfvQW/b7zNQ5iOD2Kp3miCebFwpHtaKQJwdAJI1aGMM2T"
          "\nj0ahSeFcvazgXfLavxE/jyjAsQKBgQDQHyBjK66oet2AERyJTT1/HsLBNXk6+/ev"
          "\nlF/InlRbREkEthNGZEsk+vm2zrYvmHaBcLa39KIRTCxE8sc4KdHNGGLU6FbCTCv7"
          "\nbAvf3IfIk777RRaL4KFvPqLyubWpB3lqk8irGHAGrPdVYtTkITK0kux3lQ+C3d3R"
          "\niOHr9xkIXwKBgQCNOh4ZMG1WRSU/f1dl0TOzu+0P+W7UKHDR13NPGlITi6lA4Pfr"
          "\n+nnMdXDqAbgxpnJb5VJ3R8bYz4lfD2FEgOEOqwMwgJPXaPySuszkiydrEjLWtNUc"
          "\nd6usvjpqWKD4iekUx/8oANdHzLoc9NHglnfT8A93Ol3HOr+t8PvrBGKMIQKBgQCd"
          "\nQefHB4rB45Ta4BMf7C07kJK4Sx9/YkSVdxepD3nOPJqv5KRL3ByrpLhrWWZwMFPb"
          "\nGr/13/NV/qi0sH24AmF1B6gmGCj2R3g0Uj/mt0wiUwFL+7g9mU5iMIIPxiNtxSgJ"
          "\nUAGgxqZfZPK+oh8bAbq+lwX2lbtStzKU0UlkcyGHIQKBgE286MA0TE6rLViYeE1Q"
          "\nqC7IIzkJSf/CdXXH4y4FIskPqd1x5uBA8+LQfy2pOedHi2QkhUgGf3xpLNZVK14O"
          "\nKpg/tkTLig6paQfbobB6bWYbXS8OPnpYplLQ3pbeRtpB/SI6+5xekbylYHs1tex2"
          "\nCVu1UVZWpUTbWOugIr4fHQdC\n-----END PRIVATE KEY-----\n",
      "client_email":
      "speak-clothes-vertex-realreal@unique-terminus-394917.iam.gserviceaccount.com",
      "client_id":
      "139320715526-a9mqtprt706shu2dkm6glk36g42k438a.apps.googleusercontent.com",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
      "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
      "https://www.googleapis.com/robot/v1/metadata/x509/speak-clothes-vertex-realreal"
          "%40unique-terminus-394917.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    });

    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
    _authClient = await clientViaServiceAccount(credentials, scopes);
  }

  @override
  void dispose() {
    _controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _takePictureAndProcess() async {
    if (!_controller.value.isInitialized || _isDetecting) {
      return;
    }

    setState(() {
      _isDetecting = true;
    });

    try {
      final XFile picture = await _controller.takePicture();
      await _processImage(picture);
    } catch (e) {
      print("Error taking picture: $e");
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  Future<void> _processImage(XFile picture) async {
    final apiKey = widget.visionApiKey;
    final imageBytes = await File(picture.path).readAsBytes();

    print('Image size: ${imageBytes.length} bytes');

    if (apiKey == null) {
      print('환경 변수에서 API 키를 찾을 수 없습니다.');
      return;
    }

    final client = auth.clientViaApiKey(apiKey);
    final visionApi = vision.VisionApi(client);

    final imageContent = base64Encode(imageBytes);

    final request = vision.BatchAnnotateImagesRequest.fromJson({
      'requests': [
        {
          'image': {'content': imageContent},
          'features': [
            {'type': 'LABEL_DETECTION'}
          ],
        },
      ],
    });

    try {
      final response = await visionApi.images.annotate(request);
      print(
          'Vision API Response: $response');
      if (response.responses != null && response.responses!.isNotEmpty) {
        final labelAnnotations = response.responses!.first.labelAnnotations;
        if (labelAnnotations != null && labelAnnotations.isNotEmpty) {
          final labelAnnotation = labelAnnotations.first;
          final label = labelAnnotation.description ??
              'Unknown';
          if (label != null) {
            final colorInfo = await _getColorInfo(label, picture);
            print('이미지 분석 결과: $label\n색상: $colorInfo');

            // Vertex AI 예측 모델 호출 및 결과 처리
            final prevertexPrediction = await _getVertexPrediction(imageBytes);
            final vertexPrediction;
            switch (prevertexPrediction) {
              case 'hood_zip_up':
                vertexPrediction = '후드집업';
                break;
              case 'knit':
                vertexPrediction = '니트';
                break;
              case 'check_shirt':
                vertexPrediction = '체크 셔츠';
                break;
              case 'shirt':
                vertexPrediction = '셔츠';
                break;
              case 'stripe_t_shirt':
                vertexPrediction = '줄무늬 티셔츠';
                break;
              case 't_shirt':
                vertexPrediction = '티';
                break;
              case 'hood_t_shirt':
                vertexPrediction = '후드티';
                break;
              case 'cardigan':
                vertexPrediction = '가디건';
                break;
              case 'jacket':
                vertexPrediction = '자켓';
                break;
              case 'sweatshirt':
                vertexPrediction = '맨투맨';
                break;
              case 'sleeveless':
                vertexPrediction = '나시';
                break;
              case 'blouse':
                vertexPrediction = '블라우스';
                break;
              default:
                vertexPrediction = '인식 불가능';
            }
            print('옷 종류: $vertexPrediction');

            setState(() {
              //_analysisResult = '옷 종류: $vertexPrediction\n색상: $colorInfo';
              _analysisResult = '$colorInfo상의 $vertexPrediction입니다.';
            });

            await flutterTts.setLanguage('en-US');
            await flutterTts.setSpeechRate(0.4);
            await flutterTts.setVolume(1.0);
            await flutterTts.speak('$colorInfo상의 $vertexPrediction입니다.');
          }
        }
      }
    } catch (e) {
      print("사진 처리 중 오류 발생 $e");
      setState(() {
        //_analysisResult = '이미지 처리 중 오류 발생';
        _analysisResult = ' ';
      });
    }
  }

  // Vertex AI 예측 모델 호출
  Future<String> _getVertexPrediction(Uint8List imageBytes) async {
    await dotenv.load(fileName: ".env");
    final vertexApiKey = dotenv.env['SPEAK_CLOTHES_API'];
    final ENDPOINT_ID = dotenv.env['ENDPOINTID'];
    final PROJECT_ID = dotenv.env['PROJECTID'];
    final vertexEndpoint = Uri.parse(
        'https://us-central1-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/us-central1/endpoints/${ENDPOINT_ID}:predict'); // Vertex AI 모델 엔드포인트 URL

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $vertexApiKey',
    };

    final requestBody = {
      'instances': [
        {
          "content": base64Encode(imageBytes),
        },
      ]
    };

    //print('Sending API request to Vertex AI...');

    try {
      final response = await _authClient.post(
        vertexEndpoint,
        headers: headers,
        body: json.encode(requestBody),
      );

      //print('Response status code: ${response.statusCode}');
      //print('Response from Vertex AI: ${response.body}');

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        final predictions =
        decodedResponse['predictions'] as List<dynamic>;
        final confidenceList = predictions[0]['confidences'];
        final maxConfidence =
        confidenceList.reduce((max, value) => value > max ? value : max);
        final maxConfidenceIndex = confidenceList.indexOf(maxConfidence);
        if (predictions.isNotEmpty) {
          final prediction = predictions[0]['displayNames'][maxConfidenceIndex]
          as String?;
          //print('예측 결과: $prediction');
          return prediction ?? 'Unknown1';
        } else {
          //print('예측 결과 없음');
          return 'Unknown2';
        }
      } else {
        //print('Error, Failed to load prediction from Vertex AI: ${response.reasonPhrase}');
        return 'Error1';
      }
    } catch (e) {
      //print("Error, Failed to send API request to Vertex AI: $e"); // 예외 출력
      return 'Error2';
    }
  }

  Future<String> _getColorInfo(String label, XFile picture) async {
    final apiKey = widget.visionApiKey;

    if (apiKey == null) {
      print('환경 변수에서 API 키를 찾을 수 없습니다.');
      return 'Unknown';
    }

    final client = auth.clientViaApiKey(apiKey);
    final visionApi = vision.VisionApi(client);

    final imageBytes = await File(picture.path).readAsBytes();
    final imageContent = base64Encode(imageBytes);

    final image = vision.Image(content: imageContent);

    final request = vision.BatchAnnotateImagesRequest(
      requests: [
        vision.AnnotateImageRequest(
          image: image,
          features: [
            vision.Feature(type: 'IMAGE_PROPERTIES'),
          ],
        ),
      ],
    );

    try {
      final response = await visionApi.images.annotate(request);
      if (response.responses != null && response.responses!.isNotEmpty) {
        final color = response.responses!.first.imagePropertiesAnnotation
            ?.dominantColors?.colors?.first;
        if (color != null && color.color != null) {
          final r = (color.color!.red!).toInt();
          final g = (color.color!.green!).toInt();
          final b = (color.color!.blue!).toInt();

          final hexColor = '0xff${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}';
          print('hexColor : $hexColor');

          final colorLabel = _findAndPrintMatchingFields(hexColor);

          return colorLabel;
        }
      }
    } catch (e) {
      print("사진 처리 중 오류 발생 $e");
    }

    return 'Unknown';
  }

  Future<String> _findAndPrintMatchingFields(String targetValue) async {
    int intTargetValue = int.parse(targetValue);
    List<int> numbers = [4281479730, 4286085240, 4279500800, 4278190080, 4288059030,
      4280888355, 4280819230, 4278523202, 4280627566, 4284075519, 4282344053, 4280147668,
      4279918763, 4287275708, 4279511456, 4290102217, 4278254591, 4278254591, 4278452479,
      4287734453, 4290896092, 4287408760, 4292999880, 4278251610, 4282808350, 4278206740,
      4285446440, 4283479150, 4286767360, 4280862815, 4282152960, 4280870400, 4281497600,
      4291361440, 4284136960, 4280199680, 4286758500, 4282140210, 4279834900, 4291989870,
      4294927360, 4294935110, 4284759075, 4286732860, 4294947990, 4291975720, 4291340950,
      4284764230, 4286735440, 4294940260, 4294932480, 4291655750, 4287383070, 4286739305,
      4294932530, 4288035850, 4284753920, 4292625920, 4291791501, 4289206329, 4283503921,
      4290075545, 4283042929, 4293867102, 4289272714, 4284361801, 4294810021, 4292527587,
      4294956260, 4288046180, 4285071360, 4294955730, 4294948020, 4294924890, 4294901760,
      4290641920, 4285411890, 4292935680, 4294937740, 4294940310, 4285399040, 4294927460,
      4294909470, 4285419600, 4282122240, 4282129950, 4290667620, 4290680470, 4290654770,
      4294917180, 4294638280, 4294963440, 4294310889, 4294766802, 4294967295, 4294965760,
      4287794944, 4294632985, 4291347260, 4291347260, 4292203008, 4294967075, 4294307920,
      4292335385, 4294440342, 4294638270];
    int realIntTargetValue = numbers.reduce((closest, current) {
      int currentDistance = (current - intTargetValue).abs();
      int closestDistance = (closest - intTargetValue).abs();

      if (currentDistance < closestDistance) {
        return current;
      } else {
        return closest;
      }
    });
    final collectionRef = FirebaseFirestore.instance.collection('colors');
    final querySnapshot = await collectionRef.get();

    for (final doc in querySnapshot.docs) {
      final fieldMap = doc.data() as Map<String, dynamic>;
      for (final fieldName in fieldMap.keys) {
        final fieldValue = fieldMap[fieldName];
        if (fieldValue is int) {
          if (fieldValue == realIntTargetValue) {
            print('Matching field name in document "${doc.id}": $fieldName');

            return fieldName;
          }
        }
      }
    }
    throw Exception('Matching field not found');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Speak Clothes')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        //_isDetecting ? '이미지 분석 중' : _analysisResult,
                        _isDetecting ? ' ' : _analysisResult,
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color.fromARGB(255, 150, 5, 5),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}