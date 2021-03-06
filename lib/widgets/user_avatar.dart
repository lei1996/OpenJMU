///
/// [Author] Alex (https://github.com/AlexVincent525)
/// [Date] 2019-11-23 18:15
///
import 'package:flutter/material.dart';

import 'package:openjmu/openjmu_route_helper.dart';
import 'package:openjmu/constants/constants.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final int uid;
  final int timestamp;
  final bool canJump;

  const UserAvatar({
    Key key,
    this.uid,
    this.size = 48.0,
    this.timestamp,
    this.canJump = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _uid = uid ?? UserAPI.currentUser.uid;
    return SizedBox(
      width: suSetWidth(size),
      height: suSetWidth(size),
      child: GestureDetector(
        child: ClipRRect(
          borderRadius: maxBorderRadius,
          child: FadeInImage(
            fadeInDuration: 150.milliseconds,
            placeholder: AssetImage('assets/avatar_placeholder.png'),
            image: UserAPI.getAvatarProvider(uid: _uid),
          ),
        ),
        onTap: canJump
            ? () {
                final _routeSettings = ModalRoute.of(context).settings;
                if (_routeSettings is FFRouteSettings) {
                  final settings = ModalRoute.of(context).settings as FFRouteSettings;
                  if (settings.name != Routes.OPENJMU_USER ||
                      settings.arguments.toString() != {'uid': _uid}.toString()) {
                    navigatorState.pushNamed(Routes.OPENJMU_USER, arguments: {'uid': _uid});
                  }
                } else {
                  navigatorState.pushNamed(Routes.OPENJMU_USER, arguments: {'uid': _uid});
                }
              }
            : null,
      ),
    );
  }
}
