import XCTest
@testable import MeterCore
final class MeterCoreTests:XCTestCase {
    let chat=digest("fixture-chat")
    func snap(_ messages:[Message],scope:Scope? = .personal,busy:Bool=false,complete:Bool=true,chat:String?=nil)->Snapshot {Snapshot(chat:chat ?? self.chat,scope:scope,model:"Opus 5.5 High",messages:messages,busy:busy,complete:complete)}
    let old=[Message(1,.user,"old prompt"),Message(2,.assistant,"old reply")]
    func testRecognizedAccountsOnly(){XCTAssertEqual(accountScope("Personal MAX",personalLabel:"Personal Max",workLabel:"Example Team"),.personal);XCTAssertEqual(accountScope("Example TEAM",personalLabel:"Personal Max",workLabel:"Example Team"),.work);XCTAssertNil(accountScope("Someone else"));XCTAssertNil(accountScope("Personal"))}
    func testFirstResponseInObservedNewChat(){let t=Tracker();t.armNewChat(scope:.personal)
        XCTAssertNil(t.ingest(snap(old),now:1));XCTAssertNil(t.ingest(snap(old),now:2));XCTAssertNotNil(t.ingest(snap(old),now:6))
    }
    func testNewChatArmDoesNotCrossAccounts(){let t=Tracker();t.armNewChat(scope:.personal);XCTAssertNil(t.ingest(snap(old,scope:.work),now:1));XCTAssertNil(t.ingest(snap(old,scope:.work),now:6))}
    func testNewChatArmSurvivesHydrationGaps(){let t=Tracker();t.armNewChat(scope:.personal)
        XCTAssertNil(t.ingest(snap([],complete:false),now:1));XCTAssertNil(t.ingest(snap([]),now:2));XCTAssertNil(t.ingest(snap(old),now:3));XCTAssertNil(t.ingest(snap(old),now:4));XCTAssertNotNil(t.ingest(snap(old),now:8))
    }
    func testPendingReplySurvivesIncompleteMessageList(){let t=Tracker();_ = t.ingest(snap(old),now:0)
        let user=old+[Message(3,.user,"new")];XCTAssertNil(t.ingest(snap(user,busy:true),now:1))
        XCTAssertNil(t.ingest(snap(user,busy:true,complete:false),now:2))
        let reply=user+[Message(4,.assistant,"reply")];XCTAssertNil(t.ingest(snap(reply),now:3));XCTAssertNotNil(t.ingest(snap(reply),now:7))
    }
    func testColdStartDoesNotBackfill(){let t=Tracker();for n in 0...10 {XCTAssertNil(t.ingest(snap(old),now:Double(n)))}}
    func testNewReplySettlesAndStreamingWaits(){let t=Tracker();_ = t.ingest(snap(old),now:0)
        let next=old+[Message(3,.user,"new prompt"),Message(4,.assistant,"response")]
        XCTAssertNil(t.ingest(snap(next,busy:true),now:1));XCTAssertNil(t.ingest(snap(next,busy:true),now:6));let r=t.ingest(snap(next),now:7)
        XCTAssertEqual(r?.output,2);XCTAssertEqual(r?.input,estimate("old prompt\nold reply\nnew prompt"));XCTAssertEqual(r?.cost ?? -1,0.000072,accuracy:0.000001)
    }
    func testSameSnapshotUpsertsRatherThanDuplicates(){let t=Tracker();var ledger=Ledger();ledger.bind(chat:chat,scope:.personal);_ = t.ingest(snap(old),now:0)
        let next=old+[Message(3,.user,"new"),Message(4,.assistant,"reply")];_ = t.ingest(snap(next),now:1)
        for n in 4...8 {if let r=t.ingest(snap(next),now:Double(n)){XCTAssertTrue(ledger.upsert(r))}}
        XCTAssertEqual(ledger.totals(scope:.personal).responses,1)
        let replacement=Tracker();XCTAssertNil(replacement.ingest(snap(next),now:20));XCTAssertNil(replacement.ingest(snap(next),now:30))
    }
    func testUnknownAccountAndIncompleteChatResetBaseline(){let t=Tracker();_ = t.ingest(snap(old),now:0)
        let next=old+[Message(3,.user,"new"),Message(4,.assistant,"reply")]
        XCTAssertNil(t.ingest(snap(next,scope:nil),now:1));XCTAssertNil(t.ingest(snap(next),now:5));XCTAssertNil(t.ingest(snap(next),now:10));XCTAssertNil(t.ingest(snap(next,complete:false),now:11));XCTAssertNil(t.ingest(snap(next),now:20))
    }
    func testTwoAccountsNeverShareBoundChat(){var ledger=Ledger();XCTAssertTrue(ledger.bind(chat:chat,scope:.personal));XCTAssertFalse(ledger.bind(chat:chat,scope:.work));let other=digest("work-chat");XCTAssertTrue(ledger.bind(chat:other,scope:.work))
        let a=Record(id:"a",chat:chat,scope:.personal,model:"Opus 5.5",input:10,output:5,cost:0.1,observedAt:Date())
        let b=Record(id:"b",chat:other,scope:.work,model:"Opus 5.5",input:20,output:8,cost:0.2,observedAt:Date())
        XCTAssertTrue(ledger.upsert(a));XCTAssertTrue(ledger.upsert(b));XCTAssertEqual(ledger.totals(scope:.personal).input,10);XCTAssertEqual(ledger.totals(scope:.work).input,20)
        var forged=a;forged.scope = .work;XCTAssertFalse(ledger.upsert(forged));XCTAssertEqual(ledger.totals(scope:.personal).cost,0.1)
    }
    func testRetryObservedThroughBusyStartsSeparateAttempt(){let t=Tracker();_ = t.ingest(snap(old),now:0)
        let next=old+[Message(3,.user,"new"),Message(4,.assistant,"first")];_ = t.ingest(snap(next),now:1);let first=t.ingest(snap(next),now:5)!
        XCTAssertNil(t.ingest(snap(next,busy:true),now:6));let retried=old+[Message(3,.user,"new"),Message(4,.assistant,"second response")];XCTAssertNil(t.ingest(snap(retried,busy:true),now:7));let second=t.ingest(snap(retried),now:11)!
        XCTAssertNotEqual(first.id,second.id);XCTAssertEqual(second.output,4)
    }
    func testContinuationUpdatesSameAttempt(){let t=Tracker();_ = t.ingest(snap(old),now:0)
        let next=old+[Message(3,.user,"new"),Message(4,.assistant,"first")];_ = t.ingest(snap(next),now:1);let first=t.ingest(snap(next),now:5)!
        let extended=next+[Message(5,.assistant,"continued")];_ = t.ingest(snap(extended),now:6);let second=t.ingest(snap(extended),now:10)!
        XCTAssertEqual(first.id,second.id);XCTAssertGreaterThan(second.output,first.output)
    }
    func testLedgerPersistsOnlyWhitelist(){var ledger=Ledger();ledger.bind(chat:chat,scope:.personal);let r=Record(id:"opaque",chat:chat,scope:.personal,model:"Opus 5.5",input:10,output:5,cost:0.1,observedAt:Date());ledger.upsert(r)
        let data=try! JSONEncoder().encode(ledger);let decoded=try! JSONDecoder().decode(Ledger.self,from:data);XCTAssertEqual(decoded.records,[r]);let obj=try! JSONSerialization.jsonObject(with:data) as! [String:Any];let row=(obj["records"] as! [[String:Any]])[0]
        XCTAssertEqual(Set(row.keys),Set(["id","chat","scope","model","input","output","cost","observedAt"]))
    }
    func testPricingAndUTF8(){XCTAssertEqual(estimate("😀"),1);XCTAssertEqual(Pricing.cost(model:"Opus 5.5 High",input:1000000,output:1000000),24);XCTAssertNil(Pricing.cost(model:"Unknown future model",input:1,output:1));XCTAssertEqual(Pricing.cost(model:"Haiku 5.5",input:100001,output:0),0.0500005)}
}
