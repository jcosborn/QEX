# this is just a mock-up, not working code
template unimplemented(x: untyped) = discard

import qex
import qex/physics/qcdTypes

var latf = [16,16,16,16]
var latc = [4,4,4,4]
var lf = newLayout(latf)
var lc = newLayout(latc)

const nv = 10

var v1f = lf.ColorVector()
unimplemented:
  var v1c = lc.ColorVector(nc=nv)

var p: array[nv, type(v1f)]
for i in 0..<nv:
  p[i] = lf.ColorVector()

unimplemented:
  var blocks = newMgBlock(lf, fc)

  blocks.prolong(v1f, v1c, p)
  blocks.prolong(v1f, v1c, p, "even")  # fine parity

  blocks.restrict(v1c, v1f, p)
