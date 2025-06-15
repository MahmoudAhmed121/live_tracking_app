import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:live_tracking_app/google_maps/presentation/cubit/order_track_map_cubit_cubit.dart';
import 'package:live_tracking_app/google_maps/presentation/cubit/order_track_map_cubit_state.dart';

class OrderTrackMapScreen extends StatelessWidget {
  const OrderTrackMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrderTrackMapCubit()..initialize(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Track Order'),
          centerTitle: true,
        ),
        body: BlocBuilder<OrderTrackMapCubit, OrderTrackMapState>(
          builder: (context, state) {
            if (state.status == OrderTrackMapStatus.loading ||
                state.currentUserLocation == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == OrderTrackMapStatus.error) {
              return Center(
                child: Text(state.errorMessage ?? 'An error occurred'),
              );
            }
            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: state.currentUserLocation!,
                    zoom: state.zoom!,
                    tilt: state.tilt!,
                    bearing: state.heading ?? 0.0,
                  ),
                  markers: state.markers,
                  polylines: state.polylines,
                  onTap: (position) {
                    context
                        .read<OrderTrackMapCubit>()
                        .customInfoWindowController
                        .hideInfoWindow!();
                  },
                  onCameraMove: (position) {
                    context
                        .read<OrderTrackMapCubit>()
                        .customInfoWindowController
                        .onCameraMove!();
                  },
                  onMapCreated: (controller) {
                    context.read<OrderTrackMapCubit>().controller.complete(
                      controller,
                    );
                    context
                            .read<OrderTrackMapCubit>()
                            .customInfoWindowController
                            .googleMapController =
                        controller;
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                ),
                CustomInfoWindow(
                  controller: context
                      .read<OrderTrackMapCubit>()
                      .customInfoWindowController,
                  height: 220,
                  width: MediaQuery.sizeOf(context).width - 100,
                  offset: 40,
                ),
              ],
            );
          },
        ),
        floatingActionButton:
            BlocBuilder<OrderTrackMapCubit, OrderTrackMapState>(
              builder: (context, state) {
                return FloatingActionButton(
                  onPressed: () =>
                      context.read<OrderTrackMapCubit>().reCenterCamera(),
                  tooltip: 'Re-center',
                  child: const Icon(Icons.center_focus_strong),
                );
              },
            ),
      ),
    );
  }
}
