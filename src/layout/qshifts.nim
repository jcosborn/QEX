import qgather
import layoutTypes, shiftX
import comms/qmp
import strutils

const
  PAIR = true
  MAXTHREADS = 512

template aalloc(n: SomeInteger): untyped =
  let a = 64
  let x = cast[ByteAddress](alloc(n+a))
  let a1 = a - 1
  let y = x + (a1-((x+a1) mod a))
  cast[pointer](y)

proc prepareShiftBufsQ*(sb: openArray[ptr ShiftBufQ];
                        si: openArray[ptr ShiftIndicesQ];
                        n: cint; esize: cint) =
  var
    sbs: cint = 0
    rbs: cint = 0
  var i: cint = 0
  while i < n:
    inc(sbs, esize * si[i].nSendSites1)
    inc(rbs, esize * si[i].nRecvSites1)
    inc(i)
  i=0
  while i < n:
    sb[i].sbufSize = sbs
    sb[i].rbufSize = rbs
    sb[i].smsg = nil
    sb[i].rmsg = nil
    sb[i].first = 0
    sb[i].offr = cast[type(sb[i].offr)](alloc(MAXTHREADS * sizeof(cint)))
    sb[i].lenr = cast[type(sb[i].lenr)](alloc(MAXTHREADS * sizeof(cint)))
    sb[i].nthreads = cast[type(sb[i].nthreads)](alloc(MAXTHREADS*sizeof(cint)))
    var j: cint = 0
    while j < MAXTHREADS:
      sb[i].nthreads[j] = 0
      inc(j)
    inc(i)
  sb[0].first = 1
  if sbs > 0:
    var sbuf: pointer = aalloc(sbs)
    #printf("sbuf: %p\n", sbuf);
    var i: cint = 0
    while i < n:
      sb[i].sbuf = cast[type(sb[i].sbuf)](sbuf)
      if si[i].nSendRanks > 0:
        sb[i].sqmpmem = QMP_declare_msgmem(sbuf, sbs)
        sb[i].smsg = QMP_declare_send_to(sb[i].sqmpmem, si[i].sendRanks[0], 0)
        #printf("send: to: %i\tsize: %i\t%p\t%p\n",si[i]->sendRanks[0],sbs,sbuf,sb[i]->smsg);
        #fflush(stdout);
      inc(i)
  if rbs > 0:
    var rbuf: pointer = aalloc(rbs)
    var i: cint = 0
    while i < n:
      sb[i].rbuf = cast[type(sb[i].rbuf)](rbuf)
      if si[i].nRecvRanks > 0:
        sb[i].rqmpmem = QMP_declare_msgmem(rbuf, rbs)
        sb[i].rmsg = QMP_declare_receive_from(sb[i].rqmpmem,
                                              si[i].recvRanks[0], 0)
        #printf("recv: fr: %i\tsize: %i\t%p\t%p\n",si[i]->recvRanks[0],rbs,rbuf,sb[i]->rmsg);
        #fflush(stdout);
      inc(i)
  when PAIR:
    var p = newSeq[QMP_msghandle_t](2*n)
    var nn: cint = 0
    i=0
    while i < n:
      if not isNil sb[i].rmsg:
        p[nn] = sb[i].rmsg
        inc(nn)
      if not isNil sb[i].smsg:
        p[nn] = sb[i].smsg
        inc(nn)
      inc(i)
    var pairmsg: QMP_msghandle_t = nil
    if nn > 0:
      pairmsg = QMP_declare_send_recv_pairs(p[0].addr, nn)
    i=0
    while i < n:
      sb[i].pairmsg = pairmsg
      #printf("pair[%i]: %p\t%p\t%p\n",i,sb[i]->rmsg,sb[i]->smsg,sb[i]->pairmsg);
      inc(i)
    #fflush(stdout);

proc prepareShiftBufQ*(sb: ptr ShiftBufQ; si: ptr ShiftIndicesQ; esize: cint) =
  prepareShiftBufsQ([sb], [si], 1, esize)

