import SwiftUI

struct KeyboardInput<Content: View, AccessoryView: View> : View 
{
    @Binding var model: RowModel
    @Binding var isActive: Int?
    
    let tag: Int
    let content: Content 
    let accessoryView: AccessoryView
    
    init(
model: Binding<RowModel>, 
tag: Int, 
isActive: Binding<Int?>,
    @ViewBuilder _ content: ()->Content,
    @ViewBuilder _ accessoryView: ()->AccessoryView) {
        self._model = model
        self.tag = tag
        self._isActive = isActive
        self.content = content()
        self.accessoryView = accessoryView()
    }
    
    @State var contentSize: CGSize = CGSize.zero
    
    var body: some View {
        
        ZStack {
            
            content.background(GeometryReader {
                proxy in 
                
                Color.clear.onAppear {
                    contentSize = proxy.size
                }
            })
            
            KeyboardInputUIKit(
                model: $model,
                tag: self.tag,
                isActive: $isActive,
                accessoryView: accessoryView)
                .frame(width: contentSize.width, height: contentSize.height)
                .border(self.isActive == self.tag ? .red : .green)
        }
    }
}

struct KeyboardInputUIKit<AccessoryView: View>: UIViewRepresentable {
    
    class InternalView<AccessoryView: View>: UIControl, UIKeyInput
    {
//        var model: RowModel
//        let focusTag: Int
//        var isActive: Int?
        
//        var accessoryView: AccessoryView
        
        var owner: KeyboardInputUIKit<AccessoryView>
        
        init(owner: KeyboardInputUIKit<AccessoryView>) {
            self.owner = owner
//            self.focusTag = tag
//            self.isActive = isActive
//            self.accessoryView = accessoryView
            self.vc = UIHostingController(rootView: self.owner.accessoryView)
            
            self.accView = UIView()
            
            super.init(frame: CGRect.infinite)
            addTarget(self, 
                      action: #selector(self.onTap(_:)),
                      for: .touchUpInside)
            
            self.initAccessoryView()
        }
        
        let vc: UIHostingController<AccessoryView>
        let accView: UIView
        
        func initAccessoryView()
        {
            self.accView.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: 44)
            
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            accView.addSubview(vc.view)
            vc.view.leadingAnchor.constraint(equalTo: accView.safeAreaLayoutGuide.leadingAnchor).isActive = true
            vc.view.trailingAnchor.constraint(equalTo: accView.safeAreaLayoutGuide.trailingAnchor).isActive = true
            vc.view.topAnchor.constraint(equalTo: accView.safeAreaLayoutGuide.topAnchor).isActive = true
            vc.view.heightAnchor.constraint(equalToConstant: 44).isActive = true
            
            self.inputAccessoryView = accView
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override open func resignFirstResponder() -> Bool {
            if self.owner.isActive == owner.tag {
                //                return true
                self.owner.isActive = nil
                //                fatalError("asd")
            }
            
            return super.resignFirstResponder()
        }
        
        override open func becomeFirstResponder() -> Bool {
            guard !self.owner.model.isSubmitted else {
                return false
            }
            
            if self.owner.isActive != owner.tag {
                self.owner.isActive = self.owner.tag
            }
            
            return super.becomeFirstResponder()
        }
        
        var _inputAccessoryView: UIView?
        override var inputAccessoryView: UIView? {
            get {
                _inputAccessoryView
            }
            set {
                _inputAccessoryView = newValue
            }
        }
        
        override var canBecomeFirstResponder: Bool {
            return !self.owner.model.isSubmitted
        }
        
        @objc private func onTap(_: AnyObject) {
//            fatalError("onTap")
//            UIView.performWithoutAnimation { 
//                _ = self.becomeFirstResponder()
//            }
        }
        
        var hasText: Bool {
            return owner.model.word.isEmpty == false
        } 
        
        func insertText(_ text: String) {
            print("Inserting text", text)
            for chr in text { 
                guard chr.isLetter else {
                    if chr == "\n" && self.owner.model.word.count == 5 {
                        // After the last editable row, isActive will
                        // point to something that doesn't exist. This is fine,
                        // as it simply ensures that the keyboard goes away.
                        self.owner.isActive = owner.tag + 1
                        
                        self.owner.model = RowModel(
                            word: self.owner.model.word,
                            expected: self.owner.model.expected,
                            isSubmitted: true
                        )
                    }
                    
                    return
                }
            }
            
            self.owner.model = RowModel(
                word:  String((self.owner.model.word + text).prefix(5)),
                expected: self.owner.model.expected,
                isSubmitted: self.owner.model.isSubmitted)
        }
        
