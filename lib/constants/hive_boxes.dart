///
/// [Author] Alex (https://github.com/AlexVincent525)
/// [Date] 2019-12-01 19:34
///
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'package:openjmu/constants/constants.dart';

class HiveBoxes {
  const HiveBoxes._();

  static Box<Map> appMessagesBox;
  static Box<Map> personalMessagesBox;

  static Box<Map> coursesBox;
  static Box<String> courseRemarkBox;
  static Box<DateTime> startWeekBox;
  static Box<Map> scoresBox;
  static Box<List> webAppsBox;

  static Box<List> reportRecordBox;
  static Box<dynamic> settingsBox;
  static Box<ChangeLog> changelogBox;

  static Future openBoxes() async {
    Hive
      ..registerAdapter(AppMessageAdapter())
      ..registerAdapter(ChangeLogAdapter())
      ..registerAdapter(CourseAdapter())
      ..registerAdapter(MessageAdapter())
      ..registerAdapter(ScoreAdapter())
      ..registerAdapter(WebAppAdapter());

    appMessagesBox = await Hive.openBox<Map>('openjmu_app_messages');
//    personalMessagesBox = await Hive.openBox<Map>('openjmu_personal_messages');

    coursesBox = await Hive.openBox<Map>('openjmu_user_courses');
    courseRemarkBox = await Hive.openBox<String>('openjmu_user_course_remark');
    startWeekBox = await Hive.openBox<DateTime>('openjmu_start_week');
    scoresBox = await Hive.openBox<Map>('openjmu_user_scores');
    webAppsBox = await Hive.openBox<List>('openjmu_webapps');

    reportRecordBox = await Hive.openBox<List>('openjmu_report_record');
    settingsBox = await Hive.openBox<dynamic>('openjmu_app_settings');

    changelogBox = await Hive.openBox<ChangeLog>('openjmu_changelog');
  }

  static void clearBoxes(context) async {
    final confirm = await ConfirmationBottomSheet.show(
      context,
      title: '清除应用数据',
      showConfirm: true,
      content: '清除数据会将您的所有应用内容（包括设置、应用消息）清除。\n确定继续吗？',
    );
    if (confirm) {
      debugPrint('Clearing Hive Boxes...');
      await appMessagesBox?.clear();
      await changelogBox?.clear();
      await coursesBox?.clear();
      await courseRemarkBox?.clear();
      await personalMessagesBox?.clear();
      await reportRecordBox?.clear();
      await scoresBox?.clear();
      await webAppsBox?.clear();
      await settingsBox?.clear();
      await startWeekBox?.clear();
      if (kReleaseMode) SystemNavigator.pop();
    }
  }
}

class HiveAdapterTypeIds {
  const HiveAdapterTypeIds._();

  static const int appMessage = 0;
  static const int message = 1;
  static const int course = 2;
  static const int score = 3;
  static const int webapp = 4;
  static const int changelog = 5;
}
