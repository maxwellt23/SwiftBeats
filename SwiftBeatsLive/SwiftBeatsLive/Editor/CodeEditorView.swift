//
//  CodeEditorView.swift
//  SwiftBeatsLive
//
//  Created by Tyler Maxwell on 6/3/26.
//

import SwiftUI
import AppKit

// MARK: - SwiftBeatsTextView
//
// NSTextView subclass so we can override keyDown for Cmd+/ comment toggling.
// This is the correct AppKit pattern — key handling belongs on the view,
// not on the NSObject-based Coordinator which has no responder chain.

final class SwiftBeatsTextView: NSTextView {

    var onToggleComment: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // keyCode 44 = / on all standard layouts, Cmd modifier = Cmd+/
        if event.modifierFlags.contains(.command) && event.keyCode == 44 {
            onToggleComment?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - CodeEditorView

struct CodeEditorView: NSViewRepresentable {

    @Binding var text: String
    var onRun: () -> Void
    var sequenceLineInfos: [SequenceLineInfo] = []
    var sequencerSteps: [Int: Int] = [:]
    var errorLineIndex: Int? = nil

    func makeNSView(context: Context) -> NSScrollView {
        // NSTextView's designated initialiser that properly wires the
        // text storage chain is init(frame:textContainer:).
        // We must build the stack in order, then pass the container in.
        //
        // Correct assembly order (AppKit requirement):
        //   1. NSTextStorage
        //   2. NSLayoutManager  → addLayoutManager on storage
        //   3. NSTextContainer  → addTextContainer on layoutManager
        //   4. NSTextView(frame:textContainer:)   ← uses the container we made
        //
        // Assigning textView.textContainer after init (as we did before)
        // leaves textView.textStorage nil because the view already created
        // its own private storage during init().

        let storage   = NSTextStorage()
        let layout    = NSLayoutManager()
        let container = NSTextContainer(
            size: CGSize(width: CGFloat.greatestFiniteMagnitude,
                         height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = true

        storage.addLayoutManager(layout)
        layout.addTextContainer(container)

        let textView = SwiftBeatsTextView(frame: .zero, textContainer: container)

        textView.delegate                             = context.coordinator
        textView.isRichText                           = false
        textView.allowsUndo                           = true
        textView.isVerticallyResizable                = true
        textView.isHorizontallyResizable              = false
        textView.autoresizingMask                     = .width
        textView.font                                 = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor                      = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
        textView.textColor                            = .white
        textView.insertionPointColor                  = .green
        textView.selectedTextAttributes               = [.backgroundColor: NSColor.green.withAlphaComponent(0.3)]
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled             = false
        textView.textContainerInset                   = NSSize(width: 12, height: 12)

        textView.onToggleComment = { [weak textView] in
            guard let tv = textView else { return }
            context.coordinator.toggleComment(in: tv)
        }

        let scrollView = NSScrollView()
        scrollView.documentView        = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers  = true
        scrollView.backgroundColor     = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)

        context.coordinator.isSettingText = true
        textView.string = text
        context.coordinator.isSettingText = false
        applyHighlighting(to: textView)

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SwiftBeatsTextView else { return }
        if textView.string != text {
            context.coordinator.isSettingText = true
            let sel = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(sel)
            context.coordinator.isSettingText = false
            applyHighlighting(to: textView)
        }
        context.coordinator.updateStepHighlightsIfNeeded(in: textView, parent: self)
    }

    func applyStepHighlights(to textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let storage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        // Green: current note token in each running sequence
        for (idx, info) in sequenceLineInfos.enumerated() {
            let step = sequencerSteps[idx] ?? 0
            guard step < info.noteCharRanges.count else { continue }
            let nr = info.noteCharRanges[step]
            guard nr.location != NSNotFound, nr.location + nr.length <= storage.length else { continue }
            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: NSColor.green.withAlphaComponent(0.40),
                forCharacterRange: nr
            )
        }

        // Red: line that produced a parse error
        if let errLine = errorLineIndex {
            let nsText = storage.string as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: 0, length: 0))
            // Walk to the correct line
            var offset = 0
            var currentLine = 0
            while currentLine < errLine && offset < nsText.length {
                let lr = nsText.lineRange(for: NSRange(location: offset, length: 0))
                offset = lr.location + lr.length
                currentLine += 1
            }
            if currentLine == errLine {
                let lr = nsText.lineRange(for: NSRange(location: offset, length: 0))
                if lr.location + lr.length <= storage.length {
                    layoutManager.addTemporaryAttribute(
                        .backgroundColor,
                        value: NSColor.systemRed.withAlphaComponent(0.20),
                        forCharacterRange: lr
                    )
                }
            }
            _ = lineRange
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: - Highlighting

    func applyHighlighting(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let text = textView.string
        let full = NSRange(text.startIndex..., in: text)

        storage.setAttributes([
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ], range: full)

        applyRule(#"\b(play|chord|sequence|seq|reverb|filter|delay|tempo|bpm|stop)\b"#,
                  [.foregroundColor: NSColor.systemBlue], storage, text)
        applyRule(#"\b[A-Ga-g][#b]?[0-8]\b"#,
                  [.foregroundColor: NSColor.systemGreen], storage, text)
        applyRule(#"\b(wave|env|vel|dur|mix|feedback|instrument|inst):"#,
                  [.foregroundColor: NSColor.systemOrange], storage, text)
        applyRule(#"\b\d+(\.\d+)?\b"#,
                  [.foregroundColor: NSColor.systemPurple], storage, text)
        applyRule(#"\b(sine|square|saw|sawtooth|triangle|tri|pluck|piano|pad|organ|vibraphone|vibe|marimba|bell|flute|strings|string)\b"#,
                  [.foregroundColor: NSColor.systemTeal], storage, text)
        // Comments last — overrides all rules above
        applyRule(#"//.*$"#, [
            .foregroundColor: NSColor.gray,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .light)
        ], storage, text, options: .anchorsMatchLines)
    }

