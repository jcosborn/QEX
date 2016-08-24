import qex
import gaugeUtils
import stdUtils
import profile

proc startCornerShifts*[T](u: openArray[T]): auto =
  var s:seq[seq[ShiftB[type(u[0][0])]]]
  let nd = u.len
  s.newSeq(nd)
  for mu in 0..<nd:
    s[mu].newSeq(nd)
    for nu in 0..<nd:
      if mu!=nu:
        s[mu][nu].initShiftB(u[mu], nu, 1, "all")
        s[mu][nu].startSB(u[mu][ix])
  return s

proc startStapleShifts*[T](u: openArray[T]): auto =
  var s:seq[seq[seq[ShiftB[type(u[0][0][0])]]]]
  let nd = u.len
  s.newSeq(nd)
  for mu in 0..<nd:
    s[mu].newSeq(nd)
    for nu in 0..<nd:
      if nu!=mu:
        s[mu][nu].newSeq(nd)
        for sig in 0..<nd:
          if sig!=mu:
            s[mu][nu][sig].initShiftB(u[mu][nu], sig, 1, "all")
            s[mu][nu][sig].startSB(u[mu][nu][ix])
  return s

proc makeFwdStaples*[T](uu: openArray[T], s: any): auto =
  mixin mul
  tic()
  let u = cast[ptr cArray[T]](unsafeAddr(uu[0]))
  let lo = u[0].l
  let nd = lo.nDim
  let nc = u[0][0].ncols
  let flops = lo.nSites.float*float(nd*(nd-1)*3*(4*nc-1)*nc*nc)
  var st: seq[seq[type(uu[0])]]
  st.newSeq(nd)
  for mu in 0..<nd:
    st[mu].newSeq(nd)
    for nu in 0..<nd:
      if mu!=nu:
        st[mu][nu].new(lo)
  toc("makeStaples setup")
  threads:
    tic()
    var umu,unu,umunu: type(load1(u[0][0]))
    for ir in lo:
      for mu in 1..<nd:
        for nu in 0..<mu:
          if isLocal(s[mu][nu],ir) and isLocal(s[nu][mu],ir):
            localSB(s[mu][nu], ir, assign(umu,it), u[mu][ix])
            localSB(s[nu][mu], ir, assign(unu,it), u[nu][ix])
            mul(umunu, umu, unu.adj)
            mul(st[mu][nu][ir], u[nu][ir], umunu)
            mul(st[nu][mu][ir], u[mu][ir], umunu.adj)
    toc("makeStaples local")
    #[
    var needBoundary = false
    for mu in 0..<nd:
      for nu in 0..<nd:
        if mu != nu:
          boundaryWaitSB(s[mu][nu]): needBoundary = true
    toc("makeStaples wait")
    if needBoundary:
      boundarySyncSB()
      for ir in lo:
        for mu in 1..<nd:
          for nu in 0..<mu:
            if not isLocal(s[mu][nu],ir) or not isLocal(s[nu][mu],ir):
              getSB(s[mu][nu], ir, assign(umu,it), u[mu][ix])
              getSB(s[nu][mu], ir, assign(unu,it), u[nu][ix])
              mul(umunu, umu, unu.adj)
              mul(st[mu][nu][ir], u[nu][ir], umunu)
              mul(st[nu][mu][ir], u[mu][ir], umunu.adj)
    ]#
    for mu in 1..<nd:
      for nu in 0..<mu:
        var needBoundary = false
        boundaryWaitSB(s[mu][nu]): needBoundary = true
        boundaryWaitSB(s[nu][mu]): needBoundary = true
        if needBoundary:
          for ir in lo:
            if not isLocal(s[mu][nu],ir) or not isLocal(s[nu][mu],ir):
              getSB(s[mu][nu], ir, assign(umu,it), u[mu][ix])
              getSB(s[nu][mu], ir, assign(unu,it), u[nu][ix])
              mul(umunu, umu, unu.adj)
              mul(st[mu][nu][ir], u[nu][ir], umunu)
              mul(st[nu][mu][ir], u[mu][ir], umunu.adj)
    toc("makeStaples boundary")
  toc("makeStaples threads", flops=flops)
  return st

