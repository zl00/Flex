import Cocoa

// TODO: - Linda flex = 1. 因此要抽一个enum出来!

/**
 * Flex规则的底层原则
 * 只有当资源是有限时,才会按照Flex的比例进行分配.
 * Examples
 * e.g. 1) 宽度
 * e.g. 2) 当高度在某种case下确定下来时
 *
 * version 0.1: NOT include padding, spacing, margin, offset ...
 */
protocol FlexComponent {
    
    // MARK: -- Flex
    
    var flex: Int { get }
    var childrenNodes: [FlexComponent] { get }
    
    // MARK: -- Width
    
    /// Determined by parrent component
    var staticWidth: CGFloat? { get set }
    /// Update `staticWidth`
    /// - Parameter width: set width
    func updateStaticWidth(width: CGFloat)
    /// Determined by children components
    var dynamicWidth: CGFloat? { get set }
    /// Update `dynamicWidth`
    /// - Note: `staticWidth` and `dynamicWidth` is mutex. Make sure that `staticWidth` is not set before calling this function
    /// - Parameter remainWidth: remains width
    func updateDynamicWidth(remainWidth: CGFloat)
    /// Make sure `staticWidth` or `dynamicWidth` is set before calling this function
    var width: CGFloat { get }
    
    // MARK: -- Height
    
    /// Determined by own content
    var fittingHeight: CGFloat? { get set }
    /// Update `fittingHeight`
    /// - Parameter width: own actual width
    func updateFittingHeight(width: CGFloat)
    /// Determined by flex
    var flexedHeight: CGFloat? { get set }
    /// Update `flexedHeight`
    func updateFlexedHeight(height: CGFloat)
    /// Make sure `fittingHeight` or `flexedHeight` is set before calling this function
    var height: CGFloat { get }
    
    // MARK: -- Debug
    
    func trace(_ level: Int)
}

extension FlexComponent {
    
    var width: CGFloat {
        return staticWidth ?? dynamicWidth!
    }
    
    var height: CGFloat {
        return flexedHeight ?? fittingHeight!
    }
    
    func trace(_ level: Int) {
        var blank = ""
        (0..<level).forEach { _ in blank.append("\t") }
        print("\(blank)>>>\(level)\t\(self) | W: \(width), H: \(height)")
        childrenNodes.forEach { $0.trace(level+1) }
    }
}

class HBox: FlexComponent {
    
    let flex: Int
    var childrenNodes: [FlexComponent]
    
    var staticWidth: CGFloat?
    var dynamicWidth: CGFloat? {
        didSet {
            updateFittingHeight(width: dynamicWidth ?? 0.0)
        }
    }
    var fittingHeight: CGFloat?
    var flexedHeight: CGFloat?
    
    init(flex: Int = 1, childrenNodes: [FlexComponent]) {
        self.flex = flex
        self.childrenNodes = childrenNodes
    }
    
    func updateStaticWidth(width: CGFloat) {
        self.staticWidth = width
        
        _refreshChildrenWidth(remainWidth: width)
        
        updateFittingHeight(width: width)
    }
    
    func updateDynamicWidth(remainWidth: CGFloat) {
        guard staticWidth == nil else { assertionFailure(); dynamicWidth = nil; return }
        guard remainWidth > 0.0 else { dynamicWidth = 0.0; return }
        
        _refreshChildrenWidth(remainWidth: remainWidth)
        
        /// 🌈width = `sum(width of children)`
        self.dynamicWidth = childrenNodes.reduce(0.0) { $0 + $1.width }
    }
    
    private func _refreshChildrenWidth(remainWidth: CGFloat) {
        var remains = remainWidth
        
        /// dynamic: [prior] determined by the children
        childrenNodes.filter { $0.flex == 0 }.forEach {
            $0.updateDynamicWidth(remainWidth: remains)
            assert($0.width <= remains && $0.width >= 0.0)
            remains = max(0.0, remains - $0.width)
        }
        
        /// static: determine the width of children
        let sumFlex = childrenNodes.reduce(0) { $0 + $1.flex }
        childrenNodes.filter { $0.flex != 0 }.forEach {
            $0.updateStaticWidth(width: max(remains / CGFloat(sumFlex), 0.0))
        }
    }
    
