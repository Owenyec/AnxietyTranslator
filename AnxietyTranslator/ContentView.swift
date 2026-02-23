import SwiftUI

// MARK: - Anxiety Translator (iPad scaled, original glass style preserved)
// iOS/iPadOS 16+ compatible. No AppKit. No NavigationStack required.

private struct Metrics {
    let isPad: Bool

    // Typography
    var hero: CGFloat { isPad ? 56 : 44 }
    var title: CGFloat { isPad ? 44 : 34 }
    var h2: CGFloat { isPad ? 26 : 20 }
    var body: CGFloat { isPad ? 19 : 15 }
    var small: CGFloat { isPad ? 15 : 12 }

    // Layout
    var sidePad: CGFloat { isPad ? 42 : 16 }
    var topPad: CGFloat { isPad ? 26 : 18 }
    var gap: CGFloat { isPad ? 16 : 12 }
    var cardPad: CGFloat { isPad ? 22 : 16 }

    // Controls
    var pillH: CGFloat { isPad ? 50 : 40 }
    var buttonH: CGFloat { isPad ? 58 : 44 }
    var rowH: CGFloat { isPad ? 66 : 48 }
    var radius: CGFloat { isPad ? 24 : 18 }
    var stroke: CGFloat { isPad ? 1.2 : 1.0 }
}

// MARK: - Models

private enum FashionMood: String, CaseIterable, Identifiable {
    case calm = "Calm"
    case focus = "Focus"
    case confidence = "Confidence"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .calm: return Color(red: 0.18, green: 0.78, blue: 0.70)        // teal
        case .focus: return Color(red: 0.30, green: 0.52, blue: 0.98)       // blue
        case .confidence: return Color(red: 0.70, green: 0.42, blue: 0.98)  // purple
        }
    }
}

private enum Screen: Equatable {
    case story
    case input
    case translating(original: String)
    case result(TranslationResult)
    case landing(TranslationResult)
    case ending
}

private enum ToolType: String, CaseIterable, Identifiable {
    case breathing
    case grounding
    case journal
    case reset
    case focusSprint
    case thoughtChallenger
    case copingCards
    case buddy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathing: return "Guided Breathing"
        case .grounding: return "Grounding 5‑4‑3‑2‑1"
        case .journal: return "Mini Journal"
        case .reset: return "60‑Second Reset"
        case .focusSprint: return "Focus Sprint"
        case .thoughtChallenger: return "Thought Challenger"
        case .copingCards: return "Coping Cards"
        case .buddy: return "Buddy Chat"
        }
    }

    var subtitle: String {
        switch self {
        case .breathing: return "Calm your body first"
        case .grounding: return "Return to the present"
        case .journal: return "Make the thought readable"
        case .reset: return "Fast nervous‑system reset"
        case .focusSprint: return "Start action in 5 minutes"
        case .thoughtChallenger: return "Check the evidence gently"
        case .copingCards: return "Safe reminders you can reuse"
        case .buddy: return "Talk it out with a friend voice"
        }
    }

    var icon: String {
        switch self {
        case .breathing: return "wind"
        case .grounding: return "hand.raised.fill"
        case .journal: return "pencil.and.outline"
        case .reset: return "timer"
        case .focusSprint: return "bolt.fill"
        case .thoughtChallenger: return "brain.head.profile"
        case .copingCards: return "rectangle.stack.fill"
        case .buddy: return "message.fill"
        }
    }
}

private struct TranslationResult: Identifiable, Equatable {
    let id = UUID()
    let mood: FashionMood
    let original: String
    let emotionLabel: String
    let patternTag: String
    let readableTranslation: String
    let why: String
    let reframe: String
    let oneSmallStep: String
}

// MARK: - Main

struct ContentView: View {

    @Environment(\.horizontalSizeClass) private var hSize
    private var m: Metrics { Metrics(isPad: hSize == .regular) }

    @State private var mood: FashionMood = .calm
    @State private var screen: Screen = .story

    @State private var inputText: String = ""
    @State private var activeTool: ToolType? = nil

    // background motion
    @State private var blobShiftA: CGFloat = 0
    @State private var blobShiftB: CGFloat = 0

