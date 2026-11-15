import AppKit
import ApplicationServices
import MeterCore

struct ReadResult { var snapshot:Snapshot?; var status:String; var nodes:Int=0; var messageCount:Int=0; var newChatScope:Scope?; var draft:String=""; var model:String="Unknown"; var contextTokens:Int=0; var accountLabel:String="" }
final class AccessibilityReader: @unchecked Sendable {
    private var count=0, truncated=false
    private func attr(_ e:AXUIElement,_ k:String)->CFTypeRef? { var v:CFTypeRef?;guard AXUIElementCopyAttributeValue(e,k as CFString,&v) == .success else{return nil};return v }
    private func string(_ e:AXUIElement,_ k:String)->String {attr(e,k) as? String ?? ""}
    private func children(_ e:AXUIElement)->[AXUIElement] {attr(e,"AXChildren") as? [AXUIElement] ?? []}
    private func name(_ e:AXUIElement)->String {let d=string(e,"AXDescription");return d.isEmpty ? string(e,"AXTitle") : d}
    func read() -> ReadResult {
        guard AXIsProcessTrusted() else{return ReadResult(status:"Accessibility permission needed")}
        guard let app=NSRunningApplication.runningApplications(withBundleIdentifier:"com.anthropic.claudefordesktop").first else{return ReadResult(status:"Open Claude Desktop to begin")}
        let root=AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root,0.2)
        count=0;truncated=false
        var messages=[Message](), chat="", model="Unknown", scope:Scope?, busy=false, code=false, expected=0, newChat=false, draft="", accountLabel=""
        func text(_ e:AXUIElement,_ depth:Int=0)->String {
            guard depth<35, count<10000 else {truncated=true;return ""};count+=1
            let role=string(e,"AXRole")
            // Heading repeats message preview; actions/tool buttons are not transcript content.
            if ["AXHeading","AXButton","AXPopUpButton","AXToolbar","AXCheckBox","AXTextArea"].contains(role) {return ""}
            if role=="AXStaticText" || role=="AXListMarker" {return string(e,"AXValue")}
            return children(e).map{text($0,depth+1)}.filter{!$0.isEmpty}.joined(separator:" ")
        }
        func role(_ e:AXUIElement,_ depth:Int=0)->Message.Role? {
            guard depth<30 else{return nil}
            if string(e,"AXRole")=="AXHeading" {
                let n=name(e)+" "+children(e).map{string($0,"AXValue")}.joined(separator:" ")
                if n.contains("You said:"){return .user};if n.contains("Claude responded:"){return .assistant}
            }
            for c in children(e) {if let r=role(c,depth+1){return r}};return nil
        }
        func walk(_ e:AXUIElement,_ depth:Int) {
            guard depth<45,count<10000 else{truncated=true;return};count+=1
            let n=name(e), r=string(e,"AXRole")
            if r=="AXWebArea",let url=attr(e,"AXURL") {
                let raw=String(describing:url)
                if raw.contains("claude.ai/new") {newChat=true}
                if let range=raw.range(of:"/chat/[a-fA-F0-9-]{36}",options:.regularExpression) {chat=digest(String(raw[range]))}
            }
            if r=="AXTextArea",n.contains("Write your prompt to Claude") {draft=string(e,"AXValue")}
            if r=="AXPopUpButton" {
                if n.hasPrefix("Model:"){model=String(n.dropFirst(6)).trimmingCharacters(in:.whitespaces)}
                if let recognized=accountScope(n,personalLabel:UserDefaults.standard.string(forKey:"personalAccountLabel") ?? "",workLabel:UserDefaults.standard.string(forKey:"workAccountLabel") ?? "") {scope=recognized;accountLabel=n}
            }
            if r=="AXRadioButton",n=="Code",(attr(e,"AXValue") as? NSNumber)?.intValue==1 {code=true}
            if r=="AXButton",["Stop response","Stop generating","Stop","Stop task"].contains(n) {busy=true}
            let parts=n.split(separator:" ")
            if parts.count==4,parts[0]=="Message",parts[2]=="of",let index=Int(parts[1]),let total=Int(parts[3]) {
                expected=max(expected,total);messages.append(Message(index,role(e) ?? .other,text(e)));return
            }
            for c in children(e){walk(c,depth+1)}
        }
        // Only the focused/main window: never combine separate Claude windows.
        if let w=attr(root,"AXFocusedWindow"),CFGetTypeID(w)==AXUIElementGetTypeID() {walk(unsafeBitCast(w,to:AXUIElement.self),0)}
        else if let w=(attr(root,"AXWindows") as? [AXUIElement])?.first {walk(w,0)}
        if code {return ReadResult(status:"Code tab detected — regular Chat only",nodes:count)}
        guard !chat.isEmpty else {return ReadResult(status:newChat ? "Ready for a new chat" : "Open a regular Claude chat",nodes:count,newChatScope:newChat ? scope : nil,draft:newChat && scope != nil ? draft : "",model:model,accountLabel:accountLabel)}
        guard scope != nil else {return ReadResult(status:"Account label unrecognized — tracking paused",nodes:count,messageCount:messages.count)}
        messages.sort{$0.index<$1.index}
        let complete = !truncated && messages.count==expected && messages.enumerated().allSatisfy{$0.offset+1==$0.element.index}
        let snapshot=Snapshot(chat:chat,scope:scope,model:model,messages:messages,busy:busy,complete:complete)
        return ReadResult(snapshot:snapshot,status:complete ? "Observing accessible replies" : "Incomplete chat loaded — tracking paused",nodes:count,messageCount:messages.count,draft:draft,model:model,contextTokens:estimate(messages.map(\.text).joined(separator:"\n")),accountLabel:accountLabel)
    }
}
