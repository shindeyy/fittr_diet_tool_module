import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fittr_network_module/core/logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import '../../utils/notifications.dart';
import 'diet_item_details_screen.dart';
import 'dart:async';
import 'package:fittr_network_module/src/api/api_service.dart';
import 'package:fittr_network_module/src/api/api_service_diet_tool.dart';
import 'package:fittr_network_module/src/api/endpoints.dart';
import 'package:fittr_network_module/src/repositories/diet_tool_repository.dart';
import 'package:fittr_network_module/src/repositories/item_repository_impl.dart';
import 'package:fittr_network_module/src/usecases/get_item_details_usecase.dart';
import 'package:fittr_network_module/src/usecases/get_item_list_usecase.dart';
import 'package:fittr_network_module/src/api/env_constants.dart';
import 'package:fittr_network_module/src/bloc/diet_item_bloc.dart';
import 'package:fittr_network_module/src/bloc/diet_item_event.dart';
import 'package:fittr_network_module/src/repositories/register_dependency.dart';

void main() {
  // Use the appropriate environment here
  RegisterDependencies().setupDependencies(AppEnvironments.sit4);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fittr Diet Tool',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ItemListScreen(), // Your initial screen
    );
  }
}

class ItemListScreen extends StatelessWidget {
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController _scrollController = ScrollController();
    final bloc = GetIt.I<DietItemBloc>();
    Timer? _debounce; // Timer for debounce effect

    // Initial page load and scroll listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bloc.add(FetchItemList());

      _scrollController.addListener(() {
        // Check if we're at the bottom of the list
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100) {
          // Fetch the next page only if the current state is not loading
          if (bloc.state is! ItemLoading) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (bloc.state is ItemLoaded && bloc.hasMoreItems) {
                print("Fetching next page..."); // Debug statement
                bloc.add(FetchItemList()); // Load next page
              }
            });
          }
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Item List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_add_sharp),
            onPressed: () async {
              Notifications notifications = Notifications();
              await notifications.initNotificationsConfig();
              notifications
                  .showRichNotification('https://picsum.photos/id/1/200/300');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              bloc.add(ResetItemList()); // Reset the list when refreshing
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              Notifications notifications = Notifications();
              await notifications.initNotificationsConfig();
              notifications.downloadFile(
                  'https://www.aeee.in/wp-content/uploads/2020/08/Sample-pdf.pdf',
                  'sample_downloaded_file.pdf'); // Download file by url
            },
          ),
        ],
      ),
      body: BlocProvider(
        create: (_) => bloc,
        child: BlocBuilder<DietItemBloc, ItemState>(
          builder: (context, state) {
            if (state is ItemLoading && state is! ItemLoaded) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ItemLoaded) {
              // Check if initial load items fit less than half the screen
              if (state.items.length <= 10) {
                // Automatically fetch next page if the first page doesn't fill the screen
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  bloc.add(FetchItemList());
                });
              }

              return ListView.builder(
                controller: _scrollController,
                itemCount: state.items.length +
                    (bloc.hasMoreItems
                        ? 1
                        : 0), // Extra item for pagination loading indicator
                itemBuilder: (context, index) {
                  if (index < state.items.length) {
                    final item = state.items[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20.0),
                      title: Row(
                        children: [
                          // Image loading with placeholder
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              item.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image, size: 50);
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${item.quantity}${item.unit} | ${item.macros.calories}kcal',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(
                                          top: 2,
                                          bottom: 2,
                                          left: 4,
                                          right:
                                              4), // Adjust the padding as needed
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .grey, // Set your desired background color
                                        borderRadius: BorderRadius.circular(
                                            5), // Rounded corners with 10px radius
                                      ),
                                      child: Text(
                                        'P: ${item.macros.protein}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white), // Text color
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.only(
                                          top: 2,
                                          bottom: 2,
                                          left: 4,
                                          right:
                                              4), // Adjust the padding as needed
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .grey, // Set your desired background color
                                        borderRadius: BorderRadius.circular(
                                            5), // Rounded corners with 10px radius
                                      ),
                                      child: Text(
                                        'C: ${item.macros.carbs}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white), // Text color
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.only(
                                          top: 2,
                                          bottom: 2,
                                          left: 4,
                                          right:
                                              4), // Adjust the padding as needed
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .grey, // Set your desired background color
                                        borderRadius: BorderRadius.circular(
                                            5), // Rounded corners with 10px radius
                                      ),
                                      child: Text(
                                        'F: ${item.macros.fats}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white), // Text color
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ItemDetailsScreen(id: item.id),
                          ),
                        );
                      },
                    );
                  } else {
                    // Show loading indicator at the end of the list if more items are expected
                    return Container(
                        padding: const EdgeInsets.all(16),
                        child:
                            const Center(child: CircularProgressIndicator()));
                  }
                },
              );
            } else if (state is ItemError) {
              return Center(child: Text('Error: ${state.message}'));
            } else {
              return const Center(child: Text('No items found.'));
            }
          },
        ),
      ),
    );
  }
}