    private func applyRule(
        _ pattern: String,
        _ attrs: [NSAttributedString.Key: Any],
        _ storage: NSTextStorage,
        _ text: String,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            storage.addAttributes(attrs, range: match.range)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {

        let parent: CodeEditorView
        var isSettingText = false
        weak var textView: SwiftBeatsTextView?
        private var lastHighlightSteps: [Int: Int] = [:]
        private var lastHighlightLineIndices: [Int] = []
        private var lastErrorLineIndex: Int? = -1   // sentinel so first render always fires

        init(parent: CodeEditorView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertNote(_:)),
                name: .insertNote,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func handleInsertNote(_ notification: Notification) {
            guard let text = notification.object as? String,
                  let tv = textView else { return }
            let range = tv.selectedRange()
            if tv.shouldChangeText(in: range, replacementString: text) {
                tv.textStorage?.replaceCharacters(in: range, with: text)
                tv.didChangeText()
                tv.setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
            }
        }

        func updateStepHighlightsIfNeeded(in textView: NSTextView, parent: CodeEditorView) {
            let indices = parent.sequenceLineInfos.map(\.lineIndex)
            guard parent.sequencerSteps != lastHighlightSteps
                    || indices != lastHighlightLineIndices
                    || parent.errorLineIndex != lastErrorLineIndex else { return }
            lastHighlightSteps = parent.sequencerSteps
            lastHighlightLineIndices = indices
            lastErrorLineIndex = parent.errorLineIndex
            parent.applyStepHighlights(to: textView)
        }

        func textDidChange(_ notification: Notification) {
            guard !isSettingText,
                  let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            let sel = tv.selectedRange()
            parent.applyHighlighting(to: tv)
            tv.setSelectedRange(sel)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)),
               NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                parent.onRun()
                return true
            }
            return false
        }

        // MARK: - Comment toggle (called from SwiftBeatsTextView.keyDown)

        func toggleComment(in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }

            let fullText  = storage.string as NSString
            let selection = textView.selectedRange()
            let lineRange = fullText.lineRange(for: selection)
            let block     = fullText.substring(with: lineRange)
            var lines     = block.components(separatedBy: .newlines)
            
            if lines.last == "" { lines.removeLast() }

            let nonEmpty     = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let allCommented = nonEmpty.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }

            let toggledLines = lines.map { line -> String in
                if allCommented {
                    if let r = line.range(of: "//") {
                        var s = line; s.removeSubrange(r); return s
                    }
                    return line
                } else {
                    return "//" + line
                }
            }
            
            let toggled = toggledLines.joined(separator: "\n") + "\n"

            if textView.shouldChangeText(in: lineRange, replacementString: toggled) {
                storage.replaceCharacters(in: lineRange, with: toggled)
                textView.didChangeText()
            }

            let newLen = min(toggled.count, max(0, storage.length - lineRange.location))
            textView.setSelectedRange(NSRange(location: lineRange.location, length: newLen))

            parent.text = storage.string
            let sel = textView.selectedRange()
            parent.applyHighlighting(to: textView)
            textView.setSelectedRange(sel)
        }
    }
}

// MARK: - Line Number Gutter

struct LineNumberGutter: View {
    let text: String
    let lineHeight: CGFloat = 20

    private var lineCount: Int {
        text.components(separatedBy: .newlines).count
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...max(1, lineCount), id: \.self) { n in
                Text("\(n)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.gray.opacity(0.4))
                    .frame(height: lineHeight)
            }
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
    }
}
