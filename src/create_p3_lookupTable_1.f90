PROGRAM create_p3_lookuptable_1

!______________________________________________________________________________________
!
! This program creates the lookup tables (that are combined into the single file
! 'p3_lookupTable_1.dat') for the microphysical processes, used by the P3 microphysics scheme.
! Note, 'p3_lookupTable_2.dat', used in ice-ice interactions for the multi-ice-category
! configuration, are created by a separate program, 'create_lookupTable_2.f90').
!
! This code is used to generate lookupTable_1 for either 2momI or 3momI, depending on
! the specified value of the parameter 'log_3momI'.
!
! All other parameter settings are linked uniquely to the version number.
!
!--------------------------------------------------------------------------------------
! Version:       6.9
! Last modified: 2025 Feb
! Version: including the liquid fraction (inner-loop i_Fl), full3mom, prognostic aerosols
!______________________________________________________________________________________

!______________________________________________________________________________________
!
! To generate 'p3_lookupTable_1.dat' using this code, do the following steps :
!
! 1. Break up this code into two parts (-top.f90 and -bottom.90).  Search for the string
!    'RUNNING IN PARALLEL MODE' and follow instructions.
!    For 2momI, need to comment do/enddo for 'i_rhor_loop' for parallelization (search for
!    'i_rhor_loop' label); for 3momI, the 'i_rhor_loop' needs to be uncomment.
!    (In the future, a script  will be written to automate this.)
!
! 2. Copy the 3 pieces of text below to create indivudual executable shell scripts.

! 3. Run script 1 (./go_1-compile.ksh).  This script will recreate several
!    versions of the full code, concatenating the -top.f90 and the -bottom.90 with
!    the following code (e.g.) in between (looping through values of i_rhor (for 2momI) or
!    i_Znorm (for 3momI):
!
!    i_rhor  = 1   ! 2-moment-ice
!    i_Znorm = 1   ! 3-moment-ice
!
!    Each version of full_code.f90 is then compiled, with a unique executable name.
!    Note, this is done is place the outer i1 loop in order to parallelized .
!
! 4. Run script 2 (./go_2-submit.csh)  This create temporary work directories,
!    moves each executable to each work directory, and runs the executables
!    simultaneously.  (Note, it is assumed that the machine on which this is done
!    has multiple processors, though it is not necessary.)
!
! 5. Run script 3 (./go_3-concatenate.ksh).  This concatenates the individual
!    partial tables (the output in each working directory) into a single, final
!    file 'p3_lookupTable_1.dat'  Once it is confirmed that the table is correct,
!    the work directories and their contents can be removed.
!
!  Note:  For testing or to run in serial, ompile with double-precision
!        (e.g. ifort -r8 create_p3_lookupTable_1.f90)
!              gfortran -fdefault-real-8 create_p3_lookupTable_1.f90)
!______________________________________________________________________________________

!--------------------------------------------------------------------------------------------
! Parallel script 1 (of 3):  [copy text below (uncommented) to file 'go_1-compile.ksh']
!  - creates individual parallel codes, compiles each
!
!-----------------------------
! For 2-MOMENT-ICE:

! #!/bin/ksh
!
! for i_rhor in 01 02 03 04 05
! do
!
!    rm cfg_input full_code.f90
!    cat > cfg_input << EOF
!     i_rhor  = ${i_rhor}
! EOF
!    cat create_p3_lookupTable_1-top.f90 cfg_input create_p3_lookupTable_1-bottom.f90 > full_code.f90
!    echo 'Compiling 'exec_${i_rhor}
!    ifort -r8 full_code.f90
!    mv a.out exec_${i_rhor}
!
! done
!
! rm cfg_input full_code.f90

!-----------------------------
! For 3-MOMENT-ICE:

!#!/bin/ksh
!
! for i_Znorm in 01 02 03 04 05 06 07 08 09 10 11
! do
!
! for i_rhor in 01 02 03 04 05
! do
!    rm cfg_input full_code.f90
!    cat > cfg_input << EOF
!    i_Znorm = ${i_Znorm}
!    i_rhor = ${i_rhor}
!EOF
!    cat create_p3_lookupTable_1-top.f90 cfg_input create_p3_lookupTable_1-bottom.f90 > full_code.f90
!    cp full_code.f90 full_code_${i_Znorm}_${i_rhor}.f90
!    echo 'Compiling 'exec_${i_Znorm}_${i_rhor}
!    ifort -r8 full_code.f90
!    mv a.out exec_${i_Znorm}_${i_rhor}
!
! done
! done
!
! rm cfg_input full_code.f90

!--------------------------------------------------------------------------------------------
!# Parallel script 2 (of 3):   [copy text below (uncommented) to file 'go_2-submit.ksh']
!#  - creates individual work directories, launches each executable

!#!/bin/ksh
!
! for exec in `ls exec_*`
! do
!    echo Submitting: ${exec}
!    mkdir ${exec}-workdir
!    mv ${exec} ${exec}-workdir
!    cd ${exec}-workdir
!    ./${exec} > log &
!    cd ..
! done

!--------------------------------------------------------------------------------------------
!# Parallel script 3 (of 3):   [copy text below (uncommented) to file 'go_3-concatenate.ksh]
!#  - concatenates the output of each parallel job into a single output file.

!#!/bin/ksh
!
! rm lt_total
!
! for i in `ls exec*/*dat`
! do
!    echo $i
!    cat lt_total $i > lt_total_tmp
!    mv lt_total_tmp lt_total
! done
!
! mv lt_total p3_lookupTable_1.dat
!
! echo 'Done.  Work directories and contents can now be removed.'
! echo 'Be sure to re-name the file with the appropriate extension, with the version number'
! echo 'corresponding to that in the header.  (e.g. 'p3_lookupTable_1.dat-v5.3-3momI')'

!--------------------------------------------------------------------------------------------

 implicit none

 !-----
 character(len=20), parameter :: version   = '6.9'
 logical, parameter           :: log_3momI = .true.    !switch to create table for 2momI (.false.) or 3momI (.true.)
 !-----

 integer            :: i_Znorm         ! index for normalized (by Q) Z (passed in through script; [1 .. n_Znorm])
 integer            :: i_rhor          ! index for rho_rime (passed in through script; [1 .. n_rhor])
 integer            :: i_Fr            ! index for rime-mass-fraction loop      [1 .. n_Fr]
 integer            :: i_Fl            ! index for liquid-mass-fraction loop    [1 .. n_Fl]
 integer            :: i_Qnorm         ! index for normalized (by N) Q loop     [1 .. n_Qnorm]
 integer            :: i_Drscale       ! index for scaled mean rain size loop   [1 .. n_Drscale]

! NOTE: n_Znorm (number of i_Znorm values) is currently equal to 80.  It is not actually used herein and therefore not declared.
!       Rather, the outer (i_Znorm) "loop" is treated by individual complilations/execuations with specified values of i_Znorm,
!       with resulting sub-tables subsequently concatenated.  The same is true for the second (i_rhor) "loop"; however, n_rhor
!       is used to decare the ranges of other arrays, hence it is declared/initialized here

!integer, parameter :: n_Znorm   = 11  ! number of indices for i_Znorm loop           (1nd "loop")  [not used in parallelized version]
 integer, parameter :: n_rhor    =  5  ! number of indices for i_rhor  loop           (2nd "loop")
 integer, parameter :: n_Fr      =  4  ! number of indices for i_Fr    loop           (3rd loop)
 integer, parameter :: n_Fl      =  4  ! number of indices for i_Fl    loop           (4th loop)
 integer, parameter :: n_Qnorm   = 50  ! number of indices for i_Qnorm loop           (5th loop)
 integer, parameter :: n_Drscale = 30  ! number of indices for scaled mean rain size  (6th [inner] loop)

 integer, parameter :: num_int_bins      = 40000 ! number of bins for numerical integration of ice processes
 integer, parameter :: num_int_coll_bins =  1500 ! number of bins for numerical integration of ice-ice and ice-rain collection

 real, parameter :: mu_i_min = 0.
 real, parameter :: mu_i_max = 20.

 integer :: i,ii,iii,jj,kk,kkk,dumii,i_iter,n_iter_psdSolve

 real :: N,q,qdum,dum1,dum2,cs1,ds1,lam,n0,lamf,qerror,del0,c0,c1,c2,dd,ddd,sum1,sum2,   &
         sum3,sum4,xx,a0,b0,a1,b1,dum,bas1,aas1,aas2,bas2,gammq,gamma,d1,d2,delu,lamold, &
         cap,lamr,dia,amg,dv,n0dum,sum5,sum6,sum7,sum8,dg,cg,bag,aag,dcritg,dcrits,      &
         dcritr,Fr,csr,dsr,duml,dum3,rhodep,cgpold,m1,m2,m3,dt,mu_r,initlamr,lamv,       &
         rdumii,lammin,lammax,pi,g,p,t,rho,mu,mu_i,ds,cs,bas,aas,dcrit,mu_dum,gdum,      &
         Z_value,sum9,mom3,mom6,intgrR1,intgrR2,intgrR3,intgrR4,dum4,cs2,ds2,mur_constant, &
         boltzman,meanpath,Daw,Dai,wcc,icc,Re,diffin,sc,st,aval,st2,Effw,Effi,eiaw,eiai

! New parameters with liquid fraction
 real :: area,area1,area2,mass,fac1,fac2,dumfac1,dumfac2,dumfac12,dumfac22,capm,gg,      &
         lamd,mu_id,n0d,qid,Zid,cs5,dum5,rhom,intgrR5,Fl

! function to compute mu for triple moment
 real :: compute_mu_3moment

! function to return diagnostic value of shape paramter, mu_i (mu_id with i_Fl)
 real :: diagnostic_mui

! function to return diagnostic value of shape paramter, mu_i
 real :: diagnostic_mui_Fl

! outputs from lookup table (i.e. "f1prxx" read by access_lookup_table in s/r p3_main)
 real, dimension(n_Qnorm,n_Fr,n_Fl) :: uns,ums,refl,dmm,rhomm,nagg,nrwat,qsave,nsave,vdep,    &
        eff,lsave,a_100,n_100,vdep1,i_qsmall,i_qlarge,lambda_i,mu_i_save,refl2

! New rates with liquid fraction (5 new columns)
 real, dimension(n_Qnorm,n_Fr,n_Fl) :: qshed,vdepm1,vdepm2,vdepm3,vdepm4

! New rates for m6
 real, dimension(n_Qnorm,n_Fr,n_Fl) :: m6rime,m6dep,m6dep1,m6mlt1,m6mlt2,m6agg,m6shd,m6sub,m6sub1

! New rates with prognostic aerosols (2 new columns)
 real, dimension(n_Qnorm,n_Fr,n_Fl) :: nawcol,naicol

! change in mass with D
 real :: dmdD
 real :: mass2

 ! outputs for triple moment
! HM zsmall, zlarge no longer needed
! real, dimension(n_Qnorm,n_Fr) :: uzs,zlarge,zsmall
 real, dimension(n_Qnorm,n_Fr,n_Fl) :: uzs

 real, dimension(n_Qnorm,n_Drscale,n_Fr,n_Fl) :: qrrain,nrrain,nsrain,qsrain,ngrain
 ! change in zi from rain-ice collection
 real, dimension(n_Qnorm,n_Drscale,n_Fr,n_Fl) :: m6collr

 real, dimension(n_Drscale)         :: lamrs
 real, dimension(num_int_bins)      :: fall1,falls1,fallr1
 real, dimension(num_int_coll_bins) :: fall2,fallr,num,numi,falls
! for M6 rates
 real, dimension(num_int_coll_bins) :: numloss,massloss,massgain
 real, dimension(n_rhor)            :: cgp,crp
 real, dimension(150)               :: mu_r_table

 real, parameter                    :: Dm_max1 =  5000.e-6   ! max. mean ice [m] size for lambda limiter
 real, parameter                    :: Dm_max2 = 20000.e-6   ! max. mean ice [m] size for lambda limiter
 real, parameter                    :: Dm_min  =     2.e-6   ! min. mean ice [m] size for lambda limiter

 real, parameter                    :: thrd = 1./3.
 real, parameter                    :: sxth = 1./6.
 real, parameter                    :: cutoff = 1.e-90

 character(len=2014)                :: filename

! Declaration variables for reflectivty init (2021)
! for rayleigh scattering based on WRF code
 real, parameter                    :: lamda_radar = 0.10   ! in meters (10 cm)
 real                               :: K_w,pi5,lamda4,cback,m_water,m_ice
 complex                            :: m_w_0,m_i_0
 real, dimension(num_int_bins+1)    :: simpson
 real, parameter, dimension(3)      :: basis = (/1./3., 4./3., 1./3./)
 real                               :: melt_outside = 0.9
 complex                            :: m_complex_water_ray,m_complex_ice_maetzler

 complex*16 :: m_complex_maxwellgarnett
 complex*16 :: get_m_mix
 complex*16 :: get_m_mix_nested

 complex                            :: m_air = (1.0,0.0)
 integer, parameter                 :: slen = 20
 character(len=slen)                :: mixingrulestring_m, matrixstring_m, inclusionstring_m,    &
                                       hoststring_m, hostmatrixstring_m, hostinclusionstring_m
 integer :: bb

 real :: dumm3,dumm6,dummu_i,compute_mu_3moment2


do i = 1, slen
   mixingrulestring_m(i:i) = char(0)
   matrixstring_m(i:i) = char(0)
   inclusionstring_m(i:i) = char(0)
   hoststring_m(i:i) = char(0)
   hostmatrixstring_m(i:i) = char(0)
   hostinclusionstring_m(i:i) = char(0)
enddo

mixingrulestring_m = 'maxwellgarnett'
hoststring_m = 'air'
matrixstring_m = 'water'
inclusionstring_m = 'spheroidal'
hostmatrixstring_m = 'icewater'
hostinclusionstring_m = 'spheroidal'
! End declaration variables for reflectivty (2021)

!===   end of variable declaration ===

 if (log_3momI) then
! HM, no longer need iteration loop
!    n_iter_psdSolve = 3   ! 3 iterations found to be sufficient (trial-and-error)
    n_iter_psdSolve = 1
 else
    n_iter_psdSolve = 1
 endif


!                            RUNNING IN PARALLEL MODE:
!
!------------------------------------------------------------------------------------
! CODE ABOVE HERE IS FOR THE "TOP" OF THE BROKEN UP CODE (for running in parallel)
!
!   Before running ./go_1-compile.ksh, delete all lines below this point and
!   and save as 'create_p3_lookupTable_1-top.f90'
!------------------------------------------------------------------------------------


! For testing single values, uncomment the following:
! i_Znorm = 1
! i_rhor  = 1

!------------------------------------------------------------------------------------
! CODE BELOW HERE IS FOR THE "BOTTOM" OF THE BROKEN UP CODE (for running in parallel)
!
!   Before running ./go_1-compile.ksh, delete all lines below this point and
!   and save as 'create_p3_lookupTable_1-bottom.f90'
!------------------------------------------------------------------------------------

 if (.not.log_3momI) i_Znorm = -9  ! to avoid uninitialized value (2-moment only)

! set constants and parameters

! assume 600 hPa, 253 K for p and T for fallspeed calcs (for reference air density)
 pi  = acos(-1.)
 g   = 9.861                           ! gravity
 p   = 60000.                          ! air pressure (pa)
 t   = 253.15                          ! temp (K)
 rho = p/(287.15*t)                    ! air density (kg m-3)
 mu  = 1.496E-6*t**1.5/(t+120.)/rho    ! viscosity of air
 dv  = 8.794E-5*t**1.81/p              ! diffusivity of water vapor in air
 dt  = 10.                             ! time step for collection (s)

! constants for prognostic aerosols (collection with ice)
 boltzman = 1.3806503E-23
 meanpath = 0.0256E-6
 Daw = 0.04E-6
 Dai = 0.8E-6

! parameters for surface roughness of ice particle used for fallspeed
! see mitchell and heymsfield 2005
 del0 = 5.83
 c0   = 0.6
 c1   = 4./(del0**2*c0**0.5)
 c2   = del0**2/4.

! exponent parameter for dm/dt of shedding
 bb   = 3

 dd   =  2.e-6 ! bin width for numerical integration of ice processes (units of m)
 ddd  = 50.e-6 ! bin width for numerical integration for ice-ice and ice-rain collection (units of m)

!--- specified mass-dimension relationship (cgs units) for unrimed crystals:

! ms = cs*D^ds
!
! for graupel:
! mg = cg*D^dg     no longer used, since bulk volume is predicted
!===

