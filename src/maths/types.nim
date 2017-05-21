import base
#import stdUtils
#import comms
#import complexConcept
#import matrixConcept
#import metaUtils
import base/wrapperTypes
import macros

template makeDeclare(s:untyped):untyped {.dirty.} =
  template `declare s`*(t:typedesc):untyped {.dirty.} =
    template `declared s`*(y:t):untyped {.dirty.} = true
  template `is s`*(x:typed):untyped {.dirty.} =
    when compiles(`declared s`(x)):
      `declared s`(x)
    else:
      false
makeDeclare(Scalar)
makeDeclare(Matrix)
makeDeclare(Vector)
makeDeclare(Real)
makeDeclare(Imag)
makeDeclare(Complex)

# converter adjMat*[T](x:Adjointed[AsMatrix[T]]):AsMatrix[Adjointed[T]]

type
  #Adjointed*{.borrow: `.`.}[T] = distinct T
  #Adjointed*[T] = distinct T
  Adjointed*[T] = object
    v*:T

template adj*(xx: typed): untyped =
  mixin adj
  lets(x,xx):
    when isComplex(x):
      asComplex(adj(x[]))
    elif isVector(x):
      asVector(adj(x[]))
    elif isMatrix(x):
      asMatrix(adj(x[]))
    elif x is SomeNumber:
      x
    elif compiles(adjImpl(x)):
      adjImpl(x)
    else:
      when compiles(addr(x)):
      #when compiles(unsafeAddr(x)):
        #cast[ptr Adjointed[type(x)]](addr(x))[]
        cast[ptr Adjointed[type(x)]](unsafeAddr(x))[]
        #cast[Adjointed[type(x)]](x)
      else:
        #(Adjointed[type(x)])(x)
        cast[Adjointed[type(x)]](x)
        #cast[Adjointed[type(x)]]((var t=x; t.addr))

#template `[]`*[T](x:Adjointed[T]):untyped = cast[T](x)
makeDeref(Adjointed, x.T)
template `[]`*(x:Adjointed; i:SomeInteger):untyped = x[][i].adj
template `[]`*(x:Adjointed; i,j:SomeInteger):untyped = x[][j,i].adj
template len*(x:Adjointed):untyped = x[].len
template nrows*(x:Adjointed):untyped = x[].ncols
template ncols*(x:Adjointed):untyped = x[].nrows
template declaredVector*(x:Adjointed):untyped = isVector(x[])
template declaredMatrix*(x:Adjointed):untyped = isMatrix(x[])
template re*(x:Adjointed):untyped = x[].re
template im*(x:Adjointed):untyped = -(x[].im)
template simdType*(x: Adjointed): untyped = simdType(x[])
#template mvLevel*(x:Adjointed):untyped =
#  mixin mvLevel
#  mvLevel(x[])


type
  #ToSingle*{.borrow: `.`.}[T] = distinct T
  #ToSingle*[T] = distinct T
  ToSingle*[T] = object
    v*:T
template toSingleDefault*(xx: typed): untyped =
  lets(x,xx):
    when compiles(addr(x)):
    #when compiles(unsafeAddr(x)):
      #cast[ptr ToSingle[type(x)]](addr(x))[]
      cast[ptr ToSingle[type(x)]](unsafeAddr(x))[]
      #cast[ToSingle[type(x)]](x)
    else:
      #(ToSingle[type(x)])(x)
      cast[ToSingle[type(x)]](x)
      #cast[ToSingle[type(x)]]((var t=x; t.addr))
template toSingle*(xx:typed):untyped =
  mixin isVector, isMatrix
  lets(x,xx):
    when compiles(toSingleImpl(x)):
      toSingleImpl(x)
    elif isComplex(x):
      asComplex(toSingle(x[]))
    elif isVector(x):
      asVector(toSingle(x[]))
    elif isMatrix(x):
      asMatrix(toSingle(x[]))
    elif x is SomeNumber:
      float32(x)
    else:
      toSingleDefault(x)
