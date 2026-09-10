import DayVaultCore
import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false, cloudKitEnabled: Bool? = nil) -> ModelContainer {
        let schema = Schema(versionedSchema: DayVaultSchemaV2.self)
        let useCloudKit = !inMemory && (cloudKitEnabled ?? defaultCloudKitAvailability)

        if useCloudKit {
            do {
                return try makeContainer(
                    schema: schema,
                    inMemory: false,
                    cloudKitDatabase: .private("iCloud.com.dayvault.app")
                )
            } catch {
                // A missing account, entitlement, or unavailable service must not
                // prevent the schedule from opening. The next launch can retry sync.
                NSLog("DayVault: CloudKit unavailable; opening the local store instead. \(error)")
            }
        }

        do {
            return try makeContainer(schema: schema, inMemory: inMemory, cloudKitDatabase: .none)
        } catch {
            fatalError("Unable to create DayVault local model container: \(error)")
        }
    }

    private static func makeContainer(
        schema: Schema,
        inMemory: Bool,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "DayVault",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: DayVaultMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private static var defaultCloudKitAvailability: Bool {
#if targetEnvironment(simulator)
        // Unsigned simulator builds do not carry the CloudKit entitlement and
        // CloudKit currently traps asynchronously instead of returning an error.
        // Explicit opt-in remains available for signed CloudKit integration tests.
        ProcessInfo.processInfo.arguments.contains("-enableCloudKitInSimulator")
#else
        true
#endif
    }
}
