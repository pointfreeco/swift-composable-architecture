import MapKit
import SwiftUI

struct MapView: UIViewRepresentable {

  @Binding var region: CoordinateRegion?

  func makeUIView(context: Context) -> MKMapView{
    let mapView = MKMapView(frame: .zero)
    mapView.showsUserLocation = true;
    return mapView
  }

  func updateUIView(_ uiView: MKMapView, context: UIViewRepresentableContext<MapView>) {
    uiView.delegate = context.coordinator

    if let region = self.region {
      uiView.setRegion(region.asMKCoordinateRegion, animated: true)
    }
  }

  func makeCoordinator() -> MapViewCoordinator {
      MapViewCoordinator(self)
  }
}

class MapViewCoordinator: NSObject, MKMapViewDelegate {
  var mapView: MapView

  init(_ control: MapView) {
    self.mapView = control
  }

  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    self.mapView.region = CoordinateRegion(coordinateRegion: mapView.region)
  }
}
