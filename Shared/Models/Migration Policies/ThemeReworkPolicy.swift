//
//  ThemeReworkPolicy.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/2/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

let errorDomain = "Migration"

class ThemeReworkPolicy: NSEntityMigrationPolicy {
    typealias Colors = (lightSeparatorHex: String,
                        lightSecondarySystemBackgroundHex: String,
                        lightTertiarySystemBackgroundHex: String,
                        lightSystemGroupedBackgroundHex: String,
                        lightSystemFillHex: String,
                        lightSecondarySystemFillHex: String,
                        darkSeparatorHex: String,
                        darkSecondarySystemBackgroundHex: String,
                        darkTertiarySystemBackgroundHex: String,
                        darkSystemGroupedBackgroundHex: String,
                        darkSystemFillHex: String,
                        darkSecondarySystemFillHex: String)

    // swiftlint:disable function_body_length
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager) throws {
        let description = NSEntityDescription.entity(forEntityName: "Theme", in: manager.destinationContext)

        let newTheme = Theme(entity: description!, insertInto: manager.destinationContext)

        try self.traversePropertyMappings(mapping) { propertyMapping, destinationName in
            if let valueExpression = propertyMapping.valueExpression {
                let context: NSMutableDictionary = ["source": sInstance]
                guard let destinationValue = valueExpression.expressionValue(with: sInstance, context: context) else { return }

                newTheme.setValue(destinationValue, forKey: destinationName)
            }
        }

        let themeTitle = sInstance.value(forKeyPath: "title") as? String ?? "Default / Dark"

        let colors = self.getMissingValues(for: themeTitle)

        newTheme.setValue(colors.lightSeparatorHex, forKey: "lightSeparatorHex")
        newTheme.setValue(colors.lightSecondarySystemBackgroundHex, forKey: "lightSecondarySystemBackgroundHex")
        newTheme.setValue(colors.lightTertiarySystemBackgroundHex, forKey: "lightTertiarySystemBackgroundHex")
        newTheme.setValue(colors.lightSystemGroupedBackgroundHex, forKey: "lightSystemGroupedBackgroundHex")
        newTheme.setValue(colors.lightSystemFillHex, forKey: "lightSystemFillHex")
        newTheme.setValue(colors.lightSecondarySystemFillHex, forKey: "lightSecondarySystemFillHex")
        newTheme.setValue(colors.darkSeparatorHex, forKey: "darkSeparatorHex")
        newTheme.setValue(colors.darkSecondarySystemBackgroundHex, forKey: "darkSecondarySystemBackgroundHex")
        newTheme.setValue(colors.darkTertiarySystemBackgroundHex, forKey: "darkTertiarySystemBackgroundHex")
        newTheme.setValue(colors.darkSystemGroupedBackgroundHex, forKey: "darkSystemGroupedBackgroundHex")
        newTheme.setValue(colors.darkSystemFillHex, forKey: "darkSystemFillHex")
        newTheme.setValue(colors.darkSecondarySystemFillHex, forKey: "darkSecondarySystemFillHex")

        manager.associate(sourceInstance: sInstance,
                          withDestinationInstance: newTheme,
                          for: mapping)
    }

    func getMissingValues(for themeTitle: String) -> Colors {
        let lightSeparatorHex: String
        let lightSecondarySystemBackgroundHex: String
        let lightTertiarySystemBackgroundHex: String
        let lightSystemGroupedBackgroundHex: String
        let lightSystemFillHex: String
        let lightSecondarySystemFillHex: String
        let darkSeparatorHex: String
        let darkSecondarySystemBackgroundHex: String
        let darkTertiarySystemBackgroundHex: String
        let darkSystemGroupedBackgroundHex: String
        let darkSystemFillHex: String
        let darkSecondarySystemFillHex: String

        switch themeTitle {
        case "Default / Pure Black":
            lightSeparatorHex = "DCDCDC"
            lightSecondarySystemBackgroundHex = "FCFBFC"
            lightTertiarySystemBackgroundHex = "E8E7E9"
            lightSystemGroupedBackgroundHex = "EFEEF0"
            lightSystemFillHex = "87A0BA"
            lightSecondarySystemFillHex = "ACAAB1"
            darkSeparatorHex = "2F3032"
            darkSecondarySystemBackgroundHex = "000001"
            darkTertiarySystemBackgroundHex = "181818"
            darkSystemGroupedBackgroundHex = "0E0E0F"
            darkSystemFillHex = "5E7792"
            darkSecondarySystemFillHex = "68666B"
        case "Ayu":
            lightSeparatorHex = "E2E4E4"
            lightSecondarySystemBackgroundHex = "FCFCFC"
            lightTertiarySystemBackgroundHex = "EAEAEB"
            lightSystemGroupedBackgroundHex = "F1F1F1"
            lightSystemFillHex = "D9BAA0"
            lightSecondarySystemFillHex = "B5B9BC"
            darkSeparatorHex = "343D49"
            darkSecondarySystemBackgroundHex = "101419"
            darkTertiarySystemBackgroundHex = "2D3440"
            darkSystemGroupedBackgroundHex = "292F3A"
            darkSystemFillHex = "7C745C"
            darkSecondarySystemFillHex = "545E6B"
        case "Vintage":
            lightSeparatorHex = "D2CDC1"
            lightSecondarySystemBackgroundHex = "F8F6F2"
            lightTertiarySystemBackgroundHex = "DED9CF"
            lightSystemGroupedBackgroundHex = "E5E1D8"
            lightSystemFillHex = "859692"
            lightSecondarySystemFillHex = "A09985"
            darkSeparatorHex = "3E3A2E"
            darkSecondarySystemBackgroundHex = "13110F"
            darkTertiarySystemBackgroundHex = "342F25"
            darkSystemGroupedBackgroundHex = "2F2B22"
            darkSystemFillHex = "5D6D67"
            darkSecondarySystemFillHex = "5F5843"
        case "Sepia":
            lightSeparatorHex = "CFCAB8"
            lightSecondarySystemBackgroundHex = "F6F4EC"
            lightTertiarySystemBackgroundHex = "DBD7C4"
            lightSystemGroupedBackgroundHex = "E3DFCC"
            lightSystemFillHex = "A79166"
            lightSecondarySystemFillHex = "9E9883"
            darkSeparatorHex = "3D382D"
            darkSecondarySystemBackgroundHex = "13120E"
            darkTertiarySystemBackgroundHex = "342F26"
            darkSystemGroupedBackgroundHex = "2F2A22"
            darkSystemFillHex = "7E7052"
            darkSecondarySystemFillHex = "5D5744"
        case "Sky":
            lightSeparatorHex = "E0E1E2"
            lightSecondarySystemBackgroundHex = "FCFCFC"
            lightTertiarySystemBackgroundHex = "E9EAEA"
            lightSystemGroupedBackgroundHex = "EFF1F1"
            lightSystemFillHex = "88B3BF"
            lightSecondarySystemFillHex = "B5B9BC"
            darkSeparatorHex = "525C61"
            darkSecondarySystemBackgroundHex = "0F1719"
            darkTertiarySystemBackgroundHex = "3B464D"
            darkSystemGroupedBackgroundHex = "313C43"
            darkSystemFillHex = "84A3AB"
            darkSecondarySystemFillHex = "93979A"
        case "Duotone Heat":
            lightSeparatorHex = "DBDCDE"
            lightSecondarySystemBackgroundHex = "FBFCFB"
            lightTertiarySystemBackgroundHex = "E6E6E7"
            lightSystemGroupedBackgroundHex = "EEEDF0"
            lightSystemFillHex = "A38AA5"
            lightSecondarySystemFillHex = "A6A6A8"
            darkSeparatorHex = "53576A"
            darkSecondarySystemBackgroundHex = "161724"
            darkTertiarySystemBackgroundHex = "42445A"
            darkSystemGroupedBackgroundHex = "383A53"
            darkSystemFillHex = "8E7C9B"
            darkSecondarySystemFillHex = "878B99"
        case "Forest":
            lightSeparatorHex = "DCDBDD"
            lightSecondarySystemBackgroundHex = "FCFCFC"
            lightTertiarySystemBackgroundHex = "E8E6E8"
            lightSystemGroupedBackgroundHex = "EEEEEF"
            lightSystemFillHex = "81A289"
            lightSecondarySystemFillHex = "ABABB0"
            darkSeparatorHex = "454A4D"
            darkSecondarySystemBackgroundHex = "121615"
            darkTertiarySystemBackgroundHex = "353C3D"
            darkSystemGroupedBackgroundHex = "2E3535"
            darkSystemFillHex = "6C8776"
            darkSecondarySystemFillHex = "717377"
        case "Barbershop":
            lightSeparatorHex = "DFE1E5"
            lightSecondarySystemBackgroundHex = "FCFCFC"
            lightTertiarySystemBackgroundHex = "E9EAEC"
            lightSystemGroupedBackgroundHex = "F0F0F1"
            lightSystemFillHex = "C09BA0"
            lightSecondarySystemFillHex = "B0BAC3"
            darkSeparatorHex = "28426D"
            darkSecondarySystemBackgroundHex = "040E28"
            darkTertiarySystemBackgroundHex = "17315F"
            darkSystemGroupedBackgroundHex = "122858"
            darkSystemFillHex = "7D6C86"
            darkSecondarySystemFillHex = "547096"
        default:
            lightSeparatorHex = "DCDCDC"
            lightSecondarySystemBackgroundHex = "FCFBFC"
            lightTertiarySystemBackgroundHex = "E8E7E9"
            lightSystemGroupedBackgroundHex = "EFEEF0"
            lightSystemFillHex = "87A0BA"
            lightSecondarySystemFillHex = "ACAAB1"
            darkSeparatorHex = "434448"
            darkSecondarySystemBackgroundHex = "111113"
            darkTertiarySystemBackgroundHex = "333538"
            darkSystemGroupedBackgroundHex = "2C2D30"
            darkSystemFillHex = "647E98"
            darkSecondarySystemFillHex = "707176"
        }

        return (lightSeparatorHex,
                lightSecondarySystemBackgroundHex,
                lightTertiarySystemBackgroundHex,
                lightSystemGroupedBackgroundHex,
                lightSystemFillHex,
                lightSecondarySystemFillHex,
                darkSeparatorHex,
                darkSecondarySystemBackgroundHex,
                darkTertiarySystemBackgroundHex,
                darkSystemGroupedBackgroundHex,
                darkSystemFillHex,
                darkSecondarySystemFillHex)
    }
}

extension NSEntityMigrationPolicy {
    func traversePropertyMappings(_ mapping: NSEntityMapping, block: (NSPropertyMapping, String) -> Void) throws {
        if let attributeMappings = mapping.attributeMappings {
            for propertyMapping in attributeMappings {
                if let destinationName = propertyMapping.name {
                    block(propertyMapping, destinationName)
                } else {
                    let message = "Attribute destination not configured properly"
                    let userInfo = [NSLocalizedFailureReasonErrorKey: message]
                    throw NSError(domain: errorDomain,
                                  code: 0, userInfo: userInfo)
                }
            }
        } else {
            let message = "No Attribute Mappings found!"
            let userInfo = [NSLocalizedFailureReasonErrorKey: message]
            throw NSError(domain: errorDomain, code: 0, userInfo: userInfo)
        }
    }
}
