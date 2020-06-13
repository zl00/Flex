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
protocol ComponentProtocol: NSObject {
    
    // MARK: -- Flex
    
    var flex: Int { get }
    var childrenNodes: [ComponentProtocol] { get }
    func snap(_ fixedWidth: CGFloat, _ fixedHeight: CGFloat?)
    
    // MARK: -- Width
    
    /// From json
    var fixedWidth: CGFloat? { get }
    /// Update by `setWidthByParrent` or `adaptWidthToChildren`
    var flexedWidth: CGFloat? { get }
    /// From `flexedWidth` or `fixedWidth`
    var width: CGFloat { get }
    /// Set width by parrent component
    func setWidthByParrent(_ width: CGFloat)
    /// Adapt width to children
    func adaptWidthToChildren(remainWidth: CGFloat)
    
    // MARK: -- Height
    
    /// From json
    var fixedHeight: CGFloat? { get }
    /// Update by
    var flexedHeight: CGFloat? { get }
    /// From `fixedHeight` or `flexedHeight`
    var height: CGFloat { get }
    /// Set height by parrent component
    func setHeightByParrent(_ height: CGFloat)
    /// Adapt height to children
    func adaptHeightToChildren(width: CGFloat)
    
    // MARK: -- Debug
    
    func trace(_ level: Int)
}

extension ComponentProtocol {
    // TODO: - Linda
    var width: CGFloat { return fixedWidth ?? (flexedWidth ?? 0.0) }
    // TODO: - Linda
    var height: CGFloat { return fixedHeight ?? (flexedHeight ?? 0.0) }
    
    func snap(_ fixedWidth: CGFloat, _ fixedHeight: CGFloat?) {
        setWidthByParrent(fixedWidth)
        
        if let fixedHeight = fixedHeight {
            setHeightByParrent(fixedHeight)
        }
    }
    
    func trace(_ level: Int) {
        print("\([String](repeating: "\t", count: level).joined())➜➜➜➜\(level)\t\(self) | W: \(width), H: \(height)")
        childrenNodes.forEach { $0.trace(level + 1) }
    }
}

class HBox: NSObject, ComponentProtocol {

    init(flex: Int = 1, fixedWidth: CGFloat? = nil, fixedHeight: CGFloat? = nil, childrenNodes: [ComponentProtocol]) {
        self.flex = flex
        self.fixedWidth = fixedWidth
        self.fixedHeight = fixedHeight
        self.childrenNodes = childrenNodes
    }
    
    override var description: String { return "HBox.flex(\(self.flex))" }
    
    private func _refreshChildrenWidth(remainWidth: CGFloat) {
        var remains = remainWidth
        
        /// fixed: [prior]
        childrenNodes.compactMap { $0.fixedWidth }.forEach {
            remains = max(0.0, remains - $0)
        }
        
        /// dynamic: [prior] determined by the children
        childrenNodes.filter { $0.flex == 0 && $0.fixedWidth == nil }.forEach {
            $0.adaptWidthToChildren(remainWidth: remains)
            assert($0.width <= remains && $0.width >= 0.0)
            remains = max(0.0, remains - $0.width)
        }
        
        /// static: determine the width of children
        let sumFlex = childrenNodes.filter { $0.fixedWidth == nil }.reduce(0) { $0 + $1.flex }
        childrenNodes.filter { $0.flex != 0 && $0.fixedWidth == nil }.forEach {
            $0.setWidthByParrent(max(CGFloat($0.flex) / CGFloat(sumFlex) * remains, 0.0))
        }
    }
    
    // MARK: -- property
    
    let flex: Int
    let fixedWidth: CGFloat?
    let fixedHeight: CGFloat?
    var childrenNodes: [ComponentProtocol]
    
    private(set) var flexedWidth: CGFloat?
    func setWidthByParrent(_ width: CGFloat) {
        guard fixedWidth == nil else { return }
        guard flexedWidth != width else { return }
        
        flexedWidth = width
        _refreshChildrenWidth(remainWidth: width)
        adaptHeightToChildren(width: width)
    }
    
    func adaptWidthToChildren(remainWidth: CGFloat) {
        guard fixedWidth == nil else { return }
        guard remainWidth > 0.0 else { flexedWidth = 0.0; return }
        
        _refreshChildrenWidth(remainWidth: remainWidth)
        /// 🌈`sum(width of children)`
        let w = childrenNodes.reduce(0.0) { $0 + $1.width }
        flexedWidth = w
        adaptHeightToChildren(width: w)
    }
    
