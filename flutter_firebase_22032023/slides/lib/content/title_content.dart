import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:prides/prides.dart';

class TitleContent extends SlideWidget {
  const TitleContent({
    required this.title,
    required this.points,
    required SlideController slideController,
    this.imagePath,
    super.key,
  }) : _slideController = slideController;

  final String title;

  final List<String> points;

  final String? imagePath;

  final SlideController _slideController;

  @override
  SlideController get controller => _slideController;

  @override
  Widget slide(BuildContext context) {
    return TitleContentWidget(
      title: title,
      points: points,
      imagePath: imagePath,
      controller: _slideController,
      key: key,
    );
  }

  @override
  Widget? background() => null;
}

class TitleContentWidget extends StatefulWidget {
  const TitleContentWidget({
    required this.title,
    required this.points,
    required this.controller,
    this.imagePath,
    super.key,
  });

  final String title;

  final List<String> points;

  final String? imagePath;

  final SlideController controller;

  @override
  State<TitleContentWidget> createState() => _TitleContentWidgetState();
}

class _TitleContentWidgetState extends State<TitleContentWidget>
    implements SlideControllerListener {
  late int currentPoint;
  late int pointsLength;

  @override
  void initState() {
    super.initState();
    // attach the listener to the controller
    widget.controller.addListener(this);
    currentPoint = 0;
    pointsLength = widget.points.length;
    if (widget.imagePath != null) pointsLength++;
  }

  @override
  void dispose() {
    // detach the listener from the controller
    widget.controller.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.all(70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 20,
                  top: 30,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List<Widget>.generate(widget.points.length,
                            (index) {
                          return Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '- ',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                Flexible(
                                  child: Text(
                                    widget.points[index],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                ),
                              ],
                            )
                                .animate(
                                    target: currentPoint >= index + 1 ? 1 : 0)
                                .fadeIn(
                                  curve: Curves.easeInOutCubic,
                                  duration: 300.ms,
                                ),
                          );
                        }),
                      ),
                    ),
                    if (widget.imagePath != null)
                      Flexible(
                        child: Center(
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: Image.asset(widget.imagePath!)
                                .animate(
                                    target:
                                        currentPoint >= pointsLength ? 1 : 0)
                                .elevation()
                                .slideX(
                                  begin: 2.5,
                                  end: 0,
                                  duration: 300.ms,
                                  curve: Curves.fastLinearToSlowEaseIn,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool onAdvanceSlide() {
    if (currentPoint >= pointsLength) return false;
    setState(() {
      currentPoint++;
    });
    return true;
  }

  @override
  bool onReverseSlide() {
    return false;
  }
}