        func deleteBackward() {
            self.owner.model = RowModel(
                word: String(self.owner.model.word.dropLast()),
                expected: self.owner.model.expected,
                isSubmitted: self.owner.model.isSubmitted)
        }
    }
    
    @Binding var model: RowModel
    let tag: Int
    @Binding var isActive: Int?
    let accessoryView: AccessoryView
    
    func makeUIView(context: Context) -> InternalView<AccessoryView> {
        let result = InternalView(owner: self)
        
        result.setContentHuggingPriority(.defaultHigh, for: .vertical)
        result.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        if isActive == tag {
            UIView.performWithoutAnimation { 
                _ = result.becomeFirstResponder()
            }
        } 
        
        return result
    }
    
    class Coordinator {
        var sendUpdates = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func updateUIView(_ uiView: InternalView<AccessoryView>, context: Context) {
        
        
        
        uiView.owner = self
        
        uiView.accView.subviews[0].removeFromSuperview()
        uiView.vc.rootView = self.accessoryView
        uiView.accView.addSubview(uiView.vc.view)
        
        uiView.accView.frame = CGRect(x: 0.0, y: 0.0, width: uiView.bounds.width, height: 44)
        
        print("Resetting...")
        
//        uiView.resetAccessoryView()
        
        // The following are not called on main asynchronously,
        // there's an attribute cycle. See:
        // https://stackoverflow.com/questions/59707784/
        if self.tag == self.isActive {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation { 
                        _ = uiView.becomeFirstResponder()
                    }
                }
            }
        } else {
            if uiView.isFirstResponder {
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation { 
                        _ = uiView.resignFirstResponder()
                    }
                }
            }
        }
    }
}

struct EditableRow : View
{
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Binding var model: RowModel
    let tag: Int
    @Binding var isActive: Int?
    
    init(
        model: Binding<RowModel>, 
        tag: Int, isActive: Binding<Int?>) {
        self._model = model
        self.tag = tag
        self._isActive = isActive
    }
    
    var body: some View {
        Self._printChanges()
        return body_internal
        
//        Text(colorScheme == .light ? "light" : "dark")
    }
    
    @ViewBuilder
    var body_internal: some View { 
        //        if !model.isSubmitted {
        KeyboardInput(
            model: $model,
            tag: self.tag,
            isActive: $isActive, {
                Row(model: model)
            }) {
                Text(String(randomLength: 3))
                PaletteSetterView {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Text(colorScheme == .light ? "light" : "dark")
                            Tile(
                                letter: "A", 
                                delay: 0, 
                                revealState: .rightPlace)
                            Tile(
                                letter: "B", 
                                delay: 0, 
                                revealState: .wrongPlace)
                            
                            Spacer()
                        } 
                        Spacer()
                    }.background(Color(UIColor.systemFill))
                }
                
            }
//            .border( model.isSubmitted ? Color.clear : (self.tag == isActive ? Color.yellow : Color.purple) , width: 2 )
        
        //        } else {
        //            Row(model: model)
        //        }
        
        //        Text(verbatim: "Active: \(self.isActive)")
        //        Text(verbatim: "Tag: \(self.tag)")
    }
}

struct EditableRow_ForPreview : View {
    @State var isActive: Int? = nil
    
    @State var model1 = RowModel(expected: "fuels")
    @State var model2 = RowModel(expected: "fuels")
    
    var body: some View {
        VStack {
            EditableRow(
                model: $model1,
                tag: 0,
                isActive: $isActive)
            
            EditableRow(
                model: $model2,
                tag: 1,
                isActive: $isActive)
            
            Button("Toggle") {
                // only works if
                // it is going nil->any
                //
                // any->any resigns both
                print("=== toggling ===")
                if isActive == nil {
                    isActive = 1
                    return
                }
                if isActive == 1 {
                    isActive = 0
                    return
                }
                if isActive == 0 {
                    isActive = nil
                    return
                }
            }
        }
    }
}


fileprivate struct InternalPreview: View 
{
    @State var state = GameState(expected: "board")
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    @State var count = 0
    
    var body: some View {
        VStack {
            GameBoardView(state: state)
            Text("Count: \(count)")
            Button("Reset") {
                self.state = GameState(expected: "fuels")
            }.onReceive(timer) {
                _ in 
                self.count += 1
            }
        }
    }
}

struct KeyboardInput_Previews: PreviewProvider {
    static var previews: some View {
        InternalPreview()
        
        VStack {
            Text("Above").background(.green)
            EditableRow_ForPreview()
            Text("Below").background(.red)
        }
    }
}