    var body: some View {
        ZStack {
            FashionBackground(accent: mood.accent, blobShiftA: blobShiftA, blobShiftB: blobShiftB)

            CenteredContainer(maxWidth: hSize == .regular ? 980 : 680, sidePad: m.sidePad, topPad: m.topPad) {
                switch screen {
                case .story:
                    StoryScreen(m: m, accent: mood.accent) {
                        withAnimation(.easeInOut(duration: 0.25)) { screen = .input }
                    }

                case .input:
                    InputScreen(
                        m: m,
                        mood: $mood,
                        accent: mood.accent,
                        inputText: $inputText,
                        onTranslate: startTranslate,
                        onUseSample: { inputText = sampleText() }
                    )

                case .translating(let original):
                    TranslatingScreen(m: m, accent: mood.accent, original: original)

                case .result(let result):
                    ResultScreen(
                        m: m,
                        accent: mood.accent,
                        result: result,
                        onBackToInput: { withAnimation(.easeInOut(duration: 0.25)) { screen = .input } },
                        onNext: { withAnimation(.easeInOut(duration: 0.25)) { screen = .landing(result) } }
                    )

                case .landing(let result):
                    LandingScreen(
                        m: m,
                        accent: mood.accent,
                        result: result,
                        onOpenTool: { tool in activeTool = tool },
                        onBack: { withAnimation(.easeInOut(duration: 0.25)) { screen = .result(result) } },
                        onFinish: { withAnimation(.easeInOut(duration: 0.25)) { screen = .ending } }
                    )

                case .ending:
                    EndingScreen(m: m, accent: mood.accent) {
                        inputText = ""
                        withAnimation(.easeInOut(duration: 0.25)) { screen = .input }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) { blobShiftA = 160 }
            withAnimation(.easeInOut(duration: 10.0).repeatForever(autoreverses: true)) { blobShiftB = -190 }
        }
        .sheet(item: $activeTool) { tool in
            ToolSheet(m: m, accent: mood.accent, tool: tool)
        }
    }

    // MARK: - Actions

    private func startTranslate() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        let original = trimmed
        inputText = ""

        withAnimation(.easeInOut(duration: 0.25)) { screen = .translating(original: original) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            let result = translateThought(original, mood: mood)
            withAnimation(.easeInOut(duration: 0.25)) { screen = .result(result) }
        }
    }

fileprivate func applyModeTone(mood: FashionMood, readable: String, why: String, reframe: String, step: String) -> (String, String, String, String) {
    switch mood {
    case .calm:
        return (
            "Slow it down → \(readable)",
            why + "\n\nCalm mode: lower the volume first, then move 1% forward.",
            "Gentle reframe: \(reframe)\n\nTry: name 1 fact + 1 feeling.",
            "One calm step: \(step)\n• Exhale slowly (6s) once\n• Write: “Next, I will ____.”"
        )
    case .focus:
        return (
            "Turn noise into a plan → \(readable)",
            why + "\n\nFocus mode: uncertainty steals attention. Pick the next 10 minutes.",
            "Practical reframe: \(reframe)\n\nAsk: what action creates information?",
            "Next 10 minutes: \(step)\n• Set a 10‑min timer\n• Do only the first step."
        )
    case .confidence:
        return (
            "Turn fear into courage → \(readable)",
            why + "\n\nConfidence mode: your brain is protecting you. Borrow bravery and act anyway (1% step).",
            "Confidence reframe: \(reframe)\n\nSay: “I can handle discomfort for one small action.”",
            "Brave 1% move: \(step)\n• Pick one bold‑but‑safe action\n• Do it now, then celebrate the attempt."
        )
    }
}

fileprivate func translateThought(_ text: String, mood: FashionMood) -> TranslationResult {
        let lower = text.lowercased()

        func make(_ emotion: String, _ pattern: String, _ readable: String, _ why: String, _ reframe: String, _ step: String) -> TranslationResult {
    let toned = applyModeTone(mood: mood, readable: readable, why: why, reframe: reframe, step: step)
    let modeLabel: String = {
        switch mood {
        case .calm: return "Calm"
        case .focus: return "Focus"
        case .confidence: return "Confidence"
        }
    }()

    return TranslationResult(
        mood: mood,
        original: text,
        emotionLabel: emotion,
        patternTag: "\(pattern) · \(modeLabel)",
        readableTranslation: toned.0,
        why: toned.1,
        reframe: toned.2,
        oneSmallStep: toned.3
    )
}

        if (lower.contains("they") && (lower.contains("think") || lower.contains("judge") || lower.contains("laugh"))) ||
            lower.contains("everyone will") || lower.contains("people will") {
            return make(
                "Social Anxiety",
                "Mind Reading",
                "I’m guessing other people’s thoughts — and treating the guess like a fact.",
                "When you’re stressed, your brain fills in missing social info with assumptions. It’s protective, but not always accurate.",
                "I can’t read minds. I can focus on what I control: one clear sentence, one calm breath, one next step.",
                "Ground for 30 seconds, then pick one small action you control."
            )
        }

        if lower.contains("perfect") || lower.contains("ruined") || lower.contains("always") || lower.contains("never") {
            return make(
                "Pressure",
                "All‑or‑Nothing",
                "I’m measuring myself in extremes. Anything less than perfect feels like failure.",
                "All‑or‑nothing thinking shows up when the stakes feel high. It narrows your options so you can feel certain.",
                "Good enough still counts. One imperfect step is more real than zero perfect steps.",
                "Do a 5‑minute focus sprint on the smallest task."
            )
        }

        if lower.contains("what if") || lower.contains("fail") || lower.contains("mess up") || lower.contains("worst") {
            return make(
                "Fear",
                "Catastrophizing",
                "My brain is rehearsing the worst‑case to feel safer — not because it’s true.",
                "When uncertainty rises, your mind runs scary scenarios to prepare. It’s protection, just too loud.",
                "The worst‑case is one possibility — not the most likely. I can plan one step without predicting everything.",
                "Breathe once, then write the smallest next action that reduces uncertainty by 1%."
            )
        }

        if lower.contains("tired") || lower.contains("exhaust") || lower.contains("burn") || lower.contains("overwhelm") {
            return make(
                "Overload",
                "Overthinking Loop",
                "My nervous system is overloaded, not broken. I need a smaller next step.",
                "When energy is low, your brain tries to solve everything at once — which feels like paralysis.",
                "I don’t need full motivation. I just need a tiny action that makes the next step easier.",
                "Pick one ‘tiny win’ you can finish in 3–5 minutes."
            )
        }

        return make(
            "Anxiety",
            "Uncertainty Loop",
            "I’m trying to get 100% certainty before moving. But I can move with 60% clarity.",
            "Uncertainty triggers endless ‘what‑ifs’ to regain control. The goal is to lower the volume, not erase thoughts.",
            "I can’t solve the whole future. I can do the next step that makes things slightly clearer.",
            "Do grounding, then choose one small action that doesn’t require certainty."
        )
    }

    private func sampleText() -> String {
        "What if I mess up my presentation and everyone thinks I’m not good enough?"
    }
}

// MARK: - Screens

private struct StoryScreen: View {
    let m: Metrics
    let accent: Color
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: m.gap) {
            HStack {
                TagPill(m: m, text: "Final Demo • Offline", icon: "lock.fill", accent: accent)
                Spacer()
            }

            Text("Why I built\nAnxiety Translator")
                .font(.system(size: m.hero, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            FashionBlock(m: m, accent: accent) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Before exams, my thoughts become noise.")
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))

                    Text("I didn’t need more advice. I needed my thoughts to become readable — so I could take one small step.")
                        .font(.system(size: m.body))
                        .foregroundColor(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    DividerLine()

                    Text("Not therapy. Not diagnosis.\nJust clarity + the next step.")
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                }
            }

