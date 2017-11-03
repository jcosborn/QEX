import qex/base
import qex/layout
import qex/field

type
  SolverParams* = object
    r2req*:float
    maxits*:int
    verbosity*:int
    finalIterations*:int
    seconds*: float
    subset*:Subset
    subsetName*:string

proc cgSolve*(x: Field; b: Field2; op: any; sp: var SolverParams) =
  mixin apply
  tic()
  let vrb = sp.verbosity
  template verb(n:int; body:untyped):untyped =
    if vrb>=n: body
  let sub = sp.subset
  template subset(body:untyped):untyped =
    onNoSync(sub):
      body
  template mythreads(body:untyped):untyped =
    threads:
      onNoSync(sub):
        body

  var b2: float
  mythreads:
    b2 = b.norm2
  verb(1):
    echo("input norm2: ", b2)
  if b2 == 0.0:
    sp.finalIterations = 0
    return

  var r = newOneOf(x)
  var p = newOneOf(x)
  var Ap = newOneOf(x)
  let r2stop = sp.r2req * b2;
  let maxits = sp.maxits
  var finalIterations = 0

  threads:
    var r2:float
    op.apply(Ap, x)
    subset:
      r := b - Ap
      p := r
      r2 = r.norm2
      verb(3):
        echo("p2: ", p.norm2)
        echo("r2: ", r2)

    var itn = 0
    var r2o = r2
    verb(1):
      #echo(-1, " ", r2)
      echo(itn, " ", r2/b2)
    toc("cg setup")

    if r2 >= r2stop:    # skip iterations otherwise
      while itn<maxits:
        tic()
        inc itn
        op.apply(Ap, p)
        toc("Ap")
        subset:
          let pAp = p.redot(Ap)
          toc("pAp", flops=2*numNumbers(p[0])*sub.lenOuter)
          let alpha = r2/pAp
          x += alpha*p
          toc("x", flops=2*numNumbers(p[0])*sub.lenOuter)
          r -= alpha*Ap
          toc("r", flops=2*numNumbers(r[0])*sub.lenOuter)
          r2 = r.norm2
          toc("r2", flops=2*numNumbers(r[0])*sub.lenOuter)
        verb(2):
          #echo(itn, " ", r2)
          echo(itn, " ", r2/b2)
        verb(3):
          subset:
            let pAp = p.redot(Ap)
            echo "p2: ", p.norm2
            echo "Ap2: ", Ap.norm2
            echo "pAp: ", pAp
            echo "alpha: ", r2o/pAp
            echo "x2: ", x.norm2
            echo "r2: ", r2
          op.apply(Ap, x)
          var fr2: float
          subset:
            fr2 = (b - Ap).norm2
          echo "   ", fr2/b2
        if r2<r2stop: break
        let beta = r2/r2o
        r2o = r2
        subset:
          p := r + beta*p
        toc("p update", flops=2*numNumbers(r[0])*sub.lenOuter)
        verb(3):
          echo "beta: ", beta
    toc("cg iterations")
    if threadNum==0: finalIterations = itn

    var fr2: float
    op.apply(Ap, x)
    subset:
      r := b - Ap
      fr2 = r.norm2
    verb(1):
      echo finalIterations, " acc r2:", r2/b2
      echo finalIterations, " tru r2:", fr2/b2

  sp.finalIterations = finalIterations
  toc("cg final")

when isMainModule:
  import qex
  import qex/physics/qcdTypes
  qexInit()
  echo "rank ", myRank, "/", nRanks
  #var lat = [8,8,8,8]
  var lat = [4,4,4,4]
  var lo = newLayout(lat)
  var m = lo.ColorMatrix()
  var v1 = lo.ColorVector()
  var v2 = lo.ColorVector()
  type opArgs = object
    m: type(m)
  var oa = opArgs(m: m)
  proc apply*(oa: opArgs; r: type(v1); x: type(v1)) =
    r := oa.m*x
    #mul(r, m, x)
  var sp:SolverParams
  sp.r2req = 1e-14
  sp.maxits = 100
  sp.verbosity = 3
  sp.subset.layoutSubset(lo, "all")
  threads:
    m.even := 1
    m.odd := 10
    threadBarrier()
    tfor i, 0..<lo.nSites:
      m{i} := i+1
    threadBarrier()
    v1.even := 1
    v1.odd := 2
    v2 := 0
    echo v1.norm2
    echo m.norm2

  cgSolve(v2, v1, oa, sp)
  echo sp.finalIterations
