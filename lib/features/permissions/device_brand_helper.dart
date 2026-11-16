class DeviceBrandHelper {
  static bool isXiaomi(String brand) {
    return brand.toLowerCase().contains('xiaomi') ||
        brand.toLowerCase().contains('redmi') ||
        brand.toLowerCase().contains('poco');
  }

  static bool isSamsung(String brand) {
    return brand.toLowerCase().contains('samsung');
  }

  static bool isHuawei(String brand) {
    final b = brand.toLowerCase();
    return b.contains('huawei') || b.contains('honor');
  }

  /// آیا این برند صفحه «آغاز خودکار» واقعی دارد؟
  /// سامسونگ ندارد.
  static bool supportsAutoStart(String brand) {
    return !isSamsung(brand);
  }

  // فقط برای AutoStart استفاده میشه
  static String getAutoStartType(String brand) {
    final b = brand.toLowerCase();

    if (isXiaomi(b)) {
      return "xiaomi";
    }

    if (isHuawei(b)) {
      return "huawei";
    }

    if (isSamsung(b)) {
      return "none"; // سامسونگ آغاز خودکار ندارد
    }

    return "default";
  }

  static bool isSupportedBrand(String brand) {
    final b = brand.toLowerCase();
    return isXiaomi(b) || isSamsung(b) || isHuawei(b);
  }
}