#template `[]`*[T](x:ToSingle[T]):untyped = cast[T](x)
makeDeref(ToSingle, x.T)
template `[]`*(x:ToSingle; i:SomeInteger):untyped = x[][i].toSingle
template `[]`*(x:ToSingle; i,j:SomeInteger):untyped = x[][j,i].toSingle
template len*(x:ToSingle):untyped = x[].len
template nrows*(x:ToSingle):untyped = x[].ncols
template ncols*(x:ToSingle):untyped = x[].nrows
template declaredVector*(x:ToSingle):untyped = isVector(x[])
template declaredMatrix*(x:ToSingle):untyped = isMatrix(x[])
template re*(x: ToSingle): untyped = toSingle(x[].re)
template im*(x: ToSingle): untyped = toSingle(x[].im)
template simdType*(x: ToSingle): untyped = simdType(x[])

type
  #ToDouble*{.borrow: `.`.}[T] = distinct T
  #ToDouble*[T] = distinct T
  ToDouble*[T] = object
    v*:T
template toDoubleDefault*(xx: typed): untyped =
  lets(x,xx):
    when compiles(addr(x)):
    #when compiles(unsafeAddr(x)):
      #cast[ptr ToDouble[type(x)]](addr(x))[]
      cast[ptr ToDouble[type(x)]](unsafeAddr(x))[]
      #cast[ToDouble[type(x)]](x)
    else:
      #(ToDouble[type(x)])(x)
      cast[ToDouble[type(x)]](x)
      #cast[ToDouble[type(x)]]((var t=x; t.addr))
template toDouble*(xx: typed): untyped =
  mixin isVector, isMatrix, isComplex, toDoubleImpl
  lets(x,xx):
    when compiles(toDoubleImpl(x)):
      toDoubleImpl(x)
    elif isComplex(x):
      asComplex(toDoubleDefault(x[]))
    elif isVector(x):
      asVector(toDouble(x[]))
    elif isMatrix(x):
      asMatrix(toDouble(x[]))
    elif x is SomeNumber:
      float64(x)
    else:
      toDoubleDefault(x)
#template `[]`*[T](x:ToDouble[T]):untyped = cast[T](x)
makeDeref(ToDouble, x.T)
template `[]`*(x:ToDouble; i:SomeInteger):untyped = x[][i].toDouble
template `[]`*(x:ToDouble; i,j:SomeInteger):untyped = x[][j,i].toDouble
template len*(x:ToDouble):untyped = x[].len
template nrows*(x:ToDouble):untyped = x[].nrows
template ncols*(x:ToDouble):untyped = x[].ncols
template declaredVector*(x:ToDouble):untyped = isVector(x[])
template declaredMatrix*(x:ToDouble):untyped = isMatrix(x[])
template re*(x:ToDouble):untyped = toDouble(x[].re)
template im*(x:ToDouble):untyped = toDouble(x[].im)
template simdType*(x: ToDouble): untyped = simdType(x[])
macro dump2(x: typed): auto =
  result = newEmptyNode()
  echo x.treerepr
template numberType*(x: ToDouble): untyped =
  dump2: x
  numberType(x[])



type
  MaskedObj*[T] = object
    pobj*:ptr T
    mask*:int
  Masked*[T] = distinct MaskedObj[T]
template pobj*(x:Masked):untyped = ((MaskedObj[x.T])(x)).pobj
template mask*(x:Masked):untyped = ((MaskedObj[x.T])(x)).mask
template `pobj=`*(x:Masked;y:untyped):untyped = ((MaskedObj[x.T])(x)).pobj = y
template `mask=`*(x:Masked;y:untyped):untyped = ((MaskedObj[x.T])(x)).mask = y
template maskedObj*(x:typed; msk:int):untyped =
  (MaskedObj[type(x)])(pobj:x.addr,mask:msk)
template masked*(): untyped = discard
template masked*(x:typed; msk:int):untyped =
  mixin masked,isComplex,isVector,isMatrix
  when isComplex(x):
    #ctrace()
    #asComplex((Masked[type(x)])(maskedObj(x,msk)))
    asVarComplex(masked(x[],msk))
  elif isVector(x):
    #ctrace()
    #asVarMatrix((Masked[type(x)])(maskedObj(x,msk)))
    asVarVector(masked(x[],msk))
  elif isMatrix(x):
    #ctrace()
    #asVarMatrix((Masked[type(x)])(maskedObj(x,msk)))
    asVarMatrix(masked(x[],msk))
  elif x is SomeNumber:
    #ctrace()
    #asVarMatrix((Masked[type(x)])(maskedObj(x,msk)))
    x
  else:
    #ctrace()
    (Masked[type(x)])(maskedObj(x,msk))
