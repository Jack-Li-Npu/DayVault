import DayVaultCore
import SwiftUI
import UniformTypeIdentifiers

private struct MCPJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw MCPImportError.unreadableFile }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct MCPExchangeView: View {
    @Environment(AppModel.self) private var model
    @State private var goalID: UUID?
    @State private var snapshot: MCPSnapshot?
    @State private var exportDocument: MCPJSONDocument?
    @State private var showsExporter = false
    @State private var showsImporter = false
    @State private var proposal: MCPProposalPreview?
    @State private var error: String?
    @State private var result: String?
#if DEBUG
    @State private var testProposalData: Data?
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("在电脑端使用 Codex、Claude Code 或 Gemini CLI 读取目标记录，再将计划草案导回 DayVault。需要自行配置 MCP 和相应 AI 工具。")
                    .font(.subheadline).foregroundStyle(EditorialPalette.muted)
                exportSection
                VStack(alignment: .leading, spacing: 12) {
                    Text("导入计划草案").font(.headline)
                    Text("导入前可以查看每项安排。确认后只会新增有日期的事项，不修改现有记录或成就。")
                        .font(.subheadline).foregroundStyle(EditorialPalette.muted)
                    Button("选择 JSON 文件") { chooseProposal() }
                        .frame(minHeight: 44).accessibilityIdentifier("mcp-import")
                }
                .padding(16).background(EditorialPalette.sheet)
                Text("DayVault 不调用模型，也不保存 API 密钥。将快照交给外部 AI 后，数据可能由该工具发送给其服务商；费用及隐私规则取决于你使用的工具。")
                    .font(.footnote).foregroundStyle(EditorialPalette.muted)
                if let result { Text(result).foregroundStyle(EditorialPalette.ink).accessibilityIdentifier("mcp-result") }
            }.padding(20)
        }
        .background(EditorialPalette.paper).foregroundStyle(EditorialPalette.ink)
        .navigationTitle("MCP 文件交换").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if goalID == nil { goalID = model.selectedGoalID ?? model.goals.first?.id }
#if DEBUG
            prepareProposalFixtureIfRequested()
