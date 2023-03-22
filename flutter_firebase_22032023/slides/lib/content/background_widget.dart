import 'package:flutter/material.dart';

class BackgroundWidget extends StatelessWidget {
  const BackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SizedBox.expand(child: ColoredBox(color: Color(0xFFFFCA28))),
        Opacity(
          opacity: 0.9,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xDDEEA000),
                  Color(0xDD799696),
                  Color(0xDD027DFE),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 30),
            child: SizedBox(
              height: 40,
              width: 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: FlutterLogo(),
                    ),
                    const Text(
                      '+',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 6, top: 7, bottom: 7),
                      child: Image.asset('assets/firebase_logo.png'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 30, bottom: 30),
            child: SizedBox(
              height: 45,
              width: 160,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFF1D9BF0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(child: Image.asset('assets/twitter_logo.png')),
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Text(
                        '@immadisairaj',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
