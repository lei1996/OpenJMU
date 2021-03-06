import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image_downloader/image_downloader.dart';

import 'package:openjmu/constants/constants.dart';
import 'package:openjmu/widgets/image/image_gesture_detector.dart';

@FFRoute(
  name: "openjmu://image-viewer",
  routeName: "图片浏览",
  argumentNames: ["index", "pics", "needsClear", "post", "heroPrefix"],
  pageRouteType: PageRouteType.transparent,
)
class ImageViewer extends StatefulWidget {
  final int index;
  final List<ImageBean> pics;
  final bool needsClear;
  final Post post;
  final String heroPrefix;

  const ImageViewer({
    @required this.index,
    @required this.pics,
    @required this.heroPrefix,
    this.needsClear = false,
    this.post,
  });

  @override
  ImageViewerState createState() => ImageViewerState();
}

class ImageViewerState extends State<ImageViewer> with TickerProviderStateMixin {
  final pageStreamController = StreamController<int>.broadcast();
  final backgroundOpacityStreamController = StreamController<double>.broadcast();
  final slidePageKey = GlobalKey<ExtendedImageSlidePageState>();
  int currentIndex;
  bool popping = false;

  AnimationController _doubleTapAnimationController;
  Animation _doubleTapCurveAnimation;
  Animation<double> _doubleTapAnimation;
  VoidCallback _doubleTapListener;

  PageController _controller;

