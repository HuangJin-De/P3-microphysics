PROGRAM make_p3_lookuptable2

!______________________________________________________________________________________
!
! This program creates the lookup tables for two-category interactions used by
! the P3 microphysics scheme.
!
!  Note:  compile with double-precision (pgf90 -r8 make_p3_lookuptable2.f90)
!
! P3 package version: v3.1.1
! Last modified     : 2018-10-18
!______________________________________________________________________________________

 implicit none

 real   :: pi,g,p,t,rho,mu,pgam,ds,cs,bas,aas,dcrit,eii
 integer :: i,k,ii,iii,jj,kk,jjj,kkk,jjjj,dumii

 integer, parameter :: rimsize   =  4
 integer, parameter :: isize     = 25
 integer, parameter :: jsize     = 1
 integer, parameter :: densize   =  5

 integer i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2

 real :: N,q,qdum,dum1,dum2,cs1,ds1,lam,n0,lamf,qerror,del0,c0,c1,c2,dd,sum1,sum2,       &
         sum3,sum4,xx,a0,b0,a1,b1,dum,bas1,aas1,aas2,bas2,gammq,gamma,d1,d2,delu,lamold, &
         cap,lamr,dia,amg,dv,n0dum,sum5,sum6,sum7,sum8,dg,cg,bag,aag,dcritg,dcrits,      &
         dcritr,rr,csr,dsr,duml,dum3,dum4,rhodep,cgpold,m1,m2,m3,dt,mur,initlamr,lamv,   &
         rdumii,lammin,lammax,cs2,ds2

 real, dimension(1000)      :: num1,num2
 real, dimension(densize)   :: cgp,crp

 real, parameter            :: thrd = 1./3.
 real, parameter            :: sxth = 1./6.

! add new variables for category interaction

 real, dimension(isize,jsize,rimsize,densize) :: qsave,nsave
 real, dimension(isize,rimsize,densize) :: qon1
 real, dimension(isize,rimsize,densize,isize,jsize,rimsize,densize) :: qagg,nagg

 real, dimension(densize,rimsize) :: dcrits1,dcritr1,csr1,dsr1
 real, dimension(densize,rimsize,isize) :: n01,pgam1,lam1
 real, dimension(densize) :: cgp1
 real, dimension(1000) :: fall1
 real, dimension(densize,rimsize) :: dcrits2,dcritr2,csr2,dsr2
 real, dimension(densize,rimsize,isize,jsize) :: n02,pgam2,lam2,true
 real, dimension(densize) :: cgp2
 real, dimension(1000) :: fall2

! end of variable declaration
!-------------------------------------------------------------------------------

! set constants and parameters

! assume 600 hPa, 253 K for p and T for fallspeed calcs (for reference air density)
 pi  = 3.14159  !=acos(-1.)
 g   = 9.861               ! gravity
 p   = 60000.              ! air pressure (pa)
 t   = 253.15              ! temp (K)
 rho = p/(287.15*t)      ! air density (kg m-3)
 mu  = 1.496E-6*t**1.5/(t+120.)/rho    ! viscosity of air
 dv  = 8.794E-5*t**1.81/p  ! diffusivity of water vapor in air
 dt  = 10.

! parameters for surface roughness of ice particle
! see mitchell and heymsfield 2005
 del0 = 5.83
 c0   = 0.6
 c1   = 4./(del0**2*c0**0.5)
 c2   = del0**2/4.

!--- specified mass-dimension relationship (cgs units) for unrimed crystals:
! ms = cs*D^ds
!
! for graupel:
! mg = cg*D^dg     no longer used, since bulk volume is predicted

! Heymsfield et al. 2006
!      ds=1.75
!      cs=0.0040157+6.06e-5*(-20.)
! sector-like branches (P1b)
!      ds=2.02
!      cs=0.00142
! bullet-rosette
!     ds=2.45
!      cs=0.00739
! side planes
!      ds=2.3
!      cs=0.00419
! radiating assemblages of plates (mitchell et al. 1990)
!      ds=2.1
!      cs=0.00239
! aggreagtes of side planes, bullets, etc. (Mitchell 1996)
!      ds=2.1
!      cs=0.0028
! Brown and Francis (1995)
 ds = 1.9
! cs = 0.01855 ! original, based on assumption of Dmax
 cs = 0.0121 ! scaled value based on assumtion of Dmean from Hogan et al. 2012, JAMC

! note: if using brown and francis, already in mks units!!!!!
! uncomment line below if using other snow m-D relationships
!      cs=cs*100.**ds/1000.  ! convert from cgs units to mks
!===

! applicable for prognostic graupel density
!  note:  cg is not constant, due to variable density
 dg = 3.


!--- projected area-diam relationship (mks units) for unrimed crystals:
!       note: projected area = aas*D^bas
! sector-like branches (P1b)
!      bas = 1.97
!      aas = 0.55*100.**bas/(100.**2)
! bullet-rosettes
!      bas = 1.57
!      aas = 0.0869*100.**bas/(100.**2)
! graupel (values for hail)
!      bag=2.0
!      aag=0.625*100.**bag/(100.**2)
! aggreagtes of side planes, bullets, etc.
 bas = 1.88
 aas = 0.2285*100.**bas/(100.**2)
!===

!--- projected area-diam relationship (mks units) for graupel:
!      (assumed spheres)
!       note: projected area = aag*D^bag
 aag = pi*0.25
 bag = 2.
!===

! calculate critical diameter separating small spherical ice from crystalline ice
! "Dth" in Morrison and Grabowski 2008

   !open file to write to look-up table (which gets used by P3 scheme)
! open(unit=1,file='/sysdisk1/morrison/kinematic_ice/lookup_table_p3_cat_interaction-v13.dat',status='unknown')
 open(unit=1,file='./p3_lookup_table_2.dat-v4',status='unknown')

!.........................................................

!dcrit = (pi/(6.*cs)*0.9)**(1./(ds-3.))
 dcrit = (pi/(6.*cs)*900.)**(1./(ds-3.))
!dcrit=dcrit/100.  ! convert from cm to m

!.........................................................
! main loop over graupel density

! 1D array for RIME density (not ice/graupel density)
 crp(1) = 50.*pi*sxth
 crp(2) = 250.*pi*sxth
 crp(3) = 450.*pi*sxth
 crp(4) = 650.*pi*sxth
 crp(5) = 900.*pi*sxth

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!...........................................................................................
!...........................................................................................

! parameters for category 1

! main loop over graupel density

 do jjjj = 1,densize

!------------------------------------------------------------------------
! main loops around N, q, rr for lookup tables

! find threshold with rimed mass added

! loop over rimed mass fraction (4 points)
! rr below are values of rime mass fraction for the lookup table
! specific values in model are interpolated between these four points

!- note:  should move outside of rime density loop
!     rr(1)=0.
!     rr(2)=0.333
!     rr(3)=0.667
!     rr(4)=1.
!=

    do jjj = 1,rimsize   ! loop for rime mass fraction, Fr

! calculate critical dimension separate graupel and nonspherical ice
! "Dgr" in morrison and grabowski (2008)

!   dcrits = (cs/crp(jjjj))**(1./(dg-ds)) ! calculated below for variable graupel density
!   dcrits = dcrits/100.  ! convert from cm to m

!    print*,(pi/(4.*aas))**(1./(bas-2.))
!    print*,(aas/aag)**(1./(bag-bas))

!    print*,'dcrit,dcrits',jjjj,dcrit,dcrits1(jjjj,jjj)

! check to make sure projected area at dcrit not greater than than of solid sphere
! stop and give warning message if that is the case

!    if (pi/4.*dcrit**2.lt.aas*dcrit**bas) then
!       print*,'STOP, area > area of solid ice sphere, unrimed'
!       stop
!    endif
!    if (pi/4.*dcrits1(jjjj,jjj)**2.lt.aag*dcrits1(jjjj,jjj)**bag) then
!       print*,'STOP, area > area of solid ice sphere, graupel'
!       stop
!    endif

!      cg=cg*100.**dg/1000.  ! convert from cgs units to mks

!      print*,cg,dg
!      stop
!      do jj=1,100
!         dd=real(jj)*30.e-6
!         write(6,'5e15.5')dd,aas*dd**bas,pi/4.*dd**2,
!     1      cs*dd**ds,pi*sxth*917.*dd**3
!      end do

!-- these lines to be replaced by rr(jjj) initialization outside of loops
       if (jjj.eq.1) rr = 0.
       if (jjj.eq.2) rr = 0.333
       if (jjj.eq.3) rr = 0.667
       if (jjj.eq.4) rr = 1.
!==

