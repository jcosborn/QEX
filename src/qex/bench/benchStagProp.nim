import qex
#import stdUtils
import qex/field
import qex/physics/qcdTypes
import qex/gauge/gaugeUtils
import qex/physics/stagD
#import profile
import os
import qex/rng

qexInit()
#var defaultLat = [4,4,4,4]
#var defaultLat = [8,8,8,8]
var defaultLat = @[8,8,8,8]
#var defaultLat = @[12,12,12,12]
defaultSetup()
var v1 = lo.ColorVector()
var v2 = lo.ColorVector()
var r = lo.ColorVector()
var rs = newRNGField(RngMilc6, lo, intParam("seed", 987654321).uint64)
threads:
  g.random rs
  g.setBC
  g.stagPhase
  v1 := 0
  #for e in v1:
  #  template x(d:int):untyped = lo.vcoords(d,e)
  #  v1[e][0].re := foldl(x, 4, a*10+b)
  #  #echo v1[e][0]
#echo v1.norm2
if myRank==0:
  v1{0}[0] := 1
  #v1{2*1024}[0] := 1
echo v1.norm2
#var gs = lo.newGaugeS
#for i in 0..<gs.len: gs[i] := g[i]
var s = newStag(g)
var m = 0.000001
threads:
  v2 := 0
  echo v2.norm2
  threadBarrier()
  s.D(v2, v1, m)
  threadBarrier()
  #echoAll v2
  echo v2.norm2
#echo v2
var sp = initSolverParams()
sp.maxits = int(1e9/lo.physVol.float)
s.solve(v2, v1, m, sp)
resetTimers()
s.solve(v2, v1, m, sp)
threads:
  echo "v2: ", v2.norm2
  echo "v2.even: ", v2.even.norm2
  echo "v2.odd: ", v2.odd.norm2
  s.D(r, v2, m)
  threadBarrier()
  r := v1 - r
  threadBarrier()
  echo r.norm2
#echo v2
echoTimers()

var g3:array[8,type(g[0])]
for i in 0..3:
  g3[2*i] = g[i]
  g3[2*i+1] = lo.ColorMatrix()
  g3[2*i+1].randomSU rs
var s3 = newStag3(g3)
#s3.D(v2, v1, m)
s3.solve(v2, v1, m, sp)
resetTimers()
s3.solve(v2, v1, m, sp)

qexFinalize()
