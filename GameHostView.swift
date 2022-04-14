import SwiftUI

enum ActiveSheet {
    case stats 
    case help
}

extension ActiveSheet: Identifiable {
    var id: Self { self }
}

struct GameHostView: View {
    
    @State var debugMessage: String = ""
    
    @AppStorage 
    var dailyState: DailyState?
    
    @AppStorage 
    var stats: Stats
    
    @AppStorage 
    var shouldShowHelp: Bool
    
    @State var finished = false
    
    @State var timer = Timer.publish(
        every: 1, 
        on: .main, 
        in: .common).autoconnect()
    
    @StateObject var validator: WordValidator
    @StateObject var game: GameState = GameState()
    
    @Environment(\.paceSetter) var paceSetter: PaceSetter
    
    @State var activeSheet: ActiveSheet? = nil
    
    let title: String
    let locale: String
    
    init(_ name: String) {
        self._validator = StateObject(wrappedValue: WordValidator(name: name))
        
        self._stats = AppStorage(
            wrappedValue: Stats(), 
            "stats.\(name)")
        
        self._dailyState = AppStorage(
            wrappedValue: nil, 
            "turnState.\(name)")
        
        // Showing help should not be dependent
        // on the name (unlike turn state and stats)
        self._shouldShowHelp = AppStorage(
            wrappedValue: true, "shouldShowHelp")
        
        self.locale = name
        
        if name == "en" {
            title = "English"
        } else {
            title = "Français"
        }
    }
    
    var todayIndex: Int {
        self.paceSetter.turnIndex(at: Date())
    }
    
    func updateFromLoadedState(_ newState: DailyState) {
        debugMessage = "Updating..."
        
        game.expected = DayWord(
            word: newState.expected, 
            day: todayIndex,
            locale: self.locale)
        game.rows = newState.rows
        game.isTallied = newState.isTallied
        game.id = UUID()
        game.initialized = true
        game.date = newState.date
    }
    
    var body: some View {
        VStack {
            if game.initialized && paceSetter.isFresh(game.date, at: Date()) {
                GameBoardView(state: game,
                              canBeAutoActivated: !finished && !shouldShowHelp)
                    .onStateChange(edited: { newRows in
                        self.dailyState = DailyState(
                            expected: dailyState!.expected,
                            date: dailyState!.date,
                            rows: newRows,
                            isTallied: dailyState!.isTallied)
                    }, completed: { 
                        state in
                        
                        if let dailyState = self.dailyState {
                            self.dailyState = DailyState(expected: dailyState.expected, date: dailyState.date, rows: dailyState.rows, isTallied: true)
                        }
                        
                        stats = stats.update(from: game, with: paceSetter)
                        
                        finished = true
                    })
                Text(verbatim: "\(game.submittedRows)")
                Text(verbatim: "\(game.isCompleted)")
                Text(dailyState?.expected ?? "none")
                Text(dailyState?.rows[0].word ?? "none")
                Text(self.debugMessage).id("message")
            } 
            
            
            if let ds = dailyState, !paceSetter.isFresh(ds.date, at: Date()) {
                Text("Rummaging in the sack for a new word...")
            }
            
            if dailyState == nil {
                Text("Initializing state...").onAppear {
                    guard let dailyState = dailyState else {
                        dailyState = DailyState(expected: validator.answer(at: todayIndex))
                        return
                    }
                }
            }
        }
        .environmentObject(validator)
        .onAppear {
            if shouldShowHelp {
                activeSheet = .help
            }
            
            if let newState = self.dailyState {
                updateFromLoadedState(newState)
            } 
        }
        .onChange(of: self.dailyState) {
            newState in
            
            if let newState = newState {
                updateFromLoadedState(newState)
            }
        }
        .onReceive(timer) { newTime in
            
            guard let dailyState = self.dailyState else {
                return
            }
            
            debugMessage = "TTL: \(paceSetter.remainingTtl(at: newTime)) (f:\(paceSetter.isFresh(dailyState.date, at: newTime))) for word: \(dailyState.expected)" + "\nTIX: \(todayIndex)" + "\nTALLIED: \(self.dailyState?.isTallied ?? false)" + "\nPS: \(paceSetter)" + "\nSSH: \(shouldShowHelp)"
            
            if !paceSetter.isFresh(dailyState.date, at: newTime) {
                // TODO: process daily results if needed
                self.dailyState = DailyState(expected: validator.answer(at: todayIndex))
            }
        }
        .sheet(item: $activeSheet, 
               onDismiss: {
            
            // assuming this is the first
            // sheet to ever be dismissed
            if shouldShowHelp {
                shouldShowHelp = false
            }
            
        }) { item in
            PaletteSetterView {
                switch (item) {
                case .help:
                    HelpView().padding(16)
                    case .stats:
                    StatsView(stats: stats, state: game)
                }    
            }
        }
        .onChange(of: finished) {
            newF in 
            if (newF && activeSheet == nil) {
                activeSheet = .stats
            }
        }
//        .sheet(isPresented: $shouldShowHelp, onDismiss: { shouldShowHelp = false }) {
//            PaletteSetterView {
//                HelpView().padding(16)
//            }
//        }
//        .sheet(isPresented: $finished) {
//            PaletteSetterView {
//                StatsView(stats: stats, state: game)
//            }
//        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(
                    action: { 
                        activeSheet = .stats
                    }, 
                    label: {
                        Label(
                            "Stats", 
                            systemImage: "chart.bar")
                            .foregroundColor(
                                Color(
                                    UIColor.label))
                    }) 
            }
        }
        .padding(8)
    }
}

struct GameHostView_Previews: PreviewProvider {
    static var previews: some View {
        GameHostView("en")
        GameHostView("fr")
    }
}
