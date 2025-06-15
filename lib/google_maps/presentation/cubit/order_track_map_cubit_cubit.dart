import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:live_tracking_app/google_maps/presentation/cubit/order_track_map_cubit_state.dart';
import 'package:live_tracking_app/google_maps/presentation/widgets/custom_cache_network_image.dart';
import 'package:live_tracking_app/google_maps/presentation/widgets/location_services.dart';

class OrderTrackMapCubit extends Cubit<OrderTrackMapState> {
  OrderTrackMapCubit() : super(OrderTrackMapState.initialState);

  final Completer<GoogleMapController> controller = Completer();
  StreamSubscription<Position>? _locationSubscription;
  final CustomInfoWindowController customInfoWindowController =
      CustomInfoWindowController();
  final LatLng destination = const LatLng(30.5979055, 30.8903263);
  bool _snappedOnce = false;
  double initialzoom = 14;
  final Your_API_KEY = '';

  Future<void> initialize() async {
    emit(state.copyWith(status: OrderTrackMapStatus.loading));
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      final currentLocation = LatLng(position.latitude, position.longitude);
      final polylineCoordinates = await _getRoute(currentLocation, destination);
      emit(
        state.copyWith(
          status: OrderTrackMapStatus.loaded,
          currentUserLocation: currentLocation,
          polylineCoordinates: polylineCoordinates,
          passedPolylineCoordinates: [],
        ),
      );
      await _updateMarkersAndPolylines();
      _startTracking();
    } catch (e) {
      emit(
        state.copyWith(
          status: OrderTrackMapStatus.error,
          errorMessage: 'Failed to initialize: $e',
        ),
      );
    }
  }

  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    if (points.isEmpty) return [];
    final path = points.map((p) => '${p.latitude},${p.longitude}').join('|');
    final url =
        'https://roads.googleapis.com/v1/snapToRoads?path=$path&interpolate=true&key=$Your_API_KEY';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final snappedPoints = data['snappedPoints'] as List;
      return snappedPoints
          .map(
            (p) =>
                LatLng(p['location']['latitude'], p['location']['longitude']),
          )
          .toList();
    } else {
      debugPrint('Snap to Road failed: ${response.body}');
      return points;
    }
  }

  Future<List<LatLng>> _getRoute(LatLng origin, LatLng dest) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$Your_API_KEY';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if ((data['routes'] as List).isEmpty) return [];
      final route = data['routes'][0];
      final overviewPolyline = route['overview_polyline']['points'];
      return _decodePolyline(overviewPolyline);
    } else {
      debugPrint('Directions API error: ${response.body}');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;
    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  Future<void> reCenterCamera() async {
    if (state.currentUserLocation == null ||
        state.polylineCoordinates.isEmpty) {
      return;
    }
    final controllerFuture = await controller.future;
    final nextIndex =
        _findClosestPointIndex(
          state.currentUserLocation!,
          state.polylineCoordinates,
        ) +
        1;
    final nextPoint = (nextIndex < state.polylineCoordinates.length)
        ? state.polylineCoordinates[nextIndex]
        : state.polylineCoordinates.last;
    final bearingToNext = Geolocator.bearingBetween(
      state.currentUserLocation!.latitude,
      state.currentUserLocation!.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );
    controllerFuture.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: state.currentUserLocation!,
          zoom: 17.5,
          tilt: 15,
          bearing: bearingToNext,
        ),
      ),
    );
    emit(state.copyWith(zoom: 17.5, tilt: 15));
  }

  void _startTracking() {
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        ).listen((Position? position) async {
          if (position == null) return;
          LatLng newPosition = LatLng(position.latitude, position.longitude);
          if (!_snappedOnce) {
            final snappedPoints = await snapToRoads([newPosition]);
            if (snappedPoints.isNotEmpty) {
              newPosition = snappedPoints.first;
            }
            _snappedOnce = true;
          }
          final bool onRoute = _isOnPolyline(
            newPosition,
            state.polylineCoordinates,
            tolerance: 20,
          );
          List<LatLng> newPolylineCoordinates = state.polylineCoordinates;
          final List<LatLng> newPassedPolylineCoordinates = List.from(
            state.passedPolylineCoordinates,
          );
          if (!onRoute) {
            newPolylineCoordinates = await _getRoute(newPosition, destination);
            final snappedPoints = await snapToRoads([newPosition]);
            if (snappedPoints.isNotEmpty) {
              newPosition = snappedPoints.first;
            }
            newPassedPolylineCoordinates.clear();
          } else {
            final closestIndex = _findClosestPointIndex(
              newPosition,
              state.polylineCoordinates,
            );
            if (closestIndex > 0) {
              newPassedPolylineCoordinates.addAll(
                state.polylineCoordinates.sublist(0, closestIndex),
              );
              newPolylineCoordinates = state.polylineCoordinates.sublist(
                closestIndex,
              );
            } else if (state.currentUserLocation != null) {
              final distance = Geolocator.distanceBetween(
                state.currentUserLocation!.latitude,
                state.currentUserLocation!.longitude,
                newPosition.latitude,
                newPosition.longitude,
              );
              if (distance > 1) {
                final newClosestIndex = _findClosestPointIndex(
                  newPosition,
                  state.polylineCoordinates,
                );
                if (newClosestIndex > 0) {
                  newPassedPolylineCoordinates.addAll(
                    state.polylineCoordinates.sublist(0, newClosestIndex),
                  );
                  newPolylineCoordinates = state.polylineCoordinates.sublist(
                    newClosestIndex,
                  );
                }
              }
            }
          }
          emit(
            state.copyWith(
              currentUserLocation: newPosition,
              heading: position.heading,
              polylineCoordinates: newPolylineCoordinates,
              passedPolylineCoordinates: newPassedPolylineCoordinates,
            ),
          );
          await _updateMarkersAndPolylines();
          final controllerFuture = await controller.future;
          final nextIndex =
              _findClosestPointIndex(
                state.currentUserLocation!,
                state.polylineCoordinates,
              ) +
              1;
          final nextPoint = (nextIndex < state.polylineCoordinates.length)
              ? state.polylineCoordinates[nextIndex]
              : state.polylineCoordinates.last;
          final bearingToNext = Geolocator.bearingBetween(
            state.currentUserLocation!.latitude,
            state.currentUserLocation!.longitude,
            nextPoint.latitude,
            nextPoint.longitude,
          );
          controllerFuture.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: state.currentUserLocation!,
                zoom: state.zoom!,
                tilt: state.tilt!,
                bearing: bearingToNext,
              ),
            ),
          );
        });
  }

  void showOrderInfoWindow() {
    customInfoWindowController.addInfoWindow!(
      _buildInfoWindowContent('Order Location'),
      destination,
    );
  }

  void showUserInfoWindow() {
    if (state.currentUserLocation == null) return;
    customInfoWindowController.addInfoWindow!(
      _buildInfoWindowContent('Your Location'),
      state.currentUserLocation!,
    );
  }

  Widget _buildInfoWindowContent(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomNetworkImage(
              imageUrl:
                  'https://hips.hearstapps.com/hmg-prod/images/classic-cheese-pizza-recipe-2-64429a0cb408b.jpg?crop=0.6666666666666667xw:1xh;center,top&resize=1200:*',
              width: 300,
              fit: BoxFit.cover,
              placeholderWidget: Container(width: 50),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Order ID: #123456'), Text('1 kilometer')],
            ),
            const SizedBox(height: 5),
            const Text('Status: On the way'),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMarkersAndPolylines() async {
    final markerIcon = await LocationServices.getByteFromAsset(
      'assets/images/pngs/order.png',
      50,
    );
    final userMarkerIcon = await LocationServices.getByteFromAsset(
      'assets/images/pngs/truck.png',
      50,
    );
    final newMarkers = <Marker>{
      Marker(
        icon: BitmapDescriptor.bytes(markerIcon),
        markerId: const MarkerId('order_location'),
        position: destination,
        onTap: showOrderInfoWindow,
      ),
      if (state.currentUserLocation != null)
        Marker(
          icon: BitmapDescriptor.bytes(userMarkerIcon),
          markerId: const MarkerId('user_location'),
          position: state.currentUserLocation!,
          onTap: showUserInfoWindow,
        ),
    };
    final newPolylines = <Polyline>{};
    if (state.passedPolylineCoordinates.isNotEmpty) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('passed_route'),
          color: Colors.grey,
          width: 8,
          points: state.passedPolylineCoordinates,
        ),
      );
    }
    if (state.polylineCoordinates.isNotEmpty) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('remaining_route'),
          color: Colors.blue,
          width: 8,
          points: state.polylineCoordinates,
        ),
      );
    }
    emit(state.copyWith(markers: newMarkers, polylines: newPolylines));
  }

  bool _isOnPolyline(
    LatLng point,
    List<LatLng> polyline, {
    double tolerance = 20,
  }) {
    for (int i = 0; i < polyline.length - 1; i++) {
      final distance = _distanceToSegment(point, polyline[i], polyline[i + 1]);
      if (distance <= tolerance) return true;
    }
    return false;
  }

  double _distanceToSegment(LatLng p, LatLng v, LatLng w) {
    final lat = p.latitude;
    final lng = p.longitude;
    final lat1 = v.latitude;
    final lng1 = v.longitude;
    final lat2 = w.latitude;
    final lng2 = w.longitude;
    final l2 = pow(lat2 - lat1, 2) + pow(lng2 - lng1, 2);
    if (l2 == 0) {
      return Geolocator.distanceBetween(lat, lng, lat1, lng1);
    }
    double t =
        ((lat - lat1) * (lat2 - lat1) + (lng - lng1) * (lng2 - lng1)) / l2;
    t = t.clamp(0, 1);
    final projLat = lat1 + t * (lat2 - lat1);
    final projLng = lng1 + t * (lng2 - lng1);
    return Geolocator.distanceBetween(lat, lng, projLat, projLng);
  }

  int _findClosestPointIndex(LatLng point, List<LatLng> points) {
    double minDist = double.infinity;
    int minIndex = 0;
    for (int i = 0; i < points.length; i++) {
      final dist = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (dist < minDist) {
        minDist = dist;
        minIndex = i;
      }
    }
    return minIndex;
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    customInfoWindowController.dispose();
    return super.close();
  }
}