    private(set) var flexedHeight: CGFloat?
    func setHeightByParrent(_ height: CGFloat) {
        guard fixedHeight == nil && height != flexedHeight else { return }

        flexedHeight = height
        childrenNodes.forEach { $0.setHeightByParrent(height) }
    }
    func adaptHeightToChildren(width: CGFloat) {
        guard fixedHeight == nil && width != flexedHeight else { return }
        guard width > 0.0 else { flexedHeight = 0.0; return }
        
        /// update `fittingHeight` of children
        childrenNodes.forEach { $0.adaptWidthToChildren(remainWidth: $0.width) }
        
        /// 🌈`max(height of children)`
        let h = childrenNodes.compactMap { $0.height }.max() ?? 0.0
        flexedHeight = h
        
        /// 🌈`flexedHeight` of children
        childrenNodes.filter { $0.fixedHeight == nil && $0.height != h }.forEach { $0.setHeightByParrent(h) }
    }
}

class VBox: NSObject, ComponentProtocol {
    
    init(flex: Int = 1, fixedWidth: CGFloat? = nil, fixedHeight: CGFloat? = nil, childrenNodes: [ComponentProtocol]) {
        self.flex = flex
        self.fixedWidth = fixedWidth
        self.fixedHeight = fixedHeight
        self.childrenNodes = childrenNodes
    }
    
    override var description: String { return "VBox.flex(\(self.flex))" }
    
    // MARK: -- property
    
    let flex: Int
    let fixedWidth: CGFloat?
    let fixedHeight: CGFloat?
    let childrenNodes: [ComponentProtocol]
    
    private(set) var flexedWidth: CGFloat?
    func setWidthByParrent(_ width: CGFloat) {
        guard fixedWidth == nil && width != flexedWidth else { return }
        
        flexedWidth = width
        childrenNodes.forEach { $0.setWidthByParrent(width) } // update children's width
        adaptHeightToChildren(width: width)
    }
    func adaptWidthToChildren(remainWidth: CGFloat) {
        guard flexedWidth == nil else { return }
        guard remainWidth > 0.0 else { flexedWidth = 0.0; adaptHeightToChildren(width: 0.0); return }
        
        childrenNodes.forEach { $0.adaptWidthToChildren(remainWidth: remainWidth) }
        /// 🌈width = `max(width of children)`
        let w = min(remainWidth, childrenNodes.compactMap { $0.width }.max() ?? 0.0)
        flexedWidth = w
        adaptHeightToChildren(width: w)
    }

    private(set) var flexedHeight: CGFloat?
    func setHeightByParrent(_ height: CGFloat) {
        guard fixedHeight == nil && flexedHeight != height else { return }
        
        flexedHeight = height
        
        /// static: determine the width of children
        let sumFlex = childrenNodes.filter { $0.fixedHeight == nil }.reduce(0) { $0 + $1.flex }
        let remainsHeight = height - childrenNodes.filter { $0.flex == 0 || $0.fixedHeight != nil }.reduce(0.0) { $0 + $1.height }
        assert(remainsHeight >= 0.0)
        
        childrenNodes.filter { $0.flex != 0 && $0.fixedHeight == nil }.forEach {
            let h = CGFloat($0.flex) / CGFloat(sumFlex) * remainsHeight
            $0.setHeightByParrent(h)
        }
    }
    
    func adaptHeightToChildren(width: CGFloat) {
        guard fixedHeight == nil else { return }
        
        /// update fittingHeight of children
        childrenNodes.forEach { $0.adaptHeightToChildren(width: width) }
        
        /// 🌈`sum(fittingHeight of children)`
        flexedHeight = childrenNodes.reduce(CGFloat(0.0)) { $0 + $1.height }
    }
    
}

class LeafComponent: NSObject, ComponentProtocol {
    
    init(flex: Int = 1, fittingHeightPrediction: @escaping (_ w: CGFloat) -> CGFloat, minWidthPrediction: @escaping () -> CGFloat) {
        self.flex = flex
        self.fixedWidth = nil
        self.fixedHeight = nil
        self.fittingHeightPrediction = fittingHeightPrediction
        self.minWidthPrediction = minWidthPrediction
    }
    
    override var description: String { return "LeafComponent.flex(\(self.flex))" }
    
    // MARK: -- property
    let flex: Int
    let fixedWidth: CGFloat?
    let fixedHeight: CGFloat?
    let childrenNodes: [ComponentProtocol] = []
    
    private(set) var flexedWidth: CGFloat?
    func setWidthByParrent(_ width: CGFloat) {
        guard flexedWidth != width else { return }
        
        flexedWidth = width
        adaptHeightToChildren(width: width)
    }
    func adaptWidthToChildren(remainWidth: CGFloat) {
        guard flexedWidth == nil else { return }
        guard remainWidth > 0.0 else { flexedWidth = 0.0; return }
        
        let w = min(minWidthPrediction(), remainWidth)
        flexedWidth = w
        adaptHeightToChildren(width: w)
    }
    