            Button(action: onStart) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Start translating")
                }
                .frame(height: m.buttonH)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))

            Spacer(minLength: 0)
        }
    }
}

private struct InputScreen: View {
    let m: Metrics
    @Binding var mood: FashionMood
    let accent: Color
    @Binding var inputText: String
    let onTranslate: () -> Void
    let onUseSample: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: m.gap) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Anxiety Translator")
                        .font(.system(size: m.title, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Turn brain‑noise into readable language.")
                        .font(.system(size: m.body, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.76))
                }
                Spacer()
                TagPill(m: m, text: "Not medical advice", icon: "exclamationmark.shield.fill", accent: accent)
            }

            HStack(spacing: 10) {
                ForEach(FashionMood.allCases) { item in
                    PillButton(m: m, title: item.rawValue, isSelected: item == mood, accent: item.accent) {
                        withAnimation(.easeInOut(duration: 0.2)) { mood = item }
                    }
                }
            }

            FashionBlock(m: m, accent: accent) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What’s on your mind?")
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    TextEditor(text: $inputText)
                        .font(.system(size: m.body, design: .rounded))
                        .frame(height: m.isPad ? 200 : 160)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(m.radius)

                    HStack(spacing: 12) {
                        Button(action: onTranslate) {
                            HStack(spacing: 10) {
                                Image(systemName: "quote.bubble.fill")
                                Text("Translate")
                            }
                            .frame(height: m.buttonH)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(action: onUseSample) {
                            Text("Use sample")
                                .frame(height: m.buttonH)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(m: m))
                    }

                    Text("Tip: 1–2 sentences is enough.")
                        .font(.system(size: m.small, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            FashionBlock(m: m, accent: accent) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your journey")
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    HStack(spacing: 10) {
                        StepChip(m: m, title: "Enter", icon: "pencil")
                        StepChip(m: m, title: "Translate", icon: "quote.bubble")
                        StepChip(m: m, title: "Guide", icon: "location")
                        StepChip(m: m, title: "Land", icon: "flag")
                    }
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TranslatingScreen: View {
    let m: Metrics
    let accent: Color
    let original: String
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: m.gap) {

            Text("Translating…")
                .font(.system(size: m.title, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            FashionBlock(m: m, accent: accent) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You typed")
                        .font(.system(size: m.small, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))

                    Text("“\(original)”")
                        .font(.system(size: m.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)

                    DividerLine()

                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.10)).frame(width: m.isPad ? 64 : 52, height: m.isPad ? 64 : 52)
                            Circle()
                                .stroke(accent.opacity(0.55), lineWidth: 2)
                                .frame(width: m.isPad ? 64 : 52, height: m.isPad ? 64 : 52)
                                .scaleEffect(pulse ? 1.12 : 0.92)
                                .opacity(pulse ? 0.35 : 0.85)
                                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulse)
                            Image(systemName: "sparkles").foregroundColor(.white.opacity(0.85))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Making it readable…")
                                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.86))
                            Text("Not therapy. Just clarity.")
                                .font(.system(size: m.small, design: .rounded))
                                .foregroundColor(.white.opacity(0.55))
                        }

                        Spacer()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .onAppear { pulse = true }
    }
}

