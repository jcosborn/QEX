import base
import complexNumbers
import matrixConcept
import types
import strformat

proc adjugate*(r: var Mat1, x: Mat2) =
  const nc = r.nrows
  when nc==1:
    r := 1
  elif nc==2:
    r[0,0] :=  x[1,1]
    r[0,1] := -x[0,1]
    r[1,0] := -x[1,0]
    r[1,1] :=  x[0,0]
  elif nc==3:
    let x00 = x[0,0]
    let x01 = x[0,1]
    let x02 = x[0,2]
    let x10 = x[1,0]
    let x11 = x[1,1]
    let x12 = x[1,2]
    let x20 = x[2,0]
    let x21 = x[2,1]
    let x22 = x[2,2]
    r[0,0] := x11*x22 - x12*x21
    r[0,1] := x21*x02 - x22*x01
    r[0,2] := x01*x12 - x02*x11
    r[1,0] := x12*x20 - x10*x22
    r[1,1] := x22*x00 - x20*x02
    r[1,2] := x02*x10 - x00*x12
    r[2,0] := x10*x21 - x11*x20
    r[2,1] := x20*x01 - x21*x00
    r[2,2] := x00*x11 - x01*x10
  else:
    echo &"adjugate n({nc})>3 not supported"
    doAssert(false)

proc inverse*(r: var Mat1, x: Mat2) =
  const nc = r.nrows
  when nc==1:
    r := 1 / x[0,0]
  elif nc==2:
    let x00 = x[0,0]
    let x01 = x[0,1]
    let x10 = x[1,0]
    let x11 = x[1,1]
    let det = x00*x11 - x01*x10
    let idet = 1 / det
    r[0,0] :=  idet * x11
    r[0,1] := -idet * x01
    r[1,0] := -idet * x10
    r[1,1] :=  idet * x00
  elif nc==3:
    let x00 = x[0,0]
    let x01 = x[0,1]
    let x02 = x[0,2]
    let x10 = x[1,0]
    let x11 = x[1,1]
    let x12 = x[1,2]
    let x20 = x[2,0]
    let x21 = x[2,1]
    let x22 = x[2,2]
    let det0 = x00 * x11 - x01 * x10
    let det1 = x02 * x10 - x00 * x12
    let det2 = x01 * x12 - x02 * x11
    let det = det0*x22 + det1*x21 + det2*x20
    let idet = 1 / det
    r[0,0] := idet*(x11*x22-x12*x21)
    r[0,1] := idet*(x21*x02-x22*x01)
    r[0,2] := idet*det2
    r[1,0] := idet*(x12*x20-x10*x22)
    r[1,1] := idet*(x22*x00-x20*x02)
    r[1,2] := idet*det1
    r[2,0] := idet*(x10*x21-x11*x20)
    r[2,1] := idet*(x20*x01-x21*x00)
    r[2,2] := idet*det0
  else:
    echo &"inverse n({nc})>3 not supported"
    doAssert(false)

#[
#define set(i0,j0,i1,j1,i2,j2) \
    QLA_c_eq_c_times_c (det, a##i1##j1, a##i2##j2); \
    QLA_c_meq_c_times_c(det, a##i1##j2, a##i2##j1); \
    QLA_c_eq_c_times_c(QLA_elem_M(*x,i0,j0), det, idet);
    set(0,0,1,1,2,2);
    set(0,1,2,1,0,2);
    QLA_c_eq_c_times_c(QLA_elem_M(*x,0,2), det0, idet);
    set(1,0,1,2,2,0);
    set(1,1,2,2,0,0);
    QLA_c_eq_c_times_c(QLA_elem_M(*x,1,2), det1, idet);
    set(2,0,1,0,2,1);
    set(2,1,2,0,0,1);
    QLA_c_eq_c_times_c(QLA_elem_M(*x,2,2), det2, idet);
#undef set
    return;
  }

  QLAN(ColorMatrix, c);
  QLAN(ColorMatrix, d);
  int row[NC];

  // copy input, set identity output and row pivot
  for(int i=0; i<NC; i++) {
    for(int j=0; j<NC; j++) {
      QLA_c_eq_c(QLA_elem_M(c,i,j), QLA_elem_M(*a,i,j));
      QLA_c_eq_r(QLA_elem_M(d,i,j), 0);
    }
    QLA_c_eq_r(QLA_elem_M(d,i,i), 1);
    row[i] = i;
  }

#define C(i,j) QLA_elem_M(c,row[i],j)
#define D(i,j) QLA_elem_M(d,row[i],j)
  for(int k=0; k<NC; k++) {
    QLA_Complex s;
    QLA_Real rmax = QLA_norm2_c(C(k,k));
    int imax = k;
    for(int i=k+1; i<NC; i++) {
      QLA_Real r = QLA_norm2_c(C(i,k));
      if(r>rmax) { rmax = r; imax = i; }
    }
    { int rk = row[k]; row[k] = row[imax]; row[imax] = rk; }
    rmax = 1/rmax;
    QLA_c_eq_r_times_ca(s, rmax, C(k,k));
    QLA_c_eq_c(C(k,k), s);
    for(int i=0; i<NC; i++) {
      if(i==k) continue;
      QLA_Complex t;
      QLA_c_eq_c_times_c(t, s, C(i,k));
      for(int j=k+1; j<NC; j++) {
        QLA_c_meq_c_times_c(C(i,j), t, C(k,j));
      }
      for(int j=0; j<NC; j++) {
        QLA_c_meq_c_times_c(D(i,j), t, D(k,j));
      }
    }
  }
  for(int i=0; i<NC; i++) {
    for(int j=0; j<NC; j++) {
      QLA_c_eq_c_times_c(QLA_elem_M(*x,i,j), C(i,i), D(i,j));
    }
  }
}
]#