    private(set) var flexedHeight: CGFloat?
    func setHeightByParrent(_ height: CGFloat) {
        flexedHeight = height
    }
    func adaptHeightToChildren(width: CGFloat) {
        flexedHeight = fittingHeightPrediction(width)
    }
    
    private(set) var fittingHeightPrediction: (_ w: CGFloat) -> CGFloat
    private(set) var minWidthPrediction: () -> CGFloat
}

// MARK: - TEST CASE

ps1("Flex in Vertical Box - 1 (Line)") {
    let rootNode = HBox(childrenNodes: [
        VBox(
            flex: 1,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 120 },
                    minWidthPrediction: { return 20 }
                )
            ]
        ),
        VBox(
            flex: 1,
            childrenNodes: [
                LeafComponent(
                    flex: 2,
                    fittingHeightPrediction: { w -> CGFloat in return 10 },
                    minWidthPrediction: { return 50}
                ),
                LeafComponent(
                    flex: 3,
                    fittingHeightPrediction: { w -> CGFloat in return 10 },
                    minWidthPrediction: { return 50}
                )
            ]
        )
    ])

    rootNode.snap(300, nil)
    rootNode.trace(0)
}

ps1("Flex in Vertical Box - 2 (Line)") {
    let rootNode = HBox(childrenNodes: [
        VBox(
            flex: 1,
            childrenNodes: [
                LeafComponent(
                    flex: 2,
                    fittingHeightPrediction: { w -> CGFloat in return 25 },
                    minWidthPrediction: { return 50}
                ),
                LeafComponent(
                    flex: 3,
                    fittingHeightPrediction: { w -> CGFloat in return 25 },
                    minWidthPrediction: { return 50}
                )
            ]
        )
    ])

    rootNode.snap(300, nil)
    rootNode.trace(0)
}

ps1("Image in Vertical Box (line)") {
    let rootNode = VBox(
        flex: 1,
        childrenNodes: [
            LeafComponent(
                flex: 1,
                fittingHeightPrediction: { w -> CGFloat in return 100 },
                minWidthPrediction: { return 100 }
            ),
            LeafComponent(
                flex: 4,
                fittingHeightPrediction: { w -> CGFloat in return 100 },
                minWidthPrediction: { return 65 }
            )
        ]
    )

    rootNode.snap(300, nil)
    rootNode.trace(0)
}

ps1("Image in Horizontal Box (Line)") {
    let rootNode = HBox(
        flex: 1,
        childrenNodes: [
            LeafComponent(
                flex: 1,
                fittingHeightPrediction: { w -> CGFloat in return 100 },
                minWidthPrediction: { return 100 }
            ),
            LeafComponent(
                flex: 4,
                fittingHeightPrediction: { w -> CGFloat in return 100 },
                minWidthPrediction: { return 65 }
            )
        ]
    )

    rootNode.snap(300, nil)
    rootNode.trace(0)
}

ps1("Flex优先级规则: [先序flex=0] > [后序flex=0] > [flex > 0]") {
    let rootNode = HBox(childrenNodes: [
        VBox(
            flex: 1,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 20 },
                    minWidthPrediction: { () -> CGFloat in return 100 }
                )
            ]
        ),
        VBox(
            flex: 0,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 50 },
                    minWidthPrediction: { () -> CGFloat in return 300 }
                ),
            ]
        ),
        VBox(
            flex: 0,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 20 },
                    minWidthPrediction: { () -> CGFloat in return 200 }
                )
            ]
        )
    ])

    rootNode.snap(400, nil)
    rootNode.trace(0)
}

ps1("Fixed width") {
    let rootNode = HBox(childrenNodes: [
        VBox(
            flex: 1,
            fixedWidth: 100,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 20 },
                    minWidthPrediction: { () -> CGFloat in return 100 }
                )
            ]
        ),
        VBox(
            flex: 0,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 50 },
                    minWidthPrediction: { () -> CGFloat in return 300 }
                ),
            ]
        ),
        VBox(
            flex: 0,
            childrenNodes: [
                LeafComponent(
                    flex: 1,
                    fittingHeightPrediction: { w -> CGFloat in return 20 },
                    minWidthPrediction: { () -> CGFloat in return 200 }
                )
            ]
        )
    ])

    rootNode.snap(400, nil)
    rootNode.trace(0)
}

// MARK: Util

func ps1(_ desp: String, _ closure: @escaping () -> Void) {
    print("🐾🐾🐾🐾🐾🐾")
    print("\(desp)")
    closure()
    print("")
}


