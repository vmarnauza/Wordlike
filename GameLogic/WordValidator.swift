import SwiftUI

protocol Validator {
    /// Returns the answer for a given turn.
    /// Can return nil if validator is not yet initialized
    func answer(at turnIndex: Int) -> WordModel?
    
    /// Load the required resources (word list etc.)
    func load()
    var ready: Bool { get } 
    
    /// Checks if word can be submitted. 
    /// If not, sets the reason message.
    /// If so, returns a sanitized version that should
    /// be stored in the row.
    ///
    /// The sanitized version can help with e.g. ignoring
    /// accents while still preserving the right letters
    /// from the expected word.
    func canSubmit(
        word: WordModel, 
        expected: WordModel,
        model: [RowModel]?,
        mustMatchKnown: Bool,    // e.g. hard mode
        reason: inout String?) -> WordModel?
}

/// Used as a temporary invalid value.
///
/// Every method invokes `fatalError()` to prevent 
/// accidental use.
class DummyValidator: Validator, ObservableObject {
    func answer(at turnIndex: Int) -> WordModel? {
        fatalError()
    }
    
    func load() {
        fatalError()
    }
    
    var ready: Bool {
        false
    }
    
    func canSubmit(
        word: WordModel, 
        expected: WordModel,
        model: [RowModel]?,
        mustMatchKnown: Bool,    // e.g. hard mode
        reason: inout String?) -> WordModel? {
            fatalError()
        }
}

class WordValidator : Validator, ObservableObject
{
    static func letterNumberMsg(_ ix: Int) -> String {
        guard let ordinal = (ix+1).ordinal else {
            return "Letter \(ix+1)"
        }
        
        return "\(ordinal) letter"
    }
    
    /// Will only set reason if validation fails
    /// If no model given, assume no 
    /// requirements so -> return true
    func validateRequirements(
        word: WordModel,
        model: [RowModel]?, 
        reason: inout String?) -> Bool 
    {
        guard let model = model else {
            return true
        }
        
        var required = [MultiCharacterModel]()
        guard let expected = model.first?.expected else {
            fatalError("Model doesn't have an expected word.")
        }
        
        for row in model {
            for ix in 0..<row.word.count {
                let revealState = row.revealState(ix)
                switch(revealState) {
                    case .rightPlace:
                    if word[ix] != expected[ix] {
                        print("Expected", expected)
                        print("Word", word)
                        reason = "\(Self.letterNumberMsg(ix)) must be \(expected[ix].displayValue)"
                        return false
                    }
                    case .wrongPlace:
                    required.append(row.char(guessAt: ix))
                    default:
                    continue
                }
            }
        }
        
        for requiredChar in required {
            guard word.contains(requiredChar) else {
                reason = "Guess must contain \(requiredChar)"
                return false 
            }
        } 
        
        return true
    }
    
    /// Validator protocol 
    func load() {
        let _ = self.loadAnswers()
        let _ = self.loadGuessTree()
        ready = true
    }
    
    @Published var ready: Bool = false
    
    func answer(at turnIndex: Int) -> WordModel? {
        guard let answers = answers else { return nil }
        
        return WordModel(
            answers[turnIndex % answers.count],
            locale: locale.nativeLocale)
    }
    
    func canSubmit(
        word: WordModel, 
        expected: WordModel,
        model: [RowModel]?,
        mustMatchKnown: Bool,    // e.g. hard mode
        reason: inout String?) -> WordModel? {
            guard let guessTree = self.guessTree else {
                reason = "Wait a sec, loading words..."
                return nil
            } 
            
            /* To avoid accidentally breaking input files,
             do some checks centrally (e.g. we can check length
             just here, instead of ensuring every input
             file doesn't contain an invalid short/empty line) */
            guard word.count == 5 else {
                reason = "Not enough letters"
                return nil
            }
            
            return guessTree.contains(
                word: word, 
                mustMatch: mustMatchKnown ? model : nil,
                reason: &reason)
        }
    
    /// Other stuff
    var answers: [String]? = nil
    var guessTree: WordTree? = nil
        
    func loadAnswers() -> [String] {
        if let preloaded = self.answers {
            return preloaded 
        }
        
        var random = ArbitraryRandomNumberGenerator(seed: UInt64(self.seed))
        
        let answers =  Self.load("\(locale.fileBaseName)_A").shuffled(using: &random)
        self.answers = answers 
        return answers
    }
    
    func loadGuessTree() -> WordTree {
        if let preloaded = self.guessTree {
            return preloaded
        }
        
        let guessTree = WordTree(
            words: self.loadGuesses(),
            locale: self.locale.nativeLocale
        )
        self.guessTree = guessTree
        return guessTree
    }
    
    func loadGuesses() -> [WordModel] {
        Self.load("\(locale.fileBaseName)_G").map {
            WordModel($0, locale: locale.nativeLocale)
        }
    }
    
    static func load(_ name: String) -> [String] {
        do {
            guard let fileUrl = Bundle.main.url(forResource: name, withExtension: "txt") else { 
                fatalError("Data not found: \(name)") 
            }
            
            let text = try String(contentsOf: fileUrl, encoding: String.Encoding.utf8)
            return text.components(separatedBy: "\n").map {
                $0.uppercased()
            }
        } catch {
            fatalError(String(describing: error))
        }
    }
    
    let locale: GameLocale
    let seed: Int 
    
    /// Constant used as the start date of counting 
    /// the turns.
    /// TODO: move somewhere else
    static let MAR_22_2022 = Date(timeIntervalSince1970: 1647966002) 
    
    init(
        locale: GameLocale, 
        seed: Int? = nil 
    )
    {
        self.locale = locale
        self.seed = seed ?? 14384982345
    }
}

struct InternalLetterNumberMessageTest: View {
    var body: some View {
        VStack {
        Text(verbatim: "0 == \(WordValidator.letterNumberMsg(0)) ==> 1st")
            Text(verbatim: "2 == \(WordValidator.letterNumberMsg(2)) ==> 3rd")
            Text(verbatim: "21 == \(WordValidator.letterNumberMsg(21)) ==> 22nd")
        }
    }
}

struct InternalLetterNumberMessageTest_Previews: PreviewProvider {
    static var previews: some View {
        InternalLetterNumberMessageTest()
    }
}