    func updateFittingHeight(width: CGFloat) {
        guard width > 0.0 else { self.flexedHeight = 0.0; return }
        
        /// update fittingHeight of children
        childrenNodes.forEach {
            $0.updateFittingHeight(width: $0.width)
        }
        
        /// 🌈fittingHeight = `max(height of children)`
        let h = childrenNodes.compactMap { $0.fittingHeight }.max() ?? 0.0
        self.fittingHeight = h
        
        /// 🌈set flexedHeight of children
        self.childrenNodes.filter { $0.fittingHeight != h }.forEach {
            $0.updateFlexedHeight(height: h)
        }
    }
    
    func updateFlexedHeight(height: CGFloat) {
        assert(fittingHeight! < height)
        
        self.flexedHeight = height
        self.childrenNodes.forEach {
            $0.updateFlexedHeight(height: height)
        }
    }
}

class VBox: FlexComponent {
    let flex: Int
    let childrenNodes: [FlexComponent]
    
    var staticWidth: CGFloat?
    var dynamicWidth: CGFloat? {
        didSet {
            guard let width = dynamicWidth else { return }
            updateFittingHeight(width: width)
        }
    }
    var fittingHeight: CGFloat?
    var flexedHeight: CGFloat?
    
    init(flex: Int = 1, childrenNodes: [FlexComponent]) {
        self.flex = flex
        self.childrenNodes = childrenNodes
    }
    
    func updateStaticWidth(width: CGFloat) {
        self.staticWidth = width
        _refreshChildrenWidth(remainWidth: width)
        updateFittingHeight(width: width)
    }
    
    func updateDynamicWidth(remainWidth: CGFloat) {
        guard staticWidth == nil else { assertionFailure(); dynamicWidth = nil; return }
        guard remainWidth > 0.0 else { dynamicWidth = 0.0; return }
        
        _refreshChildrenWidth(remainWidth: remainWidth)
        
        /// 🌈width = `max(width of children)`
        self.dynamicWidth = min(remainWidth, childrenNodes.compactMap { $0.width }.max() ?? 0.0)
    }
    
    private func _refreshChildrenWidth(remainWidth: CGFloat) {
        childrenNodes.forEach {
            $0.updateDynamicWidth(remainWidth: remainWidth)
        }
    }
    
    func updateFittingHeight(width: CGFloat) {
        /// update fittingHeight of children
        childrenNodes.forEach {
            $0.updateFittingHeight(width: $0.width)
        }
        
        /// 🌈fittingHeight = `sum(fittingHeight of children)`
        self.fittingHeight = childrenNodes.reduce(CGFloat(0.0)) { $0 + $1.fittingHeight! }
    }
    
    func updateFlexedHeight(height: CGFloat) {
        assert(fittingHeight! < height)
        self.flexedHeight = height
        
        /// static: determine the width of children
        let sumFlex = childrenNodes.reduce(0) { $0 + $1.flex }
        let remainsHeight = height - childrenNodes.filter { $0.flex == 0 }.reduce(0.0) { $0 + $1.height }
        assert(remainsHeight >= 0.0)
        
        childrenNodes.filter { $0.flex != 0 }.forEach {
            let h = CGFloat($0.flex) / CGFloat(sumFlex) * remainsHeight
            $0.updateFlexedHeight(height: h)
        }
    }
}

class Text: FlexComponent {
    let flex: Int
    let text: String
    let childrenNodes: [FlexComponent] = []
    
    var staticWidth: CGFloat?
    var dynamicWidth: CGFloat? {
        didSet {
            guard let width = dynamicWidth else { return }
            updateFittingHeight(width: width)
        }
    }
    var fittingHeight: CGFloat?
    var flexedHeight: CGFloat?
    
    init(text: String, flex: Int = 1) {
        self.text = text
        self.flex = flex
    }
    
    func updateStaticWidth(width: CGFloat) {
        self.staticWidth = width
        updateFittingHeight(width: width)
    }
    
    func updateDynamicWidth(remainWidth: CGFloat) {
        guard staticWidth == nil else { assertionFailure(); dynamicWidth = nil; return }
        guard remainWidth > 0.0 else { dynamicWidth = 0.0; return }
        
        // TODO: - Linda
        self.dynamicWidth = min(300.0, remainWidth)
    }
    
    func updateFittingHeight(width: CGFloat) {
        self.fittingHeight = 100 // TODO:
    }
    
    func updateFlexedHeight(height: CGFloat) {
        self.flexedHeight = height
    }
}

class Image: FlexComponent {
    let flex: Int
    let theorySize: CGSize
    let childrenNodes: [FlexComponent] = []
    
    var staticWidth: CGFloat?
    var dynamicWidth: CGFloat? {
        didSet {
            guard let width = dynamicWidth else { return }
            updateFittingHeight(width: width)
        }
    }
    var fittingHeight: CGFloat?
    var flexedHeight: CGFloat?
    
