import strutils
import primme
import qex/base, qex/field, qex/comms/qmp

type
  PP = primme_params or primme_svds_params

proc sumReal*[P:PP](sendBuf: pointer; recvBuf: pointer; count: ptr cint;
                    primme: ptr P; ierr: ptr cint) {.noconv.} =
  for i in 0..<count[]:
    asarray[float](recvBuf)[i] = asarray[float](sendBuf)[i]
  QMP_sum_double_array(cast[ptr cdouble](recvBuf), count[])
  ierr[] = 0

# WARNING: low level implementation details follow.
template convPrimmeArray(ff:Field, aa:ptr complex[float], ss:int, body:untyped) {.dirty.} =
  const
    nc = ff[0].len
    vl = ff.V
    cl = 2*vl
  let
    n = nc*f.l.nEven div vl
    skip = nc*ss div vl
  var
    a = asarray[float]aa
    f = asarray[float]ff.s.data
  tfor i, 0..<n:
    let s = i + skip
    forO j, 0, vl.pred:
      body
proc toPrimmeArray*(f:Field, a:ptr complex[float], skip:int = 0) =
  ## `skip` is in units of sites.
  convPrimmeArray(f,a,skip):
    a[cl*i+2*j] = f[cl*s+j]
    a[cl*i+2*j+1] = f[cl*s+j+vl]
proc fromPrimmeArray*(f:Field, a:ptr complex[float], skip:int = 0) =
  ## `skip` is in units of sites.
  convPrimmeArray(f,a,skip):
    f[cl*s+j] = a[cl*i+2*j]
    f[cl*s+j+vl] = a[cl*i+2*j+1]

template ff*(x:untyped):auto = formatFloat(x,ffScientific,17)
