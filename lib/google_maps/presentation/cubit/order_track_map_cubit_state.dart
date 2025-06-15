import 'package:google_maps_flutter/google_maps_flutter.dart';

enum OrderTrackMapStatus { initial, loading, loaded, error }

class OrderTrackMapState {
  final OrderTrackMapStatus status;
  final LatLng? currentUserLocation;
  final double? heading;
  final List<LatLng> polylineCoordinates;
  final List<LatLng> passedPolylineCoordinates;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final String? errorMessage;
  final double? zoom;
  final double? tilt;


  const OrderTrackMapState({
    required this.status,
    required this.currentUserLocation,
    required this.heading,
    required this.polylineCoordinates,
    required this.passedPolylineCoordinates,
    required this.markers,
    required this.polylines,
    required this.errorMessage,
    required this.zoom,
    required this.tilt,
    
  });

  static OrderTrackMapState initialState = const OrderTrackMapState(
    status: OrderTrackMapStatus.initial,
    currentUserLocation: null,
    heading: 0.0,
    polylineCoordinates: [],
    passedPolylineCoordinates: [],
    markers: {},
    polylines: {},
    errorMessage:'', zoom: 14.0, tilt: 0.0, 
    
  );

  OrderTrackMapState copyWith({
    OrderTrackMapStatus? status,
    LatLng? currentUserLocation,
    double? heading,
    List<LatLng>? polylineCoordinates,
    List<LatLng>? passedPolylineCoordinates,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    String? errorMessage,
    double? zoom,
    double? tilt,
  
  }) {
    return OrderTrackMapState(
      status: status ?? this.status,
      currentUserLocation: currentUserLocation ?? this.currentUserLocation,
      heading: heading ?? this.heading,
      polylineCoordinates: polylineCoordinates ?? this.polylineCoordinates,
      passedPolylineCoordinates:
          passedPolylineCoordinates ?? this.passedPolylineCoordinates,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      errorMessage: errorMessage ?? this.errorMessage,
      zoom: zoom ?? this.zoom,
      tilt: tilt ?? this.tilt,
     
    );
  }
}
