import MapKit
import SwiftUI

class PointOfInterestAnnotation: NSObject, MKAnnotation {
  let pointOfInterest: PointOfInterest

  init(pointOfInterest: PointOfInterest) {
    self.pointOfInterest = pointOfInterest
  }

  var coordinate: CLLocationCoordinate2D { self.pointOfInterest.coordinate }
  var subtitle: String? { self.pointOfInterest.subtitle }
  var title: String? { self.pointOfInterest.title }
}

struct MapView: UIViewRepresentable {
  let pointsOfInterest: [PointOfInterest]
  @Binding var region: CoordinateRegion?

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView(frame: .zero)
    mapView.showsUserLocation = true
    return mapView
  }

  func updateUIView(_ mapView: MKMapView, context: UIViewRepresentableContext<MapView>) {
    mapView.delegate = context.coordinator

    if let region = self.region {
      mapView.setRegion(region.asMKCoordinateRegion, animated: true)
    }

    mapView.removeAnnotations(mapView.annotations)
    mapView.addAnnotations(
      self.pointsOfInterest.map(PointOfInterestAnnotation.init(pointOfInterest:))
    )
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