proc startSendBufQ*(sb: ptr ShiftBufQ) =
  #printf("send: %g\n",*(float *)(sb->sbuf));
  when PAIR:
    if not isNil sb.pairmsg:
      discard QMP_start(sb.pairmsg)
  else:
    if not isNil sb.smsg:
      discard QMP_start(sb.smsg)

proc startRecvBufQ*(sb: ptr ShiftBufQ) =
  when not PAIR:
    if not isNil sb.rmsg:
      discard QMP_start(sb.rmsg)

proc waitSendBufQ*(sb: ptr ShiftBufQ) =
  when not PAIR:
    if not isNil sb.smsg:
      discard QMP_wait(sb.smsg)

proc waitRecvBufQ*(sb: ptr ShiftBufQ) =
  when PAIR:
    if not isNil sb.pairmsg:
      discard QMP_wait(sb.pairmsg)
  else:
    if not isNil sb.rmsg: QMP_wait(sb.rmsg)
  #printf("recv: %g\n",*(float *)(sb->rbuf));

proc doneRecvBufQ*(sb: ptr ShiftBufQ) =
  when PAIR:
    if not isNil sb.pairmsg:
      discard QMP_clear_to_send(sb.pairmsg, QMP_CTS_READY)

proc freeShiftBufsQ*(sb: openArray[ptr ShiftBufQ]) =
  let n = sb.len
  var i: cint = 0
  while i < n:
    dealloc(sb[i].offr)
    dealloc(sb[i].lenr)
    dealloc(sb[i].nthreads)
    inc(i)
  when PAIR:
    i=0
    while i < n:
      if sb[i].first!=0 and not isNil sb[i].pairmsg:
        QMP_free_msghandle(sb[i].pairmsg)
      sb[i].pairmsg = nil
      if not isNil sb[i].smsg:
        sb[i].smsg = nil
        QMP_free_msgmem(sb[i].sqmpmem)
        sb[i].sqmpmem = nil
      if not isNil sb[i].rmsg:
        sb[i].rmsg = nil
        QMP_free_msgmem(sb[i].rqmpmem)
        sb[i].rqmpmem = nil
      inc(i)
  else:
    var i: cint = 0
    while i < n: 
      if sb[i].smsg: 
        QMP_free_msghandle(sb[i].smsg)
        sb[i].smsg = nil
        QMP_free_msgmem(sb[i].sqmpmem)
        sb[i].sqmpmem = nil
      if sb[i].rmsg: 
        QMP_free_msghandle(sb[i].rmsg)
        sb[i].rmsg = nil
        QMP_free_msgmem(sb[i].rqmpmem)
        sb[i].rqmpmem = nil
      inc(i)
  i=0
  while i < n:
    if sb[i].first!=0 and sb[i].sbufSize > 0: dealloc(sb[i].sbuf)
    if sb[i].first!=0 and sb[i].rbufSize > 0: dealloc(sb[i].rbuf)
    inc(i)

proc freeShiftBufQ*(sb: ptr ShiftBufQ) =
  freeShiftBufsQ([sb])

import qlayout, base

#[
proc makeGDFromShiftSubs*(gd: ptr GatherDescription; l: ptr LayoutQ;
                          disps: ptr cArray[ptr cArray[cint]];
                          subs: ptr cArray[cstring]; ndisps: cint) {.
                            importc.}
]#

# #[

type
  mapargs* = object
    l*: ptr LayoutQ
    disp*: ptr cArray[cint]
    parity*: cint

