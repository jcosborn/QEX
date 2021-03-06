{. deadCodeElim: on .}

import simdX86Types
import simdSse
import simdAvx
import simdAvx512
#import ../basicOps
import base
import maths/types
import math
import macros

template binaryMixed(T,op1,op2:untyped):untyped =
  template op1*(x:SomeNumber; y:T):T = op2(x.to(T),y)
  template op1*(x:T; y:SomeNumber):T = op2(x,y.to(T))
template unaryMixedVar(T,op1,op2:untyped):untyped =
  template op1*(r: T; x:SomeNumber) = op2(r,x.to(T))
template binaryMixedVar(T,op1,op2:untyped):untyped =
  template op1*(r: T; x:SomeNumber; y:T) = op2(r,x.to(T),y)
  template op1*(r: T; x:T; y:SomeNumber) = op2(r,x,y.to(T))
template trinaryMixedVar(T,op1,op2:untyped):untyped =
  template op1*(r: T; x:SomeNumber; y:T; z:T) = op2(r,x.to(T),y,z)
  template op1*(r: T; x:T; y:SomeNumber; z:T) = op2(r,x,y.to(T),z)
  template op1*(r: T; x:T; y:T; z:SomeNumber) = op2(r,x,y,z.to(T))
template map1(T,N,op:untyped):untyped {.dirty.} =
  proc op*(x:T):T {.inline,noInit.} =
    let t = x.toArray
    var r{.noInit.}:type(t)
    for i in 0..<N:
      r[i] = op(t[i])
    assign(result, r)
template map2(T,N,op:untyped):untyped {.dirty.} =
  proc op*(x:T, y:T):T {.inline,noInit.} =
    let
      t = x.toArray
      u = y.toArray
    var r{.noInit.}:type(t)
    for i in 0..<N:
      r[i] = op(t[i], u[i])
    assign(result, r)

