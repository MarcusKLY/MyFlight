import Foundation
import UIKit

struct AircraftImageMapper {
    /// Robust fuzzy matching: accepts multiple data points for aircraft identification
    /// Maps aircraft model strings to existing asset names in the catalog.
    /// - Parameters:
    ///   - model: Aircraft model string (e.g., "Boeing 777-300ER", "B777-367ER")
    ///   - typeName: Aircraft type name (e.g., "Triple Seven")
    ///   - modelCode: IATA/ICAO code (e.g., "B777")
    /// - Returns: Asset name that exists in Assets.xcassets/MyFlight_App_Assets/
    static func getImageName(model: String?, typeName: String?, modelCode: String?) -> String {
        // Combine all available data into one searchable string
        let searchString = [model, typeName, modelCode]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        guard !searchString.isEmpty else {
            print("[AircraftImageMapper] Empty input")
            return ""
        }

        print("[AircraftImageMapper] searchString: '\(searchString)'")

        // BOEING AIRCRAFT - Check variants first, then family fallback
        if searchString.contains("777") {
            if searchString.contains("300") {
                print("[AircraftImageMapper] Matched: 777-300")
                return "clean_777-300_white_flying"
            }
            if searchString.contains("200") {
                print("[AircraftImageMapper] Matched: 777-200")
                return "clean_777-200_white_flying"
            }
            if searchString.contains("8") || searchString.contains("9") {
                let variant = searchString.contains("9") ? "9" : "8"
                print("[AircraftImageMapper] Matched: 777-\(variant)")
                return "clean_777-\(variant)_white_flying"
            }
            print("[AircraftImageMapper] Matched: 777 family")
            return "clean_777-300_white_flying"
        }

        if searchString.contains("787") {
            if searchString.contains("10") {
                print("[AircraftImageMapper] Matched: 787-10")
                return "clean_787-10_white_sm_flying"
            }
            if searchString.contains("9") {
                print("[AircraftImageMapper] Matched: 787-9")
                return "clean_787-9_white_flying"
            }
            if searchString.contains("8") {
                print("[AircraftImageMapper] Matched: 787-8")
                return "clean_787-8_white_flying"
            }
            print("[AircraftImageMapper] Matched: 787 family")
            return "clean_787-9_white_flying"
        }

        if searchString.contains("747") {
            if searchString.contains("400") {
                print("[AircraftImageMapper] Matched: 747-400")
                return "clean_747-400_white_flying"
            }
            if searchString.contains("8") {
                print("[AircraftImageMapper] Matched: 747-8")
                return "clean_747-8i_white_flying"
            }
            print("[AircraftImageMapper] Matched: 747 family")
            return "clean_747-400_white_flying"
        }

        if searchString.contains("737") {
            if searchString.contains("max") {
                print("[AircraftImageMapper] Matched: 737 MAX")
                return "clean_737_Max_8_white_sm_flying"
            }
            if searchString.contains("800") {
                print("[AircraftImageMapper] Matched: 737-800")
                return "clean_737-800_white_flying"
            }
            if searchString.contains("700") {
                print("[AircraftImageMapper] Matched: 737-700")
                return "clean_737-700_white_flying"
            }
            if searchString.contains("900") {
                print("[AircraftImageMapper] Matched: 737-900")
                return "clean_737-900_white_flying"
            }
            if searchString.contains("600") {
                print("[AircraftImageMapper] Matched: 737-600")
                return "clean_737-600_white_sm_flying"
            }
            print("[AircraftImageMapper] Matched: 737 family")
            return "clean_737-800_white_flying"
        }

        if searchString.contains("757") {
            print("[AircraftImageMapper] Matched: 757")
            return "clean_757-200_white_flying"
        }
        if searchString.contains("767") {
            print("[AircraftImageMapper] Matched: 767")
            return "clean_767-300_winglets_white_flying"
        }

        // AIRBUS AIRCRAFT - Variants first
        if searchString.contains("a380") {
            print("[AircraftImageMapper] Matched: A380")
            return "clean_A380-800_white_flying"
        }

        if searchString.contains("a350") {
            if searchString.contains("1000") {
                print("[AircraftImageMapper] Matched: A350-1000")
                return "clean_A350-1000_white_flying"
            }
            print("[AircraftImageMapper] Matched: A350 family")
            return "clean_A350-900_white_flying"
        }

        if searchString.contains("a330") {
            if searchString.contains("300") {
                print("[AircraftImageMapper] Matched: A330-300")
                return "clean_A330-300_GE_white_flying"
            }
            if searchString.contains("200") {
                print("[AircraftImageMapper] Matched: A330-200")
                return "clean_A330-200_GE_white_flying"
            }
            print("[AircraftImageMapper] Matched: A330 family")
            return "clean_A330-300_GE_white_flying"
        }

        if searchString.contains("a320") {
            if searchString.contains("neo") {
                print("[AircraftImageMapper] Matched: A320 NEO")
                return "clean_A320_NEO_CFM_LEAP_white_sm_flying"
            }
            print("[AircraftImageMapper] Matched: A320")
            return "clean_a320_white_flying"
        }

        if searchString.contains("a321") {
            if searchString.contains("neo") {
                print("[AircraftImageMapper] Matched: A321 NEO")
                return "clean_A321_NEO_CFM_LEAP_white_sm_flying"
            }
            print("[AircraftImageMapper] Matched: A321")
            return "clean_airbus_a321_white_cm56_engines_flying"
        }

        if searchString.contains("a319") {
            print("[AircraftImageMapper] Matched: A319")
            return "clean_airbus_a319_white_cm56_engines_flying"
        }

        // REGIONAL AIRCRAFT
        if searchString.contains("e190") {
            print("[AircraftImageMapper] Matched: ERJ-190")
            return "clean_ERJ-190_white_flying"
        }
        if searchString.contains("e175") {
            print("[AircraftImageMapper] Matched: ERJ-175")
            return "clean_ERJ-175_white_1024_flying"
        }
        if searchString.contains("crj") {
            if searchString.contains("700") {
                print("[AircraftImageMapper] Matched: CRJ-700")
                return "clean_CRJ-700_template_white_flying"
            }
            print("[AircraftImageMapper] Matched: CRJ family")
            return "clean_CRJ-700_template_white_flying"
        }
        if searchString.contains("atr") {
            if searchString.contains("72") {
                print("[AircraftImageMapper] Matched: ATR-72")
                return "clean_ATR_72_white_sm_flying"
            }
            print("[AircraftImageMapper] Matched: ATR family")
            return "clean_ATR_72_white_sm_flying"
        }

        // No match found - return empty string to trigger SF Symbol fallback
        print("[AircraftImageMapper] No match found")
        return ""
    }

    /// Load aircraft silhouette image from Assets/MyFlight_App_Assets folder
    /// Tries Asset catalog first, then falls back to direct filesystem access
    /// - Parameters:
    ///   - assetName: Asset name without extension (e.g., "clean_a320_white_flying")
    /// - Returns: UIImage if found, nil otherwise
    static func loadAircraftImage(_ assetName: String) -> UIImage? {
        // Try Asset catalog first (if images are converted to .imageset later)
        if let image = UIImage(named: assetName) {
            print("[AircraftImageMapper.loadAircraftImage] ✅ Found in Asset catalog: '\(assetName)'")
            return image
        }

        // Fallback: Load from MyFlight_App_Assets folder directly via filesystem
        if let url = Bundle.main.url(
            forResource: assetName,
            withExtension: "png",
            subdirectory: "MyFlight_App_Assets.xcassets/MyFlight_App_Assets"
        ) {
            print("[AircraftImageMapper.loadAircraftImage] ✅ Found via filesystem: '\(assetName)' at \(url.lastPathComponent)")
            return UIImage(contentsOfFile: url.path)
        }

        print("[AircraftImageMapper.loadAircraftImage] ❌ NOT found: '\(assetName)'")
        return nil
    }
}
