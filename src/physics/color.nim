import base/wrapperTypes
import maths/types
import maths
import simd/simdWrap

makeWrapperType(Color):
  ## wrapper type for colored objects

type
  Color2*[T] = Color[T]
  Color3*[T] = Color[T]
  Color4*[T] = Color[T]

template asVarWrapper*(x: Color, y: typed): untyped =
  #static: echo "asVarWrapper Color"
  #var cy = asColor(y)
  #cy
  asVar(asColor(y))

template `[]`*[T](x: Color, i: T): untyped =
  when T is Color:
    x[][i[]]
  elif T.isWrapper:
    #indexed(x, i)
    var tColorBracket = asColor(x[][i])
    tColorBracket
  else:
    x[][i]
template `[]`*(x: Color, i,j: typed): untyped = x[][i,j]

template `[]=`*[T](x: Color, i: T; y: typed) =
  when T is Color:
    x[][i[]] = y
  elif T.isWrapper:
    #indexed(x, i)
    var tColorBracket = asColor(x[][i])
    tColorBracket := y
  else:
    x[][i] = y
#[
template `[]=`*[T](x: Color, i:T, y: typed): untyped =
  when T.isWrapper and T isnot Color:
    x[][asScalar(i)] = y
  else:
    x[][i] = y
template `[]=`*(x: Color, i,j,y: typed): untyped =
  x[][i,j] = y
]#

forwardFunc(Color, len)
forwardFunc(Color, nrows)
forwardFunc(Color, ncols)
forwardFunc(Color, numberType)
forwardFunc(Color, nVectors)
forwardFunc(Color, simdType)
forwardFunc(Color, simdLength)
template numberType*[T](x: typedesc[Color[T]]): untyped = numberType(T)
#template numNumbers*[T](x: typedesc[Color[T]]): untyped = numberType(T)
template numNumbers*(x: Color): untyped = numNumbers(x[])
template toSingle*[T](x: typedesc[Color[T]]): untyped =
  Color[toSingle(type(T))]

template row*(x: Color, i: untyped): untyped =
  mixin row
  asColor(row(x[],i))
template setRow*(r: Color; x: Color2; i: untyped): untyped =
  setRow(r[], x[], i)

template getNc*(x: Color): untyped =
  when x[] is Mat1:
    x[].nrows
  elif x[] is Vec1:
    x[].len
  else:
    static:
      echo "error: unknown Nc"
      echo x.repr
      echo type(x).name
      qexExit 1
    0

template getNs*(x: Color): untyped = getNs(x[])

template binDDRet(fn,wr,T1,T2) =
  template fn*(x: T1, y: T2): untyped =
    wr(fn(x[], y[]))

binDDRet(`+`, asColor, Color, Color2)
binDDRet(`-`, asColor, Color, Color2)
binDDRet(`*`, asColor, Color, Color2)
binDDRet(`/`, asColor, Color, Color2)

template load1*(x: Color): untyped = asColor(load1(x[]))
template `-`*(x: Color): untyped = asColor(-(x[]))
template assign*(r: var Color, x: SomeNumber) =
  assign(r[], x)
template assign*(r: var Color, x: AsComplex) =
  assign(r[], x)
template assign*(r: var Color, x: Color2) =
  assign(r[], x[])
template `:=`*(r: var Color, x: SomeNumber) =
  r[] := x
template `:=`*(r: var Color, x: AsComplex) =
  r[] := x
template `:=`*(r: var Color, x: Color2) =
  r[] := x[]
template `+=`*(r: var Color, x: Color2) =
  r[] += x[]
template `-=`*(r: var Color, x: Color2) =
  r[] -= x[]
template `*=`*(r: var Color, x: SomeNumber) =
  r[] *= x
template iadd*(r: var Color, x: SomeNumber) =
  iadd(r[], x)
template iadd*(r: var Color, x: AsComplex) =
  iadd(r[], x)
template iadd*(r: var Color, x: Color2) =
  iadd(r[], x[])
template isub*(r: var Color, x: Color2) =
  isub(r[], x[])
template imul*(r: var Color, x: SomeNumber) =
  imul(r[], x)