! calculate mass-dimension relationship for partially-rimed crystals
! msr = csr*D^dsr
! formula from morrison grabowski 2008

! dcritr is critical size separating graupel from partially-rime crystal
! same as "Dcr" in morrison and grabowski 2008

! first guess, set cgp=crp
       cgp1(jjjj) = crp(jjjj)

! case of no riming (Fr = 0%), then we need to set dcrits and dcritr to arbitrary large values

       if (jjj.eq.1) then
          dcrits1(jjjj,jjj) = 1.e6
          dcritr1(jjjj,jjj) = dcrits1(jjjj,jjj)
          csr1(jjjj,jjj)    = cs
          dsr1(jjjj,jjj)    = ds
! case of partial riming (Fr between 0 and 100%)
       elseif (jjj.eq.2.or.jjj.eq.3) then
          do
             dcrits1(jjjj,jjj) = (cs/cgp1(jjjj))**(1./(dg-ds))
             dcritr1(jjjj,jjj) = ((1.+rr/(1.-rr))*cs/cgp1(jjjj))**(1./(dg-ds))
             csr1(jjjj,jjj)    = cs*(1.+rr/(1.-rr))
             dsr1(jjjj,jjj)    = ds

! get mean density of vapor deposition/aggregation grown ice
             rhodep = 1./(dcritr1(jjjj,jjj)-dcrits1(jjjj,jjj))* &
            6.*cs/(pi*(ds-2.))*(dcritr1(jjjj,jjj)**(ds-2.)- &
             dcrits1(jjjj,jjj)**(ds-2.))

! get graupel density as rime mass fraction weighted rime density plus
! density of vapor deposition/aggregation grown ice
             cgpold    = cgp1(jjjj)
             cgp1(jjjj) = crp(jjjj)*rr+rhodep*(1.-rr)*pi*sxth

             if (abs((cgp1(jjjj)-cgpold)/cgp1(jjjj)).lt.0.01) goto 115
          enddo

 115  continue

! case of complete riming (Fr=100%)
       else

! set threshold size for pure graupel arbitrary large
          dcrits1(jjjj,jjj) = (cs/cgp1(jjjj))**(1./(dg-ds))
          dcritr1(jjjj,jjj) = 1.e6
          csr1(jjjj,jjj)    = cgp1(jjjj)
          dsr1(jjjj,jjj)    = dg

       endif

!---------------------------------------------------------------------------------------
! set up particle fallspeed arrays
! fallspeed is a function of mass dimension and projected area dimension relationships
! following mitchell and heymsfield (2005), jas

! set up array of particle fallspeed to make computationally efficient
!.........................................................
! ****
!  note: this part could be incorporated into the longer (every 2 micron) loop
! ****
       do jj = 1,1000

! particle size
          d1 = real(jj)*20.*1.e-6 - 10.e-6

          if (d1.le.dcrit) then
             cs1  = pi*sxth*900.
             ds1  = 3.
             bas1 = 2.
             aas1 = pi/4.
          else if (d1.gt.dcrit.and.d1.le.dcrits1(jjjj,jjj)) then
             cs1  = cs
             ds1  = ds
             bas1 = bas
             aas1 = aas
          else if (d1.gt.dcrits1(jjjj,jjj).and.d1.le.dcritr1(jjjj,jjj)) then
             cs1  = cgp1(jjjj)
             ds1  = dg
             bas1 = bag
             aas1 = aag
          else if (d1.gt.dcritr1(jjjj,jjj)) then
             cs1  = csr1(jjjj,jjj)
             ds1  = dsr1(jjjj,jjj)
             if (jjj.eq.1) then
                aas1 = aas
                bas1 = bas
             else
! for area,
! keep bas1 constant, but modify aas1 according
! to rimed fraction
                bas1 = bas
                dum1 = aas*d1**bas
                dum2 = aag*d1**bag
!               dum3 = (1.-rr)*dum1+rr*dum2
                m1   = cs1*d1**ds1
                m2   = cs*d1**ds
                m3   = cgp1(jjjj)*d1**dg
! linearly interpolate based on particle mass
                dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                aas1 = dum3/(d1**bas)
             endif
          endif

! correction for turbulence
!            if (d1.lt.500.e-6) then
          a0 = 0.
          b0 = 0.
!            else
!               a0=1.7e-3
!               b0=0.8
!            end if

! fall speed for ice
! best number
          xx = 2.*cs1*g*rho*d1**(ds1+2.-bas1)/(aas1*(mu*rho)**2)

! drag terms
          b1 = c1*xx**0.5/(2.*((1.+c1*xx**0.5)**0.5-1.)*(1.+c1*xx**0.5)**0.5)-a0*b0*xx** &
               b0/(c2*((1.+c1*xx**0.5)**0.5-1.)**2)

          a1 = (c2*((1.+c1*xx**0.5)**0.5-1.)**2-a0*xx**b0)/xx**b1

! velocity in terms of drag terms
          fall1(jj) = a1*mu**(1.-2.*b1)*(2.*cs1*g/(rho*aas1))**b1*d1**(b1*(ds1-bas1+2.)-1.)

!---------------------------------------------------------------
       enddo !jj-loop
       
!---------------------------------------------------------------------------------
! main loops around q and N for lookup table
! produces 30 x 30 x 4 x 5 table
!
! q = normalized ice mass mixing ratio = q/N, units are kg^-1

       do i = 1,isize              ! q loop

!          q=10.**(i-16)
! normalized q (range of mean mass diameter from ~ 1 micron to 1 cm)
	   q=261.7**((i+5)*0.2)*1.e-18

! uncomment below to test and print proposed values of qovn
!       print*,i,(6./(pi*500.)*q)**0.3333
!       end do
!       stop

! test values
!            N=5.e3
!            q=0.01e-3

!             print*,'&&&&&&&&&&&jjjj',jjjj
!             print*,'***************',i
             print*,'i,rr,den',i,jjj,jjjj
             print*,'q,N',q

! initialize qerror to arbitrarily large value
             qerror = 1.e20

!.....................................................................................
! find parameters for gamma distribution

! size distribution for ice is assumed to be
! N(D) = n0 * D^pgam * exp(-lam*D)

! for the given q and N, we need to find n0, pgam, and lam

! approach for finding lambda:
! cycle through a range of lambda, find closest lambda to produce correct q

! start with lam, range of lam from 100 to 5 x 10^6 is large enough to
! cover full range over mean size from 2 to 5000 micron

             do ii = 1,9000
                lam1(jjjj,jjj,i) = real(ii)*100.
                lam1(jjjj,jjj,i) = 1.0013**ii*100.

! get 'mu' parameter (Heymsfield 2003)
! division by 100 is to convert m-1 to cm-1
                pgam1(jjjj,jjj,i) = 0.076*(lam1(jjjj,jjj,i)/100.)**0.8-2.
! make sure pgam >= 0, otherwise size dist is infinity at D = 0
                pgam1(jjjj,jjj,i) = max(pgam1(jjjj,jjj,i),0.)
! set upper limit at 6
                pgam1(jjjj,jjj,i) = min(pgam1(jjjj,jjj,i),6.)

! set min lam corresponding to 2000 micron for mean size
!               dum = 2000.e-6+rr*(3000.e-6)
                dum = 2000.e-6
                lam1(jjjj,jjj,i) = max(lam1(jjjj,jjj,i),(pgam1(jjjj,jjj,i)+1.)/dum)
! set max lam corresponding to 2 micron mean size
                lam1(jjjj,jjj,i) = min(lam1(jjjj,jjj,i),(pgam1(jjjj,jjj,i)+1.)/(2.e-6))
! this range corresponds to range of lam of 500 to 5000000

! get normalized n0 = n0/N
                n01(jjjj,jjj,i) = lam1(jjjj,jjj,i)**(pgam1(jjjj,jjj,i)+1.)/ &
                   (gamma(pgam1(jjjj,jjj,i)+1.))

! calculate integral for each of the 4 parts of the size distribution
! check difference with respect to q

! dum1 is integral from 0 to dcrit (solid ice)
! dum2 is integral from dcrit to dcrits (snow)
! dum3 is integral from dcrits to dcritr (graupel)
! dum4 is integral from dcritr to inf (rimed snow)

