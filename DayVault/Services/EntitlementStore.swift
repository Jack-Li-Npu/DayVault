import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class EntitlementStore {
    static let productID = "com.dayvault.app.pro.lifetime"

    private(set) var product: Product?
    private(set) var hasLifetimePro = UserDefaults.standard.bool(forKey: "hasLifetimePro")
    private(set) var isLoading = false
    var errorMessage: String?

    func start() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
            await refresh()
            Task { await observeTransactions() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else { return }
        do {
            switch try await product.purchase() {
            case let .success(result):
                let transaction = try verified(result)
                await transaction.finish()
                await refresh()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? verified(result), transaction.productID == Self.productID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        hasLifetimePro = unlocked
        UserDefaults.standard.set(unlocked, forKey: "hasLifetimePro")
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? verified(result) else { continue }
            await transaction.finish()
            await refresh()
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value): value
        case .unverified: throw StoreError.unverifiedTransaction
        }
    }

    enum StoreError: Error { case unverifiedTransaction }
}
