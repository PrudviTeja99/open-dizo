import 'package:flutter/material.dart';
import 'app.dart';
import 'services/app_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppUpdateService.getInstalledVersion();
  runApp(const DizoWatchApp());
}