! set up m-D relationship for solid ice with D < Dcrit
                cs1  = pi*sxth*900.
                ds1  = 3.
                dum1 = lam1(jjjj,jjj,i)**(-ds1-pgam1(jjjj,jjj,i)-1.)* &
              gamma(pgam1(jjjj,jjj,i)+ds1+1.)* &
              (1.-gammq(pgam1(jjjj,jjj,i)+ds1+1.,dcrit*lam1(jjjj,jjj,i)))

                dum2 = lam1(jjjj,jjj,i)**(-ds-pgam1(jjjj,jjj,i)-1.)* &
              gamma(pgam1(jjjj,jjj,i)+ds+1.)* &
                  (gammq(pgam1(jjjj,jjj,i)+ds+1.,dcrit*lam1(jjjj,jjj,i)))
                dum  = lam1(jjjj,jjj,i)**(-ds-pgam1(jjjj,jjj,i)-1.)* &
           gamma(pgam1(jjjj,jjj,i)+ds+1.)* &
            (gammq(pgam1(jjjj,jjj,i)+ds+1., &
           dcrits1(jjjj,jjj)*lam1(jjjj,jjj,i)))
                dum2 = dum2-dum
                dum2 = max(dum2,0.)

                dum3 = lam1(jjjj,jjj,i)**(-dg-pgam1(jjjj,jjj,i)-1.)* &
           gamma(pgam1(jjjj,jjj,i)+dg+1.)* &
             (gammq(pgam1(jjjj,jjj,i)+dg+1., &
            dcrits1(jjjj,jjj)*lam1(jjjj,jjj,i)))
                dum  = lam1(jjjj,jjj,i)**(-dg-pgam1(jjjj,jjj,i)-1.)* &
          gamma(pgam1(jjjj,jjj,i)+dg+1.)* &
            (gammq(pgam1(jjjj,jjj,i)+dg+1., &
          dcritr1(jjjj,jjj)*lam1(jjjj,jjj,i)))
                dum3 = dum3-dum
                dum3 = max(dum3,0.)

                dum4 = lam1(jjjj,jjj,i)**(-dsr1(jjjj,jjj)-pgam1(jjjj,jjj,i)-1.)* &
           gamma(pgam1(jjjj,jjj,i)+dsr1(jjjj,jjj)+1.)* &
           (gammq(pgam1(jjjj,jjj,i)+dsr1(jjjj,jjj)+1., &
           dcritr1(jjjj,jjj)*lam1(jjjj,jjj,i)))

! sum of the integrals from the 4 regions of the size distribution
! remember: this is a distribution normalized by N!!!!

                qdum = n01(jjjj,jjj,i)* &
          (cs1*dum1+cs*dum2+cgp1(jjjj)*dum3+csr1(jjjj,jjj)*dum4)

! numerical integration for test to make sure incomplete gamma function is working
!               sum1 = 0.
!               dd = 1.e-6
!               do iii=1,50000
!                  dum=real(iii)*1.e-6
!                  if (dum.lt.dcrit) then
!                  sum1 = sum1+n0*dum**pgam*cs1*dum**ds1*
!     1                      exp(-lam*dum)*dd
!                  else
!                  sum1 = sum1+n0*dum**pgam*cs*dum**ds*
!     1                      exp(-lam*dum)*dd
!                  end if
!               end do
!               print*,'sum1=',sum1
!               stop

                if (ii.eq.1) then
                   qerror = abs(q-qdum)
                   lamf   = lam1(jjjj,jjj,i)
                endif

! find lam with smallest difference between q and estimate of q, assign to lamf
                if (abs(q-qdum).lt.qerror) then
                   lamf   = lam1(jjjj,jjj,i)
                   qerror = abs(q-qdum)
                endif


             enddo !ii-loop

! check and print relative error in q to make sure it is not too large
! note: large error is possible if size bounds are exceeded!!!!!!!!!!

             print*,'qerror (%)',qerror/q*100.

! find n0 based on final lam value
! set final lamf to 'lam' variable
! this is the value of lam with the smallest qerror
             lam1(jjjj,jjj,i) = lamf
! recalculate pgam based on final lam
! get 'mu' parameter (Heymsfield 2003)
! division by 100 is to convert m-1 to cm-1
             pgam1(jjjj,jjj,i) = 0.076*(lam1(jjjj,jjj,i)/100.)**0.8-2.
! make sure pgam >= 0, otherwise size dist is infinity at D = 0
             pgam1(jjjj,jjj,i) = max(pgam1(jjjj,jjj,i),0.)
! set upper limit at 6
             pgam1(jjjj,jjj,i) = min(pgam1(jjjj,jjj,i),6.)

!            n0 = N*lam**(pgam+1.)/(gamma(pgam+1.))

! find n0 from lam and q
! this is done instead of finding n0 from lam and N, since N
! may need to be adjusted to constrain mean size within reasonable bounds

             dum1 = lam1(jjjj,jjj,i)**(-ds1-pgam1(jjjj,jjj,i)-1.)* &
            gamma(pgam1(jjjj,jjj,i)+ds1+1.)* &
            (1.-gammq(pgam1(jjjj,jjj,i)+ds1+1.,dcrit*lam1(jjjj,jjj,i)))

             dum2 = lam1(jjjj,jjj,i)**(-ds-pgam1(jjjj,jjj,i)-1.)* &
             gamma(pgam1(jjjj,jjj,i)+ds+1.)* &
             (gammq(pgam1(jjjj,jjj,i)+ds+1.,dcrit*lam1(jjjj,jjj,i)))
             dum  = lam1(jjjj,jjj,i)**(-ds-pgam1(jjjj,jjj,i)-1.)* &
            gamma(pgam1(jjjj,jjj,i)+ds+1.)* &
               (gammq(pgam1(jjjj,jjj,i)+ds+1., &
             dcrits1(jjjj,jjj)*lam1(jjjj,jjj,i)))
             dum2 = dum2-dum

             dum3 = lam1(jjjj,jjj,i)**(-dg-pgam1(jjjj,jjj,i)-1.)* &
            gamma(pgam1(jjjj,jjj,i)+dg+1.)* &
            (gammq(pgam1(jjjj,jjj,i)+dg+1., &
             dcrits1(jjjj,jjj)*lam1(jjjj,jjj,i)))
             dum  = lam1(jjjj,jjj,i)**(-dg-pgam1(jjjj,jjj,i)-1.)* &
           gamma(pgam1(jjjj,jjj,i)+dg+1.)* &
            (gammq(pgam1(jjjj,jjj,i)+dg+1., &
           dcritr1(jjjj,jjj)*lam1(jjjj,jjj,i)))
             dum3 = dum3-dum

             dum4 = lam1(jjjj,jjj,i)**(-dsr1(jjjj,jjj)-pgam1(jjjj,jjj,i)-1.)* &
            gamma(pgam1(jjjj,jjj,i)+dsr1(jjjj,jjj)+1.)* &
            (gammq(pgam1(jjjj,jjj,i)+dsr1(jjjj,jjj)+1., &
            dcritr1(jjjj,jjj)*lam1(jjjj,jjj,i)))

! normalized n0
             n01(jjjj,jjj,i)   = q/(cs1*dum1+ &
             cs*dum2+cgp1(jjjj)*dum3+csr1(jjjj,jjj)*dum4)
             print*,'lam,N0:',lam1(jjjj,jjj,i),n01(jjjj,jjj,i)
             print*,'pgam:',pgam1(jjjj,jjj,i)
             print*,'mean size:',(pgam1(jjjj,jjj,i)+1.)/lam1(jjjj,jjj,i)

! test final lam, N0 values
!            sum1 = 0.
!            dd = 1.e-6
!               do iii=1,50000
!                  dum=real(iii)*1.e-6
!                  if (dum.lt.dcrit) then
!                     sum1 = sum1+n0*dum**pgam*cs1*dum**ds1*exp(-lam*dum)*dd
!                  elseif (dum.ge.dcrit.and.dum.lt.dcrits) then
!                     sum1 = sum1+n0*dum**pgam*cs*dum**ds*exp(-lam*dum)*dd
!                  elseif (dum.ge.dcrits.and.dum.lt.dcritr) then
!                     sum1 = sum1+n0*dum**pgam*cg*dum**dg*exp(-lam*dum)*dd
!                  elseif (dum.ge.dcritr) then
!                     sum1 = sum1+n0*dum**pgam*csr*dum**dsr*exp(-lam*dum)*dd
!                  endif
!               enddo
!               print*,'sum1=',sum1
!               stop


! At this point, we have solve for all of the size distribution parameters

! NOTE: In the code it is assumed that mean size and number have already been
! adjusted, so that mean size will fall within allowed bounds. Thus, we do
! not apply a lambda limiter here.

             end do  ! normalized q loop
             end do  ! Fr loop
             end do  ! rime density loop

!--------------------------------------------------------------------
!.....................................................................................
! now calculate parameters for category 2

 do jjjj = 1,densize

    do jjj = 1,rimsize   ! loop for rime mass fraction, Fr

