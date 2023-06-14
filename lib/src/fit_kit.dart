part of fit_kit;

class FitKit {
  static const MethodChannel _channel = const MethodChannel('fit_kit');

  /// iOS isn't completely supported by HealthKit, false means no, true means user has approved or declined permissions.
  /// In case user has declined permissions read will just return empty list for declined data types.
  static Future<bool> hasPermissions(List<dynamic> types) async {
    return await _channel.invokeMethod('hasPermissions', {
      "types": types.map((type) => _dataTypeToString(type)).toList(),
    });
  }

  /// If you're using more than one DataType it's advised to call requestPermissions with all the data types once,
  /// otherwise iOS HealthKit will ask to approve every permission one by one in separate screens.
  ///
  /// `await FitKit.requestPermissions(DataType.values)`
  static Future<bool> requestPermissions(List<dynamic> types) async {
    return await _channel.invokeMethod('requestPermissions', {
      "types": types.map((type) => _dataTypeToString(type)).toList(),
    });
  }

  /// iOS isn't supported by HealthKit, method does nothing.
  static Future<void> revokePermissions() async {
    return await _channel.invokeMethod('revokePermissions');
  }

  static Future<bool> isAuthorized() async {
    return await _channel
        .invokeMethod('isAuthorized')
        .then((response) => response);
  }

  /// #### It's not advised to call `await FitKit.read(dataType)` without any extra parameters. This can lead to FAILED BINDER TRANSACTION on Android devices because of the data batch size being too large.
  static Future<List<FitData>> read(
    DataType type,
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    return await _channel.invokeListMethod('read', {
      "type": _androidDataTypeToString(type),
      "date_from": dateFrom.millisecondsSinceEpoch,
      "date_to": dateTo.millisecondsSinceEpoch,
    }).then(
      (response) => response.map((item) => FitData.fromJson(item)).toList(),
    );
  }

  static Future<List<dynamic>> readDay(
    IOSDataType type,
    DateTime dateFrom,
  ) async {
    List<dynamic> result = await _channel.invokeListMethod('readDay', {
      "type": _dataTypeToString(type),
      "date_from": dateFrom.millisecondsSinceEpoch,
      "date_to": dateFrom.millisecondsSinceEpoch,
    });
    return result;
  }

  static String _androidDataTypeToString(DataType type) {
    switch (type) {
      case DataType.HEART_RATE:
        return "heart_rate";
      case DataType.STEP_COUNT:
        return "step_count";
      case DataType.HEIGHT:
        return "height";
      case DataType.WEIGHT:
        return "weight";
      case DataType.DISTANCE:
        return "distance";
      case DataType.ENERGY:
        return "energy";
      case DataType.WATER:
        return "water";
    }
    throw Exception('dataType $type not supported');
  }

  static String _dataTypeToString(IOSDataType type) {
    switch (type) {
      case IOSDataType.HEART_RATE:
        return "heart_rate";
      case IOSDataType.STEP_COUNT:
        return "step_count";
      case IOSDataType.HEIGHT:
        return "height";
      case IOSDataType.WEIGHT:
        return "weight";
      case IOSDataType.DISTANCE:
        return "distance";
      case IOSDataType.ENERGY:
        return "energy";
      case IOSDataType.WATER:
        return "water";
    }
    throw Exception('dataType $type not supported');
  }
}

enum DataType {
  HEART_RATE,
  STEP_COUNT,
  HEIGHT,
  WEIGHT,
  DISTANCE,
  ENERGY,
  WATER,
}

enum IOSDataType {
  HEART_RATE,
  STEP_COUNT,
  HEIGHT,
  WEIGHT,
  DISTANCE,
  ENERGY,
  WATER
}