private struct ResultScreen: View {
    let m: Metrics
    let accent: Color
    let result: TranslationResult
    let onBackToInput: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: m.gap) {

                HStack {
                    Button(action: onBackToInput) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Start over")
                        }
                        .frame(height: m.buttonH)
                    }
                    .buttonStyle(SecondaryButtonStyle(m: m))

                    Spacer()

                    TagPill(m: m, text: "Pattern: \(result.patternTag)", icon: "tag.fill", accent: accent)
                }

                Text(result.emotionLabel)
                    .font(.system(size: m.hero, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                MascotHeroCard(m: m, accent: accent, title: "Here’s the readable version:", message: result.readableTranslation)

                HStack(alignment: .top, spacing: m.gap) {
                    InfoCard(m: m, accent: accent, title: "Why your brain says this", icon: "brain.head.profile", message: result.why)
                    InfoCard(m: m, accent: accent, title: "Gentle reframe", icon: "sparkles", message: result.reframe)
                }

                FashionBlock(m: m, accent: accent) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Next")
                            .font(.system(size: m.body, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))

                        Button(action: onNext) {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                Text("Take one small step")
                                Spacer()
                                Image(systemName: "chevron.right").opacity(0.8)
                            }
                            .frame(height: m.rowH)
                        }
                        .buttonStyle(ActionRowStyle(m: m, accent: accent))

                        Text("Tip: one step is enough for today.")
                            .font(.system(size: m.small, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                FashionBlock(m: m, accent: accent) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What you typed")
                            .font(.system(size: m.small, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                        Text("“\(result.original)”")
                            .font(.system(size: m.body, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct LandingScreen: View {
    let m: Metrics
    let accent: Color
    let result: TranslationResult
    let onOpenTool: (ToolType) -> Void
    let onBack: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: m.gap) {

            HStack {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(height: m.buttonH)
                }
                .buttonStyle(SecondaryButtonStyle(m: m))

                Spacer()

                TagPill(m: m, text: "Choose one", icon: "checkmark.circle.fill", accent: accent)
            }

            Text("One small step")
                .font(.system(size: m.title, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            FashionBlock(m: m, accent: accent) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.oneSmallStep)
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    DividerLine()

                    
VStack(spacing: 12) {
    let tools: [ToolType] = {
        switch result.mood {
        case .calm:
            return [.breathing, .grounding, .journal, .buddy, .copingCards, .reset, .thoughtChallenger, .focusSprint]
        case .focus:
            return [.focusSprint, .journal, .thoughtChallenger, .grounding, .breathing, .buddy, .reset, .copingCards]
        case .confidence:
            return [.buddy, .copingCards, .journal, .thoughtChallenger, .breathing, .grounding, .reset, .focusSprint]
        }
    }()

    ForEach(tools, id: \.self) { t in
        ActionRow(m: m, accent: accent, tool: t) { onOpenTool(t) }
    }
}
                }
            }

            Button(action: onFinish) {
                HStack(spacing: 10) {
                    Image(systemName: "flag")
                    Text("Finish & land")
                }
                .frame(height: m.buttonH)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))

            Spacer(minLength: 0)
        }
    }
}

private struct EndingScreen: View {
    let m: Metrics
    let accent: Color
    let onTranslateAnother: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: m.gap) {
            TagPill(m: m, text: "Landing", icon: "flag.fill", accent: accent)

            Text("You don’t need to solve everything today.")
                .font(.system(size: m.title, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            FashionBlock(m: m, accent: accent) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Just make it readable.\nThen take one small step.")
                        .font(.system(size: m.h2, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    DividerLine()

                    Text("Want to translate another thought?")
                        .font(.system(size: m.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            Button(action: onTranslateAnother) {
                HStack(spacing: 10) {
                    Image(systemName: "quote.bubble.fill")
                    Text("Translate another thought")
                }
                .frame(height: m.buttonH)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Tool Sheet (Close button always available)

private struct ToolSheet: View {
    let m: Metrics
    let accent: Color
    let tool: ToolType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FashionBackground(accent: accent, blobShiftA: 120, blobShiftB: -140)
                .opacity(0.95)

            CenteredContainer(maxWidth: m.isPad ? 980 : 720, sidePad: m.sidePad, topPad: m.topPad) {
                VStack(alignment: .leading, spacing: m.gap) {
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: tool.icon)
                                .font(.system(size: m.isPad ? 22 : 18, weight: .semibold))
                                .foregroundColor(accent.opacity(0.95))
                            Text(tool.title)
                                .font(.system(size: m.h2, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button("Close") { dismiss() }
                            .frame(height: m.buttonH)
                            .buttonStyle(SecondaryButtonStyle(m: m))
                    }

                    FashionBlock(m: m, accent: accent) {
                        switch tool {
                        case .breathing: BreathingTool(m: m, accent: accent)
                        case .grounding: GroundingTool(m: m, accent: accent)
                        case .journal: MiniJournalTool(m: m)
                        case .reset: ResetTool(m: m, accent: accent)
                        case .focusSprint: FocusSprintTool(m: m, accent: accent)
                        case .thoughtChallenger: ThoughtChallengerTool(m: m)
                        case .copingCards: CopingCardsTool(m: m, accent: accent)
                        case .buddy: BuddyTool(m: m, accent: accent)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Tools (offline)

private struct BreathingTool: View {
    let m: Metrics
    let accent: Color

    private let phases: [(label: String, seconds: Double, targetScale: CGFloat)] = [
        ("Inhale", 4.0, 1.06),
        ("Hold",   2.0, 1.06),
        ("Exhale", 6.0, 0.90)
    ]

    @State private var index = 0
    @State private var scale: CGFloat = 0.90
    @State private var cycleCount = 0
    private let maxCycles = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Follow the rhythm 4–2–6 for \(maxCycles) cycles.")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.08)).frame(width: m.isPad ? 220 : 190, height: m.isPad ? 220 : 190)
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 2).frame(width: m.isPad ? 220 : 190, height: m.isPad ? 220 : 190)

                    Circle().fill(accent.opacity(0.14))
                        .frame(width: m.isPad ? 220 : 190, height: m.isPad ? 220 : 190)
                        .scaleEffect(scale)
                        .animation(.easeInOut(duration: phases[index].seconds), value: scale)

                    VStack(spacing: 6) {
                        Text(phases[index].label)
                            .font(.system(size: m.h2, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                        Text("\(Int(phases[index].seconds))s")
                            .font(.system(size: m.small, design: .rounded))
                            .foregroundColor(.white.opacity(0.60))
                        Text("Cycle \(min(cycleCount + 1, maxCycles))/\(maxCycles)")
                            .font(.system(size: m.small, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.58))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tip")
                        .font(.system(size: m.small, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                    Text("Relax shoulders • unclench jaw • slow exhale.")
                        .font(.system(size: m.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))

                    DividerLine()

                    Text("If you want: exhale longer than inhale.")
                        .font(.system(size: m.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))

                    Spacer()
                }
            }

            Button(action: restart) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Restart")
                }
                .frame(height: m.buttonH)
            }
            .buttonStyle(SecondaryButtonStyle(m: m))
        }
        .onAppear { restart() }
    }

    private func restart() {
        index = 0
        cycleCount = 0
        step()
    }

    private func step() {
        scale = phases[index].targetScale
        DispatchQueue.main.asyncAfter(deadline: .now() + phases[index].seconds) {
            if index == phases.count - 1 { cycleCount += 1 }
            if cycleCount >= maxCycles {
                index = 2
                scale = 0.92
                return
            }
            index = (index + 1) % phases.count
            step()
        }
    }
}

private struct GroundingTool: View {
    let m: Metrics
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name these (out loud or silently).")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            GroundRow(m: m, accent: accent, n: "5", text: "Things you can see")
            GroundRow(m: m, accent: accent, n: "4", text: "Things you can feel")
            GroundRow(m: m, accent: accent, n: "3", text: "Things you can hear")
            GroundRow(m: m, accent: accent, n: "2", text: "Things you can smell")
            GroundRow(m: m, accent: accent, n: "1", text: "Thing you can taste")

            DividerLine()

            Text("You don’t need perfect calm — just enough to return to the present.")
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

private struct GroundRow: View {
    let m: Metrics
    let accent: Color
    let n: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            TagPill(m: m, text: n, icon: "circle.fill", accent: accent)
            Text(text)
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.86))
            Spacer()
        }
        .padding(.vertical, m.isPad ? 10 : 8)
        .padding(.horizontal, m.isPad ? 14 : 10)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.10), lineWidth: m.stroke))
        .cornerRadius(m.radius)
    }
}

private struct MiniJournalTool: View {
    let m: Metrics
    @State private var situation = ""
    @State private var thought = ""
    @State private var evidence = ""
    @State private var kinderThought = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Make it readable in 4 prompts.")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            JournalField(m: m, title: "Situation", text: $situation)
            JournalField(m: m, title: "Thought", text: $thought)
            JournalField(m: m, title: "Evidence (for/against)", text: $evidence)
            JournalField(m: m, title: "Kinder alternative", text: $kinderThought)

            DividerLine()
            Text("Small is fine. One sentence each.")
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

private struct JournalField: View {
    let m: Metrics
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: m.small, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.70))
            TextField("…", text: $text)
                .font(.system(size: m.body, design: .rounded))
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct ResetTool: View {
    let m: Metrics
    let accent: Color
    @State private var step = 0

    private let steps = [
        "Put both feet on the floor.",
        "Unclench jaw. Drop shoulders.",
        "Exhale slowly for 6 seconds.",
        "Name one thing you can see.",
        "Say: “I can do the next small step.”"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("60‑Second Reset")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            FashionBlock(m: m, accent: accent) {
                Text(steps[step])
                    .font(.system(size: m.h2, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: { step = (step + 1) % steps.count }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Next step")
                }
                .frame(height: m.buttonH)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))

            Text("You can loop this anytime.")
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

private struct FocusSprintTool: View {
    let m: Metrics
    let accent: Color
    @State private var remaining: Int = 5 * 60
    @State private var running = false
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Sprint (5 minutes)")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Text(timeString(remaining))
                .font(.system(size: m.hero, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))

            HStack(spacing: 12) {
                Button(action: toggle) {
                    HStack(spacing: 10) {
                        Image(systemName: running ? "pause.fill" : "play.fill")
                        Text(running ? "Pause" : "Start")
                    }
                    .frame(height: m.buttonH)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))

                Button(action: reset) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .frame(height: m.buttonH)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(m: m))
            }

            Text("Only one tiny task. When the timer ends, stop — that counts.")
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
        .onDisappear { stopTimer() }
    }

    private func toggle() {
        running.toggle()
        if running { startTimer() } else { stopTimer() }
    }

    private func reset() {
        stopTimer()
        running = false
        remaining = 5 * 60
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 }
            else {
                stopTimer()
                running = false
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timeString(_ seconds: Int) -> String {
        let mm = seconds / 60
        let ss = seconds % 60
        return String(format: "%d:%02d", mm, ss)
    }
}

private struct ThoughtChallengerTool: View {
    let m: Metrics
    @State private var thought = ""
    @State private var evidenceFor = ""
    @State private var evidenceAgainst = ""
    @State private var balanced = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thought Challenger")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            JournalField(m: m, title: "The thought", text: $thought)
            JournalField(m: m, title: "Evidence for", text: $evidenceFor)
            JournalField(m: m, title: "Evidence against", text: $evidenceAgainst)
            JournalField(m: m, title: "Balanced thought", text: $balanced)

            DividerLine()
            Text("Goal: balance, not forced positivity.")
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

private struct CopingCardsTool: View {
    let m: Metrics
    let accent: Color

    private let cards = [
        "I can do the next small step.",
        "Feelings are real, not always facts.",
        "Breathe out longer than in.",
        "I don’t need certainty to begin.",
        "One imperfect step is progress."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coping Cards")
                .font(.system(size: m.body, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            ForEach(cards.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(accent.opacity(0.95))
                    Text(cards[i])
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.90))
                    Spacer()
                }
                .padding(.horizontal, m.isPad ? 16 : 12)
                .padding(.vertical, m.isPad ? 12 : 10)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.10), lineWidth: m.stroke))
                .cornerRadius(m.radius)
            }

            Text("You can screenshot these and reuse anytime.")
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

private struct BuddyTool: View {
    let m: Metrics
    let accent: Color

    private struct Message: Identifiable, Equatable {
        let id = UUID()
        let isUser: Bool
        let text: String
    }

    @State private var messages: [Message] = [
        .init(isUser: false, text: "Hey. I’m here. What’s the hardest part right now?"),
        .init(isUser: false, text: "You can answer in one sentence.")
    ]
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Supportive friend voice (offline)")
                .font(.system(size: m.small, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { msg in
                        ChatBubble(m: m, accent: accent, isUser: msg.isUser, text: msg.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
            .frame(height: m.isPad ? 380 : 320)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.10), lineWidth: m.stroke))
            .cornerRadius(m.radius)

            HStack(spacing: 10) {
                TextField("Type a short sentence…", text: $draft)
                    .font(.system(size: m.body, design: .rounded))
                    .textFieldStyle(.roundedBorder)

                Button(action: send) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    .frame(height: m.buttonH)
                }
                .buttonStyle(PrimaryButtonStyle(m: m, accent: accent))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("Buddy doesn’t diagnose. It helps you name the feeling + choose a tiny next step.")
                .font(.system(size: m.small, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private func send() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft = ""
        messages.append(.init(isUser: true, text: t))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            messages.append(.init(isUser: false, text: reply(to: t)))
        }
    }

    private func reply(to text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("fail") || lower.contains("mess") || lower.contains("ruin") {
            return "That sounds heavy. If we shrink it: what’s one 5‑minute step you can do right now?"
        }
        if lower.contains("they") && (lower.contains("think") || lower.contains("judge")) {
            return "Mind‑reading is common when anxious. What’s one neutral alternative explanation?"
        }
        if lower.contains("can't") || lower.contains("stuck") {
            return "I hear stuck‑ness. Want to pick the smallest next action that makes tomorrow 1% easier?"
        }
        return "Thanks for telling me. What emotion is underneath — fear, pressure, or something else?"
    }
}

// MARK: - Reusable UI

private struct CenteredContainer<Content: View>: View {
    let maxWidth: CGFloat
    let sidePad: CGFloat
    let topPad: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            content()
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, sidePad)
                .padding(.top, topPad)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct FashionBlock<Content: View>: View {
    let m: Metrics
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(m.cardPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: m.radius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: m.radius)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.18), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.14), lineWidth: m.stroke))
            .cornerRadius(m.radius)
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

private struct TagPill: View {
    let m: Metrics
    let text: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: m.small, weight: .semibold))
            Text(text).font(.system(size: m.small, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.90))
        .padding(.vertical, m.isPad ? 9 : 7)
        .padding(.horizontal, m.isPad ? 14 : 12)
        .background(Capsule().fill(accent.opacity(0.16)))
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: m.stroke))
        .clipShape(Capsule())
    }
}

