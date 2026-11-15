---
title: 'Claude Pocket Checker: checking the model before sending the prompt'
description: 'Building a separate SwiftUI macOS companion that estimates regular Claude Desktop Chat usage and gives local model and effort advice before sending, without modifying Claude.'
date: 2026-11-15
kind: 'Native developer tools'
format: 'project-update'
draft: true
takeaways:
  - 'Read regular Desktop Chat through Accessibility while leaving the official Claude app intact.'
  - 'Keep draft advice local and explain the assumptions behind model-price comparisons.'
  - 'Separate observation, persistence and native input automation when testing a desktop companion.'
---

I do a lot of Claude work on my Mac, with local tools and browser agents connected to it. A meter that only worked in a browser covered part of that workflow. I wanted a small panel beside regular Claude Desktop Chat, with estimated input and output, a running total, and separate personal and work records.

I also manage people who can use their allowance quickly by choosing the heaviest model and effort for routine work. I wanted a useful prompt before sending: what model is a reasonable starting point for this task, and what assumptions are behind the comparison?

That became [Claude Pocket Checker](https://github.com/RaDeleon/Claude-Pocket-Checker), a separate native macOS companion built with SwiftUI, AppKit and read-only Accessibility queries.

## The problem

Keeping the official app intact was part of the requirement. I wanted to keep using my existing login and Mac workflow. The companion does not supply a Claude client, intercept requests or ask for an API key.

Accessibility provided enough structure to identify user messages, Claude replies, the selected model, the account control and the unsent composer text. That made a local observer feasible, with the same accounting constraint as the browser project: visible text is only part of the workload.

<figure class="article-figure">
  <img src="/images/writing/claude-pocket-checker-hero.svg" alt="Claude Pocket Checker product illustration showing local draft advice, hypothetical API comparisons and separate account totals using synthetic data." loading="lazy" />
  <figcaption>Illustrative panel with synthetic data. Advice and price scenarios are explained as assumptions, not provider-reported usage.</figcaption>
</figure>

## What changed

The independent floating panel shows estimates after new observed replies, a current-chat total and separate Personal and Work totals. Each user configures the account labels displayed by their own Claude installation. Unknown or ambiguous labels pause accounting.

Drafts are processed in memory. The local advisor uses transparent keyword and length rules to infer a task category, with a manual override when the inference is wrong. Basic writing starts with Sonnet at low effort; Haiku suggestions are optional and depend on availability. Bounded coding, difficult reasoning and consequential review receive different guidance.

The user chooses the model and effort in Claude. The companion does not click or type, and it does not send the draft to another AI model to make its recommendation.

## A closer look at the code

The first tracking bug came from an ordinary interface transition. Claude can briefly expose an incomplete message list while a reply loads. Clearing the pending observation at that moment caused a legitimate first reply to disappear from the meter's accounting.

The [tracker](https://github.com/RaDeleon/Claude-Pocket-Checker/blob/main/Sources/MeterCore/MeterCore.swift) now preserves the observation while requiring complete data before it commits:

```swift
guard let scope = s.scope, s.chat.count == 64 else {
    reset()
    return nil
}
guard s.complete,
      let user = s.messages.last(where: { $0.role == .user })
else { return nil }
```

That guard cannot reconstruct missing context. It prevents an intermediate state from erasing a valid pending turn. Dedicated tests cover the hydration gap, fresh-chat arming, streaming, retries and repeat snapshots.

## Price comparisons need a defined scenario

The advisor compares the same estimated visible input and a selected hypothetical output size across models. It can show a model's standard API-price ratio under those assumptions.

It cannot know how much extra thinking a higher effort setting will produce, predict exactly how many output tokens another model would use, or guarantee that two models give an equally useful answer. A Team subscription's allowance is also not a published token-to-dollar conversion.

I kept those limits in the panel. The recommendation is a starting point that someone can review against the task's actual acceptance criteria. The [accounting guide](https://github.com/RaDeleon/Claude-Pocket-Checker/blob/main/docs/ACCOUNTING.md) documents the distinction.

## Native observation and native input are different test paths

During development, physical typing began doubling while a native automation controller was also attached to Claude. Stopping the meter did not resolve it. Read-only event-tap metadata showed modifying keyboard hooks owned by that automation helper. After the helper was stopped and its hooks disappeared, I confirmed normal typing; it remained normal when the read-only meter was running.

That sequence supported keeping the automation path out of further acceptance tests. It did not prove every internal cause of the input problem. The product itself installs no keyboard hook and synthesizes no keystrokes. A desktop utility still needs manual input-reliability checks, especially when it will run alongside someone's normal work.

## How I verified it

| Check | Observed result |
| --- | --- |
| Offline source suite | 24 tests pass, including advisor rules, scope isolation and persistence fields. |
| Installed predecessor | First and follow-up replies were captured; a full restart retained two records without duplicates. |
| Local data boundary | The ledger contains numeric counters, opaque IDs and model/time metadata, without conversation or draft bodies. |
| Manual draft acceptance | I confirmed model/effort advice and normal typing with native Computer Use off. |
| Public build | Generalized account defaults and the separate product identity compile; live Work switching and broader team deployment remain open. |

The public preview is installed from source. Local builds are ad-hoc signed; Developer ID signing and notarization are not claimed. Accessibility is a broad permission, so the implementation and its narrow intended read path need to be inspectable.

## What comes next

The next work is wider manual acceptance, better task fixtures and evaluation of recommendations against real outcomes. I have not measured team-wide quota savings or established that a cheaper model gives the same answer on every routine task.

The [project page](/projects/claude-pocket-checker/) covers the native architecture and current scope. The [repository](https://github.com/RaDeleon/Claude-Pocket-Checker) includes the source, tests, setup and privacy notes. The browser counterpart, [Claude Browser Accountant](/projects/claude-browser-accountant/), covers ordinary Claude.ai web chats with a different observation boundary.