template basicDefs(T,F,N,P,S:untyped):untyped {.dirty.} =
  template isWrapper*(x:typedesc[T]): bool = false
  template isWrapper*(x:T): bool = false
  template numberType*(x:typedesc[T]):untyped = F
  template numberType*(x:T):untyped = F
  template numNumbers*(x:typedesc[T]):untyped = N
  template numNumbers*(x:T):untyped = N
  template simdType*(x:typedesc[T]):untyped = T
  template simdType*(x:T):untyped = T
  template simdLength*(x:T):untyped = N
  template simdLength*(x:typedesc[T]):untyped = N
  template load1*(x:T):untyped = x
  proc assign*(r:ptr F; x:T) {.inline.} =
    `P "_storeu_" S`(r, x)
  proc assign*(r:var T; x:ptr SomeNumber) {.inline.} =
    when x[] is F:
      r = `P "_loadu_" S`(x)
    else:
      let y = cast[ptr array[N,type(x[])]](x)
      var t{.noInit.}:array[N,F]
      for i in 0..<N: t[i] = F(y[][i])
      assign(r, t)
  template toSimd*(x:array[N,F]):untyped =
    `P "_loadu_" S`(cast[ptr F](unsafeAddr(x)))
  proc toArray*(x:T):array[N,F] {.inline,noInit.} =
    `P "_storeu_" S`(cast[ptr F](result.addr), x)
  template to*(x:SomeNumber; t:typedesc[T]):untyped =
    `P "_set1_" S`(F(x))
  template to*(x:array[N,F]; t:typedesc[T]):untyped =
    toSimd(x)
  proc to*(x:T; t:typedesc[array[N,F]]):array[N,F] {.inline,noInit.} =
    `P "_storeu_" S`(cast[ptr F](result.addr), x)
  when F is float32:
    template toSingleImpl*(x: T): untyped = x
    template toSingle*(x: T): untyped = x
  else:
    template toDoubleImpl*(x: T): untyped = x
    template toDouble*(x: T): untyped = x
  #proc assign1*(r:var T; x:SomeNumber) {.inline.} =
  template assign1*(r: var T; x: SomeNumber) =
    r = `P "_set1_" S`(F(x))
  template assign*(r: var T; x: SomeNumber) = assign1(r, x)
  template setX:untyped = `P "_setr_" S`()
  template setF(x):untyped = F(x)
  macro assign*(r:var T; x:varargs[SomeNumber]):auto =
    if x.len==1:
      result = newCall(ident"assign1", r, x[0])
    else:
      result = newStmtList()
      var call = getAst(setX()).peelStmt
      for i in 0..<N:
        call.add getAst(setF(x[i mod x.len]))
      template asgn(r,c:untyped):untyped = r = c
      result = getAst(asgn(r, call))
    #echo result.treerepr
  proc assign*(r:var T; x:array[N,SomeNumber]) {.inline.} =
    when x[0] is F:
      r = `P "_loadu_" S`(cast[ptr F](unsafeAddr(x)))
    else:
      var t{.noInit.}:array[N,F]
      for i in 0..<N: t[i] = F(x[i])
      assign(r, t)
  #proc assign*(r:var T; x:T) {.inline.} =
  #  r = x
  #template `=`*(r: var T; x: T) = {.emit: [r, " = ", x].}
  template assign*(r: T; x:T) =
    r = x
  #proc assign*(r:var array[N,F]; x:T) {.inline.} =
  #  assign(cast[ptr F](r.addr), x)
  proc assign*(r:var array[N,F]; x:T) {.inline.} =
    assign(r[0].addr, x)
  proc assign*(m: Masked[T], x: SomeNumber) =
    #static: echo "a mask"
    var i = 0
    var b = m.mask
    while b != 0:
      if (b and 1) != 0:
        m.pobj[][i] = x
      b = b shr 1
      i.inc
    #static: echo "end a mask"
  proc `[]`*(x:T; i:SomeInteger):F {.inline,noInit.} =
    toArray(x)[i]
  proc `[]=`*(r:var T; i:SomeInteger; x:SomeNumber) {.inline,noInit.} =
    var a = toArray(r)
    a[i] = F(x)
    assign(r, a)
  proc `$`*(x:T):string =
    result = "[" & $x[0]
    for i in 1..<N:
      result &= "," & $x[i]
    result &= "]"
  proc prefetch*(x:ptr T) {.inline.} =
    mm_prefetch(cast[cstring](x), 3)

  template add*(x,y:T):T = `P "_add_" S`(x,y)
  template sub*(x,y:T):T = `P "_sub_" S`(x,y)
  template mul*(x,y:T):T = `P "_mul_" S`(x,y)
  template divd*(x,y:T):T = `P "_div_" S`(x,y)
  template neg*(x:T):T = sub(`P "_setzero_" S`(), x)
  #template inv*(x:T):T = `P "_rcp_" S`(x)
  template inv*(x:T):T = divd(1.0,x)

  binaryMixed(T, add, add)
  binaryMixed(T, sub, sub)
  binaryMixed(T, mul, mul)
  binaryMixed(T, divd, divd)

  template neg*(r:var T; x:T) = r = neg(x)
  template add*(r: T; x,y:T) = r = add(x,y)
  template sub*(r: T; x,y:T) = r = sub(x,y)
  template mul*(r: T; x,y:T) = r = mul(x,y)
  template divd*(r: T; x,y:T) = r = divd(x,y)

  binaryMixedVar(T, add, add)
  binaryMixedVar(T, sub, sub)
  binaryMixedVar(T, mul, mul)
  binaryMixedVar(T, divd, divd)

  template iadd*(r: T; x:T) = add(r,r,x)
  template isub*(r: T; x:T) = sub(r,r,x)
  template imul*(r: T; x:T) = mul(r,r,x)
  template idiv*(r: T; x:T) = divd(r,r,x)
  template imadd*(r: T; x,y: T) = iadd(r,mul(x,y))
  template imsub*(r: T; x,y:T) = isub(r,mul(x,y))
  template madd*(r: T; x,y,z:T) = add(r,mul(x,y),z)
  template msub*(r: T; x,y,z:T) = sub(r,mul(x,y),z)

  unaryMixedVar(T, iadd, iadd)
  unaryMixedVar(T, isub, isub)
  unaryMixedVar(T, imul, imul)
  unaryMixedVar(T, idiv, idiv)
  binaryMixedVar(T, imadd, imadd)
  binaryMixedVar(T, imsub, imsub)
  trinaryMixedVar(T, madd, madd)
  trinaryMixedVar(T, msub, msub)

  template `-`*(x:T):T = neg(x)
  template `+`*(x,y:T):T = add(x,y)
  template `-`*(x,y:T):T = sub(x,y)
  template `*`*(x,y:T):T = mul(x,y)
  template `/`*(x,y:T):T = divd(x,y)

  binaryMixed(T, `+`, add)
  binaryMixed(T, `-`, sub)
  binaryMixed(T, `*`, mul)
  binaryMixed(T, `/`, divd)

  template `:=`*(r: T; x:T) = assign(r,x)
  template `+=`*(r: T, x:T) = iadd(r,x)
  template `-=`*(r: T, x:T) = isub(r,x)
  template `*=`*(r: T, x:T) = imul(r,x)
  template `/=`*(r: T, x:T) = idiv(r,x)

  unaryMixedVar(T, `:=`, assign)
  template `:=`*(r: T; x:openArray[SomeNumber]) = assign(r,x)
  unaryMixedVar(T, `+=`, iadd)
  unaryMixedVar(T, `-=`, isub)
  unaryMixedVar(T, `*=`, imul)
  #unaryMixedVar(T, `/=`, idiv)
  template `/=`*(r: T; x:SomeNumber) = idiv(r,x.to(T))

  #proc trace*(x:T):T {.inline,noInit.}= x
  template trace*(x: T): T = x
  proc norm2*(x:T):T {.inline,noInit.} = mul(x,x)
  proc norm2*(r:var T; x:T) {.inline.} = mul(r,x,x)
  proc inorm2*(r:var T; x:T) {.inline.} = imadd(r,x,x)
  proc max*(x,y:T):T {.inline,noInit.} = `P "_max_" S`(x,y)
  proc min*(x,y:T):T {.inline,noInit.} = `P "_min_" S`(x,y)
  proc abs*(x:T):T {.inline,noInit.} = max(x,neg(x))
  proc sqrt*(x:T):T {.inline,noInit.} = `P "_sqrt_" S`(x)
  proc rsqrt*(x:T):T {.inline,noInit.} = divd(sqrt(x),x)
  proc rsqrt*(r:var T; x:T) {.inline.} = r = rsqrt(x)
  map1(T,N, sin)
  map1(T,N, cos)
  map1(T,N, acos)
  map2(T,N, atan2)

