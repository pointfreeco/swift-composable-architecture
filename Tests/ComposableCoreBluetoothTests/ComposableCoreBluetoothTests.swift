import ComposableCoreBluetooth
import XCTest

class ComposableCoreBluetooth: XCTestCase {
    
    func testMockHasDefaultsForAllEndpoints() {
        _ = BluetoothManager.mock()
    }
    
}