!-- these lines to be replaced by rr(jjj) initialization outside of loops
       if (jjj.eq.1) rr = 0.
       if (jjj.eq.2) rr = 0.333
       if (jjj.eq.3) rr = 0.667
       if (jjj.eq.4) rr = 1.
!==

! calculate mass-dimension relationship for partially-rimed crystals
! msr = csr*D^dsr
! formula from morrison grabowski 2008

! dcritr is critical size separating graupel from partially-rime crystal
! same as "Dcr" in morrison and grabowski 2008

! first guess, set cgp=crp
       cgp2(jjjj) = crp(jjjj)

! case of no riming (Fr = 0%), then we need to set dcrits and dcritr to arbitrary large values

       if (jjj.eq.1) then
          dcrits2(jjjj,jjj) = 1.e6
          dcritr2(jjjj,jjj) = dcrits2(jjjj,jjj)
          csr2(jjjj,jjj)    = cs
          dsr2(jjjj,jjj)    = ds
! case of partial riming (Fr between 0 and 100%)
       elseif (jjj.eq.2.or.jjj.eq.3) then
          do
             dcrits2(jjjj,jjj) = (cs/cgp2(jjjj))**(1./(dg-ds))
             dcritr2(jjjj,jjj) = ((1.+rr/(1.-rr))*cs/cgp2(jjjj))**(1./(dg-ds))
             csr2(jjjj,jjj)    = cs*(1.+rr/(1.-rr))
             dsr2(jjjj,jjj)    = ds

! get mean density of vapor deposition/aggregation grown ice
             rhodep = 1./(dcritr2(jjjj,jjj)-dcrits2(jjjj,jjj))* &
            6.*cs/(pi*(ds-2.))*(dcritr2(jjjj,jjj)**(ds-2.)- &
             dcrits2(jjjj,jjj)**(ds-2.))

! get graupel density as rime mass fraction weighted rime density plus
! density of vapor deposition/aggregation grown ice
             cgpold    = cgp2(jjjj)
             cgp2(jjjj) = crp(jjjj)*rr+rhodep*(1.-rr)*pi*sxth

             if (abs((cgp2(jjjj)-cgpold)/cgp2(jjjj)).lt.0.01) goto 116
          enddo

 116  continue

! case of complete riming (Fr=100%)
       else

! set threshold size for pure graupel arbitrary large
          dcrits2(jjjj,jjj) = (cs/cgp2(jjjj))**(1./(dg-ds))
          dcritr2(jjjj,jjj) = 1.e6
          csr2(jjjj,jjj)    = cgp2(jjjj)
          dsr2(jjjj,jjj)    = dg

       endif

!---------------------------------------------------------------------------------------
! set up particle fallspeed arrays
! fallspeed is a function of mass dimension and projected area dimension relationships
! following mitchell and heymsfield (2005), jas

! set up array of particle fallspeed to make computationally efficient
!.........................................................
! ****
!  note: this part could be incorporated into the longer (every 2 micron) loop
! ****
       do jj = 1,1000

! particle size
          d1 = real(jj)*20.*1.e-6 - 10.e-6

          if (d1.le.dcrit) then
             cs1  = pi*sxth*900.
             ds1  = 3.
             bas1 = 2.
             aas1 = pi/4.
          else if (d1.gt.dcrit.and.d1.le.dcrits2(jjjj,jjj)) then
             cs1  = cs
             ds1  = ds
             bas1 = bas
             aas1 = aas
          else if (d1.gt.dcrits2(jjjj,jjj).and.d1.le.dcritr2(jjjj,jjj)) then
             cs1  = cgp2(jjjj)
             ds1  = dg
             bas1 = bag
             aas1 = aag
          else if (d1.gt.dcritr2(jjjj,jjj)) then
             cs1  = csr2(jjjj,jjj)
             ds1  = dsr2(jjjj,jjj)
             if (jjj.eq.1) then
                aas1 = aas
                bas1 = bas
             else
! for area,
! keep bas1 constant, but modify aas1 according
! to rimed fraction
                bas1 = bas
                dum1 = aas*d1**bas
                dum2 = aag*d1**bag
!               dum3 = (1.-rr)*dum1+rr*dum2
                m1   = cs1*d1**ds1
                m2   = cs*d1**ds
                m3   = cgp2(jjjj)*d1**dg
! linearly interpolate based on particle mass
                dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                aas1 = dum3/(d1**bas)
             endif
          endif

! correction for turbulence
!            if (d1.lt.500.e-6) then
          a0 = 0.
          b0 = 0.
!            else
!               a0=1.7e-3
!               b0=0.8
!            end if

! fall speed for ice
! best number
          xx = 2.*cs1*g*rho*d1**(ds1+2.-bas1)/(aas1*(mu*rho)**2)

! drag terms
          b1 = c1*xx**0.5/(2.*((1.+c1*xx**0.5)**0.5-1.)*(1.+c1*xx**0.5)**0.5)-a0*b0*xx** &
               b0/(c2*((1.+c1*xx**0.5)**0.5-1.)**2)

          a1 = (c2*((1.+c1*xx**0.5)**0.5-1.)**2-a0*xx**b0)/xx**b1

! velocity in terms of drag terms
          fall2(jj) = a1*mu**(1.-2.*b1)*(2.*cs1*g/(rho*aas1))**b1*d1**(b1*(ds1-bas1+2.)-1.)

!---------------------------------------------------------------
       enddo !jj-loop


!---------------------------------------------------------------------------------
! main loops around q and N for lookup table
! produces 30 x 30 x 4 x 5 table
!
! q = total ice mixing ratio (vapor dep. plus rime mixing ratios), units kg/kg
! N = particle number concentrations, units kg-1

       do i = 1,isize              ! q loop

          lamold = 0.
!          do k = 1,jsize           ! N loop
          k=1

!             q = 5.1**(i*1.73)*3.e-17
!             N = 8.**(k*1.73)*3.e-11

!             q=10.**(i-16)
! normalized q (range of mean mass diameter from ~ 1 micron to 1 cm)
           q=261.7**((i+5)*0.2)*1.e-18

!             print*,'q',5.1**(1*1.73)*3.e-17,5.1**(12*1.73)*3.e-17
!             print*,'N',8.**(1*1.73)*3.e-11,8.**(12*1.73)*3.e-11

!             print*,'q',5.1**1*1.e-16,5.1**20*1.e-16
!             print*,'N',8.**1*1.e-10,8.**20*1.e-10

! test values
!            N=5.e3
!            q=0.01e-3

             print*,'&&&&&&&&&&&jjjj',jjjj
             print*,'***************',i,k
             print*,'rr',rr
             print*,'q,N',q,N

! initialize qerror to arbitrarily large value
             qerror = 1.e20

!.....................................................................................
! find parameters for gamma distribution

! size distribution for ice is assumed to be
! N(D) = n0 * D^pgam * exp(-lam*D)

! for the given q and N, we need to find n0, pgam, and lam

! approach for finding lambda:
! cycle through a range of lambda, find closest lambda to produce correct q

! start with lam, range of lam from 100 to 5 x 10^6 is large enough to
! cover full range over mean size from 2 to 5000 micron

             do ii = 1,9000
                lam2(jjjj,jjj,i,k) = real(ii)*100.
                lam2(jjjj,jjj,i,k) = 1.0013**ii*100.

! get 'mu' parameter (Heymsfield 2003)
! division by 100 is to convert m-1 to cm-1
                pgam2(jjjj,jjj,i,k) = 0.076*(lam2(jjjj,jjj,i,k)/100.)**0.8-2.
! make sure pgam >= 0, otherwise size dist is infinity at D = 0
                pgam2(jjjj,jjj,i,k) = max(pgam2(jjjj,jjj,i,k),0.)
! set upper limit at 6
                pgam2(jjjj,jjj,i,k) = min(pgam2(jjjj,jjj,i,k),6.)

! set min lam corresponding to 2000 micron for mean size
!               dum = 2000.e-6+rr*(3000.e-6)
                dum = 2000.e-6
                lam2(jjjj,jjj,i,k) = max(lam2(jjjj,jjj,i,k),(pgam2(jjjj,jjj,i,k)+1.)/dum)
! set max lam corresponding to 2 micron mean size
                lam2(jjjj,jjj,i,k) = min(lam2(jjjj,jjj,i,k),(pgam2(jjjj,jjj,i,k)+1.)/(2.e-6))
! this range corresponds to range of lam of 500 to 5000000

! get n0, note this is normalized
                n02(jjjj,jjj,i,k) = lam2(jjjj,jjj,i,k)**(pgam2(jjjj,jjj,i,k)+1.)/ &
                   (gamma(pgam2(jjjj,jjj,i,k)+1.))