    init(theorySize: CGSize = CGSize(width: 50, height: 50), flex: Int = 1) {
        self.theorySize = theorySize
        self.flex = flex
    }
    
    func updateStaticWidth(width: CGFloat) {
        self.staticWidth = width
        updateFittingHeight(width: width)
    }
    
    func updateDynamicWidth(remainWidth: CGFloat) {
        guard staticWidth == nil else { assertionFailure(); dynamicWidth = nil; return }
        guard remainWidth > 0.0 else { dynamicWidth = 0.0; return }
        
        self.dynamicWidth = min(theorySize.width, remainWidth)
    }
    
    func updateFittingHeight(width: CGFloat) {
        self.fittingHeight = 20
    }
    
    func updateFlexedHeight(height: CGFloat) {
        self.flexedHeight = height
    }
}

// MARK: - TEST

func test1() {
    defer { print("🌳🌳🌳🌳🌳 test1 end") }
    print("")
    print("🌳🌳🌳🌳🌳 test1 start")
    
    let rootNode = HBox(childrenNodes: [
        Text.init(text: "hello 1", flex: 0),
        Text.init(text: "hello 2", flex: 1)
    ])
    
    rootNode.updateDynamicWidth(remainWidth: 250)
    
    print("test1 >>> \(rootNode.width)")
    
    rootNode.childrenNodes.forEach {
        print("test1 >>> \($0) \($0.width)")
    }
}
test1()


func test2() {
    defer { print("🌳🌳🌳🌳🌳 test2 end") }
    print("")
    print("🌳🌳🌳🌳🌳 test2 start")
    
    let rootNode = VBox(childrenNodes: [
        Text.init(text: "hello 1", flex: 0),
        Text.init(text: "hello 2", flex: 1)
    ])
    
    rootNode.updateDynamicWidth(remainWidth: 250)
    
    print("test1 >>> \(rootNode.width)")
    
    rootNode.childrenNodes.forEach {
        print("test1 >>> \($0) \($0.width)")
    }
}
test2()


func test3() {
    defer { print("🌳🌳🌳🌳🌳 test3 end") }
    print("")
    print("🌳🌳🌳🌳🌳 test3 start")
    
    let rootNode = HBox(childrenNodes: [
        Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 0),
        Text.init(text: "hello 2", flex: 1)
    ])
    
    rootNode.updateDynamicWidth(remainWidth: 250)
    
    print("test1 >>> \(rootNode.width)")
    
    rootNode.childrenNodes.forEach {
        print("test1 >>> \($0) \($0.width)")
    }
}
test3()


func test4() {
    defer { print("🌳🌳🌳🌳🌳 test4 end") }
    print("")
    print("🌳🌳🌳🌳🌳 test4 start")
    
    let rootNode = HBox(childrenNodes: [
        Text.init(text: "hello 2", flex: 0),
        VBox.init(flex: 0, childrenNodes: [
            Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 1),
            Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 3)
        ])
    ])
    
    rootNode.updateDynamicWidth(remainWidth: 500)
    rootNode.updateFittingHeight(width: 250)
    rootNode.trace(0)
}
test4()

func test5() {
    defer { print("🌳🌳🌳🌳🌳 test5 end") }
    print("")
    print("🌳🌳🌳🌳🌳 test5 start")
    
    let rootNode = HBox(childrenNodes: [
        Text.init(text: "hello 2", flex: 1),
        VBox.init(flex: 1, childrenNodes: [
            Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 1),
            Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 3)
        ])
    ])
    
    rootNode.updateDynamicWidth(remainWidth: 500)
    rootNode.updateFittingHeight(width: 250)
    rootNode.trace(0)
}
test5()


func test6() {
    defer { print("🌳🌳🌳🌳🌳 test6 end") }
    print("")
    print("🌳🌳🌳🌳🌳 test6 start")
    
    let rootNode = HBox(childrenNodes: [
        Text.init(text: "hello 2", flex: 1),
        VBox.init(flex: 1, childrenNodes: [
            VBox.init(flex: 0, childrenNodes: [ // TODO: 这里计算❌,估计是递归的地方错了. 以后确定该方案的时候再修改!
                Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 1),
                Image.init(theorySize: CGSize.init(width: 300, height: 150), flex: 3)
            ])
        ])
    ])
    
    rootNode.updateDynamicWidth(remainWidth: 500)
    rootNode.updateFittingHeight(width: 250)
    rootNode.trace(0)
}
test6()
