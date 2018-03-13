import macros, tables
import .. / plugin


proc withNameProxyPlugin*(data: NodeProxyPluginData) =
    data.checkArgs()

    if "addTo" in data.props:
        return

    var propName = data.prop.getPropNameIdent()
    let name = data.props.getOrDefault("withName")
    var parent = data.props.getOrDefault("inParent")

    var oninit: NimNode
    if parent.isNil:
        oninit = quote:
            `NP`.`propName` = `NP`.node.findNode(`name`)
    else:
        if parent.kind == nnkStrLit:
            oninit = quote:
                `NP`.`propName` = `NP`.node.findNode(`parent`).findNode(`name`)
        else:
            if parent.kind == nnkIdent:
                parent = nnkDotExpr.newTree(
                    NP,
                    parent
                )

            oninit = quote:
                `NP`.`propName` = `parent`.findNode(`name`)
    
    if not oninit.isNil:
        data.init.add(oninit)

static:
    registerPlugin("withName", withNameProxyPlugin)


proc addToNodeProxyPlugin*(data: NodeProxyPluginData) =
    data.checkArgs()

    var propName = data.prop.getPropNameIdent()
    var parent = data.props.getOrDefault("addTo")
    if parent.isNil:
        raise

    if parent.kind == nnkStrLit:
        parent = quote:
            np.node.findNode(`parent`)
    elif parent.kind == nnkIdent:
        parent = nnkDotExpr.newTree(
            NP,
            parent
        )

    var name = data.props.getOrDefault("withName")
    if name.isNil:
        name = newLit($propName.ident)

    let oninit = quote:
        np.`propName` = `parent`.newChild(`name`)
    data.init.add(oninit)

static:
    registerPlugin("addTo", addToNodeProxyPlugin)