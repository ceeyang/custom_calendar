import 'dart:collection';

import 'package:flutter/material.dart';
import 'calendar_provider.dart';
import 'configuration.dart';
import 'constants/constants.dart';
import 'flutter_custom_calendar.dart';
import 'utils/LogUtil.dart';
import 'utils/date_util.dart';
import 'widget/default_combine_day_view.dart';
import 'widget/default_custom_day_view.dart';
import 'widget/default_week_bar.dart';

import 'model/date_model.dart';

/**
 * 利用controller来控制视图
 */

class CalendarController {
  static const Set<DateTime> EMPTY_SET = {};
  static const Map<DateModel, Object> EMPTY_MAP = {};
  static const Duration DEFAULT_DURATION = const Duration(milliseconds: 500);

  late CalendarConfiguration calendarConfiguration;

  CalendarProvider calendarProvider = CalendarProvider();

  /**
   * 下面的信息不是配置的
   */
  List<DateModel> monthList = []; //月份list
  List<DateModel> weekList = []; //星期list
  late PageController monthController; //月份的controller
  late PageController weekController; //星期的controller

  CalendarController(
      {CalendarSelectedMode selectMode = CalendarSelectedMode.singleSelect,
      int showMode = CalendarConstants.MODE_SHOW_WEEK_AND_MONTH,
      int minYear = 2022,
      int maxYear = 2030,
      int minYearMonth = 1,
      int maxYearMonth = 12,
      required int nowYear,
      required int nowMonth,
      int? nowDay,
      int minSelectYear = 2022,
      int minSelectMonth = 1,
      int minSelectDay = 1,
      int maxSelectYear = 2030,
      int maxSelectMonth = 12,
      int maxSelectDay = 30,
      Set<DateTime> selectedDateTimeList = EMPTY_SET, //多选模式下，默认选中的item列表
      DateModel? selectDateModel, //单选模式下，默认选中的item
      int maxMultiSelectCount = 9999,
      Map<DateModel, Object> extraDataMap = EMPTY_MAP,
      int offset = 0 // 首日偏移量
      }) {
    assert(offset >= 0 && offset <= 6);
    LogUtil.log(TAG: this.runtimeType, message: "init CalendarConfiguration");
    //如果没有指定当前月份和年份，默认是当年时间
    if (nowYear == null) {
      nowYear = DateTime.now().year;
    }
    if (nowMonth == null) {
      nowMonth = DateTime.now().month;
    }
    calendarConfiguration = CalendarConfiguration(
      selectMode: selectMode,
      showMode: showMode,
      minYear: minYear,
      maxYear: maxYear,
      maxYearMonth: maxYearMonth,
      nowYear: nowYear,
      nowMonth: nowMonth,
      nowDay: nowDay,
      minSelectYear: minSelectYear,
      minSelectMonth: minSelectMonth,
      minYearMonth: minYearMonth,
      minSelectDay: minSelectDay,
      maxSelectYear: maxSelectYear,
      maxSelectMonth: maxSelectMonth,
      extraDataMap: extraDataMap,
      maxSelectDay: maxSelectDay,
      maxMultiSelectCount: maxMultiSelectCount,
      selectDateModel: selectDateModel,
      offset: offset,
    );

    calendarConfiguration.defaultSelectedDateList = HashSet<DateModel>();
    calendarConfiguration.defaultSelectedDateList
        ?.addAll(selectedDateTimeList.map((dateTime) {
      return DateModel.fromDateTime(dateTime);
    }).toSet());
    //将默认选中的数据，放到provider中
    calendarProvider.selectDateModel = selectDateModel;
    calendarProvider.selectedDateList =
        calendarConfiguration.defaultSelectedDateList;
    if (calendarConfiguration.minSelectYear != null) {
      calendarConfiguration.minSelectDate = DateModel.fromDateTime(DateTime(
          calendarConfiguration.minSelectYear!,
          calendarConfiguration.minSelectMonth ?? 1,
          calendarConfiguration.minSelectDay ?? 1));
    }
    if (calendarConfiguration.maxSelectYear != null) {
      calendarConfiguration.maxSelectDate = DateModel.fromDateTime(DateTime(
          calendarConfiguration.maxSelectYear!,
          calendarConfiguration.maxSelectMonth ?? 12,
          calendarConfiguration.maxSelectDay ?? 28));
    }

    LogUtil.log(
        TAG: this.runtimeType,
        message: "start:${DateModel.fromDateTime(DateTime(
          minYear,
          minYearMonth,
        ))},end:${DateModel.fromDateTime(DateTime(
          maxYear,
          maxYearMonth,
        ))}");
    _weekAndMonthViewChange(showMode);
  }

  void _weekAndMonthViewChange(
    int showMode,
  ) {
    int minYear = calendarConfiguration.minYear;
    int maxYear = calendarConfiguration.maxYear;
    int minYearMonth = calendarConfiguration.minYearMonth;
    int maxYearMonth = calendarConfiguration.maxYearMonth;
    int nowYear = calendarConfiguration.nowYear;
    int nowMonth = calendarConfiguration.nowMonth;
    int nowDay = calendarConfiguration.selectDateModel?.day ?? calendarConfiguration.nowDay ?? -1;

    if (showMode != CalendarConstants.MODE_SHOW_ONLY_WEEK) {
      //初始化pageController,initialPage默认是当前时间对于的页面
      int initialPage = 0;
      int nowMonthIndex = 0;
      monthList.clear();
      for (int i = minYear; i <= maxYear; i++) {
        for (int j = 1; j <= 12; j++) {
          if (i == minYear && j < minYearMonth) {
            continue;
          }
          if (i == maxYear && j > maxYearMonth) {
            continue;
          }
          DateModel dateModel = DateModel();
          dateModel.year = i;
          dateModel.month = j;

          if (i == nowYear && j == nowMonth) {
            initialPage = nowMonthIndex;
          }
          monthList.add(dateModel);
          nowMonthIndex++;
        }
      }
      this.monthController =
          PageController(initialPage: initialPage, keepPage: true);

      LogUtil.log(
          TAG: this.runtimeType,
          message:
              "初始化月份视图的信息:一共有${monthList.length}个月，initialPage为$initialPage");
    }

    if (showMode != CalendarConstants.MODE_SHOW_ONLY_MONTH) {
      //计算一共多少周
      //计算方法：第一天是周几，最后一天是周几，中间的天数/7后加上2就是结果了
      int initialWeekPage = 0;
      weekList.clear();
      //如果没有配置当前时间，设置成当前的时间
      if (nowYear == -1 || nowMonth == -1) {
        nowYear = DateTime.now().year;
        nowMonth = DateTime.now().month;
      }
      if(nowDay == -1){
        nowDay = 15; // 默认月中
      }
      // 如果设置了 默认选择的时间 就取默认选择的时间天数，否则为当前时间
      DateModel currentModel = calendarProvider.selectDateModel ??
          calendarProvider.selectedDateList?.toList()[0] ??
          DateModel.fromDateTime(DateTime(nowYear, nowMonth, nowDay));
      nowDay = currentModel.day;
      DateTime nowTime = DateTime(nowYear, nowMonth, nowDay);
      LogUtil.log(TAG: "nowTime", message: " $nowTime");
      DateTime firstDayOfMonth = DateTime(minYear, minYearMonth, 1);
      //计算第一个星期的第一天的日期
      DateTime firstWeekDate =
          firstDayOfMonth.add(Duration(days: -(firstDayOfMonth.weekday - 1)));

      DateTime lastDay = DateTime(maxYear, maxYearMonth,
          DateUtil.getMonthDaysCount(maxYear, maxYearMonth));
      int temp = -1;
      for (DateTime dateTime = firstWeekDate;
          !dateTime.isAfter(lastDay);
          dateTime = dateTime.add(Duration(days: 7))) {
        DateModel dateModel = DateModel.fromDateTime(dateTime);
        weekList.add(dateModel);
//        print("nowTime.isBefore(dateTime)");
//        print("$nowTime,,,,$dateTime");

        //减去偏移量，才能显示正确的周视图
        if (!nowTime.isBefore(
            dateTime.subtract(Duration(days: calendarConfiguration.offset)))) {
          temp++;
        }
      }
      initialWeekPage = temp;
      LogUtil.log(
          TAG: this.runtimeType,
          message:
              "初始化星期视图的信息:一共有${weekList.length}个星期，initialPage为$initialWeekPage");
      this.weekController = PageController(initialPage: initialWeekPage);
    }
    calendarConfiguration.monthList = monthList;
    calendarConfiguration.weekList = weekList;
    calendarConfiguration.monthController = monthController;
    calendarConfiguration.weekController = weekController;
    calendarProvider.weekAndMonthViewChange(showMode);
  }

  void weekAndMonthViewChange(
    int showMode,
  ) {
    calendarProvider.expandStatus.value =
        showMode == CalendarConstants.MODE_SHOW_ONLY_WEEK ? true : false;
  }

  //周视图切换
  void addWeekChangeListener(OnWeekChange listener) {
    this.calendarConfiguration.weekChangeListeners.add(listener);
  }

  //月份切换监听
  void addMonthChangeListener(OnMonthChange listener) {
//    this.calendarConfiguration.monthChange = listener;
    calendarConfiguration.monthChangeListeners.add(listener);
  }

  //点击选择监听
  void addOnCalendarSelectListener(OnCalendarSelect listener) {
    this.calendarConfiguration.calendarSelect = listener;
  }

  //点击选择取消监听
  void addOnCalendarUnSelectListener(OnCalendarUnSelect listener) {
    this.calendarConfiguration.unCalendarSelect = listener;
  }

  //多选超出指定范围
  void addOnMultiSelectOutOfRangeListener(OnMultiSelectOutOfRange listener) {
    this.calendarConfiguration.multiSelectOutOfRange = listener;
  }

  //多选超出限制个数
  void addOnMultiSelectOutOfSizeListener(OnMultiSelectOutOfSize listener) {
    this.calendarConfiguration.multiSelectOutOfSize = listener;
  }

  //切换展开状态
  void toggleExpandStatus() {
    calendarProvider.expandStatus.value = !calendarProvider.expandStatus.value;
    LogUtil.log(
        TAG: this.runtimeType,
        message: "toggleExpandStatus：${calendarProvider.expandStatus.value}");
  }

  //监听展开变化
  void addExpandChangeListener(ValueChanged<bool> expandChange) {
    calendarProvider.expandStatus.addListener(() {
      expandChange(calendarProvider.expandStatus.value);
    });
  }

  //可以动态修改extraDataMap
  void changeExtraData(Map<DateModel, dynamic> newMap) {
    this.calendarConfiguration.extraDataMap = newMap;
    this.calendarProvider.generation.value++;
  }

  //可以动态修改默认选中的item。
  void changeDefaultSelectedDateList(
      HashSet<DateModel> defaultSelectedDateList) {
    this.calendarConfiguration.defaultSelectedDateList =
        defaultSelectedDateList;
    this.calendarProvider.generation.value++;
  }

  //可以动态修改默认选中的item
  void changeDefaultSelectedDateModel(DateModel dateModel) {
    this.calendarProvider.selectDateModel = dateModel;
    this.calendarProvider.generation.value++;
  }

  /**
   * 月份或者星期的上一页
   */
  Future<bool> previousPage() async {
    LogUtil.log(TAG: "TAG", message: "previousPage");
    if (calendarProvider.expandStatus.value == true) {
      //月视图
      int currentIndex = calendarProvider
              .calendarConfiguration.monthController?.page
              ?.toInt() ??
          0;
      if (currentIndex == 0) {
        return false;
      } else {
        calendarProvider.calendarConfiguration.monthController
            ?.previousPage(duration: DEFAULT_DURATION, curve: Curves.ease);
        for (var listener
            in calendarProvider.calendarConfiguration.monthChangeListeners) {
          listener(monthList[currentIndex - 1].year,
              monthList[currentIndex - 1].month);
        }
        DateModel temp = DateModel();
        temp.year = monthList[currentIndex].year;
        temp.month = monthList[currentIndex].month;
        temp.day = monthList[currentIndex].day + 14;
        print('298 周视图的变化: $temp');
        calendarProvider.lastClickDateModel = temp;
        return true;
      }
    } else {
      //周视图
      int currentIndex = calendarProvider
              .calendarConfiguration.weekController?.page
              ?.toInt() ??
          0;
      if (currentIndex == 0) {
        return false;
      } else {
        calendarProvider.calendarConfiguration.weekController
            ?.previousPage(duration: DEFAULT_DURATION, curve: Curves.ease);
        return true;
      }
    }
  }

  /**
   * 月份或者星期的下一页
   * true：成功
   * false:是最后一页
   */
  Future<bool> nextPage() async {
    LogUtil.log(TAG: "TAG", message: "nextPage");
    if (calendarProvider.expandStatus.value == true) {
      //月视图
      int currentIndex = calendarProvider
              .calendarConfiguration.monthController?.page
              ?.toInt() ??
          0;
      if (monthList.length - 1 == currentIndex) {
        return false;
      } else {
        calendarProvider.calendarConfiguration.monthController
            ?.nextPage(duration: DEFAULT_DURATION, curve: Curves.ease);
        calendarProvider.calendarConfiguration.monthChangeListeners
            .forEach((listener) {
          listener(monthList[currentIndex + 1].year,
              monthList[currentIndex + 1].month);
        });

        DateModel temp = new DateModel();
        temp.year = monthList[currentIndex].year;
        temp.month = monthList[currentIndex].month;
        temp.day = monthList[currentIndex].day + 14;
        print('341 周视图的变化: $temp');
        calendarProvider.lastClickDateModel = temp;
        return true;
      }
    } else {
      //周视图
      int currentIndex = calendarProvider
              .calendarConfiguration.weekController?.page
              ?.toInt() ??
          0;
      if (weekList.length - 1 == currentIndex) {
        return false;
      } else {
        calendarProvider.calendarConfiguration.weekController
            ?.nextPage(duration: DEFAULT_DURATION, curve: Curves.ease);
        return true;
      }
    }
  }

  //跳转到指定日期
  void moveToCalendar(int year, int month, int day,
      {bool needAnimation = false,
      Duration duration = const Duration(milliseconds: 500),
      Curve curve = Curves.ease}) {
    LogUtil.log(TAG: "move", message: "to Calendar");
    if (calendarProvider.expandStatus.value == true) {
      DateModel dateModel = DateModel.fromDateTime(DateTime(year, month, 1));
      //计算目标索引
      int targetPage = monthList.indexOf(dateModel);
      if (targetPage == -1) {
        return;
      }
      if (calendarProvider.calendarConfiguration.monthController?.hasClients ==
          false) {
        return;
      }
      if (needAnimation) {
        calendarProvider.calendarConfiguration.monthController
            ?.animateToPage(targetPage, duration: duration, curve: curve);
      } else {
        calendarProvider.calendarConfiguration.monthController
            ?.jumpToPage(targetPage);
      }
    } else {
      DateModel dateModel = DateModel.fromDateTime(DateTime(year, month, 1));
      //计算目标索引
      int targetPage = 0;
      for (int i = 0; i < weekList.length - 1; i++) {
        DateModel first = weekList[i];
        DateModel next = weekList[i + 1];
        if (!first.isAfter(dateModel) && next.isAfter(dateModel)) {
          targetPage = i;
          return;
        }
      }
      if (calendarProvider.calendarConfiguration.weekController?.hasClients ==
          false) {
        return;
      }
      if (needAnimation) {
        calendarProvider.calendarConfiguration.weekController
            ?.animateToPage(targetPage, duration: duration, curve: curve);
      } else {
        calendarProvider.calendarConfiguration.weekController
            ?.jumpToPage(targetPage);
      }
    }
  }

  //切换到下一年
  DateTime moveToNextYear(
      {bool needAnimation = false,
      Duration duration = const Duration(milliseconds: 300),
      Curve curve = Curves.ease}) {
    final config = calendarProvider.calendarConfiguration;
    DateTime now = DateTime.now();
    DateTime currentDateTime = DateTime(config.nowYear,config.nowMonth,config.nowDay ?? now.day);
    DateTime targetDateTime = currentDateTime.add(Duration(days: 365));
    moveToCalendar(
        targetDateTime.year, targetDateTime.month, targetDateTime.day,
        needAnimation: needAnimation, duration: duration, curve: curve);
    return targetDateTime;
  }

  //切换到上一年
  DateTime moveToPreviousYear(
      {bool needAnimation = false,
      Duration duration = const Duration(milliseconds: 500),
      Curve curve = Curves.ease}) {
    final config = calendarProvider.calendarConfiguration;
    DateTime now = DateTime.now();
    DateTime currentDateTime = DateTime(config.nowYear,config.nowMonth,config.nowDay ?? now.day);
    DateTime targetDateTime = currentDateTime.add(Duration(days: -365));
    moveToCalendar(
        targetDateTime.year, targetDateTime.month, targetDateTime.day,
        needAnimation: needAnimation, duration: duration, curve: curve);
    return targetDateTime;
  }

  //切换到下一个月份,
  DateTime? moveToNextMonth(
      {bool needAnimation = false,
      Duration duration = const Duration(milliseconds: 500),
      Curve curve = Curves.ease}) {
    //    如果当前显示的是周视图的话，需要计算出第一个月的index后，调用weekController
    if (calendarProvider.expandStatus.value == false) {
      int currentMonth = weekList[calendarProvider
                  .calendarConfiguration.weekController?.page
                  ?.toInt() ??
              0]
          .month;
      for (int i = calendarProvider.calendarConfiguration.weekController?.page
                  ?.toInt() ??
              0;
          i < weekList.length;
          i++) {
        if (weekList[i].month != currentMonth) {
          calendarProvider.calendarConfiguration.weekController?.jumpToPage(i);
          break;
        }
      }
      return null;
    }

    final config = calendarProvider.calendarConfiguration;
    DateTime now = DateTime.now();
    DateTime currentDateTime = DateTime(config.nowYear,config.nowMonth,config.nowDay ?? now.day);
    DateTime targetDateTime = currentDateTime.add(Duration(days: 30));
    moveToCalendar(
        targetDateTime.year, targetDateTime.month, targetDateTime.day,
        needAnimation: needAnimation, duration: duration, curve: curve);
    return targetDateTime;
  }

  //切换到上一个月份
  DateTime? moveToPreviousMonth(
      {bool needAnimation = false,
      Duration duration = const Duration(milliseconds: 500),
      Curve curve = Curves.ease}) {
    //    如果当前显示的是周视图的话，需要计算出第一个月的index后，调用weekController
    if (calendarProvider.expandStatus.value == false) {
      int currentMonth = weekList[weekController.page?.toInt() ?? 0].month;
      for (int i = calendarProvider.calendarConfiguration.weekController?.page
                  ?.toInt() ??
              0;
          i >= 0;
          i--) {
        if (weekList[i].month != currentMonth &&
            weekList[i].isAfter(DateModel.fromDateTime(DateTime(
                calendarConfiguration.minYear,
                calendarConfiguration.minYearMonth)))) {
          calendarProvider.calendarConfiguration.weekController?.jumpToPage(i);
          break;
        }
      }
      return null;
    }

    final config = calendarProvider.calendarConfiguration;
    DateTime now = DateTime.now();
    DateTime currentDateTime = DateTime(config.nowYear,config.nowMonth,config.nowDay ?? now.day);
    DateTime targetDateTime = currentDateTime.add(Duration(days: -30));
    moveToCalendar(
        targetDateTime.year, targetDateTime.month, targetDateTime.day,
        needAnimation: needAnimation, duration: duration, curve: curve);
    return targetDateTime;
  }

  // 获取当前的月份
  DateModel getCurrentMonth() {
    return monthList[monthController.page?.toInt() ?? 0];
  }

  //获取被选中的日期,多选
  HashSet<DateModel>? getMultiSelectCalendar() {
    return calendarProvider.selectedDateList;
  }

  //获取被选中的日期，单选
  DateModel? getSingleSelectCalendar() {
    return calendarProvider.selectDateModel;
  }

  //清除数据
  void clearData() {
    monthList.clear();
    weekList.clear();
    calendarProvider.clearData();
    calendarConfiguration.weekChangeListeners.clear();
    calendarConfiguration.monthChangeListeners.clear();
  }
}