private struct PillButton: View {
    let m: Metrics
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent.opacity(isSelected ? 0.90 : 0.40))
                    .frame(width: m.isPad ? 10 : 8, height: m.isPad ? 10 : 8)
                Text(title)
                    .font(.system(size: m.small, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.78))
            .padding(.horizontal, m.isPad ? 16 : 12)
            .frame(height: m.pillH)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(isSelected ? 0.14 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: m.radius)
                    .stroke(accent.opacity(isSelected ? 0.35 : 0.10), lineWidth: m.stroke)
            )
            .cornerRadius(m.radius)
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let m: Metrics
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: m.body, weight: .semibold, design: .rounded))
            .foregroundColor(.black.opacity(0.85))
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: m.radius)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.78 : 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: m.radius)
                    .stroke(accent.opacity(0.35), lineWidth: m.stroke)
            )
            .cornerRadius(m.radius)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    let m: Metrics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: m.body, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.90))
            .padding(.horizontal, 14)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.08))
            .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.12), lineWidth: m.stroke))
            .cornerRadius(m.radius)
    }
}

private struct ActionRowStyle: ButtonStyle {
    let m: Metrics
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: m.body, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, m.isPad ? 18 : 14)
            .background(Color.white.opacity(configuration.isPressed ? 0.10 : 0.08))
            .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(accent.opacity(0.22), lineWidth: m.stroke))
            .cornerRadius(m.radius)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
    }
}

