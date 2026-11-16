import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dalahoo_app/features/permissions/permission_service.dart';
import 'package:dalahoo_app/features/home/home_screen.dart';

class PermissionWizardController extends StatefulWidget {
  const PermissionWizardController({super.key});

  @override
  State<PermissionWizardController> createState() =>
      _PermissionWizardControllerState();
}

class _PermissionWizardControllerState
    extends State<PermissionWizardController> {
  bool _active = true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;
      await PermissionWizard.start(context, isActive: () => _active);
    });
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class PermissionWizard {
  static const MethodChannel _channel = MethodChannel('sms_forwarder');

  static Future<void> start(
    BuildContext context, {
    required bool Function() isActive,
  }) async {
    if (!context.mounted || !isActive()) return;

    final prefs = await SharedPreferences.getInstance();

    final wizardCompleted =
        prefs.getBool('permission_wizard_completed') ?? false;

    // ---------- مسیر برگشت (اپ قبلاً ویزارد را تمام کرده) ----------
    if (wizardCompleted) {
      final savedName = prefs.getString('driver_name') ??
          prefs.getString('user_phone_number');

      if (!context.mounted || !isActive()) return;


      // اگر دسترسی پیامک هنوز داده نشده، یک‌بار درخواست کن
      await ensureSmsPermission(context, isActive);
      if (!context.mounted || !isActive()) return;

      if (!context.mounted || !isActive()) return;
      _goHome(context);
      return;
    }

    // ---------- مسیر اولین اجرا ----------
    // 1) نام + کدملی راننده
    await _driverInfoStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // 1-ب) انتخاب سیم‌کارت باربرگ
    await _simStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // 2) همه مجوزها با یک کلیک (پیامک + باتری + آغاز خودکار)
    await _allPermissionsStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    await ensureSmsPermission(context, isActive);
    if (!context.mounted || !isActive()) return;

    // تست نهایی: فقط نام و کدملی
    try {
      await _channel.invokeMethod('sendPermissionTestSms');
    } catch (e) {
      debugPrint('PERMISSION TEST: ERROR = $e');
    }

    await PermissionService.setAppEnabled(true);

    // توضیحات نهایی
    await _disclaimerStep(context, isActive);
    if (!context.mounted || !isActive()) return;

    // علامت‌گذاری اتمام ویزارد
    await prefs.setBool('permission_wizard_completed', true);

    if (!context.mounted || !isActive()) return;
    _goHome(context);
  }

  static void _goHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const HomeScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  

  // -------------------- نام + کدملی --------------------
  static Future<void> _driverInfoStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;

    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('driver_name') ??
        prefs.getString('user_phone_number');
    final savedNationalId = prefs.getString('driver_national_id');

    // اگر هر دو از قبل پر شده‌اند، رد شو
    if (prefs.getBool('driver_info_done') == true) {
      return;
    }

    final nameController = TextEditingController(text: savedName ?? '');
    final nationalIdController =
        TextEditingController(text: savedNationalId ?? '');
    final nameFocus = FocusNode();
    final nationalIdFocus = FocusNode();

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/wizard.jpg", fit: BoxFit.cover),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("👤", style: TextStyle(fontSize: 54)),
                          const SizedBox(height: 10),
                          const Text(
                            "اطلاعات راننده",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "نام و کدملی راننده برای شناسایی در پیامک‌های ارسالی لازم است.",
                            textAlign: TextAlign.justify,
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),

                          // نام
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text("نام و نام خانوادگی"),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            focusNode: nameFocus,
                            autofocus: true,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              hintText: "مثال: علی رضایی",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0099F1),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // کدملی
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text("کدملی"),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nationalIdController,
                            focusNode: nationalIdFocus,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            textAlign: TextAlign.left,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              counterText: "",
                              hintText: "کدملی ۱۰ رقمی",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0099F1),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0099F1),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final nationalId =
                                    nationalIdController.text.trim();



                                await prefs.setString('driver_name', name);
                                await prefs.setString(
                                    'driver_national_id', nationalId);
                                await prefs.setBool('driver_info_done', true);


                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                              child: const Text("ثبت و ادامه"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    nationalIdController.dispose();
    nameFocus.dispose();
    nationalIdFocus.dispose();
  }

  // -------------------- همه مجوزها با یک کلیک --------------------
  static Future<void> _allPermissionsStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;

    // تشخیص برند برای متن و رفتار مناسب
    final brand = (await PermissionService.getDeviceBrand()).toLowerCase();
    final isSamsung = brand.contains('samsung');
    final isHuawei = brand.contains('huawei') || brand.contains('honor');
    final supportsAutoStart = !isSamsung; // سامسونگ آغاز خودکار کلاسیک ندارد

    final String description;
    if (isSamsung) {
      description =
          "با یک کلیک، دسترسی‌های لازم فعال می‌شوند:\n\n"
          "• دسترسی پیامک (دریافت و ارسال)\n"
          "• غیرفعال‌سازی بهینه‌سازی باتری\n\n"
          "در گوشی‌های سامسونگ فقط کافی است بهینه‌سازی باتری را برای این برنامه خاموش کنید.";
    } else if (isHuawei) {
      description =
          "با یک کلیک، دسترسی‌های لازم فعال می‌شوند:\n\n"
          "• دسترسی پیامک (دریافت و ارسال)\n"
          "• غیرفعال‌سازی بهینه‌سازی باتری\n"
          "• اجرای خودکار پس از روشن شدن گوشی\n\n"
          "در گوشی‌های هواوی/آنر: در صفحه بازشده، حالت «مدیریت خودکار» را به «مدیریت دستی» تغییر دهید و همه گزینه‌ها را فعال کنید.";
    } else {
      description =
          "با یک کلیک، دسترسی‌های لازم فعال می‌شوند:\n\n"
          "• دسترسی پیامک (دریافت و ارسال)\n"
          "• غیرفعال‌سازی بهینه‌سازی باتری\n"
          "• اجرای خودکار پس از روشن شدن گوشی";
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/wizard.jpg", fit: BoxFit.cover),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("🔐", style: TextStyle(fontSize: 54)),
                        const SizedBox(height: 10),
                        const Text(
                          "مجوزهای لازم برنامه",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 18),

                        // دکمه فعالسازی - فقط با زدن کاربر اجرا می‌شود
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0099F1),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () async {
                              // اول دیالوگ را ببند تا حس باز شدن دوباره ندهد
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }

                              // 1) دسترسی پیامک
                              await PermissionService.requestSmsPermission();

                              // 2) تنظیمات باتری
                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              await PermissionService.openBatterySettings();

                              // 3) آغاز خودکار فقط برای برندهایی که دارند (نه سامسونگ)
                              if (supportsAutoStart) {
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                                await PermissionService.openAutoStartSettings();
                              }
                            },
                            child: const Text("فعالسازی"),
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
      },
    );
  }

  // -------------------- انتخاب سیم‌کارت --------------------
  static Future<void> _simStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text("انتخاب سیم‌کارت"),
            content: const Text(
              "سیم‌کارت (شماره موبایل) مربوط به باربرگ را انتخاب کنید.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await PermissionService.setSelectedSim(1);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text("سیم‌کارت ۱"),
              ),
              TextButton(
                onPressed: () async {
                  await PermissionService.setSelectedSim(2);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text("سیم‌کارت ۲"),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- توضیحات نهایی --------------------
  static Future<void> _disclaimerStep(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (!context.mounted || !isActive()) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text("توجه"),
            content: const SingleChildScrollView(
              child: Text(
                "این برنامه فقط قادر به خواندن و فوروارد پیامک های مربوط به سامانه بار درون شهری می‌باشد که لیست شماره های آن در اول صفحه نیز عنوان شده هست و به هیچ گونه از پیامک های شخصی یا کاری شما دسترسی ندارد. ضمنا تمامی پیام های ارسال شده توسط برنامه هم در قسمت «تاریخچه ارسال» و هم در قسمت پیامک های گوشی قابل مشاهده هست.\n\nاز حسن توجه شما متشکریم.",
                textAlign: TextAlign.justify,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text("متوجه شدم"),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- اطمینان از دسترسی پیامک --------------------
  static Future<void> ensureSmsPermission(
    BuildContext context,
    bool Function() isActive,
  ) async {
    if (await PermissionService.isSmsPermissionGranted()) return;

    await PermissionService.requestSmsPermission();
    if (await PermissionService.isSmsPermissionGranted()) return;
    if (!context.mounted || !isActive()) return;

    // راهنما فقط یک‌بار، قبل از رفتن به تنظیمات
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text("دسترسی پیامک"),
            content: const Text(
              "در بعضی گوشی‌ها اول باید از تنظیمات برنامه، گزینه «Allow restricted settings» (اجازه دادن به تنظیمات محدود) را فعال کنی.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text("باز کردن تنظیمات"),
              ),
            ],
          ),
        );
      },
    );

    await openAppSettings();

    // بعد از برگشت به برنامه، بدون هیچ پیام خطایی دوباره دسترسی پیامک رو می‌خواد
    while (context.mounted && isActive()) {
      await Future.delayed(const Duration(seconds: 2));
      if (await PermissionService.isSmsPermissionGranted()) return;
      await PermissionService.requestSmsPermission();
      if (await PermissionService.isSmsPermissionGranted()) return;
    }
  }

  // -------------------- دیالوگ عمومی --------------------
  static Future<void> _showDialog(
    BuildContext context, {
    required String emoji,
    required String title,
    required String message,
    required String primaryText,
    required Future<void> Function() onPrimary,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/wizard.jpg", fit: BoxFit.cover),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 54)),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0099F1),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            await onPrimary();
                          },
                          child: Text(primaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