basicDefs(m128,  float32,  4, mm, ps)
basicDefs(m128d, float64,  2, mm, pd)
basicDefs(m256,  float32,  8, mm256, ps)
basicDefs(m256d, float64,  4, mm256, pd)
basicDefs(m512,  float32, 16, mm512, ps)
basicDefs(m512d, float64,  8, mm512, pd)


proc simdReduce*(r:var SomeNumber; x:m128) {.inline.} =
  let y = mm_hadd_ps(x, x)
  let z = mm_hadd_ps(y, y)
  var t{.noInit.}:float32
  mm_store_ss(t.addr, z)
  r = (type(r))(t)
proc simdReduce*(r:var SomeNumber; x:m128d) {.inline.} =
  let y = mm_hadd_pd(x, x)
  var t{.noInit.}:float64
  mm_store_sd(t.addr, y)
  r = (type(r))(t)
proc simdReduce*(r:var SomeNumber; x:m256) {.inline.} =
  let y = mm256_hadd_ps(x, mm256_permute2f128_ps(x, x, 1))
  let z = mm256_hadd_ps(y, y)
  let w = mm256_hadd_ps(z, z)
  r = (type(r))(w[0])
proc simdReduce*(r:var SomeNumber; x:m256d) {.inline.} =
  let y = mm256_hadd_pd(x, mm256_permute2f128_pd(x, x, 1))
  let z = mm256_hadd_pd(y, y)
  r = (type(r))(z[0])
proc simdReduce*(r:var SomeNumber; x:m512) {.inline.} =
  #r = (type(r))(mm512_reduce_add_ps(x))
  #let t = mm512_shuffle_f32x4(x, x, BASE4(1,0,3,2))
  #let t2 = add(x, t)
  r = x[0]
  for i in 1..<16:
    r += x[i]
proc simdReduce*(r:var SomeNumber; x:m512d) {.inline.} =
  #r = (type(r))(mm512_reduce_add_pd(x))
  r = x[0]
  for i in 1..<8:
    r += x[i]
