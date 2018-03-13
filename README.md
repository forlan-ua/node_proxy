# node_proxy
macro for wrapping Node's and their children with components
for rod game engine

Node proxy for rod game engine

# Usage:

Create test node tree with components and animation

```
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
```

# Define node proxy

```
# node proxy allways has property - ```node* : Node``` - this is root node of proxy
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
```

# Macro output

```
type
  TestProxy* = ref object of NodeProxy
    observed_obj: MyObservarble
    someNode: Node
    nilNode: Node
    someNode2: Node
    text*: Text
    child: Node
    text2: Text
    source: int
    source2: int
    anim: Animation
    anim2: Animation

template onUpdateObserved_obj(np: TestProxy) =
  np.text2.text = np.obj.name

proc obj(np: TestProxy): MyObservarble =
  np.observed_obj

proc `obj=`(np: TestProxy; obj: MyObservarble) =
  if not(np.observed_obj.isNil):
    for c2068052 in np.node.components:
      if c2068052 of ObserverComponent and
          c2068052.ObserverComponent.target ==
          np.observed_obj:
        np.node.removeComponent(c2068052)
        break
  np.observed_obj = obj
  if not(np.observed_obj.isNil):
    let c2068054 = np.node.addComponent(ObserverComponent)
    c2068054.target = np.observed_obj
    c2068054.subscribe(proc (obj: Observarble) =
      np.onUpdateObserved_obj())
    np.onUpdateObserved_obj()

proc init*(np: TestProxy; node2068050: Node) =
  np.NodeProxy.init(node2068050)
  np.someNode = np.node.findNode("somenode")
  np.someNode.parent.enabled = false
  np.nilNode = np.someNode.newChild("nilNode")
  np.nilNode.alpha = 0.1
  np.nilNode.enabled = getSomeEnabled()
  np.someNode2 = np.nilNode.newChild("somenode")
  np.someNode2.parent.enabled = false
  np.text = np.node.findNode("somenode").getComponent(Text)
  assert(np.text.isNil != true, "Component nil")
  np.text.text = "some text"
  np.child = np.node.findNode("child1")
  assert(np.nilNode.getComponent(Text).isNil, "Component already added")
  np.text2 = np.nilNode.component(Text)
  np.text2.bounds = newRect(20.0, 20.0, 100.0, 100.0)
  np.source = 100500
  block:
      let ctor2068056 = proc (np: TestProxy): int =
        result = 1060
      np.source2 = ctor2068056(np)
  np.anim = np.child.animationNamed("animation")
  assert(np.anim.isNil != true, "Animation nil")
  np.anim.numberOfLoops = 2
  np.anim.loopDuration = 0.5
  np.anim2 = np.node.animationNamed("in")
  assert(np.anim2.isNil != true, "Animation nil")
  np.anim2.numberOfLoops = 3
  np.anim2.loopDuration = 1.5

proc new*(T: typedesc[TestProxy]; node2068058: Node): T =
  result = T.new()
  result.init(node2068058)

```

# Create proxy and use
```
var tproxy = TestProxy.new(nodeForTest())

echo "proxy ", tproxy.node.name
```