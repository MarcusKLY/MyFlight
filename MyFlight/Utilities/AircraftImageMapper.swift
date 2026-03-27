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
                return "clean_737-800_white_winglets_flying"
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
            return "clean_737-800_white_winglets_flying"
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

    /// List of available aircraft images in MyFlight_App_Assets
    /// This list helps with fuzzy matching when exact names don't match
    private static let availableAircraftImages = Set([
        // Boeing 737
        "clean_737_Max_7_white_flying", "clean_737_Max_8_white_sm_flying", "clean_737-10_MAX_white_flying",
        "clean_737-100_white_flying", "clean_737-100_white_retrofitted_flying", "clean_737-200ADV_white_sm_flying",
        "clean_737-300_white_sm_flying", "clean_737-300SP_white_blended_winglets_sm_flying", "clean_737-400_white_sm_flying",
        "clean_737-400-Combi_white_flying", "clean_737-500_white_blended_winglets_sm_flying", "clean_737-500_white_no_winglets_sm_flying",
        "clean_737-600_white_sm_flying", "clean_737-700_white_flying", "clean_737-700_white_no_winglets_flying",
        "clean_737-700_white_split_scimitar_winglets_flying", "clean_737-800_white_no_winglets_flying",
        "clean_737-800_white_split_scimitar_winglets_flying", "clean_737-800_white_winglets_flying", "clean_737-800BCF_white_flying",
        "clean_737-9_MAX_white_sm_flying", "clean_737-900_white_flying", "clean_737-900er_white_split_scimitar_sm_flying",
        // Boeing 747
        "clean_747-100_white_flying", "clean_747-200_white_GE_painted_engines_flying", "clean_747-200_white_PW_painted_engines_flying",
        "clean_747-200_white_RR_painted_engines_flying", "clean_747-300_white_GE-1_flying", "clean_747-300_white_PW_flying",
        "clean_747-300_white_RR_flying", "clean_747-400_pw_white_flying", "clean_747-400_rr_white_flying",
        "clean_747-400_white_flying", "clean_747-400BCF_white_sm_flying", "clean_747-400F_white_sm_flying",
        "clean_747-8F_white_flying", "clean_747-8i_white_flying", "clean_747SP_white_PW_painted_engines_flying",
        "clean_747SP_white_RR_painted_engines_flying",
        // Boeing 757, 767, 777
        "clean_757-200_rr_white_sm_flying", "clean_757-200_rr_winglets_white_sm_flying", "clean_757-200_white_flying",
        "clean_757-200_white_winglets_flying", "clean_757-200-PF-PCF_white_pw_engines_flying", "clean_757-200-PF-PCF_white_rr_engines_flying",
        "clean_757-200-SF_white_pw_engines_flying", "clean_757-200-SF_white_rr_engines_flying", "clean_757-300_white_winglets_sm_flying",
        "clean_767-200_white_flying", "clean_767-300_no_winglets_white_flying", "clean_767-300_winglets_white_flying",
        "clean_767-300F_no_winglets_white_flying", "clean_767-300F_winglets_white_flying", "clean_767-400_white_flying",
        "clean_777-200_white_flying", "clean_777-300_white_flying", "clean_777-8_folded_wingtips_white_flying",
        "clean_777-8_white_flying", "clean_777-9_folded_wingtips_white_flying", "clean_777-9_white_flying", "clean_777F_white_sm_flying",
        // Boeing 787, 707, 717, 727
        "clean_787-10_white_sm_flying", "clean_787-8_white_flying", "clean_787-9_white_flying",
        "clean_707-320C_painted_engines_white_flying", "clean_707-MAX_white_flying", "clean_717-200_white_sm_flying",
        "clean_727-100_white_flying", "clean_727-200_white_sm_flying",
        // Boeing Other (Cargo, Historic, Concept)
        "clean_797_concept_white_flying",
        // Airbus A300-A400
        "clean_A300-600F_all_white_flying", "clean_A300B4-600R_all_white_flying", "clean_A310-300_white_flying",
        // Airbus A318-A321
        "clean_A318_cfm56_white_sm_flying", "clean_A318_pratt_whitney_white_sm_flying",
        "clean_A319_NEO_Pratt__Whitney_white_sm_flying", "clean_airbus_a319_white_cm56_engines_flying",
        "clean_airbus_a319_white_cm56_engines_sharklets_flying", "clean_airbus_a319_white_v2500_engines_flying",
        "clean_airbus_a319_white_v2500_engines_sharklets_flying",
        // Airbus A320
        "clean_A320_NEO_CFM_LEAP_white_sm_flying", "clean_A320_NEO_Pratt__Whitney_white_sm_flying",
        "clean_a320_white_flying", "clean_a320_white_v2500_flying", "clean_a320_white_with_sharklet_flying",
        "clean_a320_white_with_sharklet_v2500_flying",
        // Airbus A321
        "clean_A321_NEO_CFM_LEAP_white_sm_flying", "clean_A321_NEO_LR_CFM_LEAP_white_sm_flying",
        "clean_A321_NEO_pratt__whitney_white_sm_flying", "clean_A321P2F_white_flying",
        "clean_airbus_a321_white_cm56_engines_flying", "clean_airbus_a321_white_cm56_engines_sharklets_flying",
        "clean_airbus_a321_white_v2500_engines_flying", "clean_airbus_a321_white_v2500_engines_sharklets_flying",
        // Airbus A330
        "clean_A330-200_GE_white_flying", "clean_A330-200_PW_white_flying", "clean_A330-200_RR_white_flying",
        "clean_A330-200F_PW_white_flying", "clean_A330-200F_RR_white_flying", "clean_A330-300_GE_white_flying",
        "clean_A330-300_PW_white_flying", "clean_A330-300_RR_white_flying", "clean_A330-800_NEO_white_sm_flying",
        "clean_A330-900_NEO_white_sm_flying",
        // Airbus A340-A380
        "clean_A340-200_white_flying", "clean_A340-300_white_flying", "clean_A340-300X_white_flying",
        "clean_A340-500_white_sm_flying", "clean_A340-600_white_sm_flying",
        "clean_A350-1000_white_flying", "clean_A350-800_white_flying", "clean_A350-900_white_flying",
        "clean_A350F_white_flying", "clean_A380-800_white_flying",
        // Regional & Other
        "clean_ATR_42_white_sm_flying", "clean_ATR_72_white_sm_flying", "clean_BAC-Concorde_white_flying",
        "clean_BAe_146-200_Avro_RJ85_white_flying", "clean_Beechcraft_King_Air_B200_white_flying",
        "clean_Beechcraft-1900D-white_flying", "clean_C-17_white_flying", "clean_C909_white_flying",
        "clean_C919_white_flying", "clean_Cessna_Citation_X_white_flying", "clean_Cessna_Citation_X_with_winglets_white_flying",
        "clean_CRJ-1000_white_flying", "clean_CRJ-200_white_small_flying", "clean_CRJ-700_template_white_flying",
        "clean_CRJ-900_white_sm_flying", "clean_CS100_white_flying", "clean_CS300_white_flying",
        "clean_dassault_falcon_50_white_flying", "clean_dassault-falcon-50_winglets_white_flying",
        "clean_DC-10-30_white_flying", "clean_DC-10-30F_MD-10_white_flying", "clean_DC-3_white_flying",
        "clean_DC-4_white_flying", "clean_DC-8-53_white_flying", "clean_DC-8-61_white_flying",
        "clean_DC-8-73_white_flying", "clean_DC-8-73CF_white_flying", "clean_DC-9-30_white_flying",
        "clean_DC-9-40_white_flying", "clean_DC-9-50_white_flying", "clean_DHC-8-200_white_sm_flying",
        "clean_DHC-8-300_white_flying", "clean_Dornier_328-110_white_sm_flying", "clean_EMB-120_white_flying",
        "clean_ERJ-135_white_flying", "clean_ERJ-140_white_flying", "clean_ERJ-145_white_flying",
        "clean_ERJ-145XR_white_sm_flying", "clean_ERJ-175_white_1024_flying", "clean_ERJ-175_white_new_winglet_flying",
        "clean_ERJ-190_white_flying", "clean_ERJ-190-E2_white_flying", "clean_ERJ-195_white_flying",
        "clean_ERJ-195-E2_white_flying", "clean_Fokker_100_white_sm_flying", "clean_Fokker_70_white_flying",
        "clean_Global_7500_white_flying", "clean_Global-5000_white_flying", "clean_Gulfstream_G650ER_white_flying",
        "clean_Irkut-MC-21-300-white_flying", "clean_Jetstream-41_white_flying", "clean_L-1011-1_white_flying",
        "clean_L-1011-500_white_flying", "clean_Learjet-45-white_flying", "clean_Learjet-60-white_flying",
        "clean_MD-11_all_white_flying", "clean_MD-11F_all_white_flying", "clean_MD-80_white_flying",
        "clean_MD-87_white_flying", "clean_MD-90_white_sm_flying", "clean_Q400_white_flying",
        "clean_Saab_340B_white_flying", "clean_short_360_white_flying", "clean_ssj_100_white_flying",
        "clean_Tu-154M_white_flying", "clean_Tu-204-100_white_flying"
    ])

    /// Try to find an existing variant when exact match fails
    /// - Parameters:
    ///   - baseName: Base image name (e.g., "clean_737-800_white_flying")
    /// - Returns: An available variant if found, nil otherwise
    private static func findAvailableVariant(baseName: String) -> String? {
        // If exact match exists, return it
        if availableAircraftImages.contains(baseName) {
            return baseName
        }

        // Extract base pattern (e.g., "clean_737-800_white" from "clean_737-800_white_flying")
        let components = baseName.split(separator: "_").map(String.init)
        guard components.count >= 3 else { return nil }

        // Try to find variants by matching the base pattern
        let basePattern = components.dropLast().joined(separator: "_") // Remove "flying"
        let variants = availableAircraftImages.filter { $0.hasPrefix(basePattern) }

        if !variants.isEmpty {
            // Prefer variants with fewer modifiers
            let sorted = variants.sorted { a, b in
                a.count < b.count // Shorter names have fewer modifiers
            }
            return sorted.first
        }

        return nil
    }

    /// Load aircraft silhouette image from Assets/MyFlight_App_Assets folder
    /// Tries Asset catalog first, then falls back to direct filesystem access,
    /// with fuzzy matching for variants when exact names don't match
    /// - Parameters:
    ///   - assetName: Asset name without extension (e.g., "clean_a320_white_flying")
    /// - Returns: UIImage if found, nil otherwise
    static func loadAircraftImage(_ assetName: String) -> UIImage? {
        var nameToTry = assetName

        // Try Asset catalog first (if images are converted to .imageset later)
        if let image = UIImage(named: assetName) {
            print("[AircraftImageMapper.loadAircraftImage] ✅ Found in Asset catalog: '\(assetName)'")
            return image
        }

        // Try to find an available variant if exact match failed
        let variant = findAvailableVariant(baseName: assetName)
        if let availableVariant = variant {
            nameToTry = availableVariant
            print("[AircraftImageMapper.loadAircraftImage] Found variant: '\(availableVariant)' (requested: '\(assetName)')")
        }

        // Fallback: Load from MyFlight_App_Assets folder directly via filesystem
        if let url = Bundle.main.url(
            forResource: nameToTry,
            withExtension: "png",
            subdirectory: "MyFlight_App_Assets.xcassets/MyFlight_App_Assets"
        ) {
            print("[AircraftImageMapper.loadAircraftImage] ✅ Found via filesystem: '\(nameToTry)' at \(url.lastPathComponent)")
            return UIImage(contentsOfFile: url.path)
        }

        print("[AircraftImageMapper.loadAircraftImage] ❌ NOT found: '\(assetName)' (tried variant: '\(nameToTry)')")
        return nil
    }
}