!---- Choice of m-D parameters for large unrimed ice:

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

!-- ** note: if using one of the above (.i.e. not brown and francis, which is already in mks units),
!           then uncomment line below to convert from cgs units to mks
!      cs=cs*100.**ds/1000.
!==

! Brown and Francis (1995)
 ds = 1.9
!cs = 0.01855 ! original (pre v2.3), based on assumption of Dmax
 cs = 0.0121 ! scaled value based on assumtion of Dmean from Hogan et al. 2012, JAMC

!====

! specify m-D parameter for fully rimed ice
!  note:  cg is not constant, due to variable density
 dg = 3.


!--- projected area-diam relationship (mks units) for unrimed crystals:
!     note: projected area = aas*D^bas

! sector-like branches (P1b)
!      bas = 1.97
!      aas = 0.55*100.**bas/(100.**2)

! bullet-rosettes
!      bas = 1.57
!      aas = 0.0869*100.**bas/(100.**2)

! aggreagtes of side planes, bullets, etc.
 bas = 1.88
 aas = 0.2285*100.**bas/(100.**2)

!===

!--- projected area-diam relationship (mks units) for fully rimed ice:
!    note: projected area = aag*D^bag

! assumed non-spherical
! bag = 2.0
! aag = 0.625*100.**bag/(100.**2)

! assumed spherical:
 bag = 2.
 aag = pi*0.25
!===

 dcrit = (pi/(6.*cs)*900.)**(1./(ds-3.))

! check to make sure projected area at dcrit not greater than than of solid sphere
! stop and give warning message if that is the case

 if (pi/4.*dcrit**2.lt.aas*dcrit**bas) then
    print*,'STOP, area > area of solid ice sphere, unrimed'
    stop
 endif

!.........................................................
! generate lookup table for mu (for rain)
!
! space of a scaled q/N -- initlamr

 !Compute mu_r using diagnostic relation:
! !   do i = 1,150  ! loop over lookup table values
! !      initlamr = (real(i)*2.)*1.e-6 + 250.e-6
! !      initlamr = 1./initlamr
! !     ! iterate to get mu_r
! !     ! mu_r-lambda relationship is from Cao et al. (2008), eq. (7)
! !      mu_r = 0.  ! first guess
! !      do ii = 1,50
! !         lamr = initlamr*(gamma(mu_r+4.)/(6.*gamma(mu_r+1.)))**thrd
! !       ! new estimate for mu_r based on lambda:
! !       ! set max lambda in formula for mu to 20 mm-1, so Cao et al.
! !       ! formula is not extrapolated beyond Cao et al. data range
! !         dum = min(20.,lamr*1.e-3)
! !         mu_r = max(0.,-0.0201*dum**2+0.902*dum-1.718)
! !       ! if lambda is converged within 0.1%, then exit loop
! !         if (ii.ge.2) then
! !            if (abs((lamold-lamr)/lamr).lt.0.001) goto 111
! !         endif
! !         lamold = lamr
! !      enddo !ii-loop
! ! 111  continue
! !      mu_r_table(i) = mu_r
! !   enddo !i-loop

 !Precribe a constant mu_r:
  mu_r_table(:) = 0.
  mur_constant  = 0.

 !Compute radar_init
  pi5 = pi**5.
  lamda4 = lamda_radar*lamda_radar*lamda_radar*lamda_radar
  m_w_0 = m_complex_water_ray(pi,lamda_radar, 0.0)
  m_i_0 = m_complex_ice_maetzler(lamda_radar, 0.0)
  K_w = (abs( (m_w_0*m_w_0 - 1.0) /(m_w_0*m_w_0 + 2.0) ))**2

!.........................................................

! alpha parameter of m-D for rimed ice
 crp(1) =  50.*pi*sxth
 crp(2) = 250.*pi*sxth
 crp(3) = 450.*pi*sxth
 crp(4) = 650.*pi*sxth
 crp(5) = 900.*pi*sxth

!------------------------------------------------------------------------

! open file to write to lookup table:
 if (log_3momI) then
!   write (filename, "(A12,I0.2,A1,I0.2,A4)") "lookupTable_1-",i_Znorm,"_",i_rhor,".dat"   !if parallelized over both i_Znorm and i_rhor
    write (filename, "(A12,I0.2,A4)") "lookupTable_1-",i_Znorm,".dat"
    filename = trim(filename)
    open(unit=1, file=filename, status='unknown')
 else
    write (filename, "(A12,I0.2,A4)") "lookupTable_1-",i_rhor,".dat"
    filename = trim(filename)
    open(unit=1, file=filename, status='unknown')
 endif