proc simdReduce*(x:m128):float32 {.inline,noInit.} = simdReduce(result, x)
proc simdReduce*(x:m128d):float32 {.inline,noInit.} = simdReduce(result, x)
proc simdReduce*(x:m256):float32 {.inline,noInit.} = simdReduce(result, x)
proc simdReduce*(x:m256d):float64 {.inline,noInit.} = simdReduce(result, x)
proc simdReduce*(x:m512):float32 {.inline,noInit.} = simdReduce(result, x)
proc simdReduce*(x:m512d):float64 {.inline,noInit.} = simdReduce(result, x)

template simdSum*(x:m128):untyped = simdReduce(x)
template simdSum*(x:m128d):untyped = simdReduce(x)
template simdSum*(x:m256):untyped = simdReduce(x)
template simdSum*(x:m256d):untyped = simdReduce(x)
template simdSum*(x:m512):untyped = simdReduce(x)
template simdSum*(x:m512d):untyped = simdReduce(x)
template simdSum*(r:var SomeNumber; x:m128) = simdReduce(r, x)
template simdSum*(r:var SomeNumber; x:m256) = simdReduce(r, x)
template simdSum*(r:var SomeNumber; x:m256d) = simdReduce(r, x)
template simdSum*(r:var SomeNumber; x:m512) = simdReduce(r, x)
template simdSum*(r:var SomeNumber; x:m512d) = simdReduce(r, x)

proc simdMaxReduce*(r:var SomeNumber; x:m128) {.inline.} =
  r = x[0]
  for i in 1..<4:
    if r < x[i]: r = (type(r))(x[i])
proc simdMaxReduce*(r:var SomeNumber; x:m256) {.inline.} =
  r = x[0]
  for i in 1..<8:
    if r < x[i]: r = (type(r))(x[i])
proc simdMaxReduce*(r:var SomeNumber; x:m256d) {.inline.} =
  r = x[0]
  for i in 1..<4:
    if r < x[i]: r = (type(r))(x[i])
proc simdMaxReduce*(r:var SomeNumber; x:m512) {.inline.} =
  r = x[0]
  for i in 1..<16:
    if r < x[i]: r = (type(r))(x[i])
proc simdMaxReduce*(r:var SomeNumber; x:m512d) {.inline.} =
  r = x[0]
  for i in 1..<8:
    if r < x[i]: r = (type(r))(x[i])
proc simdMaxReduce*(x:m128):float32 {.inline,noInit.} = simdMaxReduce(result, x)
proc simdMaxReduce*(x:m256):float32 {.inline,noInit.} = simdMaxReduce(result, x)
proc simdMaxReduce*(x:m256d):float64 {.inline,noInit.} = simdMaxReduce(result, x)
proc simdMaxReduce*(x:m512):float32 {.inline,noInit.} = simdMaxReduce(result, x)
proc simdMaxReduce*(x:m512d):float64 {.inline,noInit.} = simdMaxReduce(result, x)

template simdMax*(x:m128):untyped = simdMaxReduce(x)
template simdMax*(x:m256):untyped = simdMaxReduce(x)
template simdMax*(x:m256d):untyped = simdMaxReduce(x)
template simdMax*(x:m512):untyped = simdMaxReduce(x)
template simdMax*(x:m512d):untyped = simdMaxReduce(x)
template simdMax*(r:var SomeNumber; x:m128) = simdMaxReduce(r, x)
template simdMax*(r:var SomeNumber; x:m256) = simdMaxReduce(r, x)
template simdMax*(r:var SomeNumber; x:m256d) = simdMaxReduce(r, x)
template simdMax*(r:var SomeNumber; x:m512) = simdMaxReduce(r, x)
template simdMax*(r:var SomeNumber; x:m512d) = simdMaxReduce(r, x)

#template toSingleImpl*(x:m256d):m128 = mm256_cvtpd_ps(x)
#template toDoubleImpl*(x:m128):m256d = mm256_cvtps_pd(x)

# include perm, pack and blend
include simdX86Ops1


#### mixed precision

import simdArray

template tryArray(T,TA,L,B,BB:untyped):untyped =
  when (not declared(T)) and declared(B):
    makeSimdArray(TA, L, BB)
    type T* = Simd[TA]
