import rod / component
import observarble


type ObserverComponent* = ref object of Component
    target*: Observarble
    subscriptions*: seq[ObserverHandler]
    added: bool

method componentNodeWasAddedToSceneView*(c: ObserverComponent) = 
    for cb in c.subscriptions:
        c.target.subscribe(c, cb)
    c.added = true

method componentNodeWillBeRemovedFromSceneView*(c: ObserverComponent) = 
    c.target.unsubscribe(c)
    c.added = false

proc subscribe*(c: ObserverComponent, cb: ObserverHandler) =
    if c.subscriptions.isNil:
        c.subscriptions = @[]
    c.subscriptions.add(cb)
    if c.added:
        c.target.subscribe(c, cb)

proc subscribe*(c: ObserverComponent, cb: openarray[ObserverHandler]) =
    if c.subscriptions.isNil:
        c.subscriptions = @[]
    c.subscriptions.add(cb)
    if c.added:
        for cc in cb:
            c.target.subscribe(c, cc)