! calculate integral for each of the 4 parts of the size distribution
! check difference with respect to q

! dum1 is integral from 0 to dcrit (solid ice)
! dum2 is integral from dcrit to dcrits (snow)
! dum3 is integral from dcrits to dcritr (graupel)
! dum4 is integral from dcritr to inf (rimed snow)

! set up m-D relationship for solid ice with D < Dcrit
                cs1  = pi*sxth*900.
                ds1  = 3.
                dum1 = lam2(jjjj,jjj,i,k)**(-ds1-pgam2(jjjj,jjj,i,k)-1.)* &
              gamma(pgam2(jjjj,jjj,i,k)+ds1+1.)* &
              (1.-gammq(pgam2(jjjj,jjj,i,k)+ds1+1.,dcrit*lam2(jjjj,jjj,i,k)))

                dum2 = lam2(jjjj,jjj,i,k)**(-ds-pgam2(jjjj,jjj,i,k)-1.)* &
              gamma(pgam2(jjjj,jjj,i,k)+ds+1.)* &
                  (gammq(pgam2(jjjj,jjj,i,k)+ds+1.,dcrit*lam2(jjjj,jjj,i,k)))
                dum  = lam2(jjjj,jjj,i,k)**(-ds-pgam2(jjjj,jjj,i,k)-1.)* &
           gamma(pgam2(jjjj,jjj,i,k)+ds+1.)* &
            (gammq(pgam2(jjjj,jjj,i,k)+ds+1., &
           dcrits2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))
                dum2 = dum2-dum
                dum2 = max(dum2,0.)

                dum3 = lam2(jjjj,jjj,i,k)**(-dg-pgam2(jjjj,jjj,i,k)-1.)* &
           gamma(pgam2(jjjj,jjj,i,k)+dg+1.)* &
             (gammq(pgam2(jjjj,jjj,i,k)+dg+1., &
            dcrits2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))
                dum  = lam2(jjjj,jjj,i,k)**(-dg-pgam2(jjjj,jjj,i,k)-1.)* &
          gamma(pgam2(jjjj,jjj,i,k)+dg+1.)* &
            (gammq(pgam2(jjjj,jjj,i,k)+dg+1., &
          dcritr2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))
                dum3 = dum3-dum
                dum3 = max(dum3,0.)

                dum4 = lam2(jjjj,jjj,i,k)**(-dsr2(jjjj,jjj)-pgam2(jjjj,jjj,i,k)-1.)* &
           gamma(pgam2(jjjj,jjj,i,k)+dsr2(jjjj,jjj)+1.)* &
           (gammq(pgam2(jjjj,jjj,i,k)+dsr2(jjjj,jjj)+1., &
           dcritr2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))

! sum of the integrals from the 4 regions of the size distribution
! remember: this is a distribution normalized by N!!!!

                qdum = n02(jjjj,jjj,i,k)* &
          (cs1*dum1+cs*dum2+cgp2(jjjj)*dum3+csr2(jjjj,jjj)*dum4)

! numerical integration for test to make sure incomplete gamma function is working
!               sum1 = 0.
!               dd = 1.e-6
!               do iii=1,50000
!                  dum=real(iii)*1.e-6
!                  if (dum.lt.dcrit) then
!                  sum1 = sum1+n0*dum**pgam*cs1*dum**ds1*
!     1                      exp(-lam*dum)*dd
!                  else
!                  sum1 = sum1+n0*dum**pgam*cs*dum**ds*
!     1                      exp(-lam*dum)*dd
!                  end if
!               end do
!               print*,'sum1=',sum1
!               stop

                if (ii.eq.1) then
                   qerror = abs(q-qdum)
                   lamf   = lam2(jjjj,jjj,i,k)
                endif

! find lam with smallest difference between q and estimate of q, assign to lamf
                if (abs(q-qdum).lt.qerror) then
                   lamf   = lam2(jjjj,jjj,i,k)
                   qerror = abs(q-qdum)
                endif


             enddo !ii-loop

! check and print relative error in q to make sure it is not too large
! note: large error is possible if size bounds are exceeded!!!!!!!!!!

             print*,'qerror (%)',qerror/q*100.

! find n0 based on final lam value
! set final lamf to 'lam' variable
! this is the value of lam with the smallest qerror
             lam2(jjjj,jjj,i,k) = lamf
! recalculate pgam based on final lam
! get 'mu' parameter (Heymsfield 2003)
! division by 100 is to convert m-1 to cm-1
             pgam2(jjjj,jjj,i,k) = 0.076*(lam2(jjjj,jjj,i,k)/100.)**0.8-2.
! make sure pgam >= 0, otherwise size dist is infinity at D = 0
             pgam2(jjjj,jjj,i,k) = max(pgam2(jjjj,jjj,i,k),0.)
! set upper limit at 6
             pgam2(jjjj,jjj,i,k) = min(pgam2(jjjj,jjj,i,k),6.)

!            n0 = N*lam**(pgam+1.)/(gamma(pgam+1.))

! find n0 from lam and q
! this is done instead of finding n0 from lam and N, since N
! may need to be adjusted to constrain mean size within reasonable bounds

             dum1 = lam2(jjjj,jjj,i,k)**(-ds1-pgam2(jjjj,jjj,i,k)-1.)* &
            gamma(pgam2(jjjj,jjj,i,k)+ds1+1.)* &
            (1.-gammq(pgam2(jjjj,jjj,i,k)+ds1+1.,dcrit*lam2(jjjj,jjj,i,k)))

             dum2 = lam2(jjjj,jjj,i,k)**(-ds-pgam2(jjjj,jjj,i,k)-1.)* &
             gamma(pgam2(jjjj,jjj,i,k)+ds+1.)* &
             (gammq(pgam2(jjjj,jjj,i,k)+ds+1.,dcrit*lam2(jjjj,jjj,i,k)))
             dum  = lam2(jjjj,jjj,i,k)**(-ds-pgam2(jjjj,jjj,i,k)-1.)* &
            gamma(pgam2(jjjj,jjj,i,k)+ds+1.)* &
               (gammq(pgam2(jjjj,jjj,i,k)+ds+1., &
             dcrits2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))
             dum2 = dum2-dum

             dum3 = lam2(jjjj,jjj,i,k)**(-dg-pgam2(jjjj,jjj,i,k)-1.)* &
            gamma(pgam2(jjjj,jjj,i,k)+dg+1.)* &
            (gammq(pgam2(jjjj,jjj,i,k)+dg+1., &
             dcrits2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))
             dum  = lam2(jjjj,jjj,i,k)**(-dg-pgam2(jjjj,jjj,i,k)-1.)* &
           gamma(pgam2(jjjj,jjj,i,k)+dg+1.)* &
            (gammq(pgam2(jjjj,jjj,i,k)+dg+1., &
           dcritr2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))
             dum3 = dum3-dum

             dum4 = lam2(jjjj,jjj,i,k)**(-dsr2(jjjj,jjj)-pgam2(jjjj,jjj,i,k)-1.)* &
             gamma(pgam2(jjjj,jjj,i,k)+dsr2(jjjj,jjj)+1.)* &
            (gammq(pgam2(jjjj,jjj,i,k)+dsr2(jjjj,jjj)+1., &
            dcritr2(jjjj,jjj)*lam2(jjjj,jjj,i,k)))

! n0 is normalized
             n02(jjjj,jjj,i,k)   = q/(cs1*dum1+ &
             cs*dum2+cgp2(jjjj)*dum3+csr2(jjjj,jjj)*dum4)
             print*,'lam,N0:',lam2(jjjj,jjj,i,k),n02(jjjj,jjj,i,k)
             print*,'pgam:',pgam2(jjjj,jjj,i,k)

! normalized N is always 1
             nsave(i,k,jjj,jjjj) = 1.
             qsave(i,k,jjj,jjjj) = q

             true(jjjj,jjj,i,k)=0.
             if (abs(lam2(jjjj,jjj,i,k)-lamold).lt.1.e-8) then
                true(jjjj,jjj,i,k)=1.
             end if
             lamold         = lam2(jjjj,jjj,i,k)

!             end do ! N
             end do ! q
             end do ! Fr
             end do ! rime density

