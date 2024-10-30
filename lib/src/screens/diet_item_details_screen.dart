import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:fittr_network_module/src/bloc/diet_item_bloc.dart';
import 'package:fittr_network_module/src/bloc/diet_item_event.dart';

class ItemDetailsScreen extends StatelessWidget {
  final int id;

  const ItemDetailsScreen({Key? key, required this.id}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: BlocProvider(
        create: (_) => GetIt.I<DietItemBloc>()..add(FetchItemDetails(id)),
        child: BlocBuilder<DietItemBloc, ItemState>(
          builder: (context, state) {
            if (state is ItemLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ItemDetailsLoaded) {
              final item = state.itemDetails;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${item.name}',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 16),
                    Text('Details: ${item.name}',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              );
            } else if (state is ItemError) {
              return Center(child: Text('Error: ${state.message}'));
            } else {
              return const Center(child: Text('Item not found.'));
            }
          },
        ),
      ),
    );
  }
}
