import strUtils
import stdUtils
import macros
import omp
import metaUtils

type
  ThreadShare* = object
    p*:pointer
    counter*:int
  ThreadObj* = object
    threadNum*:int
    numThreads*:int
    share*:ptr cArray[ThreadShare]

var threadNum*{.threadvar.}:int
var numThreads*{.threadvar.}:int
var threadLocals*{.threadvar.}:ThreadObj
var inited = false

template initThreadLocals*(ts:seq[ThreadShare]):untyped =
  threadLocals.threadNum = threadNum
  threadLocals.numThreads = numThreads
  threadLocals.share = cast[ptr cArray[ThreadShare]](ts[0].addr)
  threadLocals.share[threadNum].p = nil
  threadLocals.share[threadNum].counter = 0
proc init =
  inited = true
  threadNum = 0
  numThreads = 1
  var ts = newSeq[ThreadShare](numThreads)
  initThreadLocals(ts)
template threadsInit* =
  if not inited:
    init()
template checkInit* =
  threadsInit()
  #if not inited:
    #let ii = instantiationInfo()
    #let ln = ii.line
    #let fn = ii.filename[0 .. ^5]
    #echo format("error: $#($#): threads not initialized",fn,ln)
    #quit(-1)

template threads*(body:untyped):untyped =
  checkInit()
  let tidOld = threadNum
  let nidOld = numThreads
  let tlOld = threadLocals
  proc tproc{.genSym.} =
    var ts:seq[ThreadShare]
    ompParallel:
      threadNum = ompGetThreadNum()
      numThreads = ompGetNumThreads()
      if threadNum==0: ts.newSeq(numThreads)
      threadBarrier()
      initThreadLocals(ts)
      #echoAll threadNum, " s: ", ptrInt(threadLocals.share)
      body
      threadBarrier()
  tproc()
  threadNum = tidOld
  numThreads = nidOld
  threadLocals = tlOld
template threads*(x0:untyped;body:untyped):untyped =
  checkInit()
  let tidOld = threadNum
  let nidOld = numThreads
  let tlOld = threadLocals
  proc tproc(xx:var type(x0)) {.genSym.} =
    var ts:seq[ThreadShare]
    ompParallel:
      threadNum = ompGetThreadNum()
      numThreads = ompGetNumThreads()
      if threadNum==0: ts.newSeq(numThreads)
      threadBarrier()
      initThreadLocals(ts)
      #echoAll threadNum, " s: ", ptrInt(threadLocals.share)
      subst(x0,xx):
        body
  tproc(x0)
  threadNum = tidOld
  numThreads = nidOld
  threadLocals = tlOld

template threadBarrier* = ompBarrier
template threadMaster*(x:untyped) = ompMaster(x)
template threadSingle*(x:untyped) = ompSingle(x)

template threadDivideLow*(x,y:untyped):expr =
  x + (threadNum*(y-x)) div numThreads
template threadDivideHigh*(x,y:untyped):expr =
  x + ((threadNum+1)*(y-x)) div numThreads

#macro tForX(slice:Slice; index,body:untyped):stmt =
macro tFor*(index:expr; slice:Slice; body:untyped):stmt =
  #echo index.treeRepr
  #echo treeRepr(slice)
  var i0,i1:NimNode
  #echo slice.kind
  if slice.kind == nnkStmtListExpr:
    i0 = slice[1][1]
    i1 = slice[1][2]
  else:
    i0 = slice[1]
    i1 = slice[2]
  return quote do:
    let d = 1+`i1` - `i0`
    let ti0 = `i0` + (threadNum*d) div numThreads
    let ti1 = `i0` + ((threadNum+1)*d) div numThreads
    for `index` in ti0 ..< ti1:
      `body`
#template tFor*(index,slice,body:untyped):untyped =
#  tForX(slice, index, body)
    
discard """
iterator `.|`*[S, T](a: S, b: T): T {.inline.} =
  mixin threadNum
  var d = b - T(a)
  var res = T(a) + (threadNum*d) div numThreads
  var bb = T(a) + ((threadNum+1)*d) div numThreads
  while res <= bb:
    yield res
    inc(res)
"""

#template t0wait* = threadBarrier()
template t0wait* =
  if threadNum==0:
    inc threadLocals.share[0].counter
    let tbar0 = threadLocals.share[0].counter
    for b in 1..<numThreads:
      while true:
        if threadLocals.share[b].counter >= tbar0: break
  else:
    inc threadLocals.share[threadNum].counter

#template twait0* = threadBarrier()
template twait0* =
  if threadNum==0:
    inc threadLocals.share[0].counter
  else:
    inc threadLocals.share[threadNum].counter
    let tbar0 = threadLocals.share[threadNum].counter
    let p{.volatile.} = threadLocals.share[0].counter.addr
    while true:
      if p[] >= tbar0: break

macro threadSum*(a:varargs[expr]):auto =
  #echo a.treeRepr
  result = newNimNode(nnkStmtList)
  var sum = newNimNode(nnkStmtList)
  let tid = ident("threadNum")
  let nid = ident("numThreads")
  let p = newLit(1)
  for i in 0..<a.len:
    let gi = !("g" & $i)
    let ai = a[i]
    result.add quote do:
      var `gi`{.global.}:array[`p`*512,type(`ai`)]
      `gi`[`p`*`tid`] = `ai`
    let s = quote do:
      `ai` = `gi`[0]
      for i in 1..<`nid`:
        `ai` += `gi`[`p`*i]
    sum.add(s)
  let m = quote do:
    threadBarrier()
    `sum`
    threadBarrier()
  result.add(m)
  #echo result.treeRepr
macro threadSum2*(a:varargs[expr]):auto =
  #echo a.treeRepr
  result = newNimNode(nnkStmtList)
  var g0 = newNimNode(nnkStmtList)
  var gp = newNimNode(nnkStmtList)
  var a0 = newNimNode(nnkStmtList)
  for i in 0..<a.len:
    let gi = !("g" & $i)
    let ai = a[i]
    let t = quote do:
      var `gi`{.global.}:type(`ai`)
    result.add(t[0])
    let x0 = quote do:
      `gi` = `ai`
    g0.add(x0[0])
    #echo g0.treeRepr
    let xp = quote do:
      `gi` += `ai`
    gp.add(xp[0])
    #echo gp.treeRepr
    let ax = quote do:
      `ai` = `gi`
    a0.add(ax[0])
    #echo a0.treeRepr
  #echo result.treeRepr
  let m = quote do:
    if threadNum==0:
      `g0`
      threadBarrier()
      threadBarrier()
    else:
      threadBarrier()
      {.emit:"#pragma omp critical"}
      block:
        `gp`
      threadBarrier()
    `a0`
  result.add(m)
  #echo result.treeRepr

when isMainModule:
  threadsInit()
  echo threadNum, "/", numThreads
  threads:
    echo threadNum, "/", numThreads