! test final lam, N0 values
!            sum1 = 0.
!            dd = 1.e-6
!               do iii=1,50000
!                  dum=real(iii)*1.e-6
!                  if (dum.lt.dcrit) then
!                     sum1 = sum1+n0*dum**pgam*cs1*dum**ds1*exp(-lam*dum)*dd
!                  elseif (dum.ge.dcrit.and.dum.lt.dcrits) then
!                     sum1 = sum1+n0*dum**pgam*cs*dum**ds*exp(-lam*dum)*dd
!                  elseif (dum.ge.dcrits.and.dum.lt.dcritr) then
!                     sum1 = sum1+n0*dum**pgam*cg*dum**dg*exp(-lam*dum)*dd
!                  elseif (dum.ge.dcritr) then
!                     sum1 = sum1+n0*dum**pgam*csr*dum**dsr*exp(-lam*dum)*dd
!                  endif
!               enddo
!               print*,'sum1=',sum1
!               stop


! At this point, we have solve for all of the size distribution parameters

! NOTE: In the code it is assumed that mean size and number have already been
! adjusted, so that mean size will fall within allowed bounds. Thus, we do
! not apply a lambda limiter here.

!--------------------------------------------------------------------
!.....................................................................................
! begin category process interaction calculations for the lookup table

!.....................................................................................
! collection of category 1 by category 2
!.....................................................................................

221 format(a5,7i5,2e15.5)

             j2=1

             do i1=1,isize
                   do jjj1=1,rimsize
                      do jjjj1=1,densize
                         do i2=1,isize
!                            do j2=1,jsize
                            do jjj2=1,rimsize
                               do jjjj2=1,densize

             if (true(jjjj2,jjj2,i2,j2).lt.0.5) then

             sum1 = 0.  ! initialize sum
             sum2 = 0.  ! initialize sum
             dd   = 20.e-6

             do jj=1000,1,-1
! set up binned distribution of ice from category 1, note the distribution is normalized by N
                d1     = real(jj)*20.*1.e-6 - 10.e-6
                num1(jj) = n01(jjjj1,jjj1,i1)*d1**pgam1(jjjj1,jjj1,i1)*exp(-lam1(jjjj1,jjj1,i1)*d1)*dd
             enddo !jj-loop

             do jj=1000,1,-1
! set up binned distribution of ice from category 2, note the distribution is normalized by N
                d2     = real(jj)*20.*1.e-6 - 10.e-6
                num2(jj) = n02(jjjj2,jjj2,i2,j2)*d2**pgam2(jjjj2,jjj2,i2,j2)*exp(-lam2(jjjj2,jjj2,i2,j2)*d2)*dd
             enddo !jj-loop

! loop over exponential size distribution
! note: collection of ice within the same bin is neglected

! loop over particle 1
             do jj = 1000,1,-1

                d1 = real(jj)*20.*1.e-6 - 10.e-6

                   if (d1.le.dcrit) then
                      cs1  = pi*sxth*900.
                      ds1  = 3.
                      bas1 = 2.
                      aas1 = pi*0.25
                   elseif (d1.gt.dcrit.and.d1.le.dcrits1(jjjj1,jjj1)) then
                      cs1  = cs
                      ds1  = ds
                      bas1 = bas
                      aas1 = aas
                   else if (d1.gt.dcrits1(jjjj1,jjj1).and.d1.le.dcritr1(jjjj1,jjj1)) then
                      cs1  = cgp1(jjjj1)
                      ds1  = dg
                      bas1 = bag
                      aas1 = aag
                   else if (d1.gt.dcritr1(jjjj1,jjj1)) then
! hm bug fix 1/19/13
                      cs1 = csr1(jjjj1,jjj1)
                      ds1 = dsr1(jjjj1,jjj1)
                      if (jjj1.eq.1) then
                         aas1 = aas
                         bas1 = bas
                      else
! for area, keep bas1 constant, but modify aas1 according to rimed fraction
                         bas1 = bas
                         dum1 = aas*d1**bas
                         dum2 = aag*d1**bag
                         m1   = cs1*d1**ds1
                         m2   = cs*d1**ds
                         m3   = cgp1(jjjj1)*d1**dg
! linearly interpolate based on particle mass
                         dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                         aas1 = dum3/(d1**bas)
                      endif
                   endif

! loop over particle 2
                do kk = 1000,1,-1

                   d2 = real(kk)*20.*1.e-6 - 10.e-6


! parameters for particle 2
                   if (d2.le.dcrit) then
!                      cs2  = pi*sxth*900.
!                      ds2  = 3.
                      bas2 = 2.
                      aas2 = pi*0.25
                   elseif (d2.gt.dcrit.and.d2.le.dcrits2(jjjj2,jjj2)) then
!                      cs2  = cs
!                      ds2  = ds
                      bas2 = bas
                      aas2 = aas
                   else if (d2.gt.dcrits2(jjjj2,jjj2).and.d2.le.dcritr2(jjjj2,jjj2)) then
!                      cs2  = cgp2(jjjj)
!                      ds2  = dg
                      bas2 = bag
                      aas2 = aag
                   else if (d2.gt.dcritr2(jjjj2,jjj2)) then
! hm bug fix 1/19/13
                      cs2 = csr2(jjjj2,jjj2)
                      ds2 = dsr2(jjjj2,jjj2)
                      if (jjj2.eq.1) then
                         aas2 = aas
                         bas2 = bas
                      else
! for area, keep bas1 constant, but modify aas1 according to rimed fraction
                         bas2 = bas
                         dum1 = aas*d2**bas
                         dum2 = aag*d2**bag
                         m1   = cs2*d2**ds2
                         m2   = cs*d2**ds
                         m3   = cgp2(jjjj2)*d2**dg
! linearly interpolate based on particle mass
                         dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                         aas2 = dum3/(d2**bas)
                      endif
                   endif

! absolute value, differential fallspeed
!                   delu = abs(fall2(kk)-fall1(jj))

! calculate collection of category 1 by category 2, which occurs
! in fallspeed of particle in category 2 is greater than category 1

                   if (fall2(kk).gt.fall1(jj)) then
                      delu=fall2(kk)-fall1(jj)

! note: in micro code we have to multiply by air density
! correction factor for fallspeed, and collection efficiency

! sum for integral

! sum1 = # of collision pairs
! the assumption is that each collision pair reduces crystal
! number mixing ratio by 1 kg^-1 s^-1 per kg/m^3 of air (this is
! why we need to multiply by air density, to get units of
! 1/kg^-1 s^-1)
! NOTE: For consideration of particle depletion, air density is assumed to be 1 kg m-3
! This problem could be avoided by using number concentration instead of number mixing ratio
! for the lookup table calculations, and then not multipling process rate by air density 
! in the P3 code... TO BE FIXED IN THE FUTURE

!                   sum1 = sum1+min((aas1*d1**bas1+aas2*d2**bas2)*delu*num(jj)*num(kk),   &
!                          num(kk)/dt)

! set collection efficiency
!                  eii = 0.1

! accretion of number
                  sum1 = sum1+(aas1*d1**bas1+aas2*d2**bas2)*delu*num1(jj)*num2(kk)
! accretion of mass
                  sum2 = sum2+cs1*d1**ds1*(aas1*d1**bas1+aas2*d2**bas2)*delu*num1(jj)*num2(kk)

! remove collected particles from distribution over time period dt, update num1
!  note -- dt is time scale for removal, not necessarily the model time step
!                   num1(jj) = num1(jj)-(aas1*d1**bas1+aas2*d2**bas2)*delu*num1(jj)*num2(kk)*eii*dt
!                   num1(jj) = max(num1(jj),0.)

!            write(6,'(2i5,8e15.5)')jj,kk,sum1,num(jj),num(kk),delu,aas1,d1,aas2,d2
!            num(kk)=num(kk)-(aas1*d1**bas1+aas2*d2**bas2)*delu*num(jj)*num(kk)*0.1*0.5
!            num(kk)=max(num(kk),0.)
!            sum1 = sum1+0.5*(aas1*d1**bas1+aas2*d2**bas2)*delu*n0*n0*(d1+d2)**pgam*exp(-lam*(d1+d2))*dd**2

                   endif ! fall2(kk) > fall1(jj)

                enddo !kk-loop
             enddo !jj-loop

! save for output
             nagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2) = sum1
             qagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2) = sum2

             else if (true(jjjj2,jjj2,i2,j2).ge.0.5) then
             nagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2)=nagg(i1,jjj1,jjjj1,i2,j2-1,jjj2,jjjj2)   
             qagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2)=qagg(i1,jjj1,jjjj1,i2,j2-1,jjj2,jjjj2)   
             print*,'&&&&&&, skip'
             end if

             write(6,221)'index',i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2,nagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2), &
                     qagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2)

             end do
             end do
!             end do
             end do
             end do
             end do
             end do

!             print*,'nagg',nagg(i,k,jjj)

!.....................................................................................

!             nsave(i,k,jjj) = N
!             qsave(i,k,jjj) = q
!             lsave(i,k,jjj) = lam
!             lamold         = lam

