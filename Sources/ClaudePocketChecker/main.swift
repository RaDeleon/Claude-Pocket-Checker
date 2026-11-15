import AppKit
import SwiftUI
import ApplicationServices
import MeterCore

@MainActor final class MeterModel: ObservableObject {
    @Published var status="Checking Accessibility…"
    @Published var account="Waiting for Claude"
    @Published var model="Unknown"
    @Published var chatLabel="No chat"
    @Published var lastLine="Waiting for a new response"
    @Published var personal=Totals([])
    @Published var work=Totals([])
    @Published var chat=Totals([])
    @Published var paused=false
    @Published var trusted=AXIsProcessTrusted()
    @Published var error=""
    @Published var diagnostics=""
    @Published var lastUpdated=""
    @Published var advice:Advice?
    @Published var comparisons:[ScenarioRow]=[]
    @Published var taskKind:TaskKind = .auto { didSet { updateAdvice() } }
    @Published var allowHaiku=false { didSet { updateAdvice() } }
    @Published var outputAssumption=500 { didSet { updateAdvice() } }
    @Published var scenarioInput=0
    private var draft="", draftModel="Unknown", contextTokens=0
    private func updateAdvice() {
        advice=Advisor.recommend(draft:draft,task:taskKind,allowHaiku:allowHaiku)
        scenarioInput=contextTokens+estimate(draft)
        comparisons=advice.map{Advisor.scenario(input:scenarioInput,output:outputAssumption,recommended:$0.model,selected:draftModel)} ?? []
    }
    private let reader=AccessibilityReader(), tracker=Tracker(), queue=DispatchQueue(label:"com.radeleon.ClaudePocketChecker.reader",qos:.utility)
    private var timer:Timer?, reading=false, ledger=Ledger(), lastContext="", lastRecord:Record?, lastSaved:Record?
    private let url:URL
    init() {
        url=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ClaudePocketChecker",isDirectory:true).appendingPathComponent("ledger.json")
        do {if FileManager.default.fileExists(atPath:url.path){let data=try Data(contentsOf:url);ledger=try JSONDecoder().decode(Ledger.self,from:data)}}
        catch {self.error="Could not load saved totals. Tracking is paused to protect them.";paused=true}
        refreshTotals()
        timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in Task{@MainActor in self?.poll()} }
        poll()
    }
    func permission() {
        let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _=AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func togglePause(){paused.toggle();tracker.reset();lastContext="";lastRecord=nil;draft="";updateAdvice()}
    func poll() {
        guard !reading else{return}
        trusted=AXIsProcessTrusted()
        guard !paused else {status="Paused — no chat text is being read";return}
        guard error.isEmpty else{return}
        reading=true
        queue.async { [weak self, reader] in
            let result=reader.read()
            Task { @MainActor in self?.accept(result) }
        }
    }
    private func accept(_ r:ReadResult) {
        reading=false
        guard !paused,error.isEmpty else{return}
        draft=r.draft;draftModel=r.model;contextTokens=r.contextTokens;updateAdvice()
        status=r.status;diagnostics="\(r.messageCount) accessible messages · \(r.nodes) elements"
        guard let s=r.snapshot,let scope=s.scope else {
            if let scope=r.newChatScope {
                tracker.armNewChat(scope:scope);account=scope.rawValue;chatLabel="New chat";lastLine="Ready to track the first response"
            } else {account="Unrecognized / unavailable";chatLabel="Tracking paused";lastLine="Waiting for a recognized account"}
            lastContext="";chat=Totals([]);return
        }
        account=scope.rawValue+" · "+r.accountLabel
        model=s.model;chatLabel="Chat "+String(s.chat.prefix(8))
        let ctx=scope.rawValue+":"+s.chat
        if lastContext != ctx {lastContext=ctx;lastRecord=nil;lastLine="Existing messages baselined; watching for new replies"}
        guard s.complete else {return}
        guard ledger.bind(chat:s.chat,scope:scope) else {status="Account/chat mismatch — tracking paused";tracker.reset();return}
        if let record=tracker.ingest(s,now:Date().timeIntervalSince1970) {
            let changed=lastSaved.map{$0.id != record.id || $0.input != record.input || $0.output != record.output || $0.model != record.model} ?? true
            if changed,ledger.upsert(record) {lastRecord=record;lastSaved=record;save();lastUpdated=Date().formatted(date:.omitted,time:.standard)}
        }
        if s.busy {status="Reply in progress — waiting for it to settle"}
        if let last=lastRecord {
            lastLine="≈ \(last.input.formatted()) input / \(last.output.formatted()) output · "+money(last.cost)
        }
        refreshTotals(scope:scope,chatID:s.chat)
    }
    private func save() {
        do {
            let folder=url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let data=try JSONEncoder().encode(ledger)
            try data.write(to:url,options:[.atomic,.completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
        } catch {self.error="Could not save totals. Tracking paused; existing file was not intentionally replaced.";paused=true}
    }
    private func refreshTotals(scope:Scope?=nil,chatID:String?=nil) {
        personal=ledger.totals(scope:.personal);work=ledger.totals(scope:.work)
        if let scope {chat=ledger.totals(scope:scope,chat:chatID)}
    }
    func showData(){NSWorkspace.shared.open(url.deletingLastPathComponent())}
}
func money(_ value:Double?) -> String {guard let v=value else{return "Unpriced model"};return String(format:"≈ $%.5f",v)}
struct MeterView:View {
    @ObservedObject var meter:MeterModel
    @AppStorage("personalAccountLabel") private var personalLabel=""
    @AppStorage("workAccountLabel") private var workLabel=""
    @State private var showAccounts=false
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:14) {
            HStack {Image(systemName:"gauge.with.dots.needle.33percent").foregroundStyle(.teal);Text("Claude Pocket Checker").font(.headline);Spacer();Text("LOCAL").font(.caption2).padding(4).background(.quaternary,in:RoundedRectangle(cornerRadius:4))}
            Text(meter.account).font(.subheadline.bold())
            DisclosureGroup("Account labels for this Mac",isExpanded:$showAccounts) {
                TextField("Personal account label",text:$personalLabel)
                TextField("Work account label",text:$workLabel)
                Text("Match the account button at the bottom-left of Claude. Unrecognized labels pause tracking.").font(.caption2).foregroundStyle(.secondary)
            }.font(.caption)
            HStack {Text(meter.chatLabel);Spacer();Text(meter.model)}.font(.caption).foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:7) {Text("Latest observed response").font(.caption).foregroundStyle(.secondary);Text(meter.lastLine).font(.system(.body,design:.monospaced)).textSelection(.enabled)}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:10))
            advisor
            row("This chat",meter.chat)
            Divider()
            row("Personal · all tracked chats",meter.personal)
            row("Work · all tracked chats",meter.work)
            Divider()
            Label(meter.status,systemImage:meter.paused ? "pause.circle" : "circle.dotted").font(.caption).foregroundStyle(.secondary)
            if !meter.trusted {Button("Enable Accessibility…"){meter.permission()}.buttonStyle(.borderedProminent)}
            if !meter.error.isEmpty {Text(meter.error).font(.caption).foregroundStyle(.red)}
            Text("API-equivalent estimates from accessible text · not billed usage. Hidden instructions, attachments, tool payloads and cache accounting are unavailable. Prior messages are not backfilled.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {Button(meter.paused ? "Resume" : "Pause"){meter.togglePause()};Button("Data folder"){meter.showData()};Spacer();Button("Quit"){NSApp.terminate(nil)}}
            Text(meter.diagnostics+(meter.lastUpdated.isEmpty ? "" : " · "+meter.lastUpdated)).font(.caption2).foregroundStyle(.tertiary)
        }.padding(18) }.frame(width:460,height:700).onAppear { showAccounts=personalLabel.isEmpty && workLabel.isEmpty }
    }
    private var advisor:some View {
        VStack(alignment:.leading,spacing:7) {
            Text("Model advisor · local rules").font(.subheadline.bold())
            Picker("Task",selection:$meter.taskKind){ForEach(TaskKind.allCases,id:\.self){Text($0.rawValue).tag($0)}}.font(.caption)
            Toggle("Include Haiku if available in my account",isOn:$meter.allowHaiku).font(.caption)
            if let a=meter.advice {
                Text("Try \(a.model) · \(a.effort) effort").font(.subheadline.bold()).foregroundStyle(.teal)
                Text("\(a.task.rawValue) · \(a.confidence)").font(.caption).foregroundStyle(.secondary)
                Text(a.reason).font(.caption)
                Picker("Assumed output",selection:$meter.outputAssumption){Text("Short · 200 tokens").tag(200);Text("Medium · 500").tag(500);Text("Long · 2,000").tag(2000)}.font(.caption)
                Text("API scenario: ≈ \(meter.scenarioInput.formatted()) visible input + \(meter.outputAssumption.formatted()) assumed output tokens").font(.caption2).foregroundStyle(.secondary)
                ForEach(meter.comparisons,id:\.model){r in HStack{Text(r.model);Spacer();Text(String(format:"$%.5f · %.1f×",r.cost,r.relative))}.font(.system(.caption,design:.monospaced))}
                Text(a.benefit).font(.caption2)
                Text("Same token counts assumed for comparison. Team-plan usage is unknown. Effort changes token use by an unknown amount. Change model/effort yourself in Claude; availability varies.").font(.caption2).foregroundStyle(.secondary)
            } else {Text("Type a draft in Claude to get advice before sending. Draft text stays in memory and is never saved or sent.").font(.caption).foregroundStyle(.secondary)}
        }.padding(12).background(.quaternary,in:RoundedRectangle(cornerRadius:10))
    }
    private func row(_ title:String,_ total:Totals)->some View {
        HStack(alignment:.top){VStack(alignment:.leading,spacing:3){Text(title).font(.subheadline);Text("\(total.responses) tracked · ≈ \(total.input.formatted()) in / \(total.output.formatted()) out").font(.caption).foregroundStyle(.secondary)};Spacer();Text(money(total.cost)+(total.unpriced>0 ? " + unpriced" : "")).font(.system(.subheadline,design:.monospaced))}
    }
}
final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    var panel:NSPanel!, item:NSStatusItem!, model:MeterModel!
    func applicationDidFinishLaunching(_ notification:Notification) {
        model=MeterModel()
        panel=NSPanel(contentRect:NSRect(x:100,y:180,width:496,height:740),styleMask:[.titled,.closable,.utilityWindow,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title="Claude Pocket Checker — estimates";panel.level = .floating;panel.isFloatingPanel=true;panel.hidesOnDeactivate=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];panel.isReleasedWhenClosed=false;panel.delegate=self
        panel.contentView=NSHostingView(rootView:MeterView(meter:model));panel.center();panel.orderFrontRegardless()
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);item.button?.title="≈ Pocket";item.button?.target=self;item.button?.action=#selector(show)
        if let path=Bundle.main.path(forResource:"AppIcon",ofType:"icns"),let icon=NSImage(contentsOfFile:path) {
            icon.size=NSSize(width:20,height:20);icon.isTemplate=false
            item.button?.image=icon;item.button?.title="";item.button?.toolTip="Claude Pocket Checker — show meter"
        }
    }
    @objc func show(){panel.orderFrontRegardless()}
    func windowShouldClose(_ sender:NSWindow)->Bool {NSApp.terminate(nil);return true}
}
if CommandLine.arguments.contains("--probe") {
    let result=AccessibilityReader().read()
    let s=result.snapshot
    let object:[String:Any]=["trusted":AXIsProcessTrusted(),"status":result.status,"nodes":result.nodes,"messages":result.messageCount,"account":s?.scope?.rawValue ?? "Unknown","model":s?.model ?? "Unknown","complete":s?.complete ?? false,"chatIdentifierFound":s?.chat.count == 64,"userMessages":s?.messages.filter{$0.role == .user}.count ?? 0,"assistantMessages":s?.messages.filter{$0.role == .assistant}.count ?? 0,"visibleBytes":s?.messages.reduce(0){$0+$1.text.utf8.count} ?? 0,"draftBytes":result.draft.utf8.count,"recommendedModel":Advisor.recommend(draft:result.draft)?.model ?? "None","recommendedEffort":Advisor.recommend(draft:result.draft)?.effort ?? "None"]
    let data=try! JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]);print(String(decoding:data,as:UTF8.self))
} else {
    let app=NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate=AppDelegate();app.delegate=delegate;app.run()
}