/**
 * 默认的weekBar
 */
Widget defaultWeekBarWidget() {
  return const DefaultWeekBar();
}

/**
 * 使用canvas绘制item
 */
Widget defaultCustomDayWidget(DateModel dateModel, bool expand) {
  return DefaultCustomDayWidget(
    dateModel,
  );
}

/**
 * 使用组合widget的方式构造item
 */
Widget defaultCombineDayWidget(DateModel dateModel) {
  return new DefaultCombineDayWidget(
    dateModel,
  );
}

/**
 * 判断是否在范围内，不在范围内的话，可以置灰
 */
bool defaultInRange(DateModel dateModel) {
  return true;
}

/**
 * 周视图切换
 */
typedef void OnWeekChange(int year, int month, int day);

/**
 * 月份切换事件
 */
typedef void OnMonthChange(int year, int month);

/**
 * 日期选择事件
 */
typedef void OnCalendarSelect(DateModel dateModel, bool expand);
/**
 * 取消选择
 */
typedef void OnCalendarUnSelect(DateModel dateModel, bool expand);

/**
 * 多选超出指定范围
 */
typedef void OnMultiSelectOutOfRange();

/**
 * 多选超出限制个数
 */
typedef void OnMultiSelectOutOfSize();

/**
 * 可以创建自定义样式的item
 */
typedef Widget DayWidgetBuilder(DateModel dateModel, bool expand);

/**
 * 是否可以点击，外部来进行判断，默认都可以点击
 */
typedef bool CanClick(DateModel dateModel);

/**
 * 可以自定义绘制每个Item，这种扩展性好一点，以后可以提供给外部进行自定义绘制
 */
typedef void DrawDayWidget(DateModel dateModel, Canvas canvas, Size size);

/**
 * 自定义顶部weekBar
 */
typedef Widget WeekBarItemWidgetBuilder();
