import Foundation
import CryptoKit

public enum Scope: String, Codable, CaseIterable { case personal = "Personal", work = "Work" }
public func accountScope(_ text:String,personalLabel:String="",workLabel:String="")->Scope? {
    func normalized(_ s:String)->String {s.lowercased().filter{$0.isLetter || $0.isNumber}}
    let s=normalized(text), personal=normalized(personalLabel), work=normalized(workLabel)
    guard !s.isEmpty, personal != work else{return nil}
    if !personal.isEmpty,s==personal{return .personal}
    if !work.isEmpty,s==work{return .work}
    return nil
}
public func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
public func estimate(_ text: String) -> Int { (text.utf8.count + 3) / 4 }
public struct Message {
    public enum Role { case user, assistant, other }
    public var index: Int; public var role: Role; public var text: String
    public init(_ index: Int, _ role: Role, _ text: String) { self.index=index; self.role=role; self.text=text }
}
public struct Snapshot {
    public var chat: String; public var scope: Scope?; public var model: String; public var messages: [Message]; public var busy: Bool; public var complete: Bool
    public init(chat: String, scope: Scope?, model: String, messages: [Message], busy: Bool=false, complete: Bool=true) { self.chat=chat; self.scope=scope; self.model=model; self.messages=messages; self.busy=busy; self.complete=complete }
}
public struct Record: Codable, Equatable {
    public var id: String; public var chat: String; public var scope: Scope; public var model: String
    public var input: Int; public var output: Int; public var cost: Double?; public var observedAt: Date
}
public enum Pricing {
    public static let verifiedDate = "2026-11-15"
    // Standard input/output USD per million. Cache, tool fees and discounts cannot be inferred from Accessibility.
    public static let rates: [String: (Double,Double)] = ["Opus 5.5":(4,20),"Sonnet 5.5":(2,10),"Haiku 5.5":(0.1,0.5),"Opus 5":(5,25),"Opus 4.8":(5,25),"Opus 4.7":(5,25),"Opus 4.6":(5,25),"Sonnet 4.6":(3,15),"Sonnet 4.5":(3,15),"Haiku 4.5":(1,5),"Fable 5.2":(8,40),"Mythos 5.2":(8,40),"Fable 5.1":(10,50),"Mythos 5.1":(10,50)]
    public static func key(_ model:String) -> String? { rates.keys.sorted { $0.count > $1.count }.first { model.range(of: NSRegularExpression.escapedPattern(for:$0)+"(?![0-9.])", options:[.regularExpression,.caseInsensitive]) != nil } }
    public static func cost(model: String, input: Int, output: Int) -> Double? {
        guard let k=key(model), var r=rates[k], input>=0, output>=0 else { return nil }
        if k == "Haiku 5.5", input>100_000 { r=(0.5,2.5) }
        return (Double(input)*r.0 + Double(output)*r.1)/1_000_000
    }
}
public struct Totals {
    public var responses=0, input=0, output=0, unpriced=0; public var cost=0.0
    public init(_ records:[Record]) { for r in records { responses+=1;input+=r.input;output+=r.output;cost+=r.cost ?? 0;unpriced += r.cost == nil ? 1 : 0 } }
}
public struct Ledger: Codable {
    public var version=1
    public private(set) var bindings: [String:Scope]=[:]
    public private(set) var records: [Record]=[]
    public init() {}
    @discardableResult public mutating func bind(chat:String, scope:Scope) -> Bool {
        guard chat.count==64 else {return false}
        if let existing=bindings[chat] {return existing==scope}
        bindings[chat]=scope;return true
    }
    @discardableResult public mutating func upsert(_ r:Record) -> Bool {
        guard bindings[r.chat]==r.scope, !r.id.isEmpty, r.input>=0, r.output>=0 else {return false}
        if let i=records.firstIndex(where:{$0.id==r.id}) {
            guard records[i].chat==r.chat, records[i].scope==r.scope else {return false}
            records[i]=r
        } else { records.append(r) }
        return true
    }
    public func totals(scope:Scope, chat:String?=nil) -> Totals { Totals(records.filter{$0.scope==scope && (chat==nil || $0.chat==chat)}) }
}
// All transcript text and fingerprints are volatile. Only Record's numeric counters and opaque IDs are persisted.
public final class Tracker {
    private var context: String?, lastUserIndex=0, lastUserHash="", wasBusy=false
    private var candidate: Candidate?
    private var armedNewChat: Scope?
    private struct Candidate {
        var id=UUID().uuidString, userIndex:Int, input:Int, model:String, initialHash:String?, changed:Bool
        var outputHash="", stableSince:TimeInterval=0, committed=false
    }
    public init() {}
    public func reset() { context=nil;candidate=nil;lastUserIndex=0;lastUserHash="";wasBusy=false;armedNewChat=nil }
    public func armNewChat(scope:Scope) {reset();armedNewChat=scope}
    public func ingest(_ s:Snapshot, now:TimeInterval) -> Record? {
        guard let scope=s.scope, s.chat.count==64 else {reset();return nil}
        // Hydration gaps must not discard an armed first reply or an in-flight turn.
        guard s.complete, let user=s.messages.last(where:{$0.role == .user}) else {return nil}
        let ctx=scope.rawValue+":"+s.chat, uh=digest(user.text)
        let outputs=s.messages.filter{$0.index>user.index && $0.role == .assistant}
        let text=outputs.map(\.text).joined(separator:"\n"), oh=digest(text)
        if context != ctx {
            let armed=armedNewChat==scope;armedNewChat=nil
            context=ctx;lastUserIndex=user.index;lastUserHash=uh;wasBusy=s.busy;candidate=nil
            if armed || (s.busy && outputs.isEmpty) {
                let input=s.messages.filter{$0.index<=user.index}.map(\.text).joined(separator:"\n")
                candidate=Candidate(userIndex:user.index,input:estimate(input),model:s.model,initialHash:nil,changed:true)
            }
            return nil
        }
        let newUser=user.index>lastUserIndex || (user.index==lastUserIndex && uh != lastUserHash)
        let newAttempt=s.busy && !wasBusy && (candidate == nil || candidate!.committed)
        if newUser || newAttempt {
            let input=s.messages.filter{$0.index<=user.index}.map(\.text).joined(separator:"\n")
            candidate=Candidate(userIndex:user.index,input:estimate(input),model:s.model,initialHash:newUser && user.index>lastUserIndex ? nil : oh,changed:newUser && user.index>lastUserIndex)
        }
        wasBusy=s.busy;lastUserIndex=user.index;lastUserHash=uh
        guard var c=candidate, c.userIndex==user.index else{return nil}
        if c.initialHash != oh {c.changed=true}
        if c.outputHash != oh {c.outputHash=oh;c.stableSince=now}
        guard c.changed, !text.isEmpty, !s.busy, now-c.stableSince>=3 else {candidate=c;return nil}
        let output=estimate(text)
        let record=Record(id:c.id,chat:s.chat,scope:scope,model:c.model,input:c.input,output:output,cost:Pricing.cost(model:c.model,input:c.input,output:output),observedAt:Date(timeIntervalSince1970:now))
        c.committed=true;candidate=c
        return record
    }
}
