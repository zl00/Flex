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
    
    // MARK: --
    
    var flex: Int { get }
    var childrenNodes: [FlexComponent] { get }
    
    // MARK: -- Width
    
    /// Determined by parrent component
    var staticWidth: CGFloat? { get set }
    /// Determined by children components
    var dynamicWidth: CGFloat? { get set }
    func updateDynamicWidth(remainWidth: CGFloat)
    var width: CGFloat { get } // TODO: 好好设计这个接口
    
    // MARK: -- Height
    
    /// Determined by own content
    var fittingHeight: CGFloat? { get set }
    func updateFittingHeight(width: CGFloat)
    /// Determined by flex
    var flexedHeight: CGFloat? { get set }
    func updateFlexedHeight(height: CGFloat)
    var height: CGFloat { get }
}

extension FlexComponent {
    var width: CGFloat {
        print("\(self)")
        return staticWidth ?? dynamicWidth!
    }
    
    var height: CGFloat {
        return flexedHeight ?? fittingHeight!
    }
}

class HBox: FlexComponent {
    let flex: Int
    var childrenNodes: [FlexComponent]
    
    var staticWidth: CGFloat? {
        didSet {
            guard let width = staticWidth else { return }
            updateFittingHeight(width: width)
        }
    }
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
    
    func updateDynamicWidth(remainWidth: CGFloat) {
        guard staticWidth == nil else { assertionFailure(); dynamicWidth = nil; return }
        guard remainWidth > 0.0 else { dynamicWidth = 0.0; return }
        
        var remains = remainWidth
        
        /// dynamic: determined by the children
        childrenNodes.filter { $0.flex == 0 }.forEach {
            $0.updateDynamicWidth(remainWidth: remains)
            guard let w = $0.staticWidth ?? $0.dynamicWidth else { assertionFailure(); return }
            assert(w <= remains && w >= 0.0)
            remains = max(0.0, remains - w)
        }
        
        /// static: determine the width of children
        let sumFlex = childrenNodes.reduce(0) { $0 + $1.flex }
        childrenNodes = childrenNodes.map {
            guard $0.flex != 0 else { return $0 }
            var result = $0
            result.staticWidth = max(remains / CGFloat(sumFlex), 0.0)
            return result
        }
        
        /// 🌈width = `sum(width of children)`
        self.dynamicWidth = childrenNodes.reduce(CGFloat(0.0)) {
            return $0 + ($1.staticWidth ?? ($1.dynamicWidth ?? 0.0)) // TODO: - Linda 换成width接口,可以check的
        }
    }
    
    func updateFittingHeight(width: CGFloat) {
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
        assert(fittingHeight! < height && flexedHeight == nil)
        
        self.flexedHeight = height
        self.childrenNodes.forEach {
            $0.updateFlexedHeight(height: height)
        }
    }
}

class VBox: FlexComponent {
    let flex: Int
    let childrenNodes: [FlexComponent]
    
    var staticWidth: CGFloat? {
        didSet {
            guard let width = staticWidth else { return }
            updateFittingHeight(width: width)
        }
    }
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
    
    func updateDynamicWidth(remainWidth: CGFloat) {
        guard staticWidth == nil else { assertionFailure(); dynamicWidth = nil; return }
        guard remainWidth > 0.0 else { dynamicWidth = 0.0; return }
        
        childrenNodes.forEach {
            $0.updateDynamicWidth(remainWidth: remainWidth)
        }
        
        /// 🌈width = `max(width of children)`
        self.dynamicWidth = min(remainWidth, childrenNodes.compactMap { $0.staticWidth ?? $0.dynamicWidth }.max() ?? 0.0)
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
        assert(fittingHeight! < height && flexedHeight == nil)
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
    
    var staticWidth: CGFloat? {
        didSet {
            guard let width = staticWidth else { return }
            updateFittingHeight(width: width)
        }
    }
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
    
    var staticWidth: CGFloat? {
        didSet {
            guard let width = staticWidth else { return }
            updateFittingHeight(width: width)
        }
    }
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
    
    rootNode.updateDynamicWidth(remainWidth: 250)
//    rootNode.updateFittingHeight(width: 250)
    
//    print("test1 >>> \(rootNode.width) \(rootNode.height)")
    
//    rootNode.childrenNodes.forEach {
//        print("test1 >>> \($0) \($0.width) \($0.height)")
//    }
}
test4()