  @override
  void initState() {
    super.initState();

    if (widget.needsClear ?? false) {
      clearMemoryImageCache();
      clearDiskCachedImages();
    }
    currentIndex = widget.index;

    _controller = PageController(initialPage: currentIndex);

    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _doubleTapCurveAnimation = CurvedAnimation(
      parent: _doubleTapAnimationController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    final provider = Provider.of<ThemesProvider>(currentContext, listen: false);
    provider.setSystemUIDark(provider.dark);
    pageStreamController?.close();
    backgroundOpacityStreamController?.close();
    _doubleTapAnimationController?.dispose();

    super.dispose();
  }

  void pop() {
    if (popping) return;
    popping = true;
    backgroundOpacityStreamController.add(0.0);
  }

  Future<void> _downloadImage(url, {AndroidDestinationType destination}) async {
    String path;
    try {
      String imageId;
      Platform.isAndroid
          ? imageId = await ImageDownloader.downloadImage(
              url,
              destination: AndroidDestinationType.custom(directory: 'OpenJMU'),
            )
          : imageId = await ImageDownloader.downloadImage(url);
      if (imageId == null) return;
      path = await ImageDownloader.findPath(imageId);
    } on PlatformException catch (error) {
      showCenterToast(error.message);
      return;
    }
    if (!mounted) return;
    showCenterToast('图片保存至：$path');
    return;
  }

  void updateAnimation(ExtendedImageGestureState state) {
    double begin = state.gestureDetails.totalScale;
    double end = state.gestureDetails.totalScale == 1.0 ? 3.0 : 1.0;
    Offset pointerDownPosition = state.pointerDownPosition;

    _doubleTapAnimation?.removeListener(_doubleTapListener);
    _doubleTapAnimationController
      ..stop()
      ..reset();
    _doubleTapListener = () {
      state.handleDoubleTap(
        scale: _doubleTapAnimation.value,
        doubleTapPosition: pointerDownPosition,
      );
    };
    _doubleTapAnimation = Tween(
      begin: begin,
      end: end,
    ).animate(_doubleTapCurveAnimation)
      ..addListener(_doubleTapListener);

    _doubleTapAnimationController.forward();
  }

  void onLongPress(context) {
    ConfirmationBottomSheet.show(
      context,
      children: <Widget>[
        ConfirmationBottomSheetAction(
          icon: Icon(Icons.save_alt),
          text: '保存图片',
          onTap: () {
            _downloadImage(widget.pics[currentIndex].imageUrl);
          },
        ),
      ],
    );
  }

  Color slidePageBackgroundHandler(Offset offset, Size pageSize) {
    double opacity = 0.0;
    opacity = offset.distance / (Offset(pageSize.width, pageSize.height).distance / 2.0);
    backgroundOpacityStreamController.add(1.0 - opacity);
    return Colors.black.withOpacity(math.min(1.0, math.max(1.0 - opacity, 0.0)));
  }

  bool slideEndHandler(Offset offset) {
    final shouldEnd = offset.distance > Offset(Screens.width, Screens.height).distance / 7;
    if (shouldEnd) pop();
    return shouldEnd;
  }

  Widget pageBuilder(context, index) {
    return ImageGestureDetector(
      context: context,
      imageViewerState: this,
      slidePageKey: slidePageKey,
      enableTapPop: true,
      onLongPress: () => onLongPress(context),
      heroPrefix: widget.heroPrefix,
      child: ExtendedImage.network(
        widget.pics[index].imageUrl,
        fit: BoxFit.contain,
        colorBlendMode: currentIsDark ? BlendMode.darken : BlendMode.srcIn,
        mode: ExtendedImageMode.gesture,
        onDoubleTap: updateAnimation,
        enableSlideOutPage: true,
        heroBuilderForSlidingPage: (Widget result) {
          if (index < widget.pics.length && widget.heroPrefix != null) {
            String tag = widget.heroPrefix;
            if (widget.pics[index].postId != null) tag += '${widget.pics[index].postId}-';
            tag += '${widget.pics[index].id}';

            return Hero(
              tag: tag,
              child: result,
              flightShuttleBuilder: (
                _,
                __,
                HeroFlightDirection flightDirection,
                BuildContext fromHeroContext,
                BuildContext toHeroContext,
              ) {
                final Hero hero = flightDirection == HeroFlightDirection.pop
                    ? fromHeroContext.widget
                    : toHeroContext.widget;
                return hero.child;
              },
            );
          } else {
            return result;
          }
        },
        initGestureConfigHandler: (ExtendedImageState state) {
          return GestureConfig(
            initialScale: 1.0,
            minScale: 1.0,
            maxScale: 3.0,
            animationMinScale: 0.6,
            animationMaxScale: 4.0,
            cacheGesture: false,
            inPageView: true,
          );
        },
        loadStateChanged: (ExtendedImageState state) {
          Widget loader;
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              loader = SpinKitWidget();
              break;
            case LoadState.completed:
              // TODO: GIF will setState and cause this flash.
//              loader = FadeTransition(
//                opacity: Tween(
//                  begin: 0.0,
//                  end: 1.0,
//                ).animate(AnimationController(
//                  duration: 300.milliseconds,
//                  vsync: this,
//                )..forward()),
//                child: state.completedWidget,
//              );
              break;
            case LoadState.failed:
              break;
          }
          return loader;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: popping,
      child: ExtendedImageSlidePage(
        key: slidePageKey,
        slideAxis: SlideAxis.both,
        slideType: SlideType.onlyImage,
        slidePageBackgroundHandler: slidePageBackgroundHandler,
        slideEndHandler: slideEndHandler,
        resetPageDuration: widget.heroPrefix != null ? 300.milliseconds : 1.microseconds,
        child: AnnotatedRegion(
          value: SystemUiOverlayStyle.light,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: <Widget>[
                ExtendedImageGesturePageView.builder(
                  physics: const BouncingScrollPhysics(),
                  controller: _controller,
                  itemCount: widget.pics.length,
                  itemBuilder: pageBuilder,
                  onPageChanged: (int index) {
                    currentIndex = index;
                    pageStreamController.add(index);
                  },
                  scrollDirection: Axis.horizontal,
                ),
                Positioned(
                  top: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: StreamBuilder<double>(
                    initialData: 1.0,
                    stream: backgroundOpacityStreamController.stream,
                    builder: (context, data) => Opacity(
                      opacity: popping ? 0.0 : data.data,
                      child: ViewAppBar(
                        post: widget.post,
                        onMoreClicked: () => onLongPress(context),
                      ),
                    ),
                  ),
                ),
                if (widget.pics.length > 1)
                  Positioned(
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    child: StreamBuilder<double>(
                      initialData: 1.0,
                      stream: backgroundOpacityStreamController.stream,
                      builder: (context, data) => Opacity(
                        opacity: popping ? 0.0 : data.data,
                        child: ImageList(
                          controller: _controller,
                          pageStreamController: pageStreamController,
                          index: currentIndex,
                          pics: widget.pics,
                        ),
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

class ImageList extends StatelessWidget {
  final PageController controller;
  final StreamController<int> pageStreamController;
  final int index;
  final List<ImageBean> pics;

  ImageList({
    this.controller,
    this.pageStreamController,
    this.index,
    this.pics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: suSetHeight(16.0),
        bottom: Screens.bottomSafeHeight + suSetHeight(16.0),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Colors.black26, Colors.transparent],
        ),
      ),
      child: StreamBuilder<int>(
        initialData: index,
        stream: pageStreamController.stream,
        builder: (context, data) => SizedBox(
          height: suSetHeight(52.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              pics.length,
              (i) => Container(
                margin: EdgeInsets.symmetric(horizontal: suSetWidth(2.0)),
                width: suSetWidth(52.0),
                height: suSetWidth(52.0),
                child: AnimatedContainer(
                  curve: Curves.fastOutSlowIn,
                  duration: kTabScrollDuration,
                  margin: EdgeInsets.all(suSetWidth(i == data.data ? 0.0 : 6.0)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(suSetWidth(8.0)),
                    border: Border.all(
                      color: Colors.white,
                      width: suSetWidth(i == data.data ? 3.0 : 1.5),
                    ),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller?.animateToPage(
                        i,
                        duration: 300.milliseconds,
                        curve: Curves.fastOutSlowIn,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(suSetWidth(6.0)),
                      child: ExtendedImage.network(
                        pics[i].imageThumbUrl ?? pics[i].imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ViewAppBar extends StatelessWidget {
  final Post post;
  final VoidCallback onMoreClicked;

  const ViewAppBar({
    Key key,
    this.post,
    this.onMoreClicked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: Screens.topSafeHeight + suSetHeight(kAppBarHeight),
        padding: EdgeInsets.only(top: Screens.topSafeHeight),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              color: Colors.white,
              icon: Icon(Icons.arrow_back),
              onPressed: Navigator.of(context).pop,
            ),
            Expanded(
              child: post != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        UserAvatar(uid: post.uid),
                        SizedBox(width: suSetWidth(10.0)),
                        Text(
                          post.nickname,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: suSetSp(20.0),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    )
                  : SizedBox.shrink(),
            ),
            if (onMoreClicked != null)
              IconButton(
                color: Colors.white,
                icon: Icon(Icons.more_vert),
                onPressed: onMoreClicked,
              ),
          ],
        ),
      ),
    );
  }
}

class ImageBean {
  int id;
  String imageUrl;
  String imageThumbUrl;
  int postId;

  ImageBean({this.id, this.imageUrl, this.imageThumbUrl, this.postId});

  Map<String, dynamic> toJson() {
    return {'id': id, 'imageUrl': imageUrl, 'imageThumbUrl': imageThumbUrl, 'postId': postId};
  }

  @override
  String toString() {
    return 'ImageBean ${JsonEncoder.withIndent('  ').convert(toJson())}';
  }
}