!--
! The values of i_Znorm (and possibly i_rhor) are "passed in" for parallelized version of code for 3-moment.
! The values of i_rhor are "passed in" for parallelized version of code for 2-moment.
! Thus, the loops 'i_Znorm_loop' and 'i_rhor_loop' are commented out accordingingly.
!
!i_Znorm_loop: do i_Znorm = 1,n_Znorm   !normally commented (kept to illustrate the structure (and to run in serial)
!   i_rhor_loop: do i_rhor = 1,n_rhor    !COMMENT OUT FOR PARALLELIZATION OF THIS LOOP (2-MOMENT ONLY)
     i_Fr_loop_1: do i_Fr = 1,n_Fr      !COMMENT OUT FOR PARALLELIZATION OF THIS LOOP (2-MOMENT ONLY)

! 3-moment-ice only:
! compute Z value from input Z index whose value is "passed in" through the script
! Z_value = 2.1**(i_Znorm)*1.e-23 ! range from 2x10^(-23) to 600 using 80 values
  Z_value = 2.*(i_Znorm-1.) ! mu values of 0,2,4,6,8, temporary.... NOTE IF 2 MOM JUST SET TO ARBITRARY VALUE, WILL BE OVERWRITTEN LATER

       ! write header to first file:
       if (log_3momI .and. i_Znorm==1 .and. i_rhor==1 .and. i_Fr==1) then
          write(1,*) 'LOOKUP_TABLE_1-version:  ',trim(version),'-3momI'
          write(1,*)
       ! elseif (i_rhor==1) then
       elseif (.not.log_3momI .and. i_rhor==1 .and. i_Fr==1) then
          write(1,*) 'LOOKUP_TABLE_1-version:  ',trim(version),'-2momI'
          write(1,*)
       endif

!-- these lines to be replaced by Fr(i_Fr) initialization outside of loops
!  OR:  replace with: Fr = 1./float(n_Fr-1)
       if (i_Fr.eq.1) Fr = 0.
       if (i_Fr.eq.2) Fr = 0.333
       if (i_Fr.eq.3) Fr = 0.667
       if (i_Fr.eq.4) Fr = 1.
!==

       i_Fl_loop_1: do i_Fl = 1,n_Fl   !  loop for liquid mass fraction, Fl

          if (i_Fl.eq.1) Fl = 0.
          if (i_Fl.eq.2) Fl = 0.333
          if (i_Fl.eq.3) Fl = 0.667
          if (i_Fl.eq.4) Fl = 1.


! calculate mass-dimension relationship for partially-rimed crystals
! msr = csr*D^dsr
! formula from P3 Part 1 (JAS)

! dcritr is critical size separating fully-rimed from partially-rime ice

       cgp(i_rhor) = crp(i_rhor)  ! first guess

       if (i_Fr.eq.1) then   ! case of no riming (Fr = 0), then we need to set dcrits and dcritr to arbitrary large values

          dcrits = 1.e+6
          dcritr = dcrits
          csr    = cs
          dsr    = ds

       elseif (i_Fr.eq.2.or.i_Fr.eq.3) then  ! case of partial riming (Fr between 0 and 1)

          do
             dcrits = (cs/cgp(i_rhor))**(1./(dg-ds))
             dcritr = ((1.+Fr/(1.-Fr))*cs/cgp(i_rhor))**(1./(dg-ds))
             csr    = cs*(1.+Fr/(1.-Fr))
             dsr    = ds
           ! get mean density of vapor deposition/aggregation grown ice
             rhodep = 1./(dcritr-dcrits)*6.*cs/(pi*(ds-2.))*(dcritr**(ds-2.)-dcrits**(ds-2.))
           ! get density of fully-rimed ice as rime mass fraction weighted rime density plus
           ! density of vapor deposition/aggregation grown ice
             cgpold      = cgp(i_rhor)
             cgp(i_rhor) = crp(i_rhor)*Fr+rhodep*(1.-Fr)*pi*sxth
             if (abs((cgp(i_rhor)-cgpold)/cgp(i_rhor)).lt.0.01) goto 115
          enddo
115       continue

       else  ! case of complete riming (Fr=1.0)

        ! set threshold size between partially-rimed and fully-rimed ice as arbitrary large
          dcrits = (cs/cgp(i_rhor))**(1./(dg-ds))
          dcritr = 1.e+6       ! here is the "arbitrary large"
          csr    = cgp(i_rhor)
          dsr    = dg

       endif

!---------------------------------------------------------------------------------------
! set up particle fallspeed arrays
! fallspeed is a function of mass dimension and projected area dimension relationships
! following mitchell and heymsfield (2005), jas

! set up array of particle fallspeed to make computationally efficient

! for high-resolution (in diameter space), ice fallspeed is stored in 'fall1' array (m/s)
! for lower-resolution (in diameter space), ice fallspeed is stored in 'fall2' array (m/s)
! rain fallspeed is stored in 'fallr' (m/s)

! loop over particle size

       jj_loop_1: do jj = 1,num_int_bins

        ! particle size (m)
          d1 = real(jj)*dd - 0.5*dd

        !----- get mass-size and projected area-size relationships for given size (d1)
        !      call get_mass_size

          if (d1.le.dcrit) then
             cs1  = pi*sxth*900.
             ds1  = 3.
             bas1 = 2.
             aas1 = pi/4.
          else if (d1.gt.dcrit.and.d1.le.dcrits) then
             cs1  = cs
             ds1  = ds
             bas1 = bas
             aas1 = aas
          else if (d1.gt.dcrits.and.d1.le.dcritr) then
             cs1  = cgp(i_rhor)
             ds1  = dg
             bas1 = bag
             aas1 = aag
          else if (d1.gt.dcritr) then
             cs1  = csr
             ds1  = dsr
             if (i_Fr.eq.1) then
                aas1 = aas
                bas1 = bas
             else
             ! for projected area, keep bas1 constant, but modify aas1 according to rimed fraction
                bas1 = bas
                dum1 = aas*d1**bas
                dum2 = aag*d1**bag
                m1   = cs1*d1**ds1
                m2   = cs*d1**ds
                m3   = cgp(i_rhor)*d1**dg
              ! linearly interpolate based on particle mass
                dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
              ! dum3 = (1.-Fr)*dum1+Fr*dum2              !DELETE?
                aas1 = dum3/(d1**bas)
             endif
          endif
        !=====

    ! correction for turbulence
       !  if (d1.lt.500.e-6) then
       !     a0 = 0.
       !     b0 = 0.
       !  else
       !     a0=1.7e-3
       !     b0=0.8
       !  endif
       ! neglect turbulent correction for aggregates for now (no condition)
          a0 = 0.
          b0 = 0.

    ! fall speed for particle
       ! Best number:
          xx = 2.*cs1*g*rho*d1**(ds1+2.-bas1)/(aas1*(mu*rho)**2)
       ! drag terms:
          b1 = c1*xx**0.5/(2.*((1.+c1*xx**0.5)**0.5-1.)*(1.+c1*xx**0.5)**0.5)-a0*b0*xx** &
               b0/(c2*((1.+c1*xx**0.5)**0.5-1.)**2)
          a1 = (c2*((1.+c1*xx**0.5)**0.5-1.)**2-a0*xx**b0)/xx**b1
        ! velocity in terms of drag terms
          falls1(jj) = a1*mu**(1.-2.*b1)*(2.*cs1*g/(rho*aas1))**b1*d1**(b1*(ds1-bas1+2.)-1.)

    !------------------------------------
    ! fall speed for rain particle (for ventilation coefficient of melting)

          dia = d1  ! diameter m
          amg = pi*sxth*997.*dia**3 ! mass [kg]
          amg = amg*1000.           ! convert kg to g

          if (dia.le.134.43e-6) then
             dum2 = 4.5795e5*amg**(2.*thrd)
             goto 100
          endif

          if(dia.lt.1511.64e-6) then
            dum2 = 4.962e3*amg**thrd
            goto 100
          endif

          if(dia.lt.3477.84e-6) then
            dum2 = 1.732e3*amg**sxth
            goto 100
          endif

          dum2 = 917.

100       continue

          fallr1(jj) = dum2*1.e-2   ! convert (cm s-1) to (m s-1)

     !------------------------------------
     ! Compute full mixed-phase particle velocity
     ! Linear interpolation to account for the liquid fraction
          fall1(jj) = Fl*fallr1(jj)+(1.-Fl)*falls1(jj)

       enddo jj_loop_1

     !................................................................
     ! fallspeed array for ice-ice and ice-rain collision calculations

       jj_loop_2: do jj = 1,num_int_coll_bins

        ! particle size:
          d1 = real(jj)*ddd - 0.5*ddd

          if (d1.le.dcrit) then
             cs1  = pi*sxth*900.
             ds1  = 3.
             bas1 = 2.
             aas1 = pi/4.
          else if (d1.gt.dcrit.and.d1.le.dcrits) then
             cs1  = cs
             ds1  = ds
             bas1 = bas
             aas1 = aas
          else if (d1.gt.dcrits.and.d1.le.dcritr) then
             cs1  = cgp(i_rhor)
             ds1  = dg
             bas1 = bag
             aas1 = aag
          else if (d1.gt.dcritr) then
             cs1  = csr
             ds1  = dsr
             if (i_Fr.eq.1) then
                aas1 = aas
                bas1 = bas
             else
          ! for area, keep bas1 constant, but modify aas1 according to rimed fraction
                bas1 = bas
                dum1 = aas*d1**bas
                dum2 = aag*d1**bag
              ! dum3 = (1.-Fr)*dum1+Fr*dum2
                m1   = cs1*d1**ds1
                m2   = cs*d1**ds
                m3   = cgp(i_rhor)*d1**dg
              ! linearly interpolate based on particle mass:
                dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                aas1 = dum3/(d1**bas)
             endif
          endif

      ! correction for turbulence
        ! if (d1.lt.500.e-6) then
        !    a0 = 0.
        !    b0 = 0.
        ! else
        !    a0=1.7e-3
        !    b0=0.8
        ! endif
       ! neglect turbulent correction for aggregates for now (no condition)
          a0 = 0.
          b0 = 0.

     ! fall speed for ice
       ! Best number:
          xx = 2.*cs1*g*rho*d1**(ds1+2.-bas1)/(aas1*(mu*rho)**2)
       ! drag terms
          b1 = c1*xx**0.5/(2.*((1.+c1*xx**0.5)**0.5-1.)*(1.+c1*xx**0.5)**0.5)-a0*b0*xx** &
               b0/(c2*((1.+c1*xx**0.5)**0.5-1.)**2)
          a1 = (c2*((1.+c1*xx**0.5)**0.5-1.)**2-a0*xx**b0)/xx**b1
        ! velocity in terms of drag terms
          falls(jj) = a1*mu**(1.-2.*b1)*(2.*cs1*g/(rho*aas1))**b1*d1**(b1*(ds1-bas1+2.)-1.)

     !------------------------------------
     ! fall speed for rain particle

          dia = d1  ! diameter m
          amg = pi*sxth*997.*dia**3 ! mass [kg]
          amg = amg*1000.           ! convert kg to g

          if (dia.le.134.43e-6) then
             dum2 = 4.5795e5*amg**(2.*thrd)
             goto 101
          endif

          if(dia.lt.1511.64e-6) then
             dum2 = 4.962e3*amg**thrd
            goto 101
          endif

          if(dia.lt.3477.84e-6) then
             dum2 = 1.732e3*amg**sxth
             goto 101
          endif

          dum2 = 917.

101       continue

          fallr(jj) = dum2*1.e-2   ! convert (cm s-1) to (m s-1)

          !------------------------------------
          ! Compute full mixed-phase particle velocity
          ! Linear interpolation to account for the liquid fraction
          fall2(jj) = Fl*fallr(jj)+(1.-Fl)*falls(jj)

       enddo jj_loop_2

!---------------------------------------------------------------------------------

     ! loop around normalized Q (Qnorm)
       i_Qnorm_loop: do i_Qnorm = 1,n_Qnorm

       ! lookup table values of normalized Qnorm
       ! (range of mean mass diameter from ~ 1 micron to x cm)

         !q = 261.7**((i_Qnorm+10)*0.1)*1.e-18    ! old (strict) lambda limiter
          q = 800.**((i_Qnorm+10)*0.1)*1.e-18     ! new lambda limiter
          qid = (1.-Fl)*800.**((i_Qnorm+10)*0.1)*1.e-18 !qi,ice = (1-Fi,liq)*qi,tot

!--uncomment to test and print proposed values of qovn
!         print*,i_Qnorm,(6./(pi*500.)*q)**0.3333
!      enddo
!      stop
!==

! test values
!  N = 5.e+3
!  q = 0.01e-3

        ! initialize qerror to arbitrarily large value:
          qerror = 1.e+20

!.....................................................................................
! Find parameters for gamma distribution

! First, the size distribution of dry ice Nd(D_dry)
! for the melting and the deposition/sublimation processes only
! Variable called mu_id, lamd, n0d are found using qid (qi,dry)
! Cholette et al. 2019 for details

   ! size distribution for ice is assumed to be
   ! Nd(D_dry) = n0d * Dd^mu_id * exp(-lamd*D_dry)

   ! for the given qid and N, we need to find n0d, mu_id, and lamd

   ! approach for finding lambda:
   ! cycle through a range of lambda, find closest lambda to produce correct qid

   ! start with lam, range of lam from 100 to 1 x 10^7 is large enough to
   ! cover full range over mean size from approximately 1 micron to x cm

      ! to make sure n0d, mu_id and lamd are set to 0 if i_Fl=4
        if (i_Fl.eq.1 .or. i_Fl.eq.2 .or. i_Fl.eq.3) then

             if (log_3momI) then
                ! it is assumed that mu_id is equals to mu
                mu_id = Z_value
             endif

          iteration_loopa: do i_iter = 1,n_iter_psdSolve

             ii_loop_a: do ii = 1,11000 ! this range of ii to calculate lambda chosen by trial and error for the given lambda limiter values

              ! lamd = 1.0013**ii*100.   ! old (strict) lambda_i limiter
                lamd = 1.0013**ii*10.    ! new lambda_i limiter

                if (.not. log_3momI) mu_id = diagnostic_mui(mu_i_min,mu_i_max,lamd,qid,cgp(i_rhor),Fr,pi)

              ! for lambda limiter:
                dum = Dm_max1+Dm_max2*Fr**2.
                lamd = max(lamd,(mu_id+1.)/dum)     ! set min lam corresponding to mean size of x
                lamd = min(lamd,(mu_id+1.)/Dm_min)  ! set max lam corresponding to mean size of Dm_min (2 micron)

              ! normalized n0d:
                n0d = lamd**(mu_id+1.)/(gamma(mu_id+1.))

              ! calculate integral for each of the 4 parts of the size distribution
              ! check difference with respect to Qnorm

              ! set up m-D relationship for solid ice with D < Dcrit:
                cs1  = pi*sxth*900.
                ds1  = 3.

                call intgrl_section(lamd,mu_id, ds1,ds,dg,dsr, dcrit,dcrits,dcritr,intgrR1,intgrR2,intgrR3,intgrR4)
              ! intgrR1 is integral from 0 to dcrit       (solid ice)
              ! intgrR2 is integral from dcrit to dcrits  (unrimed large ice)
              ! intgrR3 is integral from dcrits to dcritr (fully rimed ice)
              ! intgrR4 is integral from dcritr to inf    (partially rimed)

              ! sum of the integrals from the 4 regions of the size distribution:
                qdum = n0d*(cs1*intgrR1 + cs*intgrR2 + cgp(i_rhor)*intgrR3 + csr*intgrR4)

                if (ii.eq.1) then
                   qerror = abs(qid-qdum)
                   lamf   = lamd
                endif

                ! find lam with smallest difference between Qnorm and estimate of Qnorm, assign to lamf
                if (abs(qid-qdum).lt.qerror) then
                   lamf   = lamd
                   qerror = abs(qid-qdum)
                endif

             enddo ii_loop_a

           ! check and print relative error in q to make sure it is not too large
           ! note: large error is possible if size bounds are exceeded!!!!!!!!!!
           ! print*,'qerror (%)',qerror/q*100.

           ! find n0 based on final lam value
           ! set final lamf to 'lam' variable
           ! this is the value of lam with the smallest qerror
             lamd = lamf

             if (.not. log_3momI) mu_id = diagnostic_mui(mu_i_min,mu_i_max,lamd,qid,cgp(i_rhor),Fr,pi)

           ! n0d = N*lamd**(mu_id+1.)/(gamma(mu_id+1.))

           ! find n0 from lam and Qnorm:
           !   (this is done instead of finding n0 from lam and N, since N;
           !    may need to be adjusted to constrain mean size within reasonable bounds)
             call intgrl_section(lamd,mu_id, ds1,ds,dg,dsr, dcrit,dcrits,dcritr,intgrR1,intgrR2,intgrR3,intgrR4)
             n0d   = qid/(cs1*intgrR1 + cs*intgrR2 + cgp(i_rhor)*intgrR3 + csr*intgrR4)

           ! print*,'lamd,N0d,mud:',lamd,n0d,mu_id

           ! calculate normalized mom3 directly from PSD parameters (3-moment-ice only)
           !  if (log_3momI) then
           !     mom3 = n0d*gamma(4.+mu_id)/lamd**(4.+mu_id)
           !   ! update normalized mom6 based on the updated ratio of normalized mom3 and normalized Q
           !   ! (we want mom6 normalized by mom3 not q)
           !     dum  = mom3/qid
           !     mom6 = Zid/dum
           !  endif  !log_3momI

          enddo iteration_loopa

        elseif (i_Fl.eq.4) then
          mu_id = 0. ! will not be really used since n0d=0 (sum = 0)
          n0d   = 0.
          lamd  = 0.
        endif ! loop over i_Fl

!.....................................................................................
! At this point, we have solved for the dry ice size distribution parameters (n0d, lamd, mu_id)
!.....................................................................................

! Second, the size distribution of wet ice N(D_p) for all other processes
! Note D_p is full particle diameter (containing liquid and dry ice)
! Variable will be call mu_i, lam, n0 and are found using q (qi,tot)
! See Cholette et al. 2019 for details
! Note that mu_id is needed to compute diagnostic mu_i

   ! size distribution for ice is assumed to be
   ! N(D_p) = n0 * D_p^mu_i * exp(-lam*D_p)

   ! for the given q and N, we need to find n0, mu_i, and lam

   ! approach for finding lambda:
   ! cycle through a range of lambda, find closest lambda to produce correct q

   ! start with lam, range of lam from 100 to 1 x 10^7 is large enough to
   ! cover full range over mean size from approximately 1 micron to x cm

   ! compute mean density assuming rho_dry is cgp(i_rhor)
   ! rhomdry = cgp(i_rhor) (for 2momI only)
    rhom = (1.-Fl)*cgp(i_rhor)+Fl*1000.*pi*sxth

! HM, no longer needed
!          if (log_3momI) then
!             ! assign provisional values for mom3 (first guess for mom3)
!             ! NOTE: these are normalized: mom3 = M3/M0, mom6 = M6/M3 (M3 = 3rd moment, etc.)
!             mom3 = q/rhom     !note: cgp is pi/6*(mean_density), computed above
!             ! update normalized mom6 based on the updated ratio of normalized mom3 and normalized Q
!             ! (we want mom6 normalized by mom3 not q)
!             dum = mom3/q
!             mom6 = Z_value/dum
!          endif  !log_3momI
!          !==

          iteration_loop1: do i_iter = 1,n_iter_psdSolve

          if (log_3momI) then
           ! compute mu_i from normalized mom3 and mom6:
! HM set to loop value of mu (temporarily called Z_value)
!                mu_i = compute_mu_3moment(mom3,mom6,mu_i_max)
!                mu_i = max(mu_i,mu_i_min)  ! make sure mu_i >= 0 (otherwise size dist is infinity at D = 0)
!                mu_i = min(mu_i,mu_i_max)  ! set upper limit
                mu_i = Z_value
          endif

          ii_loop_1: do ii = 1,11000 ! this range of ii to calculate lambda chosen by trial and error for the given lambda limiter values

           ! lam = 1.0013**ii*100.   ! old (strict) lambda_i limiter
             lam = 1.0013**ii*10.    ! new lambda_i limiter

           ! solve for mu_i for 2-moment-ice:
             if (.not. log_3momI) mu_i = diagnostic_mui_Fl(mu_i_min,mu_i_max,mu_id,lam,q,cgp(i_rhor),Fr,Fl,rhom,pi)

           ! for lambda limiter:
            !dum = Dm_max+Fr*(3000.e-6)
             dum = Dm_max1+Dm_max2*Fr**2.
             lam = max(lam,(mu_i+1.)/dum)     ! set min lam corresponding to mean size of x
             lam = min(lam,(mu_i+1.)/Dm_min)  ! set max lam corresponding to mean size of Dm_min (2 micron)

           ! normalized n0:
             n0 = lam**(mu_i+1.)/(gamma(mu_i+1.))

           ! calculate integral for each of the 4 parts of the size distribution
           ! check difference with respect to Qnorm

           ! set up m-D relationship for solid ice with D < Dcrit:
             cs1  = pi*sxth*900.
             ds1  = 3.
             cs5  = pi*sxth*1000.

             call intgrl_section_Fl(lam,mu_i, ds1,ds,dg,dsr, dcrit,dcrits,dcritr,intgrR1,intgrR2,intgrR3,intgrR4,intgrR5)
           ! intgrR1 is integral from 0 to dcrit       (solid ice)
           ! intgrR2 is integral from dcrit to dcrits  (unrimed large ice)
           ! intgrR3 is integral from dcrits to dcritr (fully rimed ice)
           ! intgrR4 is integral from dcritr to inf    (partially rimed)

           ! sum of the integrals from the 4 regions of the size distribution:
             qdum = n0*((1.-Fl)*(cs1*intgrR1 + cs*intgrR2 + cgp(i_rhor)*intgrR3 + csr*intgrR4)+Fl*cs5*intgrR5)

             if (ii.eq.1) then
                qerror = abs(q-qdum)
                lamf   = lam
             endif

           ! find lam with smallest difference between Qnorm and estimate of Qnorm, assign to lamf
             if (abs(q-qdum).lt.qerror) then
                lamf   = lam
                qerror = abs(q-qdum)
             endif

          enddo ii_loop_1

        ! check and print relative error in q to make sure it is not too large
        ! note: large error is possible if size bounds are exceeded!!!!!!!!!!
        ! print*,'qerror (%)',qerror/q*100.

        ! find n0 based on final lam value
        ! set final lamf to 'lam' variable
        ! this is the value of lam with the smallest qerror
          lam = lamf

        ! recalculate mu_i based on final lam  (for 2-moment-ice only; not needed for 3-moment-ice)
          if (.not. log_3momI) mu_i = diagnostic_mui_Fl(mu_i_min,mu_i_max,mu_id,lam,q,cgp(i_rhor),Fr,Fl,rhom,pi)

        ! n0 = N*lam**(mu_i+1.)/(gamma(mu_i+1.))

        ! find n0 from lam and Qnorm:
        !   (this is done instead of finding n0 from lam and N, since N;
        !    may need to be adjusted to constrain mean size within reasonable bounds)

          call intgrl_section_Fl(lam,mu_i, ds1,ds,dg,dsr, dcrit,dcrits,dcritr,intgrR1,intgrR2,intgrR3,intgrR4,intgrR5)
          n0   = q/((1.-Fl)*(cs1*intgrR1 + cs*intgrR2 + cgp(i_rhor)*intgrR3 + csr*intgrR4)+Fl*cs5*intgrR5)

        ! print*,'lam,N0,mu:',lam,n0,mu_i

        ! calculate normalized mom3 directly from PSD parameters (3-moment-ice only)
! HM no longer needed
!          if (log_3momI) then
!             mom3 = n0*gamma(4.+mu_i)/lam**(4.+mu_i)
!        ! update normalized mom6 based on the updated ratio of normalized mom3 and normalized Q
!        ! (we want mom6 normalized by mom3 not q)
!             dum  = mom3/q
!             mom6 = Z_value/dum
!          endif  !log_3momI

       enddo iteration_loop1

       lambda_i(i_Qnorm,i_Fr,i_Fl)  = lam
       mu_i_save(i_Qnorm,i_Fr,i_Fl) = mu_i

!.....................................................................................
! At this point, we have solved for the mixed-phase ice size distribution parameters (n0, lam, mu_i)
!.....................................................................................

!.....................................................................................
! find max/min Q* to constrain mean size (i.e. lambda limiter), this is stored and passed to
! lookup table, so that N (nitot) can be adjusted during the simulation to constrain mean size
! (computed and written as the inverses (i_qsmall,i_qlarge) to avoid run-time division in p3_main)

! set up m-D relationship for solid ice with D < Dcrit:
  cs1  = pi*sxth*900.
  ds1  = 3.
  cs5  = pi*sxth*1000.

   ! limit based on min size, Dm_min (2 micron):
          duml = (mu_i+1.)/Dm_min
          call intgrl_section_Fl(duml,mu_i, ds1,ds,dg,dsr, dcrit,dcrits,dcritr,intgrR1,intgrR2,intgrR3,intgrR4,intgrR5)
          n0dum = q/((1.-Fl)*(cs1*intgrR1 + cs*intgrR2 + cgp(i_rhor)*intgrR3 + csr*intgrR4)+Fl*cs5*intgrR5)

         !find maximum N applying the lambda limiter (lower size limit)
          dum =	n0dum/(duml**(mu_i+1.)/(gamma(mu_i+1.)))

         !calculate the lower limit of normalized Q to use in P3 main
         !(this is based on the lower limit of mean size so we call this 'qsmall')
         !qsmall(i_Qnorm,i_Fr) = q/dum
          i_qsmall(i_Qnorm,i_Fr,i_Fl) = dum/q


   ! limit based on max size, Dm_max:
          dum = Dm_max1+Dm_max2*Fr**2.
          duml = (mu_i+1.)/dum

          call intgrl_section_Fl(duml,mu_i, ds1,ds,dg,dsr, dcrit,dcrits,dcritr,intgrR1,intgrR2,intgrR3,intgrR4,intgrR5)
          n0dum = q/((1.-Fl)*(cs1*intgrR1 + cs*intgrR2 + cgp(i_rhor)*intgrR3 + csr*intgrR4)+Fl*cs5*intgrR5)

        ! find minium N applying the lambda limiter (lower size limit)
          dum = n0dum/(duml**(mu_i+1.)/(gamma(mu_i+1.)))

        ! calculate the upper limit of normalized Q to use in P3 main
        ! (this is based on the upper limit of mean size so we call this 'qlarge')
         !qlarge(i_Qnorm,i_Fr) = q/dum
          i_qlarge(i_Qnorm,i_Fr,i_Fl) = dum/q

        ! calculate bounds for normalized Z based on min/max allowed mu: (3-moment-ice only)
! HM no longer needed, don't need to calculate or output zlarge and zsmall
!          if (log_3momI) then
!             mu_dum = mu_i_min
!             gdum   = (6.+mu_dum)*(5.+mu_dum)*(4.+mu_dum)/((3.+mu_dum)*(2.+mu_dum)*(1.+mu_dum))
!             dum    = mom3/q
!             zlarge(i_Qnorm,i_Fr,i_Fl) = gdum*mom3*dum
!             mu_dum = mu_i_max
!             gdum   = (6.+mu_dum)*(5.+mu_dum)*(4.+mu_dum)/((3.+mu_dum)*(2.+mu_dum)*(1.+mu_dum))
!             zsmall(i_Qnorm,i_Fr,i_Fl) = gdum*mom3*dum
!          endif  !if (log_3momI)

!.....................................................................................
! begin moment and microphysical process calculations for the lookup table

!.....................................................................................
! mass- and number-weighted mean fallspeed (m/s)
! add reflectivity
!.....................................................................................

! assume conditions for t and p as assumed above (giving rhos), then in microphysics scheme
! multiply by density correction factor (rhos/rho)^0.54, from Heymsfield et al. 2006

! fallspeed formulation from Mitchell and Heymsfield 2005

           ! initialize for numerical integration
          sum1 = 0.
          sum2 = 0.
          sum3 = 0.
          sum4 = 0.
          sum5 = 0.
          sum6 = 0.  ! mass mean size
          sum7 = 0.  ! mass-weighted mean density
          sum8 = 0.  ! 6th moment * velocity   [3momI only]
          sum9 = 0.  ! 6th moment              [3momI only]

        ! numerically integrate over size distribution
          ii_loop_2: do ii = 1,num_int_bins

             dum = real(ii)*dd - 0.5*dd   ! particle size

            !assign mass-size parameters (depending on size at ii)
             if (dum.le.dcrit) then
                ds1 = 3.
                cs1 = pi*sxth*900.
             else if (dum.gt.dcrit.and.dum.le.dcrits) then
                ds1 = ds
                cs1 = cs
             elseif (dum.gt.dcrits.and.dum.le.dcritr) then
                ds1 = dg
                cs1 = cgp(i_rhor)
             elseif (dum.gt.dcritr) then
                ds1 = dsr
                cs1 = csr
             endif

        ! These processes assume the liquid and the dry components of ice (add Fl)
        ! See Cholette et al. 2019 for details
             mass = (1.-Fl)*cs1*dum**ds1+Fl*pi*sxth*1000.*dum**3.

           ! numerator of number-weighted velocity - sum1:
             sum1 = sum1+fall1(ii)*dum**mu_i*exp(-lam*dum)*dd

           ! numerator of mass-weighted velocity - sum2:
             sum2 = sum2+fall1(ii)*mass*dum**(mu_i)*exp(-lam*dum)*dd

           ! total number and mass for weighting above fallspeeds:
           !  (note: do not need to include n0 and cs since these parameters are in both numerator and denominator
            !denominator of number-weighted V:
             sum3 = sum3+dum**mu_i*exp(-lam*dum)*dd

            !denominator of mass-weighted V:
             sum4 = sum4+mass*dum**(mu_i)*exp(-lam*dum)*dd

            !reflectivity (integral of mass moment squared):
             sum5 = sum5+n0*(6./(pi*917.))**2*mass**2*dum**mu_i*exp(-lam*dum)*dd

            !numerator of mass-weighted mean size
             sum6 = sum6+mass*dum**(mu_i+1.)*exp(-lam*dum)*dd

            !numerator of mass-weighted density:
            ! particle density is defined as mass divided by volume of sphere with same D
             sum7 = sum7+mass**2/(pi*sxth*dum**3)*dum**mu_i*exp(-lam*dum)*dd

            !numerator in 6th-moment-weight fall speed     [3momI only]
             sum8 = sum8 + fall1(ii)*dum**(mu_i+6.)*exp(-lam*dum)*dd

            !denominator in 6th-moment-weight fall speed   [3momI only]
             sum9 = sum9 + dum**(mu_i+6.)*exp(-lam*dum)*dd

          enddo ii_loop_2

        ! save mean fallspeeds for lookup table:
          uns(i_Qnorm,i_Fr,i_Fl)   = sum1/sum3
          ums(i_Qnorm,i_Fr,i_Fl)   = sum2/sum4
          refl(i_Qnorm,i_Fr,i_Fl)  = sum5
          dmm(i_Qnorm,i_Fr,i_Fl)   = sum6/sum4
          rhomm(i_Qnorm,i_Fr,i_Fl) = sum7/sum4
          if (log_3momI) then
             uzs(i_Qnorm,i_Fr,i_Fl) = sum8/sum9
!            write(6,'(a12,3e15.5)') 'uzs,ums,uns',uzs(i_Qnorm,i_Fr,i_Fl),ums(i_Qnorm,i_Fr,i_Fl),uns(i_Qnorm,i_Fr,i_Fl)
          endif

!.....................................................................................
! Reflectivity (based on WRF) for mixed-phase particles
!.....................................................................................

          ! initialize for numerical integration
          sum1 = 0.

          ! numerically integrate over size distribution
            ii_loop_refl2: do ii = 1,num_int_bins

               dum = real(ii)*dd - 0.5*dd   ! particle size

               !assign mass-size parameters (depending on size at ii)
               if (dum.le.dcrit) then
                  ds1 = 3.
                  cs1 = pi*sxth*900.
               else if (dum.gt.dcrit.and.dum.le.dcrits) then
                  ds1 = ds
                  cs1 = cs
               elseif (dum.gt.dcrits.and.dum.le.dcritr) then
                  ds1 = dg
                  cs1 = cgp(i_rhor)
               elseif (dum.gt.dcritr) then
                  ds1 = dsr
                  cs1 = csr
               endif

               ! These processes assume the liquid and the dry components of ice (add Fl)
               ! See Cholette et al. 2019 for details
               mass = (1.-Fl)*cs1*dum**ds1+Fl*pi*sxth*1000.*dum**3.
               m_water = Fl*mass
               m_ice = (1.-Fl)*mass

               if (i_Fl.eq.1) then
                  !reflectivity (integral of mass moment squared): (original version)
                  sum1 = sum1+0.1892*n0*(6./(pi*917.))**2*mass**2*dum**mu_i*exp(-lam*dum)*dd
               elseif (i_Fl.eq.2 .or. i_Fl.eq.3) then
                  !applied WRF code to account for the liquid fraction
                  call rayleigh_soak_wetice(lamda4,pi,pi5,mass,m_water,m_ice,dum,Fl,melt_outside,m_w_0,m_i_0, &
                        lamda_radar,cback,m_air,mixingrulestring_m,matrixstring_m,inclusionstring_m,          &
                        hoststring_m,hostmatrixstring_m,hostinclusionstring_m)
                 sum1 = sum1+lamda4/(pi5*K_w)*n0*dum**mu_i*exp(-lam*dum)*cback*dd
               elseif (i_Fl.eq.4) then
                  !consider as if water drops (6th moment)
                  sum1 = sum1+n0*dum**mu_i*exp(-lam*dum)*dum**6.*dd
               endif

            enddo ii_loop_refl2

          refl2(i_Qnorm,i_Fr,i_Fl)  = sum1

!.....................................................................................
! self-aggregation
!.....................................................................................
! This process is applied to the whole particle
! (the liquid and the dry components of ice)
! See Cholette et al. 2019 for details

          sum1 = 0.

          numloss(:) = 0.
          massloss(:) = 0.
          massgain(:) = 0.

        ! set up binned distribution of ice
          do jj = num_int_coll_bins,1,-1
             d1      = real(jj)*ddd - 0.5*ddd
             num(jj) = n0*d1**mu_i*exp(-lam*d1)*ddd
          enddo !jj-loop

       ! loop over exponential size distribution
!        !   note: collection of ice within the same bin is neglected

          jj_loop_3: do jj = num_int_coll_bins,1,-1
             kk_loop_1: do kk = 1,jj-1

              ! particle size:
                d1 = real(jj)*ddd - 0.5*ddd
                d2 = real(kk)*ddd - 0.5*ddd

                if (d1.le.dcrit) then
                   bas1 = 2.
                   aas1 = pi*0.25
                elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                   bas1 = bas
                   aas1 = aas
                else if (d1.gt.dcrits.and.d1.le.dcritr) then
                   bas1 = bag
                   aas1 = aag
                else if (d1.gt.dcritr) then
                   cs1 = csr
                   ds1 = dsr
                   if (i_Fr.eq.1) then
                      aas1 = aas
                      bas1 = bas
                   else
                    ! for area, keep bas1 constant, but modify aas1 according to rimed fraction
                      bas1 = bas
                      dum1 = aas*d1**bas
                      dum2 = aag*d1**bag
                      m1   = cs1*d1**ds1
                      m2   = cs*d1**ds
                      m3   = cgp(i_rhor)*d1**dg
                    ! linearly interpolate based on particle mass
                      dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                      aas1 = dum3/(d1**bas)
                   endif
                endif

              ! total projected area for particle 1
                area1 = (1.-Fl)*aas1*d1**bas1+Fl*pi/4.*d1**2.

                ! parameters for particle 2

                if (d2.le.dcrit) then
                   bas2 = 2.
                   aas2 = pi/4.
                elseif (d2.gt.dcrit.and.d2.le.dcrits) then
                   bas2 = bas
                   aas2 = aas
                elseif (d2.gt.dcrits.and.d2.le.dcritr) then
                   bas2 = bag
                   aas2 = aag
                elseif (d2.gt.dcritr) then
                   cs2 = csr
                   ds2 = dsr
                   if (i_Fr.eq.1) then
                      aas2 = aas
                      bas2 = bas
                   else
                   ! for area, keep bas1 constant, but modify aas1 according to rime fraction
                      bas2 = bas
                      dum1 = aas*d2**bas
                      dum2 = aag*d2**bag
                      m1   = cs2*d2**ds2
                      m2   = cs*d2**ds
                      m3   = cgp(i_rhor)*d2**dg
                    ! linearly interpolate based on particle mass
                      dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                      aas2 = dum3/(d2**bas)
                   endif
                endif

              ! total projected area for particle 2
                area2 = (1.-Fl)*aas2*d2**bas2+Fl*pi/4.*d2**2.

              ! differential fallspeed:
              !  (note: in P3_MAIN  must multiply by air density correction factor, and collection efficiency
                delu = abs(fall2(jj)-fall2(kk))

        ! get m-D relation for particle 2 to obtain mass
                if (d2.le.dcrit) then
                cs1  = pi*sxth*900.
                ds1  = 3.
             elseif (d2.gt.dcrit.and.d2.le.dcrits) then
                cs1  = cs
                ds1  = ds
             elseif (d2.gt.dcrits.and.d2.le.dcritr) then
                cs1  = cgp(i_rhor)
                ds1  = dg
             elseif (d2.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
             endif

             mass2 = (1.-Fl)*cs1*d2**ds1+Fl*pi*sxth*1000.*d2**3.

!..........................

              ! sum for integral

              ! sum1 = # of collision pairs
              !  the assumption is that each collision pair reduces crystal
              !  number mixing ratio by 1 kg^-1 s^-1 per kg/m^3 of air (this is
              !  why we need to multiply by air density, to get units of 1/kg^-1 s^-1)

                sum1 = sum1+(sqrt(area1)+sqrt(area2))**2*delu*num(jj)*num(kk)

                ! distribution of particles removed, mass removed, and mass gained
                numloss(kk) = numloss(kk)+(sqrt(area1)+sqrt(area2))**2*delu*num(jj)*num(kk)
                massloss(kk) = massloss(kk)+(sqrt(area1)+sqrt(area2))**2*delu*num(jj)*num(kk)*mass2
                massgain(jj) = massgain(jj)+(sqrt(area1)+sqrt(area2))**2*delu*num(jj)*num(kk)*mass2

                 ! remove collected particles from distribution over time period dt, update num
                 !  note -- dt is time scale for removal, not model time step
                 !                   num(kk) = num(kk)-(sqrt(area1)+sqrt(area2))**2*delu*num(jj)*num(kk)*dt
                 !                   num(kk) = max(num(kk),0.)

                 ! write(6,'(2i5,8e15.5)')jj,kk,sum1,num(jj),num(kk),delu,aas1,d1,aas2,d2
                 ! num(kk)=num(kk)-(sqrt(area1)+sqrt(area2))**2*delu*num(jj)*num(kk)*0.1*0.5
                 ! num(kk)=max(num(kk),0.)
                 ! sum1 = sum1+0.5*(sqrt(area1)+sqrt(area2))**2*delu*n0*n0*(d1+d2)**mu_i*exp(-lam*(d1+d2))*dd**2

             enddo kk_loop_1
          enddo jj_loop_3

          threemom_3: if (log_3momI) then
          
! calculate change in M6
          
           sum2 = 0. ! M6 change from number loss
           sum3 = 0. ! M6 change from mass gain
           sum4 = 0. ! M3 change from number loss
           sum5 = 0. ! M3 change from mass gain

           do kk=1,num_int_coll_bins

! define particle size in kk loop
             d2 = real(kk)*ddd - 0.5*ddd

! define particle mass as as function of d2 here

      ! get m-D relation to obtain dmdD
             if (d2.le.dcrit) then
                cs1  = pi*sxth*900.
                ds1  = 3.
             elseif (d2.gt.dcrit.and.d2.le.dcrits) then
                cs1  = cs
                ds1  = ds
             elseif (d2.gt.dcrits.and.d2.le.dcritr) then
                cs1  = cgp(i_rhor)
                ds1  = dg
             elseif (d2.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
             endif

             ! dmdD, accounting for weighting by liquid fraction
             dmdD = (1.-Fl)*cs1*ds1*d2**(ds1-1.) + 3.*Fl*pi*sxth*1000.*d2**2
!..........................

! M6 change from number loss rate
             sum2 = sum2 - numloss(kk)*d2**6
! M6 change from mass gain (note: massgain = dm/dt*num(kk))
             sum3 = sum3 + massgain(kk)/dmdD*6.*d2**5 !(dM/dt*dD/dm*6*D^5)
! M3 change from number loss rate
             sum4 = sum4 - numloss(kk)*d2**3
! M3 change from mass gain (note: massgain = dm/dt*num(kk))
             sum5 = sum5 + massgain(kk)/dmdD*3.*d2**2 !(dM/dt*dD/dm*3*D^2)

           enddo ! kk loop

          endif threemom_3
          
          nagg(i_Qnorm,i_Fr,i_Fl) = sum1  ! save to write to output

          if (log_3momI) then
             mom6 = n0*gamma(mu_i+7.)/lam**(mu_i+7.)
             mom3 = n0*gamma(mu_i+4.)/lam**(mu_i+4.)
             ! change in relative variance
             m6agg(i_Qnorm,i_Fr,i_Fl) = mom6/mom3**2*sum1 + 1./mom3**2*(sum2+sum3) &
                                     -2.*mom6/mom3**3*(sum4+sum5)
          endif
          
!         print*,'nagg',nagg(i_Qnorm,i_Fr)

!.....................................................................................
! collection of cloud droplets and aerosols
!.....................................................................................
! note: In P3_MAIN, needs to be multiplied by collection efficiency Eci
!       Also needs to be multiplied by air density correction factor for fallspeed,
! !       air density, and cloud water mixing ratio or number concentration

        ! initialize sum for integral
          sum1 = 0.
          sum3 = 0. !qshed (with Fl)
          if (log_3momI) then
             sum2 = 0. !dM6/dt
             sum4 = 0. !M_bb moment for zshed calculation
             sum5 = 0. !dM3/dt
          endif
          sum6 = 0. !for niawcol
          sum7 = 0. !for niaicol
             
        ! loop over exponential size distribution (from 1 micron to 2 cm)
          jj_loop_4:  do jj = 1,num_int_bins

             d1 = real(jj)*dd - 0.5*dd  ! particle size or dimension (m) for numerical integration

              ! get mass-dimension and projected area-dimension relationships
              ! for different ice types across the size distribution based on critical dimensions
              ! separating these ice types (see Fig. 2, morrison and grabowski 2008)

              ! mass = cs1*D^ds1
              ! projected area = bas1*D^bas1
             if (d1.le.dcrit) then
                cs1  = pi*sxth*900.
                ds1  = 3.
                bas1 = 2.
                aas1 = pi*0.25
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                cs1  = cs
                ds1  = ds
                bas1 = bas
                aas1 = aas
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cs1  = cgp(i_rhor)
                ds1  = dg
                bas1 = bag
                aas1 = aag
             elseif (d1.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
                if (i_Fr.eq.1) then
                   aas1 = aas
                   bas1 = bas
                else
                ! for area, ! keep bas1 constant, but modify aas1 according to rimed fraction
                   bas1 = bas
                   dum1 = aas*d1**bas
                   dum2 = aag*d1**bag
                   m1   = cs1*d1**ds1
                   m2   = cs*d1**ds
                   m3   = cgp(i_rhor)*d1**dg
                 ! linearly interpolate based on particle mass
                   dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                   aas1 = dum3/(d1**bas)
                endif
             endif

             mass = (1.-Fl)*cs1*d1**ds1+Fl*pi*sxth*1000.*d1**3.
             area = (1.-Fl)*aas1*d1**bas1+Fl*pi/4.*d1**2.
             dmdD = (1.-Fl)*cs1*ds1*d1**(ds1-1.) + 3.*Fl*pi*sxth*1000.*d1**2

            ! sum for integral
            ! include assumed ice particle size threshold for riming of 100 micron
            ! note: sum1 (nrwat) is the scaled collection rate, units of m^3 kg^-1 s^-1


             if (d1.ge.100.e-6) then
                sum1 = sum1 + area*fall1(jj)*n0*d1**mu_i*exp(-lam*d1)*dd
                if (log_3momI) then
! dM6/dt = int(6*D^5*dD/dt*D^(mu)*n0*D^mu*exp(-lam*D)*dD)
                   sum2 = sum2 + 6.*d1**5*area*fall1(jj)*n0*d1**mu_i*exp(-lam*d1)*dd/dmdD
! M_bb moment
                   sum4 = sum4 + d1**bb*n0*d1**mu_i*exp(-lam*d1)*dd
! dM3/dt
                   sum5 = sum5 + 3.*d1**2*area*fall1(jj)*n0*d1**mu_i*exp(-lam*d1)*dd/dmdD
                endif
             endif

             ! Collection with aerosols (assuming Daw and Dai)
             ! for Effaw (water-friendly aerosols)
             Re    = 0.5*rho*d1*fall1(jj)/mu
             wcc    = 1. + 2.*meanpath/Daw *(1.257+0.4*exp(-0.55*Daw/meanpath))
             diffin  = boltzman*t*wcc/(3.*pi*mu*Daw)
             Sc    = mu/(rho*diffin)
             St    = Daw*Daw*fall1(jj)*1000.*wcc/(9.*mu*d1)
             aval  = log(1.+Re)
             St2   = (1.2 + 1./12.*aval)/(1.+aval)
             Effw = 4./(Re*Sc) * (1. + 0.4*Re**0.5*Sc**0.3333             &
                         + 0.16*Re**0.5*Sc**0.5)                         &
                         + 4.*Daw/d1 * (0.02 + Daw/d1*(1.+2.*Re**0.5))
             if (St.gt.St2) Effw = Effw  + ( (St-St2)/(St-St2+0.666667))**1.5
             eiaw = max(1.e-5, min(Effw, 1.0))

             ! for Effai (ice-friendly aerosols)
             icc    = 1. + 2.*meanpath/Dai *(1.257+0.4*exp(-0.55*Dai/meanpath))
             diffin  = boltzman*t*icc/(3.*pi*mu*Dai)
             Sc    = mu/(rho*diffin)
             St    = Dai*Dai*fall1(jj)*1000.*icc/(9.*mu*d1)
             aval  = log(1.+Re)
             St2   = (1.2 + 1./12.*aval)/(1.+aval)
             Effi = 4./(Re*Sc) * (1. + 0.4*Re**0.5*Sc**0.3333             &
                         + 0.16*Re**0.5*Sc**0.5)                         &
                         + 4.*Dai/d1 * (0.02 + Dai/d1*(1.+2.*Re**0.5))
             if (St.gt.St2) Effi = Effi  + ( (St-St2)/(St-St2+0.666667))**1.5
             eiai = max(1.e-5, min(Effi, 1.0))

             sum6 = sum6+area*eiaw*fall1(jj)*n0*d1**mu_i*exp(-lam*d1)*dd
             sum7 = sum7+area*eiai*fall1(jj)*n0*d1**mu_i*exp(-lam*d1)*dd

!.....................................................................................
! shedding
!.....................................................................................
! Shedding from mixed-phase ice is assumed to occur when Fr > 0 (included in main)
! and only for particles with D<9 mm (Rasmussen et al. 2011) (computed here)
! Note that shedding is a new process and is not related to the collection of cloud
! even if it is computed here

             if (d1.ge.0.009) then
                sum3 = sum3+mass*n0*d1**mu_i*exp(-lam*d1)*dd
             endif

          enddo jj_loop_4

        ! save for output
          nrwat(i_Qnorm,i_Fr,i_Fl) = sum1    ! note: read in as 'f1pr4' in P3_MAIN

          qshed(i_Qnorm,i_Fr,i_Fl) = sum3

          nawcol(i_Qnorm,i_Fr,i_Fl) = sum6
          naicol(i_Qnorm,i_Fr,i_Fl) = sum7

          threemom_1: if (log_3momI) then
             
             mom6 = n0*gamma(mu_i+7.)/lam**(mu_i+7.)
             mom3 = n0*gamma(mu_i+4.)/lam**(mu_i+4.)
             m6rime(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum2 - 2.*mom6/mom3**3*sum5 ! change in relative variance
             
! m6 change from shedding

             sum1 = 0. ! M6 change
             sum2 = 0. ! M3 change

             jj_loop_40:  do jj = 1,num_int_bins

             d1 = real(jj)*dd - 0.5*dd  ! particle size or dimension (m) for numerical integration

             ! get m-D relation to obtain dmdD
             if (d1.le.dcrit) then
                cs1  = pi*sxth*900.
		ds1  = 3.
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
		cs1  = cs
                ds1  = ds
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cs1  = cgp(i_rhor)
		ds1  = dg
             elseif (d1.gt.dcritr) then
                cs1 = csr
		ds1 = dsr
             endif

             ! dmdD, accounting for weighting by liquid fraction
             dmdD = (1.-Fl)*cs1*ds1*d1**(ds1-1.) + 3.*Fl*pi*sxth*1000.*d1**2
!..........................

             if (d1.ge.0.009 .and. sum4.gt.0.) then
             ! = dm/dt*dD/dm, dm/dt = sum3/sum4*D^bb
                sum1 = sum1+6.*d1**5*sum3/sum4*d1**bb*n0*d1**mu_i*exp(-lam*d1)*dd/dmdD
                sum2 = sum2+3.*d1**2*sum3/sum4*d1**bb*n0*d1**mu_i*exp(-lam*d1)*dd/dmdD
             endif

             enddo jj_loop_40

             mom6 = n0*gamma(mu_i+7.)/lam**(mu_i+7.)
             mom3 = n0*gamma(mu_i+4.)/lam**(mu_i+4.)
             m6shd(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum1 - 2.*mom6/mom3**3*sum2 ! change in relative variance

          endif threemom_1
          
!.....................................................................................
! collection of rain
!.....................................................................................

! note: In P3_MAIN, we need to multiply rate by n0r, collection efficiency,
!       air density, and air density correction factor

! This approach implicitly assumes that the PSDs are constant during the microphysics
! time step, this could produce errors if the time step is large. In particular,
! more mass or number could be removed than is available. This will be taken care
! of by conservation checks in the microphysics code.

        ! loop around lambda for rain
          i_Drscale_loop:  do i_Drscale = 1,n_Drscale

             print*,'** STATUS: ',i_rhor, i_Fr, i_Fl, i_Qnorm, i_Drscale

             dum = 1.24**i_Drscale*10.e-6

           ! assumed lamv for tests
           !    dum = 7.16e-5
           ! note: lookup table for rain is based on lamv, i.e.,inverse volume mean diameter
             lamv             = 1./dum
             lamrs(i_Drscale) = lamv

           ! get mu_r from lamr:
           !  dum = 1./lamv

           !  if (dum.lt.282.e-6) then
           !     mu_r = 8.282
           !  elseif (dum.ge.282.e-6 .and. dum.lt.502.e-6) then
           !   ! interpolate:
           !     rdumii = (dum-250.e-6)*1.e6*0.5
           !     rdumii = max(rdumii,1.)
           !     rdumii = min(rdumii,150.)
           !     dumii  = int(rdumii)
           !     dumii  = min(149,dumii)
           !     mu_r   = mu_r_table(dumii)+(mu_r_table(dumii+1)-mu_r_table(dumii))*(rdumii-real(dumii))
           !  elseif (dum.ge.502.e-6) then
           !     mu_r   = 0.
           !  endif
             mu_r = mur_constant
           ! recalculate slope based on mu_r
            !LAMR = (pi*sxth*rhow*nr(i_Qnorm,k)*gamma(mu_r+4.)/(qr(i_Qnorm,k)*gamma(mu_r+1.)))**thrd

           ! this is done by re-scaling lamv to account for DSD shape (mu_r)
             lamr   = lamv*(gamma(mu_r+4.)/(6.*gamma(mu_r+1.)))**thrd

           ! set maximum value for rain lambda
            !lammax = (mu_r+1.)/10.e-6
             lammax = (mu_r+1.)*1.e+5

           ! set to small value since breakup is explicitly included (mean size 5 mm)
            !lammin = (mu_r+1.)/5000.e-6
             lammin = (mu_r+1.)*200.
             lamr   = min(lamr,lammax)
             lamr   = max(lamr,lammin)

           ! initialize sum
             sum1 = 0.
             sum2 = 0.
             if (log_3momI) then
                sum3 = 0. ! M6 tendency
                sum4 = 0. ! M3 tendency
             endif
             sum6 = 0.
!            sum8 = 0.  ! total rain

             do jj = 1,num_int_coll_bins
              ! particle size:
                d1 = real(jj)*ddd - 0.5*ddd
              ! num is the scaled binned rain size distribution;
              !   need to multiply by n0r to get unscaled distribution
                num(jj) = d1**mu_r*exp(-lamr*d1)*ddd
              ! get (unscaled) binned ice size distribution
                numi(jj) = n0*d1**mu_i*exp(-lam*d1)*ddd
             enddo !jj-loop

           ! loop over rain and ice size distributions
             jj_loop_5: do jj = 1,num_int_coll_bins
                kk_loop_2: do kk = 1,num_int_coll_bins

                 ! particle size:
                   d1 = real(jj)*ddd - 0.5*ddd   ! ice
                   d2 = real(kk)*ddd - 0.5*ddd   ! rain
                   if (d1.le.dcrit) then
                      cs1  = pi*sxth*900.
                      ds1  = 3.
                      bas1 = 2.
                      aas1 = pi*0.25
                   elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                      cs1  = cs
                      ds1  = ds
                      bas1 = bas
                      aas1 = aas
                   elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                      cs1  = cgp(i_rhor)
                      ds1  = dg
                      bas1 = bag
                      aas1 = aag
                   else if (d1.gt.dcritr) then
                      cs1  = csr
                      ds1  = dsr
                      if (i_Fr.eq.1) then
                         aas1 = aas
                         bas1 = bas
                      else
                       ! for area, keep bas1 constant, but modify aas1 according to rime fraction
                         bas1 = bas
                         dum1 = aas*d1**bas
                         dum2 = aag*d1**bag
                         m1   = cs1*d1**ds1
                         m2   = cs*d1**ds
                         m3   = cgp(i_rhor)*d1**dg
                       ! linearly interpolate based on particle mass
                         dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                         aas1 = dum3/(d1**bas)
                      endif
                   endif

                   mass = (1.-Fl)*cs1*d1**ds1+Fl*pi*sxth*1000.*d1**3.
                   area = (1.-Fl)*aas1*d1**bas1+Fl*pi/4.*d1**2.

                   delu = abs(fall2(jj)-fallr(kk))   ! differential fallspeed

             ! get m-D relation to obtain dmdD
             if (d1.le.dcrit) then
                cs1  = pi*sxth*900.
		ds1  = 3.
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
		cs1  = cs
                ds1  = ds
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
		cs1  = cgp(i_rhor)
                ds1  = dg
             elseif (d1.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
             endif

             ! dmdD, accounting for weighting by liquid fraction
             dmdD = (1.-Fl)*cs1*ds1*d1**(ds1-1.) + 3.*Fl*pi*sxth*1000.*d1**2
!..........................

!......................................................
! collection of rain mass and number

   ! allow collection of rain both when rain fallspeed > ice fallspeed and ice fallspeed > rain fallspeed
   ! this is applied below freezing to calculate total amount of rain mass and number that collides with ice and freezes

!        if (fall2(jj).ge.fallr(kk)) then

                 ! sum for integral:

                 ! change in rain N (units of m^4 s^-1 kg^-1), thus need to multiply
                 ! by air density (units kg m^-3) and n0r (units kg^-1 m^-1) in P3_MAIN

                  !sum1 = sum1+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*n0*d1**mu_i*        &
                  !       exp(-lam*d1)* &dd*num(kk)
                   sum1 = sum1+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*n0*d1**mu_i*        &
                          exp(-lam*d1)*ddd*num(kk)
                  !sum1 = sum1+min((sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*n0*d1**mu_i*    &
                  !       exp(-lam*d1)*dd*num(kk),num(kk))

                 ! change in rain q (units of m^4 s^-1), again need to multiply by air density and n0r in P3_MAIN

                  !sum2 = sum2+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*n0*d1**mu_i*        &
                  !       exp(-lam*d1)*dd*num(kk)*pi*sxth*997.*d2**3
                   sum2 = sum2+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*n0*d1**mu_i*        &
                          exp(-lam*d1)*ddd*num(kk)*pi*sxth*997.*d2**3

                  ! remove collected rain drops from distribution:
                  !num(kk) = num(kk)-(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*n0*d1**mu_i*  &
                  !          exp(-lam*d1)*dd*num(kk)*dt
                  !num(kk) = max(num(kk),0.)

                   if (log_3momI) then
                  ! change in M6 due to collection of rain by ice
                      sum3 = sum3+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*6.*d1**5*n0*d1**mu_i*        &
                          exp(-lam*d1)*ddd*num(kk)*pi*sxth*997.*d2**3/dmdD
                  ! change in M3
                      sum4 = sum4+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*3.*d1**2*n0*d1**mu_i*        &
                          exp(-lam*d1)*ddd*num(kk)*pi*sxth*997.*d2**3/dmdD
                   endif
                   
!......................................................
! now calculate collection of ice mass by rain

! ice collecting rain

   ! again, allow collection both when ice fallspeed > rain fallspeed
   ! and when rain fallspeed > ice fallspeed
   ! this is applied to conditions above freezing to calculate
   ! acceleration of melting due to collisions with liquid (rain)

!        if (fall2(jj).ge.fallr(kk)) then

! collection of ice number

                !  sum5 = sum5+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*exp(-lamr*d2)*dd*numi(jj)

                ! collection of ice mass (units of m^4 s^-1)
                !   note: need to multiply by air density and n0r in microphysics code
                   sum6 = sum6+(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*d2**mu_r*           &
                          exp(-lamr*d2)*ddd*numi(jj)*mass

                  ! remove collected snow from distribution:
                  !numi(jj) = numi(jj)-(sqrt(area)+sqrt(pi*0.25*d2**2))**2*delu*d2**mu_r*   &
                  !           exp(-lamr*d2)*dd*numi(jj)*dt
                  !numi(jj) = max(numi(jj),0.)

                enddo kk_loop_2
             enddo jj_loop_5

           ! save for output:
             nrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl) = sum1
             qrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl) = sum2
             qsrain(i_Qnorm,i_Drscale,i_Fr,i_Fl) = sum6

             if (log_3momI) then
                mom6 = n0*gamma(mu_i+7.)/lam**(mu_i+7.)
                mom3 = n0*gamma(mu_i+4.)/lam**(mu_i+4.)
                m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl) = 1./mom3**2*sum3 - 2.*mom6/mom3**3*sum4 ! change in relative variance
             endif

          enddo i_Drscale_loop !(loop around lambda for rain)

!.....................................................................................
! melting
!.....................................................................................

! note: in microphysics code we need to multiply by air density and
! (mu/dv)^0.3333*(rhofac/mu)^0.5, where rhofac is air density correction factor

          sum1 = 0.
          sum2 = 0.
          sum3 = 0.
          sum4 = 0.
          if (log_3momI) then
             sum5 = 0. ! m6 melting term 1
             sum6 = 0. ! m6 melting term 2
             sum7 = 0. ! m3 term 1
             sum8 = 0. ! m3 term 2
          endif
             
        ! loop over exponential size distribution:
          jj_loop_6: do jj = 1,num_int_bins

             d1 = real(jj)*dd - 0.5*dd   ! particle size

! get m-D relation to obtain dmdD
             if (d1.le.dcrit) then
                cs1  = pi*sxth*900.
                ds1  = 3.
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                cs1  = cs
                ds1  = ds
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cs1  = cgp(i_rhor)
                ds1  = dg
             elseif (d1.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
             endif

! dmdD, accounting for weighting by liquid fraction
             dmdD = (1.-Fl)*cs1*ds1*d1**(ds1-1.) + 3.*Fl*pi*sxth*1000.*d1**2
!..........................


           ! get capacitance for different ice regimes:
             if (d1.le.dcrit) then
                cap = 1. ! for small spherical crystal use sphere
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                cap = 0.48  ! field et al. 2006
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cap = 1. ! for graupel assume sphere
             elseif (d1.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
                if (i_Fr.eq.1) then
                   cap  = 0.48
                else
                   dum1 = 0.48
                   dum2 = 1.
                   m1   = cs1*d1**ds1
                   m2   = cs*d1**ds
                   m3   = cgp(i_rhor)*d1**dg
                 ! linearly interpolate to get capacitance based on particle mass
                   dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                   cap  = dum3
                endif
             endif

             capm = (1.-Fl)*cap*d1+Fl*d1

           ! for ventilation, only include fallspeed and size effects, the rest of
           ! term Sc^1/3 x Re^1/2 is multiplied in-line in the model code to allow
              ! effects of atmospheric conditions on ventilation
            !dum = (mu/dv)**0.333333*(fall1(jj)*d1/mu)**0.5
             dum = (falls1(jj)*d1)**0.5
             dum1 = (fallr1(jj)*d1)**0.5

              ! ventilation from Hall and Pruppacher (1976)
              ! only include ventilation for super-100 micron particles
!        if (dum.lt.1.) then

              if (d1.le.100.e-6) then
                  dumfac1 = 1.
                  dumfac2 = 0.
                  dumfac12 = 1.
                  dumfac22 = 0.
              else
                  dumfac1 = 0.65
                  dumfac2 = 0.44*dum
                  dumfac12 = 0.78
                  dumfac22 = 0.28*dum1
              endif

              fac1 = dumfac1*(1.-Fl)+Fl*dumfac12
              fac2 = dumfac2*(1.-Fl)+Fl*dumfac22

              ! units are m^3 kg^-1 s^-1, thus multiplication by air density in P3_MAIN

             if (d1.le.dcrit) then
                ! Melted water transferred to rain
                sum1 = sum1+capm*fac1*n0d*d1**(mu_id)*exp(-lamd*d1)*dd
                sum2 = sum2+capm*fac2*n0d*d1**(mu_id)*exp(-lamd*d1)*dd
                if (log_3momI) then
                   ! M6 rates
                   sum5 = sum5+capm*6.*d1**5*fac1*n0d*d1**(mu_id)*exp(-lamd*d1)*dd/dmdD
                   sum6 = sum6+capm*6.*d1**5*fac2*n0d*d1**(mu_id)*exp(-lamd*d1)*dd/dmdD
                   ! M3 rates
                   sum7 = sum7+capm*3.*d1**2*fac1*n0d*d1**(mu_id)*exp(-lamd*d1)*dd/dmdD
                   sum8 = sum8+capm*3.*d1**2*fac2*n0d*d1**(mu_id)*exp(-lamd*d1)*dd/dmdD
                endif
                !sum3 = sum3+0.
                !sum4 = sum4+0.
             else
                ! Melted water accumulated to qi_liq
                !sum1 = sum1+0.
                !sum2 = sum2+0.
                sum3 = sum3+capm*fac1*n0d*d1**(mu_id)*exp(-lamd*d1)*dd
                sum4 = sum4+capm*fac2*n0d*d1**(mu_id)*exp(-lamd*d1)*dd

             endif

          enddo jj_loop_6

          vdepm1(i_Qnorm,i_Fr,i_Fl) = sum1
          vdepm2(i_Qnorm,i_Fr,i_Fl) = sum2
          vdepm3(i_Qnorm,i_Fr,i_Fl) = sum3
          vdepm4(i_Qnorm,i_Fr,i_Fl) = sum4

          if (log_3momI) then
             mom6 = n0*gamma(mu_i+7.)/lam**(mu_i+7.)
             mom3 = n0*gamma(mu_i+4.)/lam**(mu_i+4.)
             ! NOTE: form below includes dM0/dt change
             m6mlt1(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum5 - 1.*mom6/mom3**3*sum7  ! change relative variance
             m6mlt2(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum6 - 1.*mom6/mom3**3*sum8  ! change relative variance
          endif
             
!.....................................................................................
! vapor deposition/wet growth/refreezing
!.....................................................................................

! vapor deposition including ventilation effects
! note: in microphysics code we need to multiply by air density and
! (mu/dv)^0.3333*(rhofac/mu)^0.5, where rhofac is air density correction factor
! These processes are applied to the whole particle (liquid+dry components)

          sum1 = 0.
          sum2 = 0.
          if (log_3momI) then
             sum3 = 0. ! first term dM6/dt
             sum4 = 0. ! second term dM6/dt
             sum5 = 0. ! first term dM3/dt
             sum6 = 0. ! second term dM3/dt
          endif
             
        ! loop over exponential size distribution:
          jj_loop_7: do jj = 1,num_int_bins

             d1 = real(jj)*dd - 0.5*dd   ! particle size

! get m-D relation to obtain dmdD
             if (d1.le.dcrit) then
                cs1  = pi*sxth*900.
                ds1  = 3.
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                cs1  = cs
                ds1  = ds
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cs1  = cgp(i_rhor)
                ds1  = dg
             elseif (d1.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
             endif

! dmdD, accounting for weighting by liquid fraction
             dmdD = (1.-Fl)*cs1*ds1*d1**(ds1-1.) + 3.*Fl*pi*sxth*1000.*d1**2
!..........................

           ! get capacitance for different ice regimes:
             if (d1.le.dcrit) then
                cap = 1. ! for small spherical crystal use sphere
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                cap = 0.48  ! field et al. 2006
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cap = 1. ! for graupel assume sphere
             elseif (d1.gt.dcritr) then
                cs1 = csr
                ds1 = dsr
                if (i_Fr.eq.1) then
                   cap  = 0.48
                else
                   dum1 = 0.48
                   dum2 = 1.
                   m1   = cs1*d1**ds1
                   m2   = cs*d1**ds
                   m3   = cgp(i_rhor)*d1**dg
                 ! linearly interpolate to get capacitance based on particle mass
                   dum3 = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                   cap  = dum3
                endif
             endif

             capm = (1.-Fl)*cap*d1+Fl*d1

           ! for ventilation, only include fallspeed and size effects, the rest of
           ! term Sc^1/3 x Re^1/2 is multiplied in-line in the model code to allow
              ! effects of atmospheric conditions on ventilation
            !dum = (mu/dv)**0.333333*(fall1(jj)*d1/mu)**0.5
             dum = (fall1(jj)*d1)**0.5

              ! ventilation from Hall and Pruppacher (1976)
              ! only include ventilation for super-100 micron particles
!        if (dum.lt.1.) then

              ! units are m^3 kg^-1 s^-1, thus multiplication by air density in P3_MAIN


             if (d1.lt.100.e-6) then
                sum1 = sum1+capm*n0*d1**(mu_i)*exp(-lam*d1)*dd
                if (log_3momI) then
                   sum3 = sum3 + 6.*d1**5*capm*n0*d1**(mu_i)*exp(-lam*d1)*dd/dmdD
     		   sum5 = sum5 + 3.*d1**2*capm*n0*d1**(mu_i)*exp(-lam*d1)*dd/dmdD
                endif
             else
               !sum1 = sum1+capm*n0*(0.65+0.44*dum)*d1**(mu_i)*exp(-lam*d1)*dd
                sum1 = sum1+capm*n0*0.65*d1**(mu_i)*exp(-lam*d1)*dd
                sum2 = sum2+capm*n0*0.44*dum*d1**(mu_i)*exp(-lam*d1)*dd
                if (log_3momI) then
                   sum3 = sum3 + 0.65*6.*d1**5*capm*n0*d1**(mu_i)*exp(-lam*d1)*dd/dmdD
                   sum4 = sum4 + 0.44*dum*6.*d1**5*capm*n0*d1**(mu_i)*exp(-lam*d1)*dd/dmdD
                   sum5 = sum5 + 0.65*3.*d1**2*capm*n0*d1**(mu_i)*exp(-lam*d1)*dd/dmdD
                   sum6 = sum6 + 0.44*dum*3.*d1**2*capm*n0*d1**(mu_i)*exp(-lam*d1)*dd/dmdD
                endif
             endif

          enddo jj_loop_7

          vdep(i_Qnorm,i_Fr,i_Fl)  = sum1
          vdep1(i_Qnorm,i_Fr,i_Fl) = sum2

          if (log_3momI) then
             mom6 = n0*gamma(mu_i+7.)/lam**(mu_i+7.)
             mom3 = n0*gamma(mu_i+4.)/lam**(mu_i+4.)
             m6dep(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum3 - 2.*mom6/mom3**3*sum5
             m6dep1(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum4 - 2.*mom6/mom3**3*sum6
! NOTE: change in G for sublimation includes impact of dM0/dt, thus different from deposition above
             m6sub(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum3 - mom6/mom3**3*sum5
             m6sub1(i_Qnorm,i_Fr,i_Fl) = 1./mom3**2*sum4 - mom6/mom3**3*sum6
          endif
             
!.....................................................................................
! ice effective radius
!   use definition of Francis et al. (1994), e.g., Eq. 3.11 in Fu (1996) J. Climate
!.....................................................................................
          sum1 = 0.
          sum2 = 0.

        ! loop over exponential size distribution:
          jj_loop_8: do jj = 1,num_int_bins

             d1 = real(jj)*dd - 0.5*dd    ! particle size

             if (d1.le.dcrit) then
                cs1  = pi*sxth*900.
                ds1  = 3.
                bas1 = 2.
                aas1 = pi*0.25
             elseif (d1.gt.dcrit.and.d1.le.dcrits) then
                cs1  = cs
                ds1  = ds
                bas1 = bas
                aas1 = aas
             elseif (d1.gt.dcrits.and.d1.le.dcritr) then
                cs1  = cgp(i_rhor)
                ds1  = dg
                bas1 = bag
                aas1 = aag
             elseif (d1.gt.dcritr) then
                cs1  = csr
                ds1  = dsr
                if (i_Fr.eq.1) then
                   bas1 = bas
                   aas1 = aas
                else
                 ! for area, keep bas1 constant, but modify aas1 according to rime fraction
                   bas1  = bas
                   dum1  = aas*d1**bas
                   dum2  = aag*d1**bag
                   m1    = cs1*d1**ds1
                   m2    = cs*d1**ds
                   m3    = cgp(i_rhor)*d1**dg
                 ! linearly interpolate based on particle mass:
                   dum3  = dum1+(m1-m2)*(dum2-dum1)/(m3-m2)
                   aas1  = dum3/(d1**bas)
                endif
             endif

             mass = (1.-Fl)*cs1*d1**ds1+Fl*pi*sxth*1000.*d1**3.
             area = (1.-Fl)*aas1*d1**bas1+Fl*pi/4.*d1**2.

            ! n0 not included below becuase it is in both numerator and denominator
            !cs1  = pi*sxth*917.
            !ds1  = 3.
            !aas1 = pi/4.*2.
            !bas1 = 2.

             sum1 = sum1 + mass*d1**mu_i*exp(-lam*d1)*dd
             sum2 = sum2 + area*d1**mu_i*exp(-lam*d1)*dd

           ! if (d1.ge.100.e-6) then
           !    sum3 = sum3+n0*d1**mu_i*exp(-lam*d1)*dd
           !    sum4 = sum4+n0*aas1*d1**bas1*d1**mu_i*exp(-lam*d1)*dd
           ! endif

          enddo jj_loop_8

        ! calculate eff radius:

         !eff(i_Qnorm,i_Fr) = sum1/(1.7321*916.7*sum2)
         !calculate effective size following Fu (1996)
         !eff(i_Qnorm,i_Fr) = sum1/(1.1547*916.7*sum2)
        ! calculate for eff rad for twp ice:
          eff(i_Qnorm,i_Fr,i_Fl) = 3.*sum1/(4.*sum2*916.7)

!.....................................................................................

522  continue

       enddo i_Qnorm_loop


    !-- ice table
       i_Qnorm_loop_2:  do i_Qnorm = 1,n_Qnorm


        ! Set values less than cutoff (1.e-99) to 0.
        !   note: dim(x,cutoff) actually returns x-cutoff (if x>cutoff; else 0.), but this difference will
        !   have no effect since the values will be read in single precision in P3_INIT. The purppse
        !   here is to avoid problems trying to write values with 3-digit exponents (e.g. 0.123456E-100)
          uns(i_Qnorm,i_Fr,i_Fl)       = dim( uns(i_Qnorm,i_Fr,i_Fl),       cutoff)
          ums(i_Qnorm,i_Fr,i_Fl)       = dim( ums(i_Qnorm,i_Fr,i_Fl),       cutoff)
          nagg(i_Qnorm,i_Fr,i_Fl)      = dim( nagg(i_Qnorm,i_Fr,i_Fl),      cutoff)
          nrwat(i_Qnorm,i_Fr,i_Fl)     = dim( nrwat(i_Qnorm,i_Fr,i_Fl),     cutoff)
          m6rime(i_Qnorm,i_Fr,i_Fl)    = dim( m6rime(i_Qnorm,i_Fr,i_Fl),    cutoff)
          vdep(i_Qnorm,i_Fr,i_Fl)      = dim( vdep(i_Qnorm,i_Fr,i_Fl),      cutoff)
          eff(i_Qnorm,i_Fr,i_Fl)       = dim( eff(i_Qnorm,i_Fr,i_Fl),       cutoff)
          i_qsmall(i_Qnorm,i_Fr,i_Fl)  = dim( i_qsmall(i_Qnorm,i_Fr,i_Fl),  cutoff)
          i_qlarge(i_Qnorm,i_Fr,i_Fl)  = dim( i_qlarge(i_Qnorm,i_Fr,i_Fl),  cutoff)
          refl(i_Qnorm,i_Fr,i_Fl)      = dim( refl(i_Qnorm,i_Fr,i_Fl),      cutoff)
          vdep1(i_Qnorm,i_Fr,i_Fl)     = dim( vdep1(i_Qnorm,i_Fr,i_Fl),     cutoff)
          dmm(i_Qnorm,i_Fr,i_Fl)       = dim( dmm(i_Qnorm,i_Fr,i_Fl),       cutoff)
          rhomm(i_Qnorm,i_Fr,i_Fl)     = dim( rhomm(i_Qnorm,i_Fr,i_Fl),     cutoff)
          uzs(i_Qnorm,i_Fr,i_Fl)       = dim( uzs(i_Qnorm,i_Fr,i_Fl),       cutoff)
          lambda_i(i_Qnorm,i_Fr,i_Fl)  = dim( lambda_i(i_Qnorm,i_Fr,i_Fl),  cutoff)
          mu_i_save(i_Qnorm,i_Fr,i_Fl) = dim( mu_i_save(i_Qnorm,i_Fr,i_Fl), cutoff)
          vdepm1(i_Qnorm,i_Fr,i_Fl)    = dim( vdepm1(i_Qnorm,i_Fr,i_Fl),    cutoff)
          vdepm2(i_Qnorm,i_Fr,i_Fl)    = dim( vdepm2(i_Qnorm,i_Fr,i_Fl),    cutoff)
          vdepm3(i_Qnorm,i_Fr,i_Fl)    = dim( vdepm3(i_Qnorm,i_Fr,i_Fl),    cutoff)
          vdepm4(i_Qnorm,i_Fr,i_Fl)    = dim( vdepm4(i_Qnorm,i_Fr,i_Fl),    cutoff)
          qshed(i_Qnorm,i_Fr,i_Fl)     = dim( qshed(i_Qnorm,i_Fr,i_Fl),     cutoff)
          refl2(i_Qnorm,i_Fr,i_Fl)     = dim( refl2(i_Qnorm,i_Fr,i_Fl),     cutoff)

          ! modified below since rates could be positive or negative
          threemom_2: if (log_3momI) then
             
             if (m6dep(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6dep(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6dep(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6dep(i_Qnorm,i_Fr,i_Fl)     = dim( m6dep(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6dep1(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6dep1(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6dep1(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6dep1(i_Qnorm,i_Fr,i_Fl)     = dim( m6dep1(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6mlt1(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6mlt1(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6mlt1(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6mlt1(i_Qnorm,i_Fr,i_Fl)     = dim( m6mlt1(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6mlt2(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6mlt2(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6mlt2(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6mlt2(i_Qnorm,i_Fr,i_Fl)     = dim( m6mlt2(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6agg(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6agg(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6agg(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6agg(i_Qnorm,i_Fr,i_Fl)     = dim( m6agg(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6shd(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6shd(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6shd(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6shd(i_Qnorm,i_Fr,i_Fl)     = dim( m6shd(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6sub(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6sub(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6sub(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6sub(i_Qnorm,i_Fr,i_Fl)     = dim( m6sub(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif
             if (m6sub1(i_Qnorm,i_Fr,i_Fl).lt.0.) then
                m6sub1(i_Qnorm,i_Fr,i_Fl)     = -dim( -m6sub1(i_Qnorm,i_Fr,i_Fl),     cutoff)
             else
                m6sub1(i_Qnorm,i_Fr,i_Fl)     = dim( m6sub1(i_Qnorm,i_Fr,i_Fl),     cutoff)
             endif

          endif threemom_2

          nawcol(i_Qnorm,i_Fr,i_Fl)    = dim( nawcol(i_Qnorm,i_Fr,i_Fl),    cutoff)
          naicol(i_Qnorm,i_Fr,i_Fl)    = dim( naicol(i_Qnorm,i_Fr,i_Fl),    cutoff)
             
          if (log_3momI) then
             write(1,'(5i5,31e15.5)')                             &
                         i_Znorm,i_rhor,i_Fr,i_Fl,i_Qnorm,        &
                         uns(i_Qnorm,i_Fr,i_Fl),                  &
                         ums(i_Qnorm,i_Fr,i_Fl),                  &
                         nagg(i_Qnorm,i_Fr,i_Fl),                 &
                         nrwat(i_Qnorm,i_Fr,i_Fl),                &
                         vdep(i_Qnorm,i_Fr,i_Fl),                 &
                         eff(i_Qnorm,i_Fr,i_Fl),                  &
                         i_qsmall(i_Qnorm,i_Fr,i_Fl),             &
                         i_qlarge(i_Qnorm,i_Fr,i_Fl),             &
                         refl2(i_Qnorm,i_Fr,i_Fl),                &
                         vdep1(i_Qnorm,i_Fr,i_Fl),                &
                         dmm(i_Qnorm,i_Fr,i_Fl),                  &
                         rhomm(i_Qnorm,i_Fr,i_Fl),                &
                         uzs(i_Qnorm,i_Fr,i_Fl),                  &
                         lambda_i(i_Qnorm,i_Fr,i_Fl),             &
                         mu_i_save(i_Qnorm,i_Fr,i_Fl),            &
                         vdepm1(i_Qnorm,i_Fr,i_Fl),               &
                         vdepm2(i_Qnorm,i_Fr,i_Fl),               &
                         vdepm3(i_Qnorm,i_Fr,i_Fl),               &
                         vdepm4(i_Qnorm,i_Fr,i_Fl),               &
                         qshed(i_Qnorm,i_Fr,i_Fl),                &
                         m6rime(i_Qnorm,i_Fr,i_Fl),               &
                         m6dep(i_Qnorm,i_Fr,i_Fl),   	      	  &
                         m6dep1(i_Qnorm,i_Fr,i_Fl),               &
                         m6mlt1(i_Qnorm,i_Fr,i_Fl),   	      	  &
                         m6mlt2(i_Qnorm,i_Fr,i_Fl),               &
                         m6agg(i_Qnorm,i_Fr,i_Fl),                &
                         m6shd(i_Qnorm,i_Fr,i_Fl),                &
                         m6sub(i_Qnorm,i_Fr,i_Fl),                &
                         m6sub1(i_Qnorm,i_Fr,i_Fl),               &
                         nawcol(i_Qnorm,i_Fr,i_Fl),               &
                         naicol(i_Qnorm,i_Fr,i_Fl)
          else
             write(1,'(4i5,21e15.5)')                             &
                         i_rhor,i_Fr,i_Fl,i_Qnorm,                &
                         uns(i_Qnorm,i_Fr,i_Fl),                  &
                         ums(i_Qnorm,i_Fr,i_Fl),                  &
                         nagg(i_Qnorm,i_Fr,i_Fl),                 &
                         nrwat(i_Qnorm,i_Fr,i_Fl),                &
                         vdep(i_Qnorm,i_Fr,i_Fl),                 &
                         eff(i_Qnorm,i_Fr,i_Fl),                  &
                         i_qsmall(i_Qnorm,i_Fr,i_Fl),             &
                         i_qlarge(i_Qnorm,i_Fr,i_Fl),             &
                         refl2(i_Qnorm,i_Fr,i_Fl),                &
                         vdep1(i_Qnorm,i_Fr,i_Fl),                &
                         dmm(i_Qnorm,i_Fr,i_Fl),                  &
                         rhomm(i_Qnorm,i_Fr,i_Fl),                &
                         lambda_i(i_Qnorm,i_Fr,i_Fl),             &
                         mu_i_save(i_Qnorm,i_Fr,i_Fl),            &
                         vdepm1(i_Qnorm,i_Fr,i_Fl),               &
                         vdepm2(i_Qnorm,i_Fr,i_Fl),               &
                         vdepm3(i_Qnorm,i_Fr,i_Fl),               &
                         vdepm4(i_Qnorm,i_Fr,i_Fl),               &
                         qshed(i_Qnorm,i_Fr,i_Fl),                &
                         nawcol(i_Qnorm,i_Fr,i_Fl),               &
                         naicol(i_Qnorm,i_Fr,i_Fl)
          endif

       enddo i_Qnorm_loop_2

   !-- ice-rain collection table:
       do i_Qnorm = 1,n_Qnorm
          do i_Drscale = 1,n_Drscale

! !             !Set values less than cutoff (1.e-99) to 0.
! !              nrrain(i_Qnorm,i_Drscale,i_Fr) = dim(nrrain(i_Qnorm,i_Drscale,i_Fr), cutoff)
! !              qrrain(i_Qnorm,i_Drscale,i_Fr) = dim(qrrain(i_Qnorm,i_Drscale,i_Fr), cutoff)
             nrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl) = log10(max(nrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl), 1.e-99))
             qrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl) = log10(max(qrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl), 1.e-99))
             if (log_3momI) then
! do not output m6collr as log10
!                m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl) = log10(max(m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl), 1.e-99))
  
                if (m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl).lt.0.) then
                   m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl)     = -dim( -m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl),     cutoff)
                else
                   m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl)     = dim( m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl),     cutoff)
                endif
                
                write(1,'(4i5,3e15.5)')                           &
                         i_Qnorm,i_Drscale,i_Fr,i_Fl,             &
                         nrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl),     &
                         qrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl),     &
                         m6collr(i_Qnorm,i_Drscale,i_Fr,i_Fl)
             else ! 2-moment
                write(1,'(4i5,2e15.5)')                           &
                         i_Qnorm,i_Drscale,i_Fr,i_Fl,             &
                         nrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl),     &
                         qrrain(i_Qnorm,i_Drscale,i_Fr,i_Fl)
             endif

          enddo !i_Drscale-loop
       enddo !i_Qnorm-loop

!--
! The values of i_Znorm (3-momI) and i_rhor/i_Fr (2-momI) are "passed in" for parallelized
! version of code, thus the loops are commented out.
        enddo i_Fl_loop_1
      enddo i_Fr_loop_1
!    enddo i_rhor_loop
!enddo i_Znorm_loop
!==

 close(1)

END PROGRAM create_p3_lookuptable_1
!______________________________________________________________________________________

! Incomplete gamma function
! from Numerical Recipes in Fortran 77: The Art of
! Scientific Computing

      function gammq(a,x)

      real a,gammq,x

! USES gcf,gser
! Returns the incomplete gamma function Q(a,x) = 1-P(a,x)

      real gammcf,gammser,gln
!     if (x.lt.0..or.a.le.0) pause 'bad argument in gammq'
      if (x.lt.0..or.a.le.0) print*, 'bad argument in gammq'
      if (x.lt.a+1.) then
         call gser(gamser,a,x,gln)
         gammq=1.-gamser
      else
         call gcf(gammcf,a,x,gln)
         gammq=gammcf
      end if
      return
      end

!______________________________________________________________________________________

      subroutine gser(gamser,a,x,gln)
      integer itmax
      real a,gamser,gln,x,eps
      parameter(itmax=100,eps=3.e-7)
      integer n
      real ap,del,sum,gamma
      gln = log(gamma(a))
      if (x.le.0.) then
!        if (x.lt.0.) pause 'x < 0 in gser'
         if (x.lt.0.) print*, 'x < 0 in gser'
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
!     pause 'a too large, itmax too small in gser'
      print*, 'a too large, itmax too small in gser'
 1    gamser=sum*exp(-x+a*log(x)-gln)
      return
      end

!______________________________________________________________________________________

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
!     pause 'a too large, itmax too small in gcf'
      print*, 'a too large, itmax too small in gcf'
 1    gammcf=exp(-x+a*log(x)-gln)*h
      return
      end

!______________________________________________________________________________________

 real function compute_mu_3moment(mom3,mom6,mu_max)

 !--------------------------------------------------------------------------
 ! Computes mu as a function of G(mu), where
 !
 ! G(mu)= N*Z/Q^2 = [(6+mu)(5+mu)(4+mu)]/[(3+mu)(2+mu)(1+mu)]
 !
 ! 2018-08-08
 !--------------------------------------------------------------------------

 implicit none

! Arguments passed:
 real, intent(in) :: mom3,mom6 !normalized moments
 real, intent(in) :: mu_max    !maximum allowable value of mu

! Local variables:
 real             :: mu   ! shape parameter in gamma distribution
 real             :: a1,g1,g2,G

! calculate G from normalized moments
    G = mom6/mom3

!----------------------------------------------------------!
! !Solve alpha numerically: (brute-force)
!      mu= 0.
!      g2= 999.
!      do i=0,4000
!         a1= i*0.01
!         g1= (6.+a1)*(5.+a1)*(4.+a1)/((3.+a1)*(2.+a1)*(1.+a1))
!         if(abs(g-g1)<abs(g-g2)) then
!            mu = a1
!            g2= g1
!         endif
!      enddo
!----------------------------------------------------------!

!Piecewise-polynomial approximation of G(mu) to solve for mu:
  if (G >= 20.) then
    mu = 0.
  else
    g2 = G**2
    if (G<20.  .and.G>=13.31) mu = 3.3638e-3*g2 - 1.7152e-1*G + 2.0857e+0
    if (G<13.31.and.G>=7.123) mu = 1.5900e-2*g2 - 4.8202e-1*G + 4.0108e+0
    if (G<7.123.and.G>=4.200) mu = 1.0730e-1*g2 - 1.7481e+0*G + 8.4246e+0
    if (G<4.200.and.G>=2.946) mu = 5.9070e-1*g2 - 5.7918e+0*G + 1.6919e+1
    if (G<2.946.and.G>=1.793) mu = 4.3966e+0*g2 - 2.6659e+1*G + 4.5477e+1
    if (G<1.793.and.G>=1.405) mu = 4.7552e+1*g2 - 1.7958e+2*G + 1.8126e+2
    if (G<1.405.and.G>=1.230) mu = 3.0889e+2*g2 - 9.0854e+2*G + 6.8995e+2
    if (G<1.230) mu = mu_max
  endif

  compute_mu_3moment = mu

 end function compute_mu_3moment

!______________________________________________________________________________________

 real function diagnostic_mui(mu_i_min,mu_i_max,lam,q,cgp,Fr,pi)

!----------------------------------------------------------!
! Compute mu_i diagnostically.
!----------------------------------------------------------!

 implicit none

!Arguments:
 real    :: mu_i_min,mu_i_max,lam,q,cgp,Fr,pi

! Local variables:
 real, parameter :: Di_thres = 0.2 !diameter threshold [mm]
!real, parameter :: Di_thres = 0.6 !diameter threshold [mm]
 real            :: mu_i,dum1,dum2,dum3


!-- diagnostic mu_i, original formulation: (from Heymsfield, 2003)
!  mu_i = 0.076*(lam/100.)**0.8-2.   ! /100 is to convert m-1 to cm-1
!  mu_i = max(mu_i,0.)
!  mu_i = min(mu_i,6.)

!-- diagnostic mu_i, 3-moment-based formulation:
!  dum1 = (q/cgp)**(1./3)*1000.              ! estimated Dmvd [mm], assuming spherical
!  if (dum1<=Di_thres) then
!     !diagnostic mu_i, original formulation: (from Heymsfield, 2003)
!     mu_i = 0.076*(lam*0.01)**0.8-2.        ! /100 is to convert m-1 to cm-1
!     mu_i = min(mu_i,6.)
!  else
!     dum2 = (6./pi)*cgp                     ! mean density (total)
!     dum3 = max(1., 1.+0.00842*(dum2-400.)) ! adjustment factor for density
!     mu_i = 4.*(dum1-Di_thres)*dum3*Fr
!  endif
!  mu_i = max(mu_i,mu_i_min)  ! make sure mu_i >= 0, otherwise size dist is infinity at D = 0
!  mu_i = min(mu_i,mu_i_max)

 dum1 = (q/cgp)**(1./3)*1000.              ! estimated Dmvd [mm], assuming spherical
 if (dum1<=Di_thres) then
    !diagnostic mu_i, original formulation: (from Heymsfield, 2003)
    mu_i = 0.076*(lam*0.01)**0.8-2.        ! /100 is to convert m-1 to cm-1
    mu_i = min(mu_i,6.)
 else
    dum2 = (6./pi)*cgp                     ! mean density (total)
!   dum3 = max(1., 1.+0.00842*(dum2-400.)) ! adjustment factor for density
    dum3 = max(1., 1.+0.00842*(dum2-400.)) ! adjustment factor for density
    mu_i = 0.25*(dum1-Di_thres)*dum3*Fr
 endif
 mu_i = max(mu_i,mu_i_min)  ! make sure mu_i >= 0, otherwise size dist is infinity at D = 0
 mu_i = min(mu_i,mu_i_max)

 diagnostic_mui = mu_i

 end function diagnostic_mui

!______________________________________________________________________________________

 real function diagnostic_mui_Fl(mu_i_min,mu_i_max,mu_id,lam,q,cgp,Fr,Fl,rhom,pi)

!----------------------------------------------------------!
! Compute mu_i diagnostically.
!----------------------------------------------------------!

 implicit none

!Arguments:
 real    :: mu_i_min,mu_i_max,lam,q,cgp,Fr,pi,mu_id,Fl,rhom

! Local variables:
 real, parameter :: Di_thres = 0.2 !diameter threshold [mm]
!real, parameter :: Di_thres = 0.6 !diameter threshold [mm]
 real            :: mu_i,dum1,dum2,dum3

 dum1 = (q/rhom)**(1./3)*1000.              ! estimated Dmvd [mm], assuming spherical
 if (dum1<=Di_thres) then
    !diagnostic mu_i, original formulation: (from Heymsfield, 2003)
    mu_i = 0.076*(lam*0.01)**0.8-2.        ! /100 is to convert m-1 to cm-1
    mu_i = min(mu_i,6.)
 else
    !mu_i = (1.-Fl)*mu_id+Fl*mu_i_max        ! assume linear function with Fl (Cholette) old version
    dum2 = (6./pi)*rhom                      ! mean density (total)
    dum3 = max(1., 1.+0.00842*(dum2-400.)) ! adjustment factor for density
    mu_i = 0.25*(dum1-Di_thres)*dum3*Fr
 endif
    mu_i = max(mu_i,mu_i_min)  ! make sure mu_i >= 0, otherwise size dist is infinity at D = 0
    mu_i = min(mu_i,mu_i_max)

 diagnostic_mui_Fl = mu_i

 end function diagnostic_mui_Fl

!______________________________________________________________________________________


 subroutine intgrl_section(lam,mu, d1,d2,d3,d4, Dcrit1,Dcrit2,Dcrit3,    &
                           intsec_1,intsec_2,intsec_3,intsec_4)
 !-----------------
 ! Computes and returns partial integrals (partial moments) of ice PSD.
 !-----------------

 implicit none

!Arguments:
 real, intent(in)  :: lam,mu, d1,d2,d3,d4, Dcrit1,Dcrit2,Dcrit3
 real, intent(out) :: intsec_1,intsec_2,intsec_3,intsec_4

!Local:
 real :: dum,gammq
!-----------------

 !Region I -- integral from 0 to Dcrit1  (small spherical ice)
 intsec_1 = lam**(-d1-mu-1.)*gamma(mu+d1+1.)*(1.-gammq(mu+d1+1.,Dcrit1*lam))

 !Region II -- integral from Dcrit1 to Dcrit2  (non-spherical unrimed ice)
 intsec_2 = lam**(-d2-mu-1.)*gamma(mu+d2+1.)*(gammq(mu+d2+1.,Dcrit1*lam))
 dum      = lam**(-d2-mu-1.)*gamma(mu+d2+1.)*(gammq(mu+d2+1.,Dcrit2*lam))
 intsec_2 = intsec_2-dum

 !Region III -- integral from Dcrit2 to Dcrit3  (fully rimed spherical ice)
 intsec_3 = lam**(-d3-mu-1.)*gamma(mu+d3+1.)*(gammq(mu+d3+1.,Dcrit2*lam))
 dum      = lam**(-d3-mu-1.)*gamma(mu+d3+1.)*(gammq(mu+d3+1.,Dcrit3*lam))
 intsec_3 = intsec_3-dum

 !Region IV -- integral from Dcrit3 to infinity  (partially rimed ice)
 intsec_4 = lam**(-d4-mu-1.)*gamma(mu+d4+1.)*(gammq(mu+d4+1.,Dcrit3*lam))

 return

 end subroutine intgrl_section
!______________________________________________________________________________________


subroutine intgrl_section_Fl(lam,mu, d1,d2,d3,d4, Dcrit1,Dcrit2,Dcrit3,    &
                          intsec_1,intsec_2,intsec_3,intsec_4,intsec_5)
!-----------------
! Computes and returns partial integrals (partial moments) of ice PSD.
!-----------------

implicit none

!Arguments:
real, intent(in)  :: lam,mu, d1,d2,d3,d4, Dcrit1,Dcrit2,Dcrit3
real, intent(out) :: intsec_1,intsec_2,intsec_3,intsec_4,intsec_5

!Local:
real :: dum,gammq
!-----------------

!Region I -- integral from 0 to Dcrit1  (small spherical ice)
intsec_1 = lam**(-d1-mu-1.)*gamma(mu+d1+1.)*(1.-gammq(mu+d1+1.,Dcrit1*lam))

!Region II -- integral from Dcrit1 to Dcrit2  (non-spherical unrimed ice)
intsec_2 = lam**(-d2-mu-1.)*gamma(mu+d2+1.)*(gammq(mu+d2+1.,Dcrit1*lam))
dum      = lam**(-d2-mu-1.)*gamma(mu+d2+1.)*(gammq(mu+d2+1.,Dcrit2*lam))
intsec_2 = intsec_2-dum

!Region III -- integral from Dcrit2 to Dcrit3  (fully rimed spherical ice)
intsec_3 = lam**(-d3-mu-1.)*gamma(mu+d3+1.)*(gammq(mu+d3+1.,Dcrit2*lam))
dum      = lam**(-d3-mu-1.)*gamma(mu+d3+1.)*(gammq(mu+d3+1.,Dcrit3*lam))
intsec_3 = intsec_3-dum

!Region IV -- integral from Dcrit3 to infinity  (partially rimed ice)
intsec_4 = lam**(-d4-mu-1.)*gamma(mu+d4+1.)*(gammq(mu+d4+1.,Dcrit3*lam))

!Region V -- integral from 0 to infinity  (ice completely metled)
!because d1=3.
intsec_5 = lam**(-d1-mu-1.)*gamma(mu+d1+1.)

return

end subroutine intgrl_section_Fl

!______________________________________________________________________________________

complex function m_complex_water_ray(pi,lambda,T)

!      Complex refractive Index of Water as function of Temperature T
!      [deg C] and radar wavelength lambda [m]; valid for
!      lambda in [0.001,1.0] m; T in [-10.0,30.0] deg C
!      after Ray (1972)

implicit none
real, intent(in) :: T,lambda,pi

! Local variables
real :: epsinf,epss,epsr,epsi,alpha,lambdas,sigma,nenner
complex, parameter :: i = (0,1)


epsinf  = 5.27137 + 0.02164740 * T - 0.00131198 * T*T
epss    = 78.54+0 * (1.0 - 4.579-3 * (T - 25.0)                  &
        + 1.190-5 * (T - 25.0)*(T - 25.0)                        &
        - 2.800-8 * (T - 25.0)*(T - 25.0)*(T - 25.0))
alpha   = -16.8129/(T+273.16) + 0.0609265
lambdas = 0.00033836 * exp(2513.98/(T+273.16)) * 1e-2

nenner = 1.+2.*(lambdas/lambda)**(1-alpha)*sin(alpha*pi*0.5) &
       + (lambdas/lambda)**(2-2*alpha)
epsr = epsinf + ((epss-epsinf) * ((lambdas/lambda)**(1-alpha)   &
     * sin(alpha*pi*0.5)+1)) / nenner
epsi = ((epss-epsinf) * ((lambdas/lambda)**(1-alpha)            &
     * cos(alpha*pi*0.5)+0)) / nenner                           &
     + lambda*1.25664/1.88496

m_complex_water_ray = sqrt(cmplx(epsr,-epsi))

end function m_complex_water_ray

!______________________________________________________________________________________

complex function m_complex_ice_maetzler(lambda,T)

!      complex refractive index of ice as function of Temperature T
!      [deg C] and radar wavelength lambda [m]; valid for
!      lambda in [0.0001,30] m; T in [-250.0,0.0] C
!      Original comment from the Matlab-routine of Prof. Maetzler:
!      Function for calculating the relative permittivity of pure ice in
!      the microwave region, according to C. Maetzler, "Microwave
!      properties of ice and snow", in B. Schmitt et al. (eds.) Solar
!      System Ices, Astrophys. and Space Sci. Library, Vol. 227, Kluwer
!      Academic Publishers, Dordrecht, pp. 241-257 (1998). Input:
!      TK = temperature (K), range 20 to 273.15
!      f = frequency in GHz, range 0.01 to 3000

implicit none
real, intent(in) :: T,lambda

! Local variables
real :: f,c,TK,B1,B2,b,deltabeta,betam,beta,theta,alfa

c = 2.99d8
TK = T + 273.16
f = c / lambda * 1d-9

B1 = 0.0207
B2 = 1.16d-11
b = 335.0
deltabeta = EXP(-10.02 + 0.0364*(TK-273.16))
betam = (B1/TK) * ( EXP(b/TK) / ((EXP(b/TK)-1)**2) ) + B2*f*f
beta = betam + deltabeta
theta = 300. / TK - 1.
alfa = (0.00504 + 0.0062*theta) * EXP(-22.1*theta)
m_complex_ice_maetzler = 3.1884 + 9.1e-4*(TK-273.16)
m_complex_ice_maetzler = m_complex_ice_maetzler                   &
                       + CMPLX(0.0, (alfa/f + beta*f))
m_complex_ice_maetzler = SQRT(CONJG(m_complex_ice_maetzler))

end function m_complex_ice_maetzler

!______________________________________________________________________________________

subroutine rayleigh_soak_wetice (lamda4,pi,pi5,x_g,x_w,x_i,     &
               Diam,fmelt,mra,m_w,m_i,lambda,C_back,m_a,        &
               mixingrule,matrix,inclusion,                     &
               host,hostmatrix,hostinclusion)

implicit none

real, intent(in) :: x_g, x_w, x_i, Diam,fmelt, lambda,mra,lamda4,pi,pi5
complex, intent(in) :: m_w, m_i, m_a
character(len=*), intent(in) :: mixingrule, matrix, inclusion,      &
                                host, hostmatrix, hostinclusion
real, intent(out) :: C_back

! Local variable declaration
complex :: m_core,get_m_mix_nested
real    :: D_large, rhog, xw_a, fm, fmgrenz,    &
           volg, vg, volair, volice, volwater,            &
           meltratio_outside_grenz,mral

!    ! The relative portion of meltwater melting at outside should increase
!    ! from the given input value (between 0 and 1)
!    ! to 1 as the degree of melting approaches 1,
!    ! so that the melting particle "converges" to a water drop.
!    ! Simplest assumption is linear:
mral = mra + (1.0-mra)*fmelt

 vg = pi/6. * Diam**3
 rhog = x_g / vg
 vg = x_g / rhog

 D_large  = (6.0 / pi * vg) ** (1./3.)
 volice = (x_g - x_w) / (vg * 900.0)
 volwater = x_w / (1000. * vg)
 volair = 1.0 - volice - volwater

 !..complex index of refraction for the ice-air-water mixture
 !.. of the particle:
 m_core = get_m_mix_nested (m_a, m_i, m_w, volair, volice,        &
                   volwater, mixingrule, host, matrix, inclusion, &
                   hostmatrix, hostinclusion)

 !..Rayleigh-backscattering coefficient of melting particle:
 C_back = (abs((m_core**2-1.0)/(m_core**2+2.0)))**2           &
          * pi5 * D_large**6 / lamda4

end subroutine rayleigh_soak_wetice

!______________________________________________________________________________________

complex function get_m_mix_nested (m_a, m_i, m_w, volair,         &
               volice, volwater, mixingrule, host, matrix,        &
               inclusion, hostmatrix, hostinclusion)

implicit none

real, intent(in):: volice, volair, volwater
complex, intent(in):: m_a, m_i, m_w
character(len=*), intent(in):: mixingrule, host, matrix,          &
                   inclusion, hostmatrix, hostinclusion

! Local variables
real :: vol1, vol2
complex :: mtmp,get_m_mix

!..Folded: ( (m1 + m2) + m3), where m1,m2,m3 could each be
!.. air, ice, or water

      get_m_mix_nested = cmplx(1.0,0.0)

      if (host .eq. 'air') then

        vol1 = volice / max(volice+volwater,1e-10)
        vol2 = 1.0 - vol1
        mtmp = get_m_mix (m_a, m_i, m_w, 0.0, vol1, vol2,             &
                         mixingrule, matrix, inclusion)

        if (hostmatrix .eq. 'air') then
         get_m_mix_nested = get_m_mix (m_a, mtmp, 2.0*m_a,            &
                         volair, (1.0-volair), 0.0, mixingrule,       &
                         hostmatrix, hostinclusion)

        elseif (hostmatrix .eq. 'icewater') then
         get_m_mix_nested = get_m_mix (m_a, mtmp, 2.0*m_a,            &
                         volair, (1.0-volair), 0.0, mixingrule,       &
                         'ice', hostinclusion)
        endif

      elseif (host .eq. 'ice') then

        vol1 = volair / max(volair+volwater,1e-10)
        vol2 = 1.0 - vol1
        mtmp = get_m_mix (m_a, m_i, m_w, vol1, 0.0, vol2,             &
                         mixingrule, matrix, inclusion)

        if (hostmatrix .eq. 'ice') then
         get_m_mix_nested = get_m_mix (mtmp, m_i, 2.0*m_a,            &
                         (1.0-volice), volice, 0.0, mixingrule,       &
                         hostmatrix, hostinclusion)
        elseif (hostmatrix .eq. 'airwater') then
         get_m_mix_nested = get_m_mix (mtmp, m_i, 2.0*m_a,            &
                         (1.0-volice), volice, 0.0, mixingrule,       &
                         'air', hostinclusion)
        endif

      elseif (host .eq. 'water') then

        vol1 = volair / max(volice+volair,1e-10)
        vol2 = 1.0 - vol1
        mtmp = get_m_mix (m_a, m_i, m_w, vol1, vol2, 0.0,             &
                         mixingrule, matrix, inclusion)

        if (hostmatrix .eq. 'water') then
         get_m_mix_nested = get_m_mix (2*m_a, mtmp, m_w,              &
                         0.0, (1.0-volwater), volwater, mixingrule,   &
                         hostmatrix, hostinclusion)
        elseif (hostmatrix .eq. 'airice') then
         get_m_mix_nested = get_m_mix (2*m_a, mtmp, m_w,              &
                         0.0, (1.0-volwater), volwater, mixingrule,   &
                         'ice', hostinclusion)
        endif

      endif ! host choice

end function get_m_mix_nested

!______________________________________________________________________________________

complex function get_m_mix (m_a, m_i, m_w, volair, volice,     &
               volwater, mixingrule, matrix, inclusion)

implicit none

real, intent(in):: volice, volair, volwater
complex, intent(in):: m_a, m_i, m_w
character(len=*), intent(in):: mixingrule, matrix, inclusion
complex :: m_complex_maxwellgarnett

      get_m_mix = cmplx(1.0,0.0)

      if (mixingrule .eq. 'maxwellgarnett') then
       if (matrix .eq. 'ice') then
        get_m_mix = m_complex_maxwellgarnett(volice, volair, volwater,  &
                           m_i, m_a, m_w, inclusion)
       elseif (matrix .eq. 'water') then
        get_m_mix = m_complex_maxwellgarnett(volwater, volair, volice,  &
                           m_w, m_a, m_i, inclusion)
       elseif (matrix .eq. 'air') then
        get_m_mix = m_complex_maxwellgarnett(volair, volwater, volice,  &
                           m_a, m_w, m_i, inclusion)
       endif
      endif

end function get_m_mix

!______________________________________________________________________________________

complex function m_complex_maxwellgarnett(vol1, vol2, vol3,    &
                m1, m2, m3, inclusion)

implicit none

complex :: m1, m2, m3
real :: vol1, vol2, vol3
character(len=*) :: inclusion

! Local variables
complex :: beta2, beta3, m1t, m2t, m3t


 if (abs(vol1+vol2+vol3-1.0) .gt. 1d-6) then
  print*,'problem with partial volumes'
 endif

 m1t = m1**2
 m2t = m2**2
 m3t = m3**2

      if (inclusion .eq. 'spherical') then
       beta2 = 3.0*m1t/(m2t+2.0*m1t)
       beta3 = 3.0*m1t/(m3t+2.0*m1t)
      elseif (inclusion .eq. 'spheroidal') then
       beta2 = 2.0*m1t/(m2t-m1t) * (m2t/(m2t-m1t)*log(m2t/m1t)-1.0)
       beta3 = 2.0*m1t/(m3t-m1t) * (m3t/(m3t-m1t)*log(m3t/m1t)-1.0)
      endif

      m_complex_maxwellgarnett = &
       SQRT(((1.0-vol2-vol3)*m1t + vol2*beta2*m2t + vol3*beta3*m3t) / &
       (1.0-vol2-vol3+vol2*beta2+vol3*beta3))

end function m_complex_maxwellgarnett

 real function compute_mu_3moment2(mom0,mom3,mom6,mu_max)

 !--------------------------------------------------------------------------
 ! Computes mu as a function of moments 0, 3, and 6 of the size distribution
 ! represented by N(D) = No*D^mu*e(-lambda*D).
 !
 ! Note:  moment 3 is not equal to the mass mixing ratio (due to variable density)
 !
 ! G(mu)= mom0*mom6/mom3^2 = [(6+mu)(5+mu)(4+mu)]/[(3+mu)(2+mu)(1+mu)]
 !--------------------------------------------------------------------------

 implicit none

! Arguments passed:
 real, intent(in) :: mom0    !0th moment
 real, intent(in) :: mom3    !3th moment  (note, not normalized)
 real, intent(in) :: mom6    !6th moment  (note, not normalized)
 real, intent(in) :: mu_max  !maximum allowable value of mu

! Local variables:
 real             :: mu   ! shape parameter in gamma distribution
 double precision :: G    ! function of mu (see comments above)
 double precision :: g2,x1,x2,x3
!real             :: a1,g1
!real, parameter  :: eps_m0 = 1.e-20
 real, parameter  :: eps_m3 = 1.e-20
 real, parameter  :: eps_m6 = 1.e-35

 if (mom3>eps_m3) then

    !G = (mom0*mom6)/(mom3**2)
    !To avoid very small values of mom3**2 (not enough)
    !G = (mom0/mom3)*(mom6/mom3)
     x1 = 1./mom3
     x2 = mom0*x1
     x3 = mom6*x1
     G  = x2*x3

     !----------------------------------------------------------!
! !Solve alpha numerically: (brute-force)
!      mu= 0.
!      g2= 999.
!      do i=0,4000
!         a1= i*0.01
!         g1= (6.+a1)*(5.+a1)*(4.+a1)/((3.+a1)*(2.+a1)*(1.+a1))
!         if(abs(g-g1)<abs(g-g2)) then
!            mu = a1
!            g2= g1
!         endif
!      enddo
!----------------------------------------------------------!

!Piecewise-polynomial approximation of G(mu) to solve for mu:
     if (G>=20.) then
        mu = 0.
     else
        g2 = G**2
        if (G<20.  .and.G>=13.31) then
           mu = 3.3638e-3*g2 - 1.7152e-1*G + 2.0857e+0
        elseif (G<13.31.and.G>=7.123) then
           mu = 1.5900e-2*g2 - 4.8202e-1*G + 4.0108e+0
        elseif (G<7.123.and.G>=4.200) then
           mu = 1.0730e-1*g2 - 1.7481e+0*G + 8.4246e+0
        elseif (G<4.200.and.G>=2.946) then
           mu = 5.9070e-1*g2 - 5.7918e+0*G + 1.6919e+1
        elseif (G<2.946.and.G>=1.793) then
           mu = 4.3966e+0*g2 - 2.6659e+1*G + 4.5477e+1
        elseif (G<1.793.and.G>=1.405) then
           mu = 4.7552e+1*g2 - 1.7958e+2*G + 1.8126e+2
        elseif (G<1.405.and.G>=1.230) then
           mu = 3.0889e+2*g2 - 9.0854e+2*G + 6.8995e+2
        elseif (G<1.230) then
           mu = mu_max
        endif
     endif

     compute_mu_3moment2 = mu

 else

    print*, 'Input parameters out of bounds in function COMPUTE_MU_3MOMENT'
    print*, 'mom0 = ',mom0
    print*, 'mom3 = ',mom3
    print*, 'mom6 = ',mom6
    stop

 endif

 end function compute_mu_3moment2
