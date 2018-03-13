import macros, tables
import .. / plugin


proc withValueProxyPlugin*(data: NodeProxyPluginData) =
    data.checkArgs()

    let propName = data.prop.getPropNameIdent()
    var value = data.props["withValue"]

    var oninit: NimNode
    if value.kind == nnkLambda:
        oninit = quote:
            block:
                let ctor = `value`
                `NP`.`propName` = ctor(`NP`)
    else:
        oninit = quote:
            `NP`.`propName` = `value`
    
    if not oninit.isNil:
        data.init.add(oninit)

static:
    registerPlugin("withValue", withValueProxyPlugin)