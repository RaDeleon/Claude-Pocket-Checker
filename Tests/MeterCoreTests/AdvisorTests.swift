import XCTest
@testable import MeterCore
final class AdvisorTests:XCTestCase {
    func testCustomTeamMemberLabels(){XCTAssertEqual(accountScope("Jane TeamCo",personalLabel:"Jane Personal",workLabel:"Jane TeamCo"),.work);XCTAssertNil(accountScope("Jane",personalLabel:"Jane",workLabel:"Jane"));XCTAssertNil(accountScope("",personalLabel:"",workLabel:"TeamCo"))}
    func testEmptyDraftGivesNoAdvice(){XCTAssertNil(Advisor.recommend(draft:"  \n"))}
    func testRoutineDraftAvoidsPremium(){let a=Advisor.recommend(draft:"Rewrite this email to sound friendlier: Meeting at noon.")!;XCTAssertEqual(a.model,"Sonnet 5.5");XCTAssertEqual(a.effort,"Low")}
    func testHaikuRequiresAvailabilityOptIn(){XCTAssertEqual(Advisor.recommend(draft:"Extract names into CSV")?.model,"Sonnet 5.5");XCTAssertEqual(Advisor.recommend(draft:"Extract names into CSV",allowHaiku:true)?.model,"Haiku 5.5")}
    func testComplexTaskWinsOverSimpleKeywords(){let a=Advisor.recommend(draft:"Summarize the root cause of a distributed deadlock and prove correctness.")!;XCTAssertEqual(a.task,.complex);XCTAssertEqual(a.model,"Opus 5.5")}
    func testCodingAndHighStakesDoNotGetRoutineAdvice(){XCTAssertEqual(Advisor.recommend(draft:"Fix this Python function")?.task,.coding);XCTAssertEqual(Advisor.recommend(draft:"Rewrite this contract clause")?.task,.sensitive)}
    func testUnknownAndAttachmentsAreUncertain(){XCTAssertEqual(Advisor.recommend(draft:"Help me with this")?.confidence,"Uncertain task");XCTAssertEqual(Advisor.recommend(draft:"Summarize attached PDF")?.task,.general)}
    func testTaskOverrideDoesNotPretendAutomaticCertainty(){let a=Advisor.recommend(draft:"something",task:.routine)!;XCTAssertEqual(a.confidence,"Task selected by you")}
    func testSameTokenComparisonsAndFableVersion(){let rows=Advisor.scenario(input:1000,output:500,recommended:"Sonnet 5.5",selected:"Fable 5.1 High");XCTAssertEqual(rows.map(\.model),["Sonnet 5.5","Fable 5.1","Opus 5.5","Fable 5.2"]);XCTAssertEqual(rows.map(\.relative),[1,5,2,4])}
    func testHaikuLongContextAndUnknownModel(){let rows=Advisor.scenario(input:100001,output:500,recommended:"Haiku 5.5",selected:"Unknown");XCTAssertEqual(rows.count,3);XCTAssertEqual(rows[1].relative,8,accuracy:0.001);XCTAssertTrue(Advisor.scenario(input:0,output:0,recommended:"Sonnet 5.5",selected:"Opus 5.5").isEmpty)}
}