proc makeStaples*[T](uu: openArray[T], s: any): auto =
  mixin mul
  tic()
  let u = cast[ptr cArray[T]](unsafeAddr(uu[0]))
  let lo = u[0].l
  let nd = lo.nDim
  let nc = u[0][0].ncols
  let flops = lo.nSites.float*float(nd*(nd-1)*6*(4*nc-1)*nc*nc)
  var stf: seq[seq[type(uu[0])]]
  var stu: seq[seq[type(uu[0])]]
  var ss: seq[seq[ShiftB[type(uu[0][0])]]]
  stf.newSeq(nd)
  stu.newSeq(nd)
  ss.newSeq(nd)
  for mu in 0..<nd:
    stf[mu].newSeq(nd)
    stu[mu].newSeq(nd)
    ss[mu].newSeq(nd)
    for nu in 0..<nd:
      if mu!=nu:
        stf[mu][nu].new(lo)
        stu[mu][nu].new(lo)
        ss[mu][nu].initShiftB(stu[mu][nu], nu, -1, "all")
  toc("makeStaples setup")
  threads:
    tic()
    var umu,unu,umunu,unumu: type(load1(u[0][0]))
    for ir in lo:
      for mu in 1..<nd:
        for nu in 0..<mu:
          if isLocal(s[mu][nu],ir) and isLocal(s[nu][mu],ir):
            localSB(s[mu][nu], ir, assign(umu,it), u[mu][ix])
            localSB(s[nu][mu], ir, assign(unu,it), u[nu][ix])
            mul(umunu, umu, unu.adj)
            mul(stf[mu][nu][ir], u[nu][ir], umunu)
            mul(stf[nu][mu][ir], u[mu][ir], umunu.adj)
            mul(unumu, u[nu][ir].adj, u[mu][ir])
            mul(stu[mu][nu][ir], unumu, unu)
            mul(stu[nu][mu][ir], unumu.adj, umu)
    toc("makeStaples local")
    var needBoundary = false
    for mu in 1..<nd:
      for nu in 0..<mu:
        var needBoundaryU = false
        boundaryWaitSB(s[mu][nu]): needBoundaryU = true
        boundaryWaitSB(s[nu][mu]): needBoundaryU = true
        needBoundary = needBoundary or needBoundaryU
        if needBoundaryU:
          for ir in lo:
            if not isLocal(s[mu][nu],ir) or not isLocal(s[nu][mu],ir):
              getSB(s[mu][nu], ir, assign(umu,it), u[mu][ix])
              getSB(s[nu][mu], ir, assign(unu,it), u[nu][ix])
              mul(unumu, u[nu][ir].adj, u[mu][ir])
              mul(stu[mu][nu][ir], unumu, unu)
              mul(stu[nu][mu][ir], unumu.adj, umu)
        ss[mu][nu].startSB(stu[mu][nu][ix])
        ss[nu][mu].startSB(stu[nu][mu][ix])
    toc("makeStaplesU boundary")
    if needBoundary:
      boundarySyncSB()
      for ir in lo:
        for mu in 1..<nd:
          for nu in 0..<mu:
            if not isLocal(s[mu][nu],ir) or not isLocal(s[nu][mu],ir):
              getSB(s[mu][nu], ir, assign(umu,it), u[mu][ix])
              getSB(s[nu][mu], ir, assign(unu,it), u[nu][ix])
              mul(umunu, umu, unu.adj)
              mul(stf[mu][nu][ir], u[nu][ir], umunu)
              mul(stf[nu][mu][ir], u[mu][ir], umunu.adj)
    toc("makeStaplesF boundary")
  toc("makeStaples threads", flops=flops)
  return (stf,stu,ss)

