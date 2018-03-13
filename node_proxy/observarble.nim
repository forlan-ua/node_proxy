import tables, macros


type 
    ObserverId = int
    Observarble* = ref object of RootObj
        listeners: TableRef[ObserverId, seq[ObserverHandler]]
        noNotify: bool
    ObserverHandler* = proc(o: Observarble)

proc notifyOn*(o: Observarble): bool = not o.noNotify
proc `notifyOn=`*(o: Observarble, notifyOn: bool) = o.noNotify = not notifyOn

when defined(js):
    {.emit:"""
    var _nimx_observerIdCounter = 0;
    """.}

    proc getObserverId(rawId: RootRef): ObserverId =
        {.emit: """
            if (`rawId`.__nimx_observer_id === undefined) {
                `rawId`.__nimx_observer_id = --_nimx_observerIdCounter;
            }
            `result` = `rawId`.__nimx_observer_id;
        """.}
    template getObserverID(rawId: ref): ObserverId = getObserverId(cast[RootRef](rawId))
else:
    template getObserverID(rawId: ref): ObserverId = cast[int](rawId)


proc subscribe*(o: Observarble, r: ref, cb: ObserverHandler) =
    if o.listeners.isNil:
        o.listeners = newTable[ObserverId, seq[ObserverHandler]]()

    let id = getObserverId(r)
    var listeners = o.listeners.getOrDefault(id)
    if listeners.isNil:
        listeners = @[]
    listeners.add(cb)
    o.listeners[id] = listeners

proc subscribe*(oo: openarray[Observarble], r: ref, cb: ObserverHandler) =
    for o in oo:
        o.subscribe(r, cb)

proc unsubscribe*(o: Observarble, r: ref) =
    if o.listeners.isNil:
        return
    o.listeners.del(getObserverId(r))

proc unsubscribe*(oo: openarray[Observarble], r: ref) =
    for o in oo:
        o.unsubscribe(r)

proc unsubscribe*(o: Observarble, r: ref, cb: ObserverHandler) =
    if o.listeners.isNil:
        return
    let id = getObserverId(r)
    var listeners = o.listeners.getOrDefault(id)
    if listeners.isNil:
        return
    for c in cb:
        let index = listeners.find(c)
        if index > -1:
            listeners.del(index)

proc unsubscribe*(oo: openarray[Observarble], r: ref, cb: ObserverHandler) =
    for o in oo:
        o.unsubscribe(r, cb)

proc notify*(o: Observarble) =
    if o.noNotify:
        return

    if o.listeners.isNil:
        return
    for cbs in o.listeners.values:
        if cbs.isNil:
            continue
        for cb in cbs:
            cb(o)

template update*(o: Observarble, x: untyped): untyped =
    let notify = o.notifyOn
    o.notifyOn = false

    x

    o.notifyOn = notify
    if notify:
        o.notify()

template genType(T, TT): untyped =
    type T* = ref object of TT

proc toObservarble(x: NimNode, y: NimNode): NimNode =
    var T: NimNode
    var TT: NimNode
    
    if x.kind == nnkIdent:
        T = x
        TT = ident("Observarble")
    elif x.kind == nnkInfix:
        if not x[0].eqIdent("of"):
            raise
        T = x[1]
        TT = x[2]
    else:
        raise

    var fields = nnkRecList.newTree()
    var procs = nnkStmtList.newTree()

    y.expectKind(nnkStmtList)
    for n in y:
        var node = n
        var name: NimNode
        var ntype: NimNode
        var isPublic: bool
        var settings: NimNode
        var disabled = false

        if node.kind == nnkCommand and node[1].kind == nnkTableConstr:
            settings = node[1]
            node = node[0]

        if node.kind == nnkInfix:
            if not node[0].eqIdent("*"):
                raise
            name = node[1]
            ntype = node[2]
            isPublic = true
        elif node.kind == nnkCommand:
            name = node[0]
            ntype = node[1]
        else:
            raise

        let pname = ident("p_" & $name)
        
        var getter = quote:
            proc `name`(o: `T`): `ntype` = o.`pname`
        var setter = quote:
            proc `name`(o: `T`, `name`: `ntype`) = 
                o.`pname` = `name`
                o.notify()
        setter[0] = nnkAccQuoted.newTree(ident($setter[0] & "="))

        if isPublic:
            getter[0] = nnkPostfix.newTree(ident("*"), getter[0])
            setter[0] = nnkPostfix.newTree(ident("*"), setter[0])

        if not settings.isNil:
            for x in settings:
                if x[0].eqIdent("setter"):
                    setter[6] = x[1][6]
                    setter[3] = x[1][3]
                elif x[0].eqIdent("getter"):
                    getter[6] = x[1][6]
                    getter[3] = x[1][3]
                elif x[0].eqIdent("disabled"):
                    if x[1].eqIdent("true"):
                        disabled = true
        
        if not disabled:
            procs.add([getter, setter])
            fields.add(
                nnkIdentDefs.newTree(
                    pname,
                    ntype,
                    newEmptyNode()
                )
            )
        else:
            fields.add(
                nnkIdentDefs.newTree(
                    (if isPublic: nnkPostfix.newTree(ident("*"), name) else: name),
                    ntype,
                    newEmptyNode()
                )
            )

    let genType = getAst(genType(T, TT))
    genType[0][2][0][2] = fields
    
    result = nnkStmtList.newTree(
        genType, 
        procs
    )

macro observarble*(x: untyped, y: untyped): untyped =
    result = toObservarble(x, y)
    
    when defined(debugNodeProxy):
        echo "\ngen finished \n ", repr(result)


proc observe*[T](x: T) =
    discard


when isMainModule:
    observarble Test:
        id* string
        name* string

    let test = Test.new()
    test.subscribe(test) do(o: Observarble):
        echo "Subscriber: ", o.Test.name
    test.name = "123"
    test.name = "321"
    test.unsubscribe(test)
    test.name = "333"

    observarble Test2 of Test:
        id2* string
        name2* string {
            disabled: true,
            setter: proc(o: Test2, v: string) =
                o.p_name2 = v
                o.notify()
        }
        name3* string {
            setter: proc(o: Test2, v: string) =
                o.p_name3 = v
                o.notify()
        }

    let test2 = Test2.new()
    test2.subscribe(test2) do(o: Observarble):
        echo "Subscriber2: ", o.Test.name
    test2.name = "123"
    test2.name = "321"
