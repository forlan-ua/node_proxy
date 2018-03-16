import macros, tables
import .. / plugin


proc onNodeProxyPlugin*(data: NodeProxyPluginData) =
    data.checkArgs()

    let propName = data.prop.getPropNameIdent()
    let propType = data.prop.getPropTypeIdent()
    var node = data.props["onNode"]
    if node.kind == nnkIdent:
        node = nnkDotExpr.newTree(NP, node)
    elif node.kind == nnkStrLit:
        node = quote:
            `NP`.node.findNode(`node`)

    let oninit = quote:
        `NP`.`propName` = `node`.getComponent(`propType`)
        assert(`NP`.`propName`.isNil != true, "Component nil")
    
    if not oninit.isNil:
        data.init.add(oninit)

static:
    registerPlugin("onNode", onNodeProxyPlugin)


proc onNodeAddNodeProxyPlugin*(data: NodeProxyPluginData) =
    data.checkArgs()

    let propName = data.prop.getPropNameIdent()
    let propType = data.prop.getPropTypeIdent()
    var node = data.props["onNodeAdd"]
    if node.kind == nnkIdent:
        node = nnkDotExpr.newTree(NP, node)
    elif node.kind == nnkStrLit:
        node = quote:
            `NP`.node.findNode(`node`)

    let oninit = quote:
        assert(`node`.getComponent(`propType`).isNil, "Component already added")
        `NP`.`propName` = `node`.component(`propType`)
    
    if not oninit.isNil:
        data.init.add(oninit)

static:
    registerPlugin("onNodeAdd", onNodeAddNodeProxyPlugin)