import qex/base
import qex/layout
import qex/gauge
import strUtils
import qex/fat7l

export PerfInfo

type HypCoefs* = object
  alpha1*: float
  alpha2*: float
  alpha3*: float

proc `$`*(c: HypCoefs): string =
  result  = "alpha1: " & $c.alpha1 & "\n"
  result &= "alpha2: " & $c.alpha2 & "\n"
  result &= "alpha3: " & $c.alpha3

proc symStaple(s: any, alp: float, g1: any, g2: any,
               s1: any, s2: any, tm: any, sm: any) =
  mixin adj
  tm := g1.adj * g2 * s1.field
  discard sm ^* tm
  s += alp * ( g1 * s2.field * s1.field.adj )
  s += alp * sm.field

template proj(x: any) =
  for e in x:
    x[e].projectU x[e]

# L[mu][nu] = P( (1-a1)*g[mu] + 0.5*a1 SS(g[nu],g[mu]) )
# L2[mu][nu] = P( (1-a2)*g[mu] + 0.25*a2 sum{a,b!=mu,nu} SS(L[a][b],L[mu][b]) )
# fl[mu] = P( (1-a3)*g[mu] + a3/6 sum{nu!=mu} SS(L2[nu][mu],L2[mu][nu]) )
proc smear*(coef: HypCoefs, gf: any, fl: any, info: var PerfInfo) =
  tic()
  type lcm = type(gf[0])
  proc newlcm: lcm = result.new(gf[0].l)
  var
    l1: array[4,array[4,lcm]]
    l2: array[4,array[4,lcm]]
    tm1: lcm
    sm1: array[4,Shifter[lcm,type(gf[0][0])]]
    s1: array[4,array[4,Shifter[lcm,type(gf[0][0])]]]
    nflop = 61632.0
    dtime = 0.0

  tm1 = newlcm()
  for mu in 0..<4:
    sm1[mu] = newShifter(gf[mu], mu, -1)
    for nu in 0..<4:
      if nu!=mu:
        l1[mu][nu] = newlcm()
        l2[mu][nu] = newlcm()
        s1[mu][nu] = newShifter(gf[mu], nu, 1)
        discard s1[mu][nu] ^* gf[mu]

  let alp1 = coef.alpha1 / 2.0
  for mu in 0..<4:
    #fl[mu] := 0
    for nu in 0..<4:
      if nu!=mu:
        l1[mu][nu] := (1-coef.alpha1) * gf[mu]
        symStaple(l1[mu][nu], alp1, gf[nu], gf[mu],
                  s1[nu][mu], s1[mu][nu], tm1, sm1[nu])
        proj l1[mu][nu]
        #fl[mu] += l1[mu][nu]

  let alp2 = coef.alpha2 / 4.0
  for mu in 0..<4:
    #fl[mu] := 0
    for nu in 0..<4:
      if nu!=mu:
        l2[mu][nu] := (1-coef.alpha2) * gf[mu]
        for a in 0..<4:
          if a!=mu and a!=nu:
            let b = 1+2+3-mu-nu-a
            discard s1[nu][mu] ^* l1[a][b]
            discard s1[mu][a] ^* l1[mu][b]
            symStaple(l2[mu][nu], alp2, l1[a][b], l1[mu][b],
                      s1[nu][mu], s1[mu][a], tm1, sm1[a])
        proj l2[mu][nu]
        #fl[mu] += l1[mu][nu]

  let alp3 = coef.alpha3 / 6.0
  for mu in 0..<4:
    fl[mu] := (1-coef.alpha3) * gf[mu]
    for nu in 0..<4:
      if nu!=mu:
        discard s1[nu][mu] ^* l2[nu][mu]
        discard s1[mu][nu] ^* l2[mu][nu]
        symStaple(fl[mu], alp3, l2[nu][mu], l2[mu][nu],
                  s1[nu][mu], s1[mu][nu], tm1, sm1[nu])
    proj fl[mu]

  toc()

proc smear*(c: HypCoefs, g: any, fl: any) =
  var info: PerfInfo
  c.smear(g, fl, info)

when isMainModule:
  import qex
  import qex/physics/qcdTypes
  import qex/gauge
  qexInit()
  #var defaultGaugeFile = "l88.scidac"
  let defaultLat = @[8,8,8,8]
  defaultSetup()
  #for mu in 0..<g.len: g[mu] := 1
  #g.random

  var info: PerfInfo
  var coef: HypCoefs
  coef.alpha1 = 0.4
  coef.alpha2 = 0.5
  coef.alpha3 = 0.5

  echo coef

  var fl = lo.newGauge()

  template disp(g: typed) =
    let p = g.plaq
    let sp = 2.0*(p[0]+p[1]+p[2])
    let tp = 2.0*(p[3]+p[4]+p[5])
    echo p
    echo sp
    echo tp
    echo trace(g[0])

  disp g
  coef.smear(g, fl, info)
  disp fl
  #echo pow(1.0,4)/6.0
  #echo pow(1.0+6.0,4)/6.0
  #echo pow(1.0+6.0+6.0*4.0,4)/6.0
  #echo pow(1.0+6.0+6.0*4.0+6.0*4.0*2.0,4)/6.0
  #echo pow(1.0+6.0+6.0*4.0+6.0*4.0*2.0+6.0,4)/6.0

  qexFinalize()