#template isRIC*(x:int):untyped = true
#template isRIC*(m:Masked):untyped = isRIC(m.pobj[])
#template isComplex*(m:Masked):untyped = isComplex(m.pobj[])
template declaredComplex*(m:Masked):untyped =
  mixin declaredComplex
  declaredComplex(m.pobj[])
template isVector*(m:Masked):untyped =
  mixin isVector
  isVector(m.pobj[])
#template isMatrix*(m:Masked):untyped =
#  mixin isMatrix
  #echo "isMatrix"
  #echo isMatrix(m.pobj[])
#  isMatrix(m.pobj[])
template mvLevel*(m:Masked):untyped =
  mixin mvLevel
  mvLevel(m.pobj[])
template numNumbers*(m:Masked):untyped = numNumbers(m[])
template len*(m:Masked):untyped =
  mixin len
  len(m.pobj[])
template nrows*(m:Masked):untyped =
  mixin nrows
  nrows(m.pobj[])
template ncols*(m:Masked):untyped =
  mixin ncols
  ncols(m.pobj[])
template re*(m:Masked):untyped =
  mixin re
  masked(m.pobj[].re, m.mask)
template im*(m:Masked):untyped =
  mixin im
  masked(m.pobj[].im, m.mask)
template `re=`*(m:Masked; x:any):untyped =
  mixin re
  assign(masked(m.pobj[].re, m.mask), x)
template `im=`*(m:Masked; x:any):untyped =
  mixin im
  assign(masked(m.pobj[].im, m.mask), x)
#template `[]`*(x:Masked; i:int):untyped = Masked(x:x.pobj[i],mask:x.mask)
#template `[]`*(m:Masked; i,j:int):untyped =
#  Masked(x:unsafeAddr(m.pobj[][i,j]), mask:m.mask)
proc `[]`*[T](m:Masked[T]):var T {.inline.} = m.pobj[]
template `[]`*(m:Masked; i:int):untyped = masked(m[][i],m.mask)
#proc `[]`*[T](m:Masked[T]; i:int):auto =
#  var r:Masked[type(m.pobj[][i])]
#  #Masked(pobj:unsafeAddr(m.pobj[][i,j]), mask:m.mask)
#  r.pobj = addr(m.pobj[][i])
#  r.mask = m.mask
#  r
#proc `[]`*(m:Masked; i,j:int):var Masked[type(m.pobj[][i,j])] =
template `[]`*(m:Masked; i,j:int):untyped = masked(m[][i,j],m.mask)
  #var t = m[].addr
  #var tij = t[][i,j].addr
  #let tm = masked(tij[],m.mask)
  #ctrace()
  #tm
  #var r:Masked[type(tij)]
  #var r:Masked[type(m[][i,j])]
#  #Masked(pobj:unsafeAddr(m.pobj[][i,j]), mask:m.mask)
  #r.pobj = m.pobj[][i,j].addr
  #r.mask = m.mask
  #0
#template `[]`*(m:Masked; i,j:int):untyped =
#  Masked[type((pobj:m[][i,j].addr,mask:m.mask)
#template `[]=`*(m:Masked; i,j:int; y:untyped):untyped =
#  set(Masked(pobj:m.pobj[i,j].addr,mask:x.mask), y)
#proc `:=`*(x:Masked; y:int) =
#  mixin assign
#  var t = x
#  assign(t, y)
#proc `*=`*(x:Masked; y:int) =
  #echo "*="
#  mixin mul
  #echoAll isMatrix(t)
  #echoAll isMatrix(x.pobj[])
  #echoAll isScalar(y)
#  mul(x, x[], y)
  #echo "*="
#proc `$`*(x:Masked):string =
#  result = $(x[])

#template eval*(x: AsComplex): untyped = asComplex(eval(x[]))
template eval*(x: ToDouble): untyped =
  mixin map
  map(map(x[],toDouble),eval)
template eval*(x: SomeNumber): untyped = x
#template eval*(x: typed): untyped =
#  mixin isComplex
#  when isComplex(x):
#    asComplex(eval(x[]))
#  elif x is SomeNumber:
#    x
#  else:
#    map(map(x[],toDouble),eval)