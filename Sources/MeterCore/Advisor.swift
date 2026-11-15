import Foundation

public enum TaskKind:String,CaseIterable {
    case auto="Auto", routine="Basic writing", extraction="Extract / format", general="General work", coding="Coding", complex="Deep reasoning", sensitive="High-stakes review"
}
public struct Advice {
    public let task:TaskKind, model:String, effort:String, reason:String, benefit:String, confidence:String
}
public struct ScenarioRow {
    public let model:String, cost:Double, relative:Double
}
public enum Advisor {
    // Deterministic rules, not a model evaluation. User text is never executed or sent anywhere.
    public static func recommend(draft:String,task:TaskKind = .auto,allowHaiku:Bool=false)->Advice? {
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else{return nil}
        let s=String(text.prefix(24000)).lowercased()
        func has(_ pattern:String)->Bool{s.range(of:pattern,options:.regularExpression) != nil}
        var kind=task
        if task == .auto {
            if has(#"\b(diagnos\w*|medical|legal advice|contract|lawsuit|investment advice|retirement|patient|credit decision|hiring decision|tax advice)\b"#) {kind = .sensitive}
            else if has(#"\b(race condition|deadlock|distributed|root cause|security audit|threat model|proof|prove|multi.?step|production incident|multi.?agent|complex|architecture|trade.?offs|across multiple|deep research)\b"#) || text.count>7000 {kind = .complex}
            else if has(#"\b(code|coding|debug|bug|function|implement|refactor|script|sql|typescript|python|swift|javascript|unit test|api|deploy|server|database)\b"#) {kind = .coding}
            else if has(#"\b(attached|attachment|image|screenshot|pdf|browse|research|compare|plan|analy[sz]e|spreadsheet|calculate)\b"#) {kind = .general}
            else if has(#"\b(extract|classify|categorize|json|csv|alphabeti[sz]e|sort|format|convert)\b"#) {kind = .extraction}
            else if has(#"\b(rewrite|rephrase|proofread|grammar|spelling|summari[sz]e|email|translate|shorten|polish|bullet|thank.you)\b"#) && text.count<3500 {kind = .routine}
            else {kind = .general}
        }
        switch kind {
        case .routine,.extraction:
            return Advice(task:kind,model:allowHaiku ? "Haiku 5.5" : "Sonnet 5.5",effort:"Low",reason:"A bounded text task is a reasonable place to start with a cheaper model and low effort.",benefit:"Premium upgrade: limited expected benefit for this task type. Comparable usefulness is plausible; review the result. Identical answers are not guaranteed.",confidence:task == .auto ? "Rule-based hint" : "Task selected by you")
        case .coding:
            return Advice(task:kind,model:"Sonnet 5.5",effort:"Medium",reason:"Start with Sonnet for a bounded coding task; escalate if tests fail or the problem spans systems.",benefit:"Opus may help with difficult debugging or hidden constraints. This prompt alone cannot establish equal quality.",confidence:"Rule-based hint")
        case .complex:
            return Advice(task:kind,model:"Opus 5.5",effort:"High",reason:"The draft signals difficult reasoning, cross-system work, or a long context. Review whether those requirements are real.",benefit:"A premium model may be useful. Fable is an escalation to evaluate for demanding long-horizon work, not a guaranteed improvement.",confidence:"Rule-based hint")
        case .sensitive:
            return Advice(task:kind,model:"Sonnet 5.5",effort:"High",reason:"Use careful review and source checking for consequential work. Model selection alone does not establish correctness.",benefit:"Do not assume a cheaper or more expensive model gives the same answer. Have a qualified person review consequential conclusions.",confidence:"Review required")
        case .auto,.general:
            return Advice(task:.general,model:"Sonnet 5.5",effort:"Medium",reason:"The task is unclear, tool-based, or needs context the meter cannot see. Sonnet/Medium is a starting point; set the task category if this guess is wrong.",benefit:"Premium benefit is uncertain without task-specific evaluation. Test the cheaper option against your acceptance criteria.",confidence:"Uncertain task")
        }
    }
    public static func scenario(input:Int,output:Int,recommended:String,selected:String)->[ScenarioRow] {
        guard let base=Pricing.cost(model:recommended,input:input,output:output),base>0 else{return []}
        var seen=Set<String>()
        return [recommended,selected,"Opus 5.5","Fable 5.2"].compactMap { raw in
            guard let key=Pricing.key(raw),seen.insert(key).inserted,let cost=Pricing.cost(model:key,input:input,output:output) else{return nil}
            return ScenarioRow(model:key,cost:cost,relative:cost/base)
        }
    }
}