proc map*(sr: ptr cint; si: ptr cint; dr: cint; di: ptr cint; args: pointer) =
  var ma: ptr mapargs = cast[ptr mapargs](args)
  var l: ptr LayoutQ = ma.l
  var nd: cint = l.nDim
  if di[] >= 0:
    var x = newSeq[cint](nd)
    var
      dli: LayoutIndexQ
      sli: LayoutIndexQ
    dli.rank = dr
    dli.index = di[]
    layoutCoordQ(l, cast[ptr cArray[cint]](x[0].addr), addr(dli))
    var y = newSeq[cint](nd)
    var p: cint = 0
    var k: cint = 0
    while k < nd:
      inc(p, x[k])
      y[k] = (x[k] - ma.disp[k] + l.physGeom[k]) mod l.physGeom[k]
      inc(k)
    if ma.parity >= 0 and (p and 1) != ma.parity:
      sr[] = -1
      si[] = -1
    else:
      layoutIndexQ(l, addr(sli), cast[ptr cArray[cint]](y[0].addr))
      sr[] = sli.rank
      si[] = sli.index
  else:
    # search for site after or including di0 from rank sr to dr
    var di0: cint = - (di[] + 1)
    while di0 < l.nSites:
      var sr0: cint
      map(addr(sr0), si, dr, addr(di0), args)
      if sr0 == sr[]:
        di[] = di0
        return
      inc(di0)
    si[] = -1

# nRecvRanks (remote ranks)
# start recvs
# nSendRanks
# start sends
# local + perm
# recv buf
# nSendRanks
# - sendRanks
# - nSendPacks
# - - sendPacks
# - - nSendSites
# - - - sendSites

template SUB2PAR*(s: typed): untyped =
  (if (s)[0] == 'e': 0 else: (if (s)[0] == 'o': 1 else: -1))

proc makeGDFromShiftSubs*(gd: ptr GatherDescription; l: ptr LayoutQ;
                          disps: openArray[ptr cArray[cint]];
                          subs: openArray[cstring]; ndisps: cint) =
  var myRank: cint = l.myrank
  var myndi: cint = l.nSites
  var nndi: cint = ndisps * myndi
  var args: mapargs
  args.l = l
  var sidx: ptr cArray[cint] = cast[ptr cArray[cint]](alloc(nndi * sizeof(cint)))
  var srank: ptr cArray[cint] = cast[ptr cArray[cint]](alloc(nndi * sizeof(cint)))
  # find shift sources
  var nRecvDests: cint = 0
  var n: cint = 0
  while n < ndisps:
    var n0: cint = n * myndi
    args.disp = disps[n]
    args.parity = SUB2PAR(subs[n])
    ##pragma omp parallel for reduction(+:nRecvDests)
    var di: cint = 0
    while di < myndi:
      var
        sr: cint
        si: cint
        di0: cint = di
      map(addr(sr), addr(si), myRank, addr(di0), addr(args))
      srank[n0 + di] = sr
      sidx[n0 + di] = si
      if sr != myRank: inc(nRecvDests)
      inc(di)
    inc(n)
  gd.myRank = myRank
  gd.nIndices = nndi
  gd.srcRanks = srank
  gd.srcIndices = sidx
  gd.nRecvDests = nRecvDests
  # use inverse map
  var nd: cint = l.nDim
  var dispi = newSeq[cint](nd)
  args.disp = cast[ptr cArray[cint]](addr dispi[0])
  var sendSrcIndices = newSeq[cint]()
  var sendDestRanks = newSeq[cint]()
  var sendDestIndices = newSeq[cint]()
  var tlen: array[MAXTHREADS, cint]
  # find who to send to
  n=0
  while n < ndisps:
    var n0: cint = n * myndi
    var sp: cint = 0
    var i: cint = 0
    while i < nd:
      inc(sp, abs(disps[n][i]))
      dispi[i] = - disps[n][i]
      inc(i)
    args.parity = SUB2PAR(subs[n])
    if (sp and 1) == 1 and args.parity >= 0:
      args.parity = 1 - args.parity
    #int tid = THREADNUM;
    #int nid = NUMTHREADS;
    var tid: cint = 0
    var nid: cint = 1
    var sendSrcIndicesT = newSeq[cint]()
    var sendDestRanksT = newSeq[cint]()
    var sendDestIndicesT = newSeq[cint]()
    ##pragma omp for
    var di: cint = 0
    while di < myndi:
      var
        dr: cint = myRank
        sr: cint
        si: cint
      map(addr(sr), addr(si), dr, addr(di), addr(args))
      if sr >= 0 and si >= 0 and sr != myRank:
        if tid == 0:
          sendSrcIndices.add di
          sendDestRanks.add sr
          sendDestIndices.add n0+si
        else:
          sendSrcIndicesT.add di
          sendDestRanksT.add sr
          sendDestIndicesT.add n0+si
      inc(di)
    tlen[tid] = sendSrcIndicesT.len.cint
    #TBARRIER;
    var i0: cint = cint sendSrcIndices.len
    i=0
    while i < tid:
      inc(i0, tlen[i])
      inc(i)
    if tid == nid-1:
      var ln = i0 + sendSrcIndicesT.len
      sendSrcIndices.setLen ln
      sendDestRanks.setLen ln
      sendDestIndices.setLen ln
    #TBARRIER;
    i=0
    while i < sendSrcIndicesT.len:
      sendSrcIndices[i0 + i] = sendSrcIndicesT[i]
      sendDestRanks[i0 + i] = sendDestRanksT[i]
      sendDestIndices[i0 + i] = sendDestIndicesT[i]
      inc(i)
    # end parallel
    inc(n)
  gd.nSendIndices = cint sendSrcIndices.len
  template ARRAY_CLONE(x,y: typed) =
    x = cast[type(x)](alloc(y.len*sizeof(type(x[0]))))
    for i in 0..<y.len: x[i] = y[i]
  ARRAY_CLONE(gd.sendSrcIndices, sendSrcIndices)
  ARRAY_CLONE(gd.sendDestRanks, sendDestRanks)
  ARRAY_CLONE(gd.sendDestIndices, sendDestIndices)

