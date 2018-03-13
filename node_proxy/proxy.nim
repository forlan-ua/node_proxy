import tables, macros
import rod / node
import plugin
import plugins / [animations, components, nodes, ctors, observarbles]

import observarble_component
export observarble_component


type NodeProxy* = ref object of RootObj
    node*: Node


proc init*(np: NodeProxy, node: Node) =
    np.node = node


proc new*(T: typedesc[NodeProxy], node: Node): T =
    var res = T.new()
    res.init(node)
    result = res


template getType(T, TT): untyped =
    type T* = ref object of TT


proc getPropDef(n: NimNode): NimNode =
    result = nnkIdentDefs.newTree()
    case n.kind:
        of nnkCommand:
            result.add(n[0]).add(n[1])
        of nnkInfix:
            result.add(
                nnkPostfix.newTree(ident("*"), n[1])
            ).add(n[2])
        else:
            discard
    result.add(newEmptyNode())


proc toNodeProxy(x: NimNode, y: NimNode = nil): NimNode =
    let res = nnkStmtList.newTree()

    var T = x
    var TT = ident("NodeProxy")

    if T.kind == nnkInfix:
        if not T[0].eqIdent("of"):
            error "Unexpected infix node\n" & treeRepr(T)
        TT = T[2]
        T = T[1]

    T.expectKind(nnkIdent)
    
    let typeDef = getAst(getType(T, TT))
    res.add(typeDef)
    typedef[0][2][0][2] = nnkRecList.newTree()
    let typeProps = typedef[0][2][0][2]

    if y.isDiscard():
        return
    
    var initProc = quote:
        proc init*(`NP`: `T`, node: Node) =
            `NP`.`TT`.init(node)

    let init = initProc[6]
    
    let pluginData = NodeProxyPluginData(body: res, T: T, init: init)
    
    proc applyPlugins() =
        if pluginData.propBody.isNil:
            pluginData.propBody = nnkStmtList.newTree()

        if not pluginData.propBody.isDiscard():
            for propItem in pluginData.propBody:
                injectDots(propItem, pluginData.prop)

        for k in pluginData.props.keys():
            for plugin in pluginsForProp(k):
                plugin(pluginData)

        if not pluginData.propBody.isDiscard():
            for propItem in pluginData.propBody:
                init.add(propItem)

    for p in y:
        case p[0].kind:
            of nnkIdent:
                pluginData.prop = p.getPropDef()
                if p.len > 2:
                    for k in p[2]:
                        k.expectKind(nnkCall)
                        k[0].expectKind(nnkTableConstr)
                        
                        pluginData.props = initOrderedTable[string, NimNode]()
                        for pp in k[0]:
                            pp.expectKind(nnkExprColonExpr)
                            pp[0].expectKind(nnkIdent)
                            pluginData.props[$pp[0].ident] = pp[1]
                        
                        pluginData.propBody = nil
                        if k.len > 1:
                            k[1].expectKind(nnkStmtList)
                            pluginData.propBody = k[1]

                        applyPlugins()

            of nnkCommand, nnkInfix:
                pluginData.prop = p[0].getPropDef()
                p[1].expectKind(nnkTableConstr)

                pluginData.props = initOrderedTable[string, NimNode]()
                for pp in p[1]:
                    pp.expectKind(nnkExprColonExpr)
                    pp[0].expectKind(nnkIdent)
                    pluginData.props[$pp[0].ident] = pp[1]
                
                pluginData.propBody = nil
                if p.len > 2:
                    p[2].expectKind(nnkStmtList)
                    pluginData.propBody = p[2]

                applyPlugins()
            else:
                error "Unexpected AST\n" & treeRepr(p)

        typeProps.add(pluginData.prop)

    res.add(initProc)
    
    let TI = ident("T")
    let I = ident("init")
    let R = ident("result")
    let newProc = quote do:
        proc new*(`TI`: typedesc[`T`], node: Node): `TI` =
            `R` = `TI`.new()
            `R`.`I`(node)
    res.add(newProc)

    result = res


macro nodeProxy*(x: untyped, y: untyped = nil): untyped =
    result = toNodeProxy(x, y)

    when defined(debugNodeProxy):
        echo "\ngen finished \n ", repr(result)

#[
    Extensions
]#

when isMainModule:
    import rod.node
    import rod.viewport
    import rod.rod_types
    import rod.component
    import rod.component / [ sprite, solid, camera, text_component ]
    import nimx / [ animation, types, matrixes ]
    import observarble

    proc nodeForTest(): Node =
        result = newNode("test")
        var child1 = result.newChild("child1")

        var a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        child1.registerAnimation("animation", a)

        var child2 = result.newChild("child2")
        discard child2.newChild("sprite")

        var child3 = child2.newChild("somenode")
        discard child3.component(Text)

        discard result.newChild("someothernode")

        a = newAnimation()
        a.loopDuration = 1.0
        a.numberOfLoops = 10
        result.registerAnimation("in", a)

    proc getSomeEnabled(): bool = result = true
    
    observarble MyObservarble:
        name* string

    nodeProxy TestProxy:
        obj MyObservarble

        someNode Node {withName: "somenode"}:
            parent.enabled = false

        nilNode Node {addTo: someNode}:
            alpha = 0.1
            enabled = getSomeEnabled()

        someNode2 Node {addTo: nilNode, withName: "somenode"}:
            parent.enabled = false

        text* Text {onNode: "somenode"}:
            text = "some text"

        child Node {withName: "child1"}

        text2 Text: 
            {onNodeAdd: nilNode}:
                bounds = newRect(20.0, 20.0, 100.0, 100.0)
            {observe: obj}:
                text = np.obj.name

        source int {withValue: 100500}
        source2 int {withValue: proc(np: TestProxy): int = result = 1060}

        anim Animation {withKey: "animation", forNode: child}:
            numberOfLoops = 2
            loopDuration = 0.5

        anim2 Animation {withKey: "in"}:
            numberOfLoops = 3
            loopDuration = 1.5
        

    var tproxy = TestProxy.new(nodeForTest())
    echo "node name ", tproxy.node.name, " Text comp text ", tproxy.text.text, " intval ", tproxy.source

    nodeProxy TestProxy2 of TestProxy:
        someOtherNode Node {withName: "someothernode"}:
            enabled = false

    var tproxy2 = new(TestProxy2, nodeForTest())
    echo "node name ", tproxy2.node.name, " Text comp text ", tproxy2.text.text, " intval ", tproxy2.source, " newprop.enabled ", tproxy2.someOtherNode.enabled