private struct StepChip: View {
    let m: Metrics
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.white.opacity(0.10)).frame(width: m.isPad ? 34 : 28, height: m.isPad ? 34 : 28)
                Image(systemName: icon)
                    .font(.system(size: m.isPad ? 14 : 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
            }
            Text(title)
                .font(.system(size: m.small, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
        }
        .padding(.vertical, m.isPad ? 10 : 8)
        .padding(.horizontal, m.isPad ? 12 : 10)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.10), lineWidth: m.stroke))
        .cornerRadius(m.radius)
    }
}

private struct ActionRow: View {
    let m: Metrics
    let accent: Color
    let tool: ToolType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: m.isPad ? 14 : 10) {
                Image(systemName: tool.icon)
                    .font(.system(size: m.isPad ? 20 : 16, weight: .semibold))
                    .foregroundColor(accent.opacity(0.95))

                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.title)
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                    Text(tool.subtitle)
                        .font(.system(size: m.small, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: m.isPad ? 18 : 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(height: m.rowH)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: m.radius).stroke(Color.white.opacity(0.12), lineWidth: m.stroke))
        .cornerRadius(m.radius)
    }
}

private struct MascotHeroCard: View {
    let m: Metrics
    let accent: Color
    let title: String
    let message: String

    var body: some View {
        FashionBlock(m: m, accent: accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(accent.opacity(0.22)).frame(width: m.isPad ? 44 : 36, height: m.isPad ? 44 : 36)
                        Image(systemName: "face.smiling.fill")
                            .foregroundColor(.white.opacity(0.92))
                    }
                    Text(title)
                        .font(.system(size: m.small, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                    Spacer()
                }

                Text(message)
                    .font(.system(size: m.h2, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct InfoCard: View {
    let m: Metrics
    let accent: Color
    let title: String
    let icon: String
    let message: String

    var body: some View {
        FashionBlock(m: m, accent: accent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundColor(accent.opacity(0.95))
                    Text(title)
                        .font(.system(size: m.body, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.90))
                    Spacer()
                }

                Text(message)
                    .font(.system(size: m.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ChatBubble: View {
    let m: Metrics
    let accent: Color
    let isUser: Bool
    let text: String

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 0) }

            Text(text)
                .font(.system(size: m.body, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .padding(.vertical, m.isPad ? 12 : 10)
                .padding(.horizontal, m.isPad ? 14 : 12)
                .background(isUser ? accent.opacity(0.18) : Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: m.radius)
                        .stroke(Color.white.opacity(0.10), lineWidth: m.stroke)
                )
                .cornerRadius(m.radius)
                .frame(maxWidth: m.isPad ? 640 : 540, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Background

private struct FashionBackground: View {
    let accent: Color
    let blobShiftA: CGFloat
    let blobShiftB: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.12),
                         Color(red: 0.03, green: 0.05, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Blob(x: 160 + blobShiftA, y: 140, size: 520, c1: accent.opacity(0.28), c2: Color.white.opacity(0.07))
            Blob(x: 700, y: 360 + blobShiftB, size: 640, c1: accent.opacity(0.18), c2: Color.white.opacity(0.05))
            Blob(x: 320, y: 620 + blobShiftA, size: 580, c1: accent.opacity(0.14), c2: Color.white.opacity(0.04))

            Rectangle().fill(Color.black.opacity(0.22)).ignoresSafeArea()
        }
    }
}

private struct Blob: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let c1: Color
    let c2: Color

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [c1, c2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 64)
            .position(x: x, y: y)
    }
}