proc makeGDFromShifts*(gd: ptr GatherDescription; l: ptr LayoutQ;
                       disps: openArray[ptr cArray[cint]]; ndisps: cint) =
  var subs = newSeq[cstring](ndisps)
  var i: cint = 0
  let s = "all"
  while i < ndisps:
    subs[i] = s
    inc(i)
  makeGDFromShiftSubs(gd, l, disps, subs, ndisps)

# ]#

proc makeShiftMultiSubQ*(si: openArray[ptr ShiftIndicesQ];
                         l: ptr LayoutQ; disp: openArray[ptr cArray[cint]];
                         subs: openArray[cstring]; ndisp: cint) =
  var myRank: cint = l.myrank
  var nd: cint = l.nDim
  var vvol: cint = l.nSitesOuter
  var gi = cast[ptr GatherIndices](alloc(sizeof((GatherIndices))))
  var n: cint = 0
  while n < ndisp:
    si[n].gi = gi
    si[n].disp = cast[type(si[n].disp)](alloc(nd*sizeof((cint))))
    var i: cint = 0
    while i < nd:
      si[n].disp[i] = disp[n][i]
      inc(i)
    si[n].pidx = cast[ptr cArray[cint]](alloc(vvol*sizeof((cint))))
    si[n].sidx = cast[ptr cArray[cint]](alloc(vvol*sizeof((cint))))
    si[n].sendSites = cast[ptr cArray[cint]](alloc(vvol*sizeof((cint))))
    i=0
    while i < vvol:
      si[n].pidx[i] = -1
      si[n].sidx[i] = -1
      inc(i)
    inc(n)
  #mapmargs args;
  #args.l = l;
  #args.disp = disp;
  #args.ndisp = ndisp;
  #makeGather(gi, mapm, &args,l->nranks,l->nranks,l->nSites*ndisp,l->myrank);
  var gd = cast[ptr GatherDescription](alloc(sizeof((GatherDescription))))
  makeGDFromShiftSubs(gd, l, disp, subs, ndisp)
  #makeGDFromShiftSubs(gd, l,
  #                    cast[ptr carray[ptr carray[cint]]](disp[0].unsafeaddr),
  #                    cast[ptr carray[cstring]](subs[0].unsafeaddr), ndisp)
  makeGatherFromGD(gi, gd)
  #int si0 = 0;
  var si0: cint = ndisp-1
  var
    vvs: cint = 0
    perm: cint = 0
    pack: cint = 0
  #TRACE_ALL;
  if gi.nSendIndices > 0:
    #if(myrank==1){printf("nss: %i\n", gi->nSendIndices);fflush(stdout);}
    pack = gi.sendIndices[0] mod l.nSitesInner
    if pack == 0:
      var i: cint = 1
      while (i < gi.nSendIndices) and (i < l.nSitesInner) and
          (gi.sendIndices[i] == gi.sendIndices[0] + i):
        inc(i)
      pack = - (i mod l.nSitesInner)
    var ssi0: cint = -1
    var i: cint = 0
    while i < gi.nSendIndices:
      var ss: cint = gi.sendIndices[i]
      var ssi: cint = ss div l.nSitesInner
      if ssi != ssi0:
        si[si0].sendSites[vvs] = ssi
        inc(vvs)
        ssi0 = ssi
        if vvs > vvol:
          echo "vvs(",vvs,")>vvol(",vvol,")"
          if myRank == 0:
            var i: cint = 0
            while i < gi.nSendIndices:
              echo i, "\t", gi.sendIndices[i]
              inc(i)
          #fflush(stdout)
          QMP_barrier()
          quit(1)
      inc(i)
  var i: cint = 0
  while i < ndisp:
    si[i].nSendRanks = 0
    si[i].nSendSites1 = 0
    inc(i)
  si[si0].nSendRanks = gi.nSendRanks
  si[si0].nSendSites = vvs
  si[si0].nSendSites1 = gi.nSendIndices
  if gi.nSendRanks > 0:
    si[si0].sendRanks = gi.sendRanks
    si[si0].sendRankSizes = cast[ptr cArray[cint]](alloc(si[si0].nSendRanks*sizeof(cint)))
    si[si0].sendRankSizes1 = gi.sendRankSizes
    si[si0].sendRankOffsets = cast[ptr cArray[cint]](alloc(si[si0].nSendRanks*sizeof(cint)))
    si[si0].sendRankOffsets1 = gi.sendRankOffsets
    si[si0].sendRankSizes[0] = vvs
    si[si0].sendRankOffsets[0] = 0
  var
    nrsites: cint = 0
    nrdests = newSeq[cint](ndisp)
  i=0
  while i < ndisp:
    nrdests[i] = 0
    inc(i)
  i=0
  while i < vvol * ndisp:
    #if(myrank==1){printf("%i\n", i);fflush(stdout);}
    var dd: cint = i div l.nSitesOuter
    var ix: cint = i mod l.nSitesOuter
    var k0: cint = i * l.nSitesInner
    var recv: cint = 0
    var rbi: cint = 0
    var ii: cint = 0
    while ii < l.nSitesInner:
      var k: cint = k0 + ii
      var s: cint = gi.srcIndices[k]
      if s == -1:
        recv = -1
        break
      if s < 0:
        inc(recv)
        if rbi == 0: rbi = s
      inc(ii)
    if recv < 0:
      si[dd].pidx[ix] = -1
      si[dd].sidx[ix] = -1
    elif recv == 0:
      si[dd].pidx[ix] = gi.srcIndices[k0] div l.nSitesInner
      si[dd].sidx[ix] = gi.srcIndices[k0] div l.nSitesInner
      var p: cint = gi.srcIndices[k0] mod l.nSitesInner
      if p != 0:
        perm = p
        #si->sidx[i] = -vvs-1;
        si[dd].pidx[ix] = - (si[dd].pidx[ix]) - 2
        #vvs++;
    else:
      rbi = - (rbi + 2)
      rbi = (2 * rbi) div l.nSitesInner
      if pack == 0: rbi = rbi div 2
      si[dd].sidx[ix] = - rbi - 2
      #nrsites++;
      inc(nrdests[dd])
    inc(i)
  #TRACE_ALL;
  nrsites = gi.recvSize div l.nSitesInner
  if pack != 0: nrsites = nrsites * 2
  i=0
  while i < ndisp:
    si[i].nRecvRanks = 0
    si[i].nRecvSites1 = 0
    inc(i)
  si[0].nRecvRanks = gi.nRecvRanks
  si[0].nRecvSites = nrsites
  si[0].nRecvSites1 = gi.recvSize
  if gi.nRecvRanks > 0:
    si[0].recvRanks = gi.recvRanks
    si[0].recvRankSizes = cast[ptr cArray[cint]](alloc(si[0].nRecvRanks*sizeof(cint)))
    si[0].recvRankSizes1 = gi.recvRankSizes
    si[0].recvRankOffsets = cast[ptr cArray[cint]](alloc(si[0].nRecvRanks * sizeof(cint)))
    si[0].recvRankOffsets1 = gi.recvRankOffsets
    si[0].recvRankSizes[0] = nrsites
    si[0].recvRankOffsets[0] = 0
  n=0
  while n < ndisp:
    si[n].nRecvDests = nrdests[n]
    if nrdests[n] > 0:
      si[n].recvDests = cast[ptr cArray[cint]](alloc(nrdests[n]*sizeof(cint)))
      si[n].recvLocalSrcs = cast[ptr cArray[cint]](alloc(nrdests[n]*sizeof(cint)))
      si[n].recvRemoteSrcs = cast[ptr cArray[cint]](alloc(nrdests[n]*sizeof(cint)))
      var j: cint = 0
      var i: cint = 0
      while i < vvol:
        if si[n].sidx[i] < -1:
          var k: cint = - (si[n].sidx[i] + 2)
          si[n].recvDests[j] = i
          si[n].recvRemoteSrcs[j] = k
          si[n].recvLocalSrcs[j] = 0
          var i0: cint = 0
          while i0 < l.nSitesInner:
            var ii: cint = n * l.nSites + i * l.nSitesInner + i0
            var gs: cint = gi.srcIndices[ii]
            if gs >= 0:
              si[n].recvLocalSrcs[j] = gs div l.nSitesInner
              break
            inc(i0)
          inc(j)
          if j > nrdests[n]:
            echo "j($#)>nrdests[$#]($#)"%[$j,$n,$nrdests[n]]
            #fflush(stdout)
        inc(i)
    si[n].vv = vvol
    si[n].perm = perm
    si[n].pack = pack
    si[n].blend = pack
    #si[n]->offr = 0;
    #si[n]->lenr = 0;
    #si[n]->nthreads = 0;
    #si[n]->sqmpmem = NULL;
    #si[n]->rqmpmem = NULL;
    #si[n]->pairmsg = NULL;
    #printf("%i nsend: %i  nrecv: %i\n", myrank, si[n]->nSendSites, si[n]->nRecvSites);
    inc(n)
  #printf("disp:");
  #for(int i=0; i<nd; i++) printf(" %i", disp[i]);
  #printf("\n");
  #printf("  perm: %i\n", perm);

proc makeShiftMultiQ*(si: openArray[ptr ShiftIndicesQ]; l: ptr LayoutQ;
                      disp: openArray[ptr cArray[cint]]; ndisp: cint) =
  var subs = newSeq[cstring](ndisp)
  var i: cint = 0
  while i < ndisp:
    subs[i] = "all"
    inc(i)
  makeShiftMultiSubQ(si, l, disp, subs, ndisp)

proc makeShiftQ*(si: ptr ShiftIndicesQ; l: ptr LayoutQ;
                 disp: ptr cArray[cint]) =
  makeShiftMultiQ([si], l, [disp], 1)

proc makeShiftSubQ*(si: ptr ShiftIndicesQ; l: ptr LayoutQ;
                    disp: ptr cArray[cint]; sub: cstring) =
  makeShiftMultiSubQ([si], l, [disp], [sub], 1)