222 format(2i5,e15.5,2i5,4e15.5)

             j2=1

             do i1=1,isize
                   do jjj1=1,rimsize
                      do jjjj1=1,densize
                         do i2=1,isize
!                           do j2=1,jsize
                            do jjj2=1,rimsize
                               do jjjj2=1,densize

             write(1,222) jjjj1,jjj1,qon1(i1,jjj1,jjjj1),jjjj2,jjj2, &
              qsave(i2,j2,jjj2,jjjj2),nsave(i2,j2,jjj2,jjjj2), &
              nagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2), &
              qagg(i1,jjj1,jjjj1,i2,j2,jjj2,jjjj2)

             end do
             end do
!             end do
             end do
             end do
             end do
             end do

END PROGRAM make_p3_lookuptable2
!______________________________________________________________________________________

! Incomplete gamma function
! from Numerical Recipes in Fortran 77: The Art of
! Scientific Computing

      function gammq(a,x)

      real a,gammq,x

! USES gcf,gser
! Returns the incomplete gamma function Q(a,x) = 1-P(a,x)

      real gammcf,gammser,gln
      if (x.lt.0..or.a.le.0) pause 'bad argument in gammq'
      if (x.lt.a+1.) then
         call gser(gamser,a,x,gln)
         gammq=1.-gamser
      else
         call gcf(gammcf,a,x,gln)
         gammq=gammcf
      end if
      return
      end

!-------------------------------------

      subroutine gser(gamser,a,x,gln)
      integer itmax
      real a,gamser,gln,x,eps
      parameter(itmax=100,eps=3.e-7)
      integer n
      real ap,del,sum,gamma
      gln = log(gamma(a))
      if (x.le.0.) then
         if (x.lt.0.) pause 'x < 0 in gser'
         gamser = 0.
         return
      end if
      ap=a
      sum=1./a
      del=sum
      do n=1,itmax
         ap=ap+1.
         del=del*x/ap
         sum=sum+del
         if (abs(del).lt.abs(sum)*eps) goto 1
      end do
      pause 'a too large, itmax too small in gser'
 1    gamser=sum*exp(-x+a*log(x)-gln)
      return
      end

!-------------------------------------

      subroutine gcf(gammcf,a,x,gln)
      integer itmax
      real a,gammcf,gln,x,eps,fpmin
      parameter(itmax=100,eps=3.e-7,fpmin=1.e-30)
      integer i
      real an,b,c,d,del,h,gamma
      gln=log(gamma(a))
      b=x+1.-a
      c=1./fpmin
      d=1./b
      h=d
      do i=1,itmax
         an=-i*(i-a)
         b=b+2.
         d=an*d+b
         if(abs(d).lt.fpmin) d=fpmin
         c=b+an/c
         if(abs(c).lt.fpmin) c=fpmin
         d=1./d
         del=d*c
         h = h*del
         if(abs(del-1.).lt.eps)goto 1
      end do
      pause 'a too large, itmax too small in gcf'
 1    gammcf=exp(-x+a*log(x)-gln)*h
      return
      end

!-------------------------------------

      REAL FUNCTION gamma(X)


!D    DOUBLE PRECISION FUNCTION Dgamma(X)
!----------------------------------------------------------------------
!
! THIS ROUTINE CALCULATES THE gamma FUNCTION FOR A REAL ARGUMENT X.
!   COMPUTATION IS BASED ON AN ALGORITHM OUTLINED IN REFERENCE 1.
!   THE PROGRAM USES RATIONAL FUNCTIONS THAT APPROXIMATE THE gamma
!   FUNCTION TO AT LEAST 20 SIGNIFICANT DECIMAL DIGITS.  COEFFICIENTS
!   FOR THE APPROXIMATION OVER THE INTERVAL (1,2) ARE UNPUBLISHED.
!   THOSE FOR THE APPROXIMATION FOR X .GE. 12 ARE FROM REFERENCE 2.
!   THE ACCURACY ACHIEVED DEPENDS ON THE ARITHMETIC SYSTEM, THE
!   COMPILER, THE INTRINSIC FUNCTIONS, AND PROPER SELECTION OF THE
!   MACHINE-DEPENDENT CONSTANTS.
!
!
!----------------------------------------------------------------------
!
! EXPLANATION OF MACHINE-DEPENDENT CONSTANTS
!
! BETA   - RADIX FOR THE FLOATING-POINT REPRESENTATION
! MAXEXP - THE SMALLEST POSITIVE POWER OF BETA THAT OVERFLOWS
! XBIG   - THE LARGEST ARGUMENT FOR WHICH gamma(X) IS REPRESENTABLE
!          IN THE MACHINE, I.E., THE SOLUTION TO THE EQUATION
!                  gamma(XBIG) = BETA**MAXEXP
! XINF   - THE LARGEST MACHINE REPRESENTABLE FLOATING-POINT NUMBER;
!          APPROXIMATELY BETA**MAXEXP
! EPS    - THE SMALLEST POSITIVE FLOATING-POINT NUMBER SUCH THAT
!          1.0+EPS .GT. 1.0
! XMININ - THE SMALLEST POSITIVE FLOATING-POINT NUMBER SUCH THAT
!          1/XMININ IS MACHINE REPRESENTABLE
!
!     APPROXIMATE VALUES FOR SOME IMPORTANT MACHINES ARE:
!
!                            BETA       MAXEXP        XBIG
!
! CRAY-1         (S.P.)        2         8191        966.961
! CYBER 180/855
!   UNDER NOS    (S.P.)        2         1070        177.803
! IEEE (IBM/XT,
!   SUN, ETC.)   (S.P.)        2          128        35.040
! IEEE (IBM/XT,
!   SUN, ETC.)   (D.P.)        2         1024        171.624
! IBM 3033       (D.P.)       16           63        57.574
! VAX D-FORMAT   (D.P.)        2          127        34.844
! VAX G-FORMAT   (D.P.)        2         1023        171.489
!
!                            XINF         EPS        XMININ
!
! CRAY-1         (S.P.)   5.45E+2465   7.11E-15    1.84E-2466
! CYBER 180/855
!   UNDER NOS    (S.P.)   1.26E+322    3.55E-15    3.14E-294
! IEEE (IBM/XT,
!   SUN, ETC.)   (S.P.)   3.40E+38     1.19E-7     1.18E-38
! IEEE (IBM/XT,
!   SUN, ETC.)   (D.P.)   1.79D+308    2.22D-16    2.23D-308
! IBM 3033       (D.P.)   7.23D+75     2.22D-16    1.39D-76
! VAX D-FORMAT   (D.P.)   1.70D+38     1.39D-17    5.88D-39
! VAX G-FORMAT   (D.P.)   8.98D+307    1.11D-16    1.12D-308
!
!----------------------------------------------------------------------
!
! ERROR RETURNS
!
!  THE PROGRAM RETURNS THE VALUE XINF FOR SINGULARITIES OR
!     WHEN OVERFLOW WOULD OCCUR.  THE COMPUTATION IS BELIEVED
!     TO BE FREE OF UNDERFLOW AND OVERFLOW.
!
!
!  INTRINSIC FUNCTIONS REQUIRED ARE:
!
!     INT, DBLE, EXP, LOG, REAL, SIN
!
!
! REFERENCES:  AN OVERVIEW OF SOFTWARE DEVELOPMENT FOR SPECIAL
!              FUNCTIONS   W. J. CODY, LECTURE NOTES IN MATHEMATICS,
!              506, NUMERICAL ANALYSIS DUNDEE, 1975, G. A. WATSON
!              (ED.), SPRINGER VERLAG, BERLIN, 1976.
!
!              COMPUTER APPROXIMATIONS, HART, ET. AL., WILEY AND
!              SONS, NEW YORK, 1968.
!
!  LATEST MODIFICATION: OCTOBER 12, 1989
!
!  AUTHORS: W. J. CODY AND L. STOLTZ
!           APPLIED MATHEMATICS DIVISION
!           ARGONNE NATIONAL LABORATORY
!           ARGONNE, IL 60439
!
!----------------------------------------------------------------------
      INTEGER I,N
      LOGICAL PARITY
      REAL                  &
!D    DOUBLE PRECISION
          C,CONV,EPS,FACT,HALF,ONE,P,PI,Q,RES,SQRTPI,SUM,TWELVE, &
          TWO,X,XBIG,XDEN,XINF,XMININ,XNUM,Y,Y1,YSQ,Z,ZERO
      DIMENSION C(7),P(8),Q(8)
