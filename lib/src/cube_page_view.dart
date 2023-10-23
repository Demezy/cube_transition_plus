import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

enum CubeTransformStyle { inside, outside }

/// Signature for a function that creates a widget for a given index in a [CubePageView]
///
/// Used by [CubePageView.builder] and other APIs that use lazily-generated widgets.
///
typedef CubeWidgetBuilder = CubeWidget Function(
    BuildContext context, int index, double pageNotifier);

/// This Widget has the [PageView] widget inside.
/// It works in two modes :
///   1 - Using the default constructor [CubePageView] passing the items in `children` property.
///   2 - Using the factory constructor [CubePageView.builder] passing a `itemBuilder` and `itemCount` properties.
class CubePageView extends StatefulWidget {
  /// Called whenever the page in the center of the viewport changes.
  final ValueChanged<int>? onPageChanged;

  /// An object that can be used to control the position to which this page
  /// view is scrolled.
  final PageController? controller;

  /// Builder to customize your items
  final CubeWidgetBuilder? itemBuilder;

  /// Starting page
  final int startPage;

  /// The number of items you have, this is only required if you use [CubePageView.builder]
  final int? itemCount;

  /// Widgets you want to use inside the [CubePageView], this is only required if you use [CubePageView] constructor
  final List<Widget>? children;

  /// Direction
  final Axis scrollDirection;

  /// inside or outside
  final CubeTransformStyle transformStyle;

  /// Creates a scrollable list that works page by page from an explicit [List]
  /// of widgets.
  const CubePageView({
    Key? key,
    this.onPageChanged,
    this.controller,
    required this.children,
    this.scrollDirection = Axis.horizontal,
    this.startPage = 0,
    this.transformStyle = CubeTransformStyle.outside,
  })  : itemBuilder = null,
        itemCount = null,
        super(key: key);

  /// Creates a scrollable list that works page by page using widgets that are
  /// created on demand.
  ///
  /// This constructor is appropriate if you want to customize the behavior
  ///
  /// Providing a non-null [itemCount] lets the [CubePageView] compute the maximum
  /// scroll extent.
  ///
  /// [itemBuilder] will be called only with indices greater than or equal to
  /// zero and less than [itemCount].
  const CubePageView.builder({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.controller,
    this.scrollDirection = Axis.horizontal,
    this.startPage = 0,
    this.transformStyle = CubeTransformStyle.outside,
  })  : children = null,
        assert(itemBuilder != null),
        super(key: key);

  @override
  _CubePageViewState createState() => _CubePageViewState();
}

class _CubePageViewState extends State<CubePageView> {
  late final ValueNotifier<double> _pageNotifier;
  late PageController _pageController;

  void _listener() {
    _pageNotifier.value = _pageController.page ?? widget.startPage.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _pageController = widget.controller ?? PageController();
    _pageNotifier = ValueNotifier(widget.startPage.toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.addListener(_listener);
    });
  }

  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients)
        _pageController.jumpToPage(widget.startPage);
    });

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageController.removeListener(_listener);
    _pageController.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<double>(
        valueListenable: _pageNotifier,
        builder: (_, value, child) => PageView.builder(
          scrollDirection: widget.scrollDirection,
          controller: _pageController,
          onPageChanged: widget.onPageChanged,
          physics: const ClampingScrollPhysics(),
          itemCount: widget.itemCount ?? widget.children?.length ?? 0,
          itemBuilder: (_, index) {
            if (widget.itemBuilder != null) {
              return widget.itemBuilder!(context, index, value);
            }
            return CubeWidget(
              child: widget.children![index],
              index: index,
              pageNotifier: value,
              rotationDirection: widget.scrollDirection,
              transformStyle: widget.transformStyle,
            );
          },
        ),
      ),
    );
  }
}

/// This widget has the logic to do the 3D cube transformation
/// It only should be used if you use [CubePageView.builder]
class CubeWidget extends StatelessWidget {
  /// Index of the current item
  final int index;

  /// Page Notifier value, it comes from the [CubeWidgetBuilder]
  final double pageNotifier;

  /// Rotation direction
  final Axis rotationDirection;

  /// sides are center-aligned, it looks not like a cube, but nice
  final bool centerAligned;

  /// inside or outside
  final CubeTransformStyle transformStyle;

  /// Child you want to use inside the Cube
  final Widget child;

  const CubeWidget({
    Key? key,
    required this.index,
    required this.pageNotifier,
    required this.child,
    this.rotationDirection = Axis.horizontal,
    this.centerAligned = false,
    this.transformStyle = CubeTransformStyle.outside,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLeaving = (index - pageNotifier) <= 0;
    final t = (index - pageNotifier);
    final rotation = lerpDouble(0, 90, t) ?? 0;
    final opacity = lerpDouble(0, 1, t.abs())?.clamp(0.0, 1.0) ?? 0;
    final transform = Matrix4.identity();

    rotationDirection == Axis.horizontal
        ? transform.setEntry(3, 2, 0.003)
        : transform.setEntry(3, 2, 0.001);

    if (transformStyle == CubeTransformStyle.outside) {
      rotationDirection == Axis.horizontal
          ? transform.rotateY(-degToRad(rotation))
          : transform.rotateX(degToRad(rotation));
    } else {
      rotationDirection == Axis.horizontal
          ? transform.rotateY(degToRad(rotation))
          : transform.rotateX(-degToRad(rotation));
    }

    Alignment alignment;
    if (rotationDirection == Axis.horizontal) {
      alignment = isLeaving ? Alignment.centerRight : Alignment.centerLeft;
    } else {
      alignment = !isLeaving ? Alignment.topCenter : Alignment.bottomCenter;
    }

    return Transform(
      alignment: alignment,
      transform: transform,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: Container(
                color: Colors.black87,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

double degToRad(double deg) => deg * (pi / 180.0);
double radToDeg(double rad) => rad * (180.0 / pi);