template imadd*(r: var Color, x: Color2, y: Color3) =
  imadd(r[], x[], y[])
template imadd*(r: var Color, x: AsComplex, y: Color3) =
  imadd(r[], x, y[])
template imsub*(r: var Color, x: Color2, y: Color3) =
  imsub(r[], x[], y[])
template `+`*(r: Color, x: SomeNumber): untyped =
  asColor(r[] + x)
template `+`*(r: SomeNumber, x: Color): untyped =
  asColor(r + x[])
template `-`*(r: Color, x: SomeNumber): untyped =
  asColor(r[] - x)
template `+`*(r: Color, x: AsComplex): untyped =
  asColor(r[] + x)
template `-`*(r: Color, x: AsComplex): untyped =
  asColor(r[] - x)
template add*(r: var Color, x: Color2, y: Color3) =
  add(r[], x[], y[])
template sub*(r: var Color, x: Color2, y: Color3) =
  sub(r[], x[], y[])
template `*`*(x: Color, y: SomeNumber): untyped =
  asColor(x[] * y)
template `*`*(x: SomeNumber, y: Color2): untyped =
  asColor(x * y[])
template `*`*(x: Simd, y: Color2): untyped =
  asColor(x * y[])
template `*`*(x: AsReal, y: Color2): untyped =
  asColor(x * y[])
template `*`*(x: AsImag, y: Color2): untyped =
  asColor(x * y[])
template `*`*(x: AsComplex, y: Color2): untyped =
  asColor(x * y[])
template `*`*(x: Color, y: AsComplex): untyped =
  asColor(x[] * y)
template mul*(x: SomeNumber, y: Color2): untyped =
  asColor(`*`(x, y[]))
template mul*(x: Color, y: Color2): untyped =
  asColor(`*`(x[], y[]))
template mul*(r: var Color, x: Color2, y: Color3) =
  mul(r[], x[], y[])
template mul*(r: var Color, x: SomeNumber, y: Color3) =
  mul(r[], x, y[])
template mul*(r: var Color, x: Color2, y: SomeNumber) =
  mul(r[], x[], y)
template mul*(r: var Color, x: AsComplex, y: Color3) =
  mul(r[], x, y[])
template mul*(x: AsComplex, y: Color2): untyped =
  asColor(mul(x, y[]))
template random*(x: var Color) =
  gaussian(x[], r)
template gaussian*(x: Color, r: untyped) =
  gaussian(x[], r)
template uniform*(x: var Color, r: var untyped) =
  uniform(x[], r)
template z4*(x: var Color, r: var untyped) =
  z4(x[], r)
template z2*(x: var Color, r: var untyped) =
  z2(x[], r)
template u1*(x: var Color, r: var untyped) =
  u1(x[], r)
template projectU*(r: var Color, x: Color2) =
  projectU(r[], x[])
template projectUderiv*(r: var Color, u: Color2, x: Color3, chain: Color4) =
  projectUderiv(r[], u[], x[], chain[])
template projectUderiv*(r: var Color, x: Color3, chain: Color4) =
  projectUderiv(r[], x[], chain[])
template projectSU*(r: var Color, x: Color2) =
  projectSU(r[], x[])
template projectTAH*(r: var Color, x: Color2) =
  projectTAH(r[], x[])
template checkU*(x: Color):untyped = checkU(x[])
template checkSU*(x: Color):untyped = checkSU(x[])
template norm2*(x: Color): untyped = norm2(x[])
template norm2*(r: var any, x: Color): untyped = norm2(r, x[])
template inorm2*(r: var any, x: Color2) = inorm2(r, x[])
template dot*(x: Color, y: Color2): untyped =
  dot(x[], y[])
template idot*(r: var any, x: Color2, y: Color3) = idot(r, x[], y[])
template redot*(x: Color, y: Color2): untyped =
  redot(x[], y[])
template trace*(x: Color): untyped = trace(x[])
template simdSum*(x: Color): untyped = asColor(simdSum(x[]))
template re*(x: Color): untyped = asColor(re(x[]))
template im*(x: Color): untyped = asColor(im(x[]))
template exp*(x: Color): untyped = asColor(exp(x[]))
template ln*(x: Color): untyped = asColor(ln(x[]))