#endif
        }
        .fileExporter(isPresented: $showsExporter, document: exportDocument, contentType: .json,
                      defaultFilename: "dayvault-snapshot") { outcome in
            switch outcome {
            case .success: result = "快照已导出。请在电脑端选择这个文件。"
            case .failure: error = "未能导出文件。请检查保存位置后重试。"
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { outcome in
            do {
                let data = try MCPProposalFile.read(outcome.get())
                proposal = try model.previewMCPProposal(data)
            } catch { self.error = error.localizedDescription }
        }
        .sheet(item: $proposal) { preview in
            MCPProposalReviewView(preview: preview) { count in
                proposal = nil
                result = "已新增 \(count) 项安排。"
                snapshot = nil
            }
        }
        .alert("无法完成操作", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("返回") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func chooseProposal() {
        error = nil
        result = nil
#if DEBUG
        if let testProposalData {
            do { proposal = try model.previewMCPProposal(testProposalData) }
            catch { self.error = error.localizedDescription }
            return
        }
#endif
        showsImporter = true
    }

#if DEBUG
    /// Exercises the real decoder/preview/confirmation UI without driving the OS document provider.
    /// All flags are required; release builds and normal persistent stores cannot enter this path.
    private func prepareProposalFixtureIfRequested() {
        let flags = Set(ProcessInfo.processInfo.arguments)
        guard testProposalData == nil,
              Set(["-ui-testing", "-inMemoryStore", "-preview-journey", "-preview-mcp-proposal"]).isSubset(of: flags),
              let goal = model.goals.first(where: { $0.id == goalID }),
              let zone = TimeZone(identifier: goal.timeZoneID) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = Date()
        let items = (1...2).compactMap { offset -> MCPProposedItem? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            return MCPProposedItem(title: "MCP 导入测试事项 \(offset)",
                date: MCPExchange.dateString(day, timeZoneID: goal.timeZoneID))
        }
        let proposal = MCPScheduleProposal(snapshotID: UUID(), goalID: goal.id, goalTitle: goal.title,
            timeZoneID: goal.timeZoneID, createdAt: now.ISO8601Format(), summary: "安排两项阅读。", items: items)
        testProposalData = try? MCPExchange.encode(proposal)
    }
#endif

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出目标快照").font(.headline)
            if model.goals.isEmpty {
                Text("暂无目标。请先在“目标管理”中创建目标，并关联需要导出的事项。")
                    .font(.subheadline).foregroundStyle(EditorialPalette.muted)
            } else {
                Picker("选择目标", selection: $goalID) {
                    ForEach(model.goals) { goal in Text(goal.title).tag(Optional(goal.id)) }
                }.accessibilityIdentifier("mcp-goal-picker")
                    .onChange(of: goalID) { _, _ in snapshot = nil }
                Text("仅包含此目标前 30 天至后 14 天的事项标题、日期和状态，以及目标期限与休息日。不包含备注、对话、回忆或系统日历。")
                    .font(.subheadline).foregroundStyle(EditorialPalette.muted)
                Button("预览导出范围") {
                    do {
                        error = nil; result = nil
                        if let goalID { snapshot = try model.makeMCPSnapshot(goalID: goalID) }
                    } catch { self.error = error.localizedDescription }
                }.frame(minHeight: 44).accessibilityIdentifier("mcp-preview-export")
                if let snapshot {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.goal.title).font(.headline)
                        Text("\(snapshot.window.startDate) 至 \(snapshot.window.endDate)").font(.subheadline)
                        Text("\(snapshot.records.count) 项记录 · \(snapshot.goal.timeZoneID)").font(.subheadline)
                        Button("导出 JSON") {
                            do {
                                exportDocument = MCPJSONDocument(data: try MCPExchange.encode(snapshot))
                                showsExporter = true
                            } catch { self.error = error.localizedDescription }
                        }.frame(minHeight: 44).accessibilityIdentifier("mcp-confirm-export")
                    }.padding(12).overlay { Rectangle().stroke(EditorialPalette.rule) }
                }
            }
        }.padding(16).background(EditorialPalette.sheet)
    }
}

private struct MCPProposalReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let preview: MCPProposalPreview
    let onImported: (Int) -> Void
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(preview.proposal.goalTitle).font(.title2.bold())
                    Text("外部计划草案，尚未保存").font(.subheadline).foregroundStyle(EditorialPalette.muted)
                    Text(preview.proposal.summary)
                    Text("时区：\(preview.proposal.timeZoneID)").font(.footnote).foregroundStyle(EditorialPalette.muted)
                    ForEach(preview.proposal.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.date).font(.subheadline).foregroundStyle(EditorialPalette.muted)
                            Text(item.title).font(.headline)
                            Text("仅指定日期，不设提醒").font(.caption).foregroundStyle(EditorialPalette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(EditorialPalette.sheet)
                    }
                    Text("确认时会重新检查目标设置及重复事项。草案不会覆盖已有安排。")
                        .font(.footnote).foregroundStyle(EditorialPalette.muted)
                    if let error { Text(error).foregroundStyle(EditorialPalette.coralText).accessibilityIdentifier("mcp-import-error") }
                    Button("确认新增 \(preview.proposal.items.count) 项") {
                        do {
                            try model.confirmMCPProposal(preview)
                            onImported(preview.proposal.items.count)
                        } catch { self.error = error.localizedDescription }
                    }.frame(minHeight: 44).accessibilityIdentifier("mcp-confirm-import")
                }.padding(20)
            }.background(EditorialPalette.paper).foregroundStyle(EditorialPalette.ink)
            .navigationTitle("检查计划草案").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}
