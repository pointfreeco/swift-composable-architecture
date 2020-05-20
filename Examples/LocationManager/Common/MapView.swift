import MapKit
import SwiftUI

#if os(macOS)
  public typealias ViewRepresentable = NSViewRepresentable
#elseif os(iOS)
  public typealias ViewRepresentable = UIViewRepresentable
#endif

public struct MapView: ViewRepresentable {
  let pointsOfInterest: [PointOfInterest]
  @Binding var region: CoordinateRegion?

  public init(
    pointsOfInterest: [PointOfInterest],
    region: Binding<CoordinateRegion?>
  ) {
    self.pointsOfInterest = pointsOfInterest
    self._region = region
  }

  #if os(macOS)
    public func makeNSView(context: Context) -> MKMapView {
      self.makeView(context: context)
    }
  #elseif os(iOS)
    public func makeUIView(context: Context) -> MKMapView {
      self.makeView(context: context)
    }
  #endif

  #if os(macOS)
    public func updateNSView(_ mapView: MKMapView, context: NSViewRepresentableContext<MapView>) {
      self.updateView(mapView: mapView, delegate: context.coordinator)
    }
  #elseif os(iOS)
    public func updateUIView(_ mapView: MKMapView, context: Context) {
      self.updateView(mapView: mapView, delegate: context.coordinator)
    }
  #endif

  public func makeCoordinator() -> MapViewCoordinator {
    MapViewCoordinator(self)
  }
  private func makeView(context: Context) -> MKMapView {
    let mapView = MKMapView(frame: .zero)
    mapView.showsUserLocation = true
    return mapView
  }

  private func updateView(mapView: MKMapView, delegate: MKMapViewDelegate) {
    mapView.delegate = delegate

    if let region = self.region {
      mapView.setRegion(region.asMKCoordinateRegion, animated: true)
    }

    let currentlyDisplayedPOIs = mapView.annotations.compactMap { $0 as? PointOfInterestAnnotation }
      .map { $0.pointOfInterest }

    let addedPOIs = Set(pointsOfInterest).subtracting(currentlyDisplayedPOIs)
    let removedPOIs = Set(currentlyDisplayedPOIs).subtracting(pointsOfInterest)

    let addedAnnotations = addedPOIs.map(PointOfInterestAnnotation.init(pointOfInterest:))
    let removedAnnotations = mapView.annotations.compactMap { $0 as? PointOfInterestAnnotation }
      .filter { removedPOIs.contains($0.pointOfInterest) }

    mapView.removeAnnotations(removedAnnotations)
    mapView.addAnnotations(addedAnnotations)
  }
}

private class PointOfInterestAnnotation: NSObject, MKAnnotation {
  let pointOfInterest: PointOfInterest

  init(pointOfInterest: PointOfInterest) {
    self.pointOfInterest = pointOfInterest
  }

  var coordinate: CLLocationCoordinate2D { self.pointOfInterest.coordinate }
  var subtitle: String? { self.pointOfInterest.subtitle }
  var title: String? { self.pointOfInterest.title }
}

public class MapViewCoordinator: NSObject, MKMapViewDelegate {
  var mapView: MapView

  init(_ control: MapView) {
    self.mapView = control
  }

  public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    self.mapView.region = CoordinateRegion(coordinateRegion: mapView.region)
  }
}