# plaq: 6 types
# rect: 12 types
# pgm: 32=4*2*4=4*3*2+4*2 types
# shift corners: u[mu],nu mu != nu (12)
# make staples: s[mu][nu] mu != nu (12)
# plaq traces:
#  plaq: U[mu]^+ * sum_{nu!=mu} s[mu][nu] (6)
#  rect: shift(s[mu][nu], nu) (12 shifts)
#  pgm: shift(s[mu][nu], sig) (24 shifts)
proc gaugeAction*[T](uu: openArray[T]): auto =
  mixin mul
  tic()
  let u = cast[ptr cArray[T]](unsafeAddr(uu[0]))
  let lo = u[0].l
  let nd = lo.nDim
  let np = (nd*(nd-1)) div 2
  let nc = u[0][0].ncols
  var cs = startCornerShifts(uu)
  toc("gaugeAction startCornerShifts")
  var (stf,stu,ss) = makeStaples(uu, cs)
  toc("gaugeAction makeStaples")
  #var ss = startStapleShifts(st)
  #toc("gaugeAction startStapleShifts")
  let maxThreads = getMaxThreads()
  var nth = 0
  var act = newSeq[float](3*maxThreads)
  toc("gaugeAction setup")
  threads:
    tic()
    var plaq = 0.0
    var rect = 0.0
    var pgm = 0.0
    for ir in u[0]:
      for mu in 1..<nd:
        for nu in 0..<mu:
          # plaq
          let p1 = redot(u[mu][ir], stf[mu][nu][ir])
          plaq += simdSum(p1)
          if isLocal(ss[mu][nu],ir) and isLocal(ss[nu][mu],ir):
            var bmu,bnu: type(load1(u[0][0]))
            localSB(ss[mu][nu], ir, assign(bmu,it), stu[mu][nu][ix])
            localSB(ss[nu][mu], ir, assign(bnu,it), stu[nu][mu][ix])
            # rect
            let r1 = redot(bmu, stf[mu][nu][ir])
            rect += simdSum(r1)
            let r2 = redot(bnu, stf[nu][mu][ir])
            rect += simdSum(r2)
    toc("gaugeAction local", flops=lo.nSites.float*float(np*(4*nc*nc)))
    for mu in 1..<nd:
      for nu in 0..<mu:
        var needBoundary = false
        boundaryWaitSB(ss[mu][nu]): needBoundary = true
        boundaryWaitSB(ss[nu][mu]): needBoundary = true
        if needBoundary:
          for ir in lo:
            if not isLocal(ss[mu][nu],ir) or not isLocal(ss[nu][mu],ir):
              var bmu,bnu: type(load1(u[0][0]))
              getSB(ss[mu][nu], ir, assign(bmu,it), stu[mu][nu][ix])
              getSB(ss[nu][mu], ir, assign(bnu,it), stu[nu][mu][ix])
              # rect
              let r1 = redot(bmu, stf[mu][nu][ir])
              rect += simdSum(r1)
              let r2 = redot(bnu, stf[nu][mu][ir])
              rect += simdSum(r2)
    act[threadNum*3]   = plaq
    act[threadNum*3+1] = rect
    act[threadNum*3+2] = pgm
    if threadNum==0: nth = numThreads
    toc("gaugeAction boundary", flops=lo.nSites.float*float(np*(4*nc*nc)))
  toc("gaugeAction threads")
  var a = [0.0, 0.0, 0.0]
  for i in 0..<nth:
    a[0] += act[i*3]
    a[1] += act[i*3+1]
    a[2] += act[i*3+2]
  for i in 0..<3:
    a[i] = a[i]/(lo.physVol.float*float(np*nc))
  rankSum(a)
  echo "plaq: ", a[0]
  echo "rect: ", a[1]
  echo "pgm: ", a[2]
  result = a[0]
  toc("gaugeAction end")

when isMainModule:
  import qcdTypes
  qexInit()
  #let defaultLat = @[2,2,2,2]
  let defaultLat = @[8,8,8,8]
  defaultSetup()
  g.random

  var pl = plaq(g)
  echo pl
  echo pl.sum

  var ga = gaugeAction(g)
  echo ga

  qexFinalize()