!----------------------------------------------------------------------
!  MATHEMATICAL CONSTANTS
!----------------------------------------------------------------------
      DATA ONE,HALF,TWELVE,TWO,ZERO/1.0E0,0.5E0,12.0E0,2.0E0,0.0E0/,  &
           SQRTPI/0.9189385332046727417803297E0/,                     &
           PI/3.1415926535897932384626434E0/
!D    DATA ONE,HALF,TWELVE,TWO,ZERO/1.0D0,0.5D0,12.0D0,2.0D0,0.0D0/,
!D   1     SQRTPI/0.9189385332046727417803297D0/,
!D   2     PI/3.1415926535897932384626434D0/
!----------------------------------------------------------------------
!  MACHINE DEPENDENT PARAMETERS
!----------------------------------------------------------------------
      DATA XBIG,XMININ,EPS/35.040E0,1.18E-38,1.19E-7/,         &
           XINF/3.4E38/
!D    DATA XBIG,XMININ,EPS/171.624D0,2.23D-308,2.22D-16/,
!D   1     XINF/1.79D308/
!----------------------------------------------------------------------
!  NUMERATOR AND DENOMINATOR COEFFICIENTS FOR RATIONAL MINIMAX
!     APPROXIMATION OVER (1,2).
!----------------------------------------------------------------------
      DATA P/-1.71618513886549492533811E+0,2.47656508055759199108314E+1,  &
             -3.79804256470945635097577E+2,6.29331155312818442661052E+2,  &
             8.66966202790413211295064E+2,-3.14512729688483675254357E+4,  &
             -3.61444134186911729807069E+4,6.64561438202405440627855E+4/
      DATA Q/-3.08402300119738975254353E+1,3.15350626979604161529144E+2,  &
            -1.01515636749021914166146E+3,-3.10777167157231109440444E+3,  &
              2.25381184209801510330112E+4,4.75584627752788110767815E+3,  &
            -1.34659959864969306392456E+5,-1.15132259675553483497211E+5/
!D    DATA P/-1.71618513886549492533811D+0,2.47656508055759199108314D+1,
!D   1       -3.79804256470945635097577D+2,6.29331155312818442661052D+2,
!D   2       8.66966202790413211295064D+2,-3.14512729688483675254357D+4,
!D   3       -3.61444134186911729807069D+4,6.64561438202405440627855D+4/
!D    DATA Q/-3.08402300119738975254353D+1,3.15350626979604161529144D+2,
!D   1      -1.01515636749021914166146D+3,-3.10777167157231109440444D+3,
!D   2        2.25381184209801510330112D+4,4.75584627752788110767815D+3,
!D   3      -1.34659959864969306392456D+5,-1.15132259675553483497211D+5/
!----------------------------------------------------------------------
!  COEFFICIENTS FOR MINIMAX APPROXIMATION OVER (12, INF).
!----------------------------------------------------------------------
      DATA C/-1.910444077728E-03,8.4171387781295E-04,                     &
           -5.952379913043012E-04,7.93650793500350248E-04,                &
           -2.777777777777681622553E-03,8.333333333333333331554247E-02,   &
            5.7083835261E-03/
!D    DATA C/-1.910444077728D-03,8.4171387781295D-04,
!D   1     -5.952379913043012D-04,7.93650793500350248D-04,
!D   2     -2.777777777777681622553D-03,8.333333333333333331554247D-02,
!D   3      5.7083835261D-03/
!----------------------------------------------------------------------
!  STATEMENT FUNCTIONS FOR CONVERSION BETWEEN INTEGER AND FLOAT
!----------------------------------------------------------------------
      CONV(I) = REAL(I)
!D    CONV(I) = DBLE(I)
      PARITY=.FALSE.
      FACT=ONE
      N=0
      Y=X
      IF(Y.LE.ZERO)THEN
!----------------------------------------------------------------------
!  ARGUMENT IS NEGATIVE
!----------------------------------------------------------------------
        Y=-X
        Y1=AINT(Y)
        RES=Y-Y1
        IF(RES.NE.ZERO)THEN
          IF(Y1.NE.AINT(Y1*HALF)*TWO)PARITY=.TRUE.
          FACT=-PI/SIN(PI*RES)
          Y=Y+ONE
        ELSE
          RES=XINF
          GOTO 900
        ENDIF
      ENDIF
!----------------------------------------------------------------------
!  ARGUMENT IS POSITIVE
!----------------------------------------------------------------------
      IF(Y.LT.EPS)THEN
!----------------------------------------------------------------------
!  ARGUMENT .LT. EPS
!----------------------------------------------------------------------
        IF(Y.GE.XMININ)THEN
          RES=ONE/Y
        ELSE
          RES=XINF
          GOTO 900
        ENDIF
      ELSEIF(Y.LT.TWELVE)THEN
        Y1=Y
        IF(Y.LT.ONE)THEN
!----------------------------------------------------------------------
!  0.0 .LT. ARGUMENT .LT. 1.0
!----------------------------------------------------------------------
          Z=Y
          Y=Y+ONE
        ELSE
!----------------------------------------------------------------------
!  1.0 .LT. ARGUMENT .LT. 12.0, REDUCE ARGUMENT IF NECESSARY
!----------------------------------------------------------------------
          N=INT(Y)-1
          Y=Y-CONV(N)
          Z=Y-ONE
        ENDIF
!----------------------------------------------------------------------
!  EVALUATE APPROXIMATION FOR 1.0 .LT. ARGUMENT .LT. 2.0
!----------------------------------------------------------------------
        XNUM=ZERO
        XDEN=ONE
        DO 260 I=1,8
          XNUM=(XNUM+P(I))*Z
          XDEN=XDEN*Z+Q(I)
  260   CONTINUE
        RES=XNUM/XDEN+ONE
        IF(Y1.LT.Y)THEN
!----------------------------------------------------------------------
!  ADJUST RESULT FOR CASE  0.0 .LT. ARGUMENT .LT. 1.0
!----------------------------------------------------------------------
          RES=RES/Y1
        ELSEIF(Y1.GT.Y)THEN
!----------------------------------------------------------------------
!  ADJUST RESULT FOR CASE  2.0 .LT. ARGUMENT .LT. 12.0
!----------------------------------------------------------------------
          DO 290 I=1,N
            RES=RES*Y
            Y=Y+ONE
  290     CONTINUE
        ENDIF
      ELSE
!----------------------------------------------------------------------
!  EVALUATE FOR ARGUMENT .GE. 12.0,
!----------------------------------------------------------------------
        IF(Y.LE.XBIG)THEN
          YSQ=Y*Y
          SUM=C(7)
          DO 350 I=1,6
            SUM=SUM/YSQ+C(I)
  350     CONTINUE
          SUM=SUM/Y-Y+SQRTPI
          SUM=SUM+(Y-HALF)*LOG(Y)
          RES=EXP(SUM)
        ELSE
          RES=XINF
          GOTO 900
        ENDIF
      ENDIF
!----------------------------------------------------------------------
!  FINAL ADJUSTMENTS AND RETURN
!----------------------------------------------------------------------
      IF(PARITY)RES=-RES
      IF(FACT.NE.ONE)RES=FACT/RES
  900 gamma=RES
!D900 Dgamma = RES
      RETURN
! ---------- LAST LINE OF gamma ----------
      END


!--------------------------------------------------------------------------
! subroutine get_mass_size
!
! !----- get mass-size and projected area-size relationships for given size (d1)
!           if (d1.le.dcrit) then
!              cs1 = pi*sxth*900.
!              ds1 = 3.
!              bas1 = 2.
!              aas1 = pi/4.
!           else if (d1.gt.dcrit.and.d1.le.dcrits) then
!              cs1  = cs
!              ds1  = ds
!              bas1 = bas
!              aas1 = aas
!           else if (d1.gt.dcrits.and.d1.le.dcritr) then
!               cs1  = cgp(jjjj)
!               ds1  = dg
!               bas1 = bag
!               aas1 = aag
!           else if (d1.gt.dcritr) then
!              cs1 = csr
!              ds1 = dsr
!              if (jjj.eq.1) then
!                 aas1 = aas
!                 bas1 = bas
!              else
!
! ! for projected area, keep bas1 constant, but modify aas1 according to rimed fraction
!                 bas1 = bas
!                 dum1 = aas*d1**bas
!                 dum2 = aag*d1**bag
!                 m1   = cs1*d1**ds1
!                 m2   = cs*d1**ds
!                 m3   = cgp(jjjj)*d1**dg
! ! linearly interpolate based on particle mass
!                 dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
! !               dum3 = (1.-rr)*dum1+rr*dum2
!                 aas1 = dum3/(d1**bas)
!              endif
!           endif
! !=====
!
! end subroutine get_mass_size
