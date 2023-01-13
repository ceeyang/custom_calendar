import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../calendar_provider.dart';
import '../configuration.dart';
import '../model/date_model.dart';
import '../utils/LogUtil.dart';
import '../utils/date_util.dart';
import 'month_view.dart';

class MonthViewPager extends StatefulWidget {
  const MonthViewPager({Key? key}) : super(key: key);

  @override
  _MonthViewPagerState createState() => _MonthViewPagerState();
}

class _MonthViewPagerState extends State<MonthViewPager>
    with AutomaticKeepAliveClientMixin {
  late CalendarProvider calendarProvider;

  @override
  void initState() {
    super.initState();
    LogUtil.log(TAG: this.runtimeType, message: "MonthViewPager initState");

    calendarProvider = Provider.of<CalendarProvider>(context, listen: false);

    //计算当前月视图的index
    DateModel? dateModel = calendarProvider.lastClickDateModel;
    List<DateModel> monthList = calendarProvider.calendarConfiguration.monthList;
    int index = 0;
    for (int i = 0; i < monthList.length; i++) {
      DateModel firstDayOfMonth = monthList[i];
      DateModel lastDayOfMonth = DateModel.fromDateTime(firstDayOfMonth.getDateTime().add(Duration(days: DateUtil.getMonthDaysCount(firstDayOfMonth.year, firstDayOfMonth.month))));

      if (dateModel !=null && (dateModel.isAfter(firstDayOfMonth) ||
              dateModel.isSameWith(firstDayOfMonth)) &&
          dateModel.isBefore(lastDayOfMonth)) {
        index = i;
        LogUtil.log(TAG: "index $index  dateModel $dateModel  firstDayOfMonth $firstDayOfMonth");
        break;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      LogUtil.log(TAG: "jump whit index init");
      calendarProvider.calendarConfiguration.monthController?.jumpToPage(index);
    });
  }

  @override
  void dispose() {
    LogUtil.log(TAG: this.runtimeType, message: "MonthViewPager dispose");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    LogUtil.log(TAG: this.runtimeType, message: "MonthViewPager build");
//    获取到当前的CalendarProvider对象,设置listen为false，不需要刷新
    calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    CalendarConfiguration configuration =
        calendarProvider.calendarConfiguration;

    return PageView.builder(
      onPageChanged: (position) {
        if (calendarProvider.expandStatus.value == false) {
          return;
        }
        //月份的变化
        DateModel dateModel = configuration.monthList[position];
        configuration.nowYear = dateModel.year;
        configuration.nowMonth = dateModel.month;
        configuration.monthChangeListeners.forEach((listener) {
          listener(dateModel.year, dateModel.month);
        });
        //用来保存临时变量，用于月视图切换到周视图的时候，
        if (calendarProvider.lastClickDateModel != null ||
            calendarProvider.lastClickDateModel?.month != dateModel.month) {
          DateModel temp = DateModel();
          temp.year = configuration.monthList[position].year;
          temp.month = configuration.monthList[position].month;
          temp.day = configuration.monthList[position].day + 14; // 默认月中
          // 如果设置了 默认选择的时间 就取默认选择的时间天数，否则为当前时间
          DateModel? currentModel = calendarProvider.selectDateModel ?? calendarProvider.selectedDateList?.toList().first;
          if(currentModel != null && temp.month == currentModel.month){
            temp.day = currentModel.day;
          }
          calendarProvider.lastClickDateModel = temp;
        }
      },
      controller: configuration.monthController,
      itemBuilder: (context, index) {
        final DateModel dateModel = configuration.monthList[index];
        return MonthView(
          configuration: configuration,
          year: dateModel.year,
          month: dateModel.month,
        );
      },
      itemCount: configuration.monthList.length,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