macro makeArray(P,N:untyped):auto =
  let n = N.intVal
  let t = ident("Simd" & $P & $n)
  let ta = ident("Simd" & $P & $n & "Obj")
  var m = n div 2
  result = newStmtList()
  while m>0:
    let b = ident("Simd" & $P & $m)
    let bb = newNimNode(nnkBracketExpr).add(b)
    let l = n div m
    result.add getAst(tryArray(t,ta,newLit(l),b,bb))
    m = m div 2
  #echo result.treerepr

makeArray(D, 16)
makeArray(D,  8)
makeArray(D,  4)


when defined(SSE):
  when defined(AVX):
    proc toSingleImpl*(x: m256d): m128 {.inline,noInit.} =
      result = mm256_cvtpd_ps(x)
    proc toDoubleImpl*(x: m128): m256d {.inline,noInit.} =
      result = mm256_cvtps_pd(x)
  else:
    proc toSingleImpl*(x: SimdD4Obj): m128 {.inline,noInit.} =
      let t0 = mm128_cvtpd_ps(x[][0])
      let t1 = mm128_cvtpd_ps(x[][1])
      result = mm128_castps64_ps128(t0)
      result = mm128_insertf64_ps(result, t1, 1)
    proc toDoubleImpl*(x: m128): SimdD4Obj {.inline,noInit.} =
      result[][0] = mm128_cvtps_pd(mm128_extractf128_ps(x,0))
      result[][1] = mm128_cvtps_pd(mm128_extractf128_ps(x,1))

when defined(AVX):
  when defined(AVX512):
    proc toSingleImpl*(x: m512d): m256 {.inline,noInit.} =
      result = mm512_cvtpd_ps(x)
    proc toDoubleImpl*(x: m256): m512d {.inline,noInit.} =
      result = mm512_cvtps_pd(x)
  else:
    proc toSingleImpl*(x: SimdD8Obj): m256 {.inline,noInit.} =
      let t0 = mm256_cvtpd_ps(x[][0])
      let t1 = mm256_cvtpd_ps(x[][1])
      result = mm256_castps128_ps256(t0)
      result = mm256_insertf128_ps(result, t1, 1)
    proc toDoubleImpl*(x: m256): SimdD8Obj {.inline,noInit.} =
      result[][0] = mm256_cvtps_pd(mm256_extractf128_ps(x,0))
      result[][1] = mm256_cvtps_pd(mm256_extractf128_ps(x,1))

when defined(AVX512):
  proc toSingleImpl*(x: SimdD16Obj): m512 {.inline,noInit.} =
    let t0 = mm512_cvtpd_ps(x[][0])
    let t1 = mm512_cvtpd_ps(x[][1])
    result = mm512_castps256_ps512(t0)
    result = mm512_insertf32x8(result, t1, 1)
  proc toDoubleImpl*(x:m512):SimdD16Obj {.inline,noInit.} =
    result[][0] = mm512_cvtps_pd(mm512_castps512_ps256(x))
    var y{.noInit.}: m512
    perm8(y, x)
    result[][1] = mm512_cvtps_pd(mm512_castps512_ps256(y))
    #result[][0] = mm512_cvtps_pd(mm512_extractf32x8_ps(x,0))
    #result[][1] = mm512_cvtps_pd(mm512_extractf32x8_ps(x,1))

when defined(SimdS4):
  proc mm_cvtph_ps(x:m128i):m128
    {.importC:"_mm_cvtph_ps",header:"f16cintrin.h".}
  proc mm_cvtps_ph(x:m128,y:cint):m128i
    {.importC:"_mm_cvtps_ph",header:"f16cintrin.h".}
  template toHalf*(x:SimdS4):SimdH4 = SimdH4(mm_cvtps_ph(x))
  template toSingle*(x:SimdH4):SimdS4 = mm_cvtph_ps(x)
when defined(SimdS8):
  proc mm256_cvtph_ps(x:m128i):m256
    {.importC:"_mm256_cvtph_ps",header:"f16cintrin.h".}
  proc mm256_cvtps_ph(x:m256,y:cint):m128i
    {.importC:"_mm256_cvtps_ph",header:"f16cintrin.h".}
  template toHalf*(x:SimdS8):SimdH8 = SimdH8(mm256_cvtps_ph(x,0))
  template toSingle*(x:SimdH8):SimdS8 = mm256_cvtph_ps(m128i(x))
