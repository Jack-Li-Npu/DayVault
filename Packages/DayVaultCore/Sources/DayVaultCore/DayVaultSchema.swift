import SwiftData

public enum DayVaultSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static let models: [any PersistentModel.Type] = [
        ScheduleCategory.self,
        ScheduleItem.self,
        OccurrenceLog.self,
        QuickTemplate.self,
        DayReview.self,
        AchievementState.self,
    ]
}

public enum DayVaultMigrationPlan: SchemaMigrationPlan {
    public static let schemas: [any VersionedSchema.Type] = [DayVaultSchemaV1.self, DayVaultSchemaV2.self]
    public static let stages: [MigrationStage] = [
        .lightweight(fromVersion: DayVaultSchemaV1.self, toVersion: DayVaultSchemaV2.self),
    ]
}

public enum DayVaultSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
    public static let models: [any PersistentModel.Type] = [
        ScheduleCategory.self, ScheduleItem.self, OccurrenceLog.self,
        QuickTemplate.self, DayReview.self, AchievementState.self,
        PersonalGoal.self, PersonalAchievementDefinition.self, PersonalAchievementEvidence.self,
        CompanionMessage.self, CompanionMemory.self, PlanAdjustmentRecord.self,
    ]
}