proc sylsolve*(x: var Mat1, a: Mat2, c: Mat3) =
  ## solves A X + X A = C for X
  const nc = x.nrows
  when nc==1:
    x[0,0] := c[0,0] / (2*a[0,0])
  elif nc==2:
    # x = (C + |A| A^-1 C A^-1)/2Tr(A)
    let a00 = a[0,0]
    let a01 = a[0,1]
    let a10 = a[1,0]
    let a11 = a[1,1]
    let c00 = c[0,0]
    let c01 = c[0,1]
    let c10 = c[1,0]
    let c11 = c[1,1]
    let idet = 1/(a00*a11 - a01*a10)
    let itr = 0.5/(a00 + a11)
    # ai = [[a11,-a01][-a10,a00]]
    let aic00 = a11 * c00 - a01 * c10
    let aic01 = a11 * c01 - a01 * c11
    let aic10 = a00 * c10 - a10 * c00
    let aic11 = a00 * c11 - a10 * c01
    x[0,0] := itr * (c00 + idet * (aic00*a11-aic01*a10))
    x[0,1] := itr * (c01 + idet * (aic01*a00-aic00*a01))
    x[1,0] := itr * (c10 + idet * (aic10*a11-aic11*a10))
    x[1,1] := itr * (c11 + idet * (aic11*a00-aic10*a01))
  elif nc==3:
    # x = (C + |A| A^-1 C A^-1)/2Tr(A)
    var ad {.noInit.}: type(a)
    adjugate(ad, a)
    let t = a[0,0] + a[1,1] + a[2,2]
    let s = ad[0,0] + ad[1,1] + ad[2,2]
    let r = a[0,0]*ad[0,0] + a[0,1]*ad[1,0] + a[0,2]*ad[2,0]
    var ac {.noInit.}: type(a)
    var ca {.noInit.}: type(a)
    var aca {.noInit.}: type(a)
    var adc {.noInit.}: type(a)
    var cad {.noInit.}: type(a)
    var adcad {.noInit.}: type(a)
    mul(ac, a, c)
    mul(ca, c, a)
    mul(aca, ac, a)
    mul(adc, ad, c)
    mul(cad, c, ad)
    mul(adcad, adc, ad)
    let c2 = 1/(2*(s*t-r))
    let c0 = c2*(s+t*t)
    let c1 = c2*(t/r)
    let c4 = c2*(t)
    for i in 0..2:
      for j in 0..2:
        x[i,j] := c0*c[i,j] + c1*adcad[i,j] + c2*(aca[i,j]-adc[i,j]-cad[i,j]) -
                  c4*(ac[i,j]+ca[i,j])
  else:
    echo &"sylsolve n({nc})>3 not supported"
    doAssert(false)

#[
{
  //timebase_t tb3 = timer();
  int nc1 = QLA_Nc;
  int nc2 = nc1*nc1;
  //printf("%i  %i\n", nc1, nc2);
  QLA_N_ColorMatrix(nc2, A);
  QLA_N_ColorVector(nc2, (*B)) = (QLA_N_ColorVector(nc2, (*))) c;
  for(int i1=0; i1<nc1; i1++) {
    for(int i2=0; i2<nc1; i2++) {
      int i3 = nc1*i1 + i2;
      for(int k=0; k<nc2; k++) {
        QLA_c_eq_r(QLA_elem_M(A,i3,k), 0);
      }
      for(int k=0; k<nc1; k++) {
        int j3 = nc1*k + i2;  // i1 i2 k i2
        //QLA_c_peq_c(QLA_elem_M(A,i3,j3), QLA_elem_M(*a,i1,k));
        QLA_c_peq_ca(QLA_elem_M(A,i3,j3), QLA_elem_M(*a,k,i1));
        int jt = nc1*i1 + k;  // i1 i2 i1 k
        //QLA_c_peq_c(QLA_elem_M(A,i3,jt), QLA_elem_M(*b,k,i2));
        QLA_c_peq_ca(QLA_elem_M(A,i3,jt), QLA_elem_M(*b,i2,k));
      }
    }
  }
  //timebase_t tb4 = timer();
  //QLA_N_ColorMatrix(nc2, Ai);
#ifdef HAVE_NCN
  QLA_N_ColorVector(nc2, (*X)) = (QLA_N_ColorVector(nc2, (*))) x;
#if QOP_Precision == 'F'
  //QLA_FN_M_eq_inverse_M(nc2, &Ai, &A);
  //QLA_FN_V_eq_M_times_V(nc2, X, &Ai, B);
  QLA_FN_V_eq_M_inverse_V(nc2, X, &A, B);
#else
  //QLA_DN_M_eq_inverse_M(nc2, &Ai, &A);
  //QLA_DN_V_eq_M_times_V(nc2, X, &Ai, B);
  QLA_DN_V_eq_M_inverse_V(nc2, X, &A, B);
#endif
#else
  qerror0(1,"can't use unitary projection without Nc=N libraries\n");
#endif
  //timebase_t tb5 = timer();
  //tb0 += tb5 - tb3;
  //tb1 += tb4 - tb3;
  //tb2 += tb5 - tb4;
}
]#