when defined(m512):
  template toHalf*(x:m512):SimdH16 = SimdH16(mm512_cvtps_ph(x,0))
  template toSingle*(x:SimdH16):m512 = mm512_cvtph_ps(m256i(x))


when isMainModule:
  var x,y,z:m256d
  var d:float64
  var a = [1.0,2.0,3.0,4.0]
  assign(x, 1)
  assign(y, 2)
  assign(z, 0)

  echo z
  z = x+y
  echo z
  simdReduce(d, z)
  echo d
  assign(z, a)
  echo z
  simdReduce(d, z)
  echo d
  perm1(y, z)
  echo y
  echo z
  perm2(y, z)
  echo y

  assign(x, 1)
  echo x
  assign(x, 1, 2)
  echo x
  assign(x, 1, 2, 3)
  echo x
  assign(x, 1, 2, 3, 4)
  echo x
  assign(x, 1, 2, 3, 4, 5)
  echo x

  assign(x, a[0], a[1], a[2], a[3])
  echo x

  var s:m256
  assign(s, a[0], a[1], a[2], a[3])
  echo s

  var s8:SimdS8
  assign(s8, [0,1,2,3,4,5,6,7])
  var d8 = toDoubleA(s8)
  echo d8[0]
  echo d8[1]

  #var h:SimdH8
  #s = toSingle(h)
  #h = toHalf(s)
  #assign(s,[1,2,3,4,5,6,7,8])
  #h = toHalf(s)
  #s8 = toSingle(h)
  #echo s8

  when declared(SimdS16):
    var s16:SimdS16
    assign(s16, [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])
    var h16 = toHalf(s16)
    var t16 = toSingle(h16)
    echo t16

  proc testm128 =
    echo "testing perms m128"
    var x0,y0,z0: m128
    assign(x0, 1, 2, 3, 4)
    echo x0
    echo perm(x0, 0)
    perm1(y0, x0)
    echo y0
    echo perm(x0, 1)
    perm2(y0, x0)
    echo y0
    echo perm(x0, 2)
    perm1(z0, y0)
    echo z0
    echo perm(x0, 3)
    echo perm(x0, 4)
  testm128()

  proc testm256d =
    echo "testing perms m256d"
    var x0,y0,z0: m256d
    assign(x0, 1, 2, 3, 4)
    echo x0
    echo perm(x0, 0)
    perm1(y0, x0)
    echo y0
    echo perm(x0, 1)
    perm2(y0, x0)
    echo y0
    echo perm(x0, 2)
    perm1(z0, y0)
    echo z0
    echo perm(x0, 3)
    echo perm(x0, 4)
  testm256d()

  proc testm256 =
    echo "testing perms m256"
    var x0,y0,z0,w0: m256
    assign(x0, 1, 2, 3, 4, 5, 6, 7, 8)
    echo x0
    echo perm(x0, 0)
    perm1(y0, x0)
    echo y0
    echo perm(x0, 1)
    perm2(y0, x0)
    echo y0
    echo perm(x0, 2)
    perm1(z0, y0)
    echo z0
    echo perm(x0, 3)
    perm4(y0, x0)
    echo y0
    echo perm(x0, 4)
    perm1(z0, y0)
    echo z0
    echo perm(x0, 5)
    perm2(z0, y0)
    echo z0
    echo perm(x0, 6)
    perm1(w0, z0)
    echo w0
    echo perm(x0, 7)
    echo perm(x0, 8)
  testm256()

  when defined(AVX512):
    proc testm512 =
      echo "testing perms m512"
      var x0,y0,z0,w0: m512
      assign(x0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
      echo x0
      echo perm(x0, 0)
      perm1(y0, x0)
      echo y0
      echo perm(x0, 1)
      perm2(y0, x0)
      echo y0
      echo perm(x0, 2)
      perm1(z0, y0)
      echo z0
      echo perm(x0, 3)
      perm4(y0, x0)
      echo y0
      echo perm(x0, 4)
      perm1(z0, y0)
      echo z0
      echo perm(x0, 5)
      perm2(z0, y0)
      echo z0
      echo perm(x0, 6)
      perm1(w0, z0)
      echo w0
      echo perm(x0, 7)
      echo perm(x0, 8)
    testm512()

