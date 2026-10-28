import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'models.dart';
import 'widgets.dart';

/// Picks a photo and returns it as a small data: URL, the way the website
/// stores logos and selfies on the account. Null if the person backs out.
Future<String?> pickImageDataUrl(
  BuildContext context, {
  ImageSource source = ImageSource.gallery,
  double maxSize = 320,
  CameraDevice camera = CameraDevice.rear,
}) async {
  try {
    final file = await ImagePicker().pickImage(source: source, maxWidth: maxSize, maxHeight: maxSize, imageQuality: 85, preferredCameraDevice: camera);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1500000) throw Exception('That picture is too big. Try a smaller one.');
    return 'data:${file.mimeType ?? 'image/png'};base64,${base64Encode(bytes)}';
  } catch (e) {
    if (context.mounted) showMessage(context, e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Couldn\'t open the photo.', error: true);
    return null;
  }
}

/// Opens a link outside the app (WhatsApp, email, a website page).
Future<void> openLink(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) showMessage(context, 'Couldn\'t open that link.', error: true);
}

Uri whatsappLink(String number, String text) => Uri.https('wa.me', '/${number.replaceAll(RegExp(r'\D'), '')}', {'text': text});

Uri emailLink(String to) => Uri(scheme: 'mailto', path: to);

/// Branded, pre-made goods (name-brand electronics, vehicles) can't carry a
/// buyer's own logo. Same rule as the website's isCustomizable.
final _unbrandable = RegExp(
  r'\b(apple|samsung|huawei|oppo|realme|vivo|lenovo|beats|amazon|nokia|xiaomi|tecno|infinix|sony|jbl|bose|hp|dell|asus|nike|adidas|puma|chrysler|dodge|toyota|honda|ford|hyundai|kia|mercedes|bmw|lexus|jeep|nissan)\b',
  caseSensitive: false,
);

bool isCustomizable(Product p) => p.cat != 'cars' && !_unbrandable.hasMatch(p.name);

/// Support WhatsApp number as digits, for wa.me links.
String get supportWhatsappDigits => AppConfig.supportWhatsapp.replaceAll(RegExp(r'\D'), '');
