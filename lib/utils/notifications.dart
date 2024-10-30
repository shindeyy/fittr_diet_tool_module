import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

// Create a global instance of FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class Notifications {
  // Function to initialize the notification configuration
  Future<void> initNotificationsConfig() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS initialization settings
    DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Handle notification received while app is in foreground
      },
    );

    // Combine Android and iOS/macOS settings
    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );

    // Request notification permissions for iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  // Function to download a file with progress notifications
  Future<void> downloadFile(String url, String fileName) async {
    final Dio dio = Dio();

    try {
      // Get the directory to save the file
      final Directory dir = await getApplicationDocumentsDirectory();
      final String filePath = '${dir.path}/$fileName';

      // Start downloading the file
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) async {
          if (total != -1) {
            int progress = ((received / total) * 100).toInt();
            await _showProgressNotification(fileName, progress);
          }
        },
      );

      // Show completion notification
      await _showCompletionNotification(fileName);
    } catch (e) {
      print('Download error: $e');
    }
  }

  // Function to show progress notifications
  Future<void> _showProgressNotification(String fileName, int progress) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'download_channel',
        'File Download',
        channelDescription: 'Notification channel for file downloads',
        importance: Importance.high,
        priority: Priority.high,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0, // Notification ID, ensure this is the same to update the same notification
        'Downloading $fileName',
        '$progress% downloaded',
        platformChannelSpecifics,
      );
    } catch (e) {
      print('Progress error: $e');
    }
  }

  // Function to show completion notifications
  Future<void> _showCompletionNotification(String fileName) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'download_channel',
        'File Download',
        channelDescription: 'Notification channel for file downloads',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0, // Reuse the same ID to replace the previous notification
        'Download Complete',
        '$fileName has been downloaded successfully.',
        platformChannelSpecifics,
      );
    } catch (e) {
      print('Download completion error: $e');
    }
  }

  // Function to download an image
  Future<String?> downloadImage(String url) async {
    try {
      // Get the temporary directory of the device
      final Directory directory = await getTemporaryDirectory();
      // Create a path to save the image
      final String imagePath = '${directory.path}/downloaded_image.png';

      // Create a Dio instance
      final Dio dio = Dio();

      // Download the image and save it to the local path
      await dio.download(url, imagePath);

      // Return the image path
      return imagePath;
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  // Function to show rich notifications with an image
  Future<void> showRichNotification(String imageUrl) async {
    // Download the image from the URL
    final String? imagePath = await downloadImage(imageUrl);

    if (imagePath == null) {
      print('Image path is null, notification not shown');
      return; // Don't show the notification if the image couldn't be downloaded
    }

    // Android-specific settings for rich notification
    final BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
      FilePathAndroidBitmap(imagePath), // Use local file path for Android
      largeIcon: const DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher'), // optional large icon
    );

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'rich_channel_id', // channel id
      'Rich Notifications', // channel name
      channelDescription: 'Channel for rich notifications',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: bigPictureStyleInformation,
    );

    // iOS-specific settings (if needed)
    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      attachments: [DarwinNotificationAttachment(imagePath)],
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique notification ID
      'Rich Notification Example', // title
      'This notification includes an image from a URL.', // body
      platformChannelSpecifics,
      payload: 'payload', // optional payload
    );
  }
}
