!> @brief provides DFT-D4 dispersion
module dftd4
   use iso_fortran_env, only : wp => real64
!! ========================================================================
!  mix in the covalent coordination number from the ncoord module
!  also get the CN-Parameters to inline the CN-derivative in the gradient
   use coordination_number, only : covncoord => ncoord_d4, kn,k1,k4,k5,k6
   use class_param, only : dftd_parameter
   implicit none

   real(wp) :: pi,thopi,ootpi
   parameter ( pi = 3.141592653589793238462643383279502884197_wp )
   parameter ( thopi = 3._wp/pi )
   parameter ( ootpi = 0.5_wp/pi )

   integer,parameter :: p_refq_gfn2xtb          = 0
   integer,parameter :: p_refq_gasteiger        = 1
   integer,parameter :: p_refq_hirshfeld        = 2
   integer,parameter :: p_refq_periodic         = 3
   integer,parameter :: p_refq_gfn2xtb_gbsa_h2o = 4
   integer,parameter :: p_refq_goedecker        = 5

   integer,parameter :: p_mbd_none       = 0 !< just pair-wise dispersion
   integer,parameter :: p_mbd_rpalike    = 1 !< RPA-like (=MBD) non-additivity
   integer,parameter :: p_mbd_exact_atm  = 2 !< integrate C9 from polarizibilities
   integer,parameter :: p_mbd_approx_atm = 3 !< approximate C9 from C6

   integer,private,parameter :: max_elem = 118
!> @brief effective nuclear charge used in calculation of polarizibilities
   real(wp),parameter :: zeff(max_elem) = (/ &
   &   1,                                                 2,  & ! H-He
   &   3, 4,                               5, 6, 7, 8, 9,10,  & ! Li-Ne
   &  11,12,                              13,14,15,16,17,18,  & ! Na-Ar
   &  19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,  & ! K-Kr
   &   9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,  & ! Rb-Xe
   &   9,10,11,30,31,32,33,34,35,36,37,38,39,40,41,42,43,  & ! Cs-Lu
   &  12,13,14,15,16,17,18,19,20,21,22,23,24,25,26, & ! Hf-Rn
   !  just copy & paste from above
   &   9,10,11,30,31,32,33,34,35,36,37,38,39,40,41,42,43,  & ! Fr-Lr
   &  12,13,14,15,16,17,18,19,20,21,22,23,24,25,26 /) ! Rf-Og

!> @brief chemical hardness
!!
!! Semiempirical Evaluation of the GlobalHardness of the Atoms of 103
!! Elements of the Periodic Table Using the Most Probable Radii as
!! their Size Descriptors DULAL C. GHOSH, NAZMUL ISLAM 2009 in 
!! Wiley InterScience (www.interscience.wiley.com).
!! DOI 10.1002/qua.22202
!! values in the paper multiplied by two because 
!! (ii:ii)=(IP-EA)=d^2 E/dN^2 but the hardness
!! definition they use is 1/2d^2 E/dN^2 (in Eh)
   real(wp),parameter :: gam(1:max_elem) = (/ &
  &0.47259288,0.92203391,0.17452888,0.25700733,0.33949086,0.42195412, & ! H-C
  &0.50438193,0.58691863,0.66931351,0.75191607,0.17964105,0.22157276, & ! N-Mg
  &0.26348578,0.30539645,0.34734014,0.38924725,0.43115670,0.47308269, & ! Al-Ar
  &0.17105469,0.20276244,0.21007322,0.21739647,0.22471039,0.23201501, & ! Ca-Cr
  &0.23933969,0.24665638,0.25398255,0.26128863,0.26859476,0.27592565, & ! Mn-Zn
  &0.30762999,0.33931580,0.37235985,0.40273549,0.43445776,0.46611708, & ! Ga-Kr
  &0.15585079,0.18649324,0.19356210,0.20063311,0.20770522,0.21477254, & ! Rb-Mo
  &0.22184614,0.22891872,0.23598621,0.24305612,0.25013018,0.25719937, & ! Tc-Cd
  &0.28784780,0.31848673,0.34912431,0.37976593,0.41040808,0.44105777, & ! In-Xe
  &0.05019332,0.06762570,0.08504445,0.10247736,0.11991105,0.13732772, & ! Cs-Nd
  &0.15476297,0.17218265,0.18961288,0.20704760,0.22446752,0.24189645, & ! Pm-Dy
  &0.25932503,0.27676094,0.29418231,0.31159587,0.32902274,0.34592298, & ! Ho-Hf
  &0.36388048,0.38130586,0.39877476,0.41614298,0.43364510,0.45104014, & ! Ta-Pt
  &0.46848986,0.48584550,0.12526730,0.14268677,0.16011615,0.17755889, & ! Au-Po
  &0.19497557,0.21240778,0.07263525,0.09422158,0.09920295,0.10418621, & ! At-Th
  &0.14235633,0.16394294,0.18551941,0.22370139,0.00000000,0.00000000, & ! Pa-Cm
  &0.00000000,0.00000000,0.00000000,0.00000000,0.00000000,0.00000000, & ! Bk-No
  &0.00000000,0.00000000,0.00000000,0.00000000,0.00000000,0.00000000, & ! Rf-Mt
  &0.00000000,0.00000000,0.00000000,0.00000000,0.00000000,0.00000000, & ! Ds-Mc
  &0.00000000,0.00000000,0.00000000,0.00000000 /) ! Lv-Og

!> @brief pauling EN's 
   real(wp),parameter :: en(max_elem) = (/ &
   & 2.20,3.00, & ! H,He
   & 0.98,1.57,2.04,2.55,3.04,3.44,3.98,4.50, & ! Li-Ne
   & 0.93,1.31,1.61,1.90,2.19,2.58,3.16,3.50, & ! Na-Ar
   & 0.82,1.00, & ! K,Ca
   &           1.36,1.54,1.63,1.66,1.55,1.83,1.88,1.91,1.90,1.65, & ! Sc-Zn
   &           1.81,2.01,2.18,2.55,2.96,3.00, & ! Ga-Kr
   & 0.82,0.95, & ! Rb,Sr
   &           1.22,1.33,1.60,2.16,1.90,2.20,2.28,2.20,1.93,1.69, & ! Y-Cd
   &           1.78,1.96,2.05,2.10,2.66,2.60, & ! In-Xe
   & 0.79,0.89, & ! Cs,Ba
   &      1.10,1.12,1.13,1.14,1.15,1.17,1.18, & ! La-Eu
   &      1.20,1.21,1.22,1.23,1.24,1.25,1.26, & ! Gd-Yb
   &           1.27,1.30,1.50,2.36,1.90,2.20,2.20,2.28,2.54,2.00, & ! Lu-Hg
   &           1.62,2.33,2.02,2.00,2.20,2.20, & ! Tl-Rn
   ! only dummies below
   & 1.50,1.50, & ! Fr,Ra
   &      1.50,1.50,1.50,1.50,1.50,1.50,1.50, & ! Ac-Am
   &      1.50,1.50,1.50,1.50,1.50,1.50,1.50, & ! Cm-No
   &           1.50,1.50,1.50,1.50,1.50,1.50,1.50,1.50,1.50,1.50, & ! Rf-Cn
   &           1.50,1.50,1.50,1.50,1.50,1.50 /) ! Nh-Og
! same values in old arrangement
! &         2.200,3.000,0.980,1.570,2.040,2.550,3.040,3.440,3.980 &
! &        ,4.500,0.930,1.310,1.610,1.900,2.190,2.580,3.160,3.500 &
! &        ,0.820,1.000,1.360,1.540,1.630,1.660,1.550,1.830,1.880 &
! &        ,1.910,1.900,1.650,1.810,2.010,2.180,2.550,2.960,3.000 &
! &        ,0.820,0.950,1.220,1.330,1.600,2.160,1.900,2.200,2.280 &
! &        ,2.200,1.930,1.690,1.780,1.960,2.050,2.100,2.660,2.600 &
! &,0.79,0.89,1.10,1.12,1.13,1.14,1.15,1.17,1.18,1.20,1.21,1.22 &
! &,1.23,1.24,1.25,1.26,1.27,1.3,1.5,2.36,1.9,2.2,2.20,2.28,2.54 &
! &,2.00,1.62,2.33,2.02,2.0,2.2,2.2,1.5,1.5,1.5,1.5,1.5,1.5,1.5,1.5/)

!  D3 radii
!   real(wp),parameter :: rcov(max_elem) = (/ &
!  & 0.80628308, 1.15903197, 3.02356173, 2.36845659, 1.94011865, &
!  & 1.88972601, 1.78894056, 1.58736983, 1.61256616, 1.68815527, &
!  & 3.52748848, 3.14954334, 2.84718717, 2.62041997, 2.77159820, &
!  & 2.57002732, 2.49443835, 2.41884923, 4.43455700, 3.88023730, &
!  & 3.35111422, 3.07395437, 3.04875805, 2.77159820, 2.69600923, &
!  & 2.62041997, 2.51963467, 2.49443835, 2.54483100, 2.74640188, &
!  & 2.82199085, 2.74640188, 2.89757982, 2.77159820, 2.87238349, &
!  & 2.94797246, 4.76210950, 4.20778980, 3.70386304, 3.50229216, &
!  & 3.32591790, 3.12434702, 2.89757982, 2.84718717, 2.84718717, &
!  & 2.72120556, 2.89757982, 3.09915070, 3.22513231, 3.17473967, &
!  & 3.17473967, 3.09915070, 3.32591790, 3.30072128, 5.26603625, &
!  & 4.43455700, 4.08180818, 3.70386304, 3.98102289, 3.95582657, &
!  & 3.93062995, 3.90543362, 3.80464833, 3.82984466, 3.80464833, &
!  & 3.77945201, 3.75425569, 3.75425569, 3.72905937, 3.85504098, &
!  & 3.67866672, 3.45189952, 3.30072128, 3.09915070, 2.97316878, &
!  & 2.92277614, 2.79679452, 2.82199085, 2.84718717, 3.32591790, &
!  & 3.27552496, 3.27552496, 3.42670319, 3.30072128, 3.47709584, &
!  & 3.57788113, 5.06446567, 4.56053862, 4.20778980, 3.98102289, &
!  & 3.82984466, 3.85504098, 3.88023730, 3.90543362 /)

!> @brief covalent radii (taken from Pyykko and Atsumi, Chem. Eur. J. 15, 2009,
!! 188-197), values for metals decreased by 10 %
   real(wp),private,parameter :: rad(max_elem) = (/  &
   & 0.32,0.46, & ! H,He
   & 1.20,0.94,0.77,0.75,0.71,0.63,0.64,0.67, & ! Li-Ne
   & 1.40,1.25,1.13,1.04,1.10,1.02,0.99,0.96, & ! Na-Ar
   & 1.76,1.54, & ! K,Ca
   &           1.33,1.22,1.21,1.10,1.07,1.04,1.00,0.99,1.01,1.09, & ! Sc-Zn
   &           1.12,1.09,1.15,1.10,1.14,1.17, & ! Ga-Kr
   & 1.89,1.67, & ! Rb,Sr
   &           1.47,1.39,1.32,1.24,1.15,1.13,1.13,1.08,1.15,1.23, & ! Y-Cd
   &           1.28,1.26,1.26,1.23,1.32,1.31, & ! In-Xe
   & 2.09,1.76, & ! Cs,Ba
   &      1.62,1.47,1.58,1.57,1.56,1.55,1.51, & ! La-Eu
   &      1.52,1.51,1.50,1.49,1.49,1.48,1.53, & ! Gd-Yb
   &           1.46,1.37,1.31,1.23,1.18,1.16,1.11,1.12,1.13,1.32, & ! Lu-Hg
   &           1.30,1.30,1.36,1.31,1.38,1.42, & ! Tl-Rn
   & 2.01,1.81, & ! Fr,Ra
   &      1.67,1.58,1.52,1.53,1.54,1.55,1.49, & ! Ac-Am
   &      1.49,1.51,1.51,1.48,1.50,1.56,1.58, & ! Cm-No
   &           1.45,1.41,1.34,1.29,1.27,1.21,1.16,1.15,1.09,1.22, & ! Lr-Cn
   &           1.36,1.43,1.46,1.58,1.48,1.57 /) ! Nh-Og
   real(wp),parameter :: rcov(max_elem) = 4.0_wp/3.0_wp * rad / 0.52917726_wp


!  r2r4 =sqrt(0.5*r2r4(i)*dfloat(i)**0.5 ) with i=elementnumber
!  the large number of digits is just to keep the results consistent
!  with older versions. They should not imply any higher accuracy
!  than the old values
!   real(wp),parameter :: r4r2(max_elem) = (/ &
!   &   2.00734898,  1.56637132,  5.01986934,  3.85379032,  3.64446594, &
!   &   3.10492822,  2.71175247,  2.59361680,  2.38825250,  2.21522516, &
!   &   6.58585536,  5.46295967,  5.65216669,  4.88284902,  4.29727576, &
!   &   4.04108902,  3.72932356,  3.44677275,  7.97762753,  7.07623947, &
!   &   6.60844053,  6.28791364,  6.07728703,  5.54643096,  5.80491167, &
!   &   5.58415602,  5.41374528,  5.28497229,  5.22592821,  5.09817141, &
!   &   6.12149689,  5.54083734,  5.06696878,  4.87005108,  4.59089647, &
!   &   4.31176304,  9.55461698,  8.67396077,  7.97210197,  7.43439917, &
!   &   6.58711862,  6.19536215,  6.01517290,  5.81623410,  5.65710424, &
!   &   5.52640661,  5.44263305,  5.58285373,  7.02081898,  6.46815523, &
!   &   5.98089120,  5.81686657,  5.53321815,  5.25477007, 11.02204549, &
!   &  10.15679528,  9.35167836,  9.06926079,  8.97241155,  8.90092807, &
!   &   8.85984840,  8.81736827,  8.79317710,  7.89969626,  8.80588454, &
!   &   8.42439218,  8.54289262,  8.47583370,  8.45090888,  8.47339339, &
!   &   7.83525634,  8.20702843,  7.70559063,  7.32755997,  7.03887381, &
!   &   6.68978720,  6.05450052,  5.88752022,  5.70661499,  5.78450695, &
!   &   7.79780729,  7.26443867,  6.78151984,  6.67883169,  6.39024318, &
!   &   6.09527958, 11.79156076, 11.10997644,  9.51377795,  8.67197068, &
!   &   8.77140725,  8.65402716,  8.53923501,  8.85024712 /)

!> @brief <r4>/<r2> expectation values for atoms
!!
!! PBE0/def2-QZVP atomic values calculated by S. Grimme in Gaussian (2010)
!! rare gases recalculated by J. Mewes with PBE0/aug-cc-pVQZ in Dirac (2018)
!! He: 3.4698 -> 3.5544, Ne: 3.1036 -> 3.7943, Ar: 5.6004 -> 5.6638, 
!! Kr: 6.1971 -> 6.2312, Xe: 7.5152 -> 8.8367
!! not replaced but recalculated (PBE0/cc-pVQZ) were
!!  H: 8.0589 ->10.9359, Li:29.0974 ->39.7226, Be:14.8517 ->17.7460
!! also new super heavies Cn,Nh,Fl,Lv,Og
   real(wp),private,parameter :: r2r4(max_elem) = (/  &
   &  8.0589, 3.4698, & ! H,He
   & 29.0974,14.8517,11.8799, 7.8715, 5.5588, 4.7566, 3.8025, 3.1036, & ! Li-Ne
   & 26.1552,17.2304,17.7210,12.7442, 9.5361, 8.1652, 6.7463, 5.6004, & ! Na-Ar
   & 29.2012,22.3934, & ! K,Ca
   &         19.0598,16.8590,15.4023,12.5589,13.4788, & ! Sc-
   &         12.2309,11.2809,10.5569,10.1428, 9.4907, & ! -Zn
   &                 13.4606,10.8544, 8.9386, 8.1350, 7.1251, 6.1971, & ! Ga-Kr
   & 30.0162,24.4103, & ! Rb,Sr
   &         20.3537,17.4780,13.5528,11.8451,11.0355, & ! Y-
   &         10.1997, 9.5414, 9.0061, 8.6417, 8.9975, & ! -Cd
   &                 14.0834,11.8333,10.0179, 9.3844, 8.4110, 7.5152, & ! In-Xe
   & 32.7622,27.5708, & ! Cs,Ba
   &         23.1671,21.6003,20.9615,20.4562,20.1010,19.7475,19.4828, & ! La-Eu
   &         15.6013,19.2362,17.4717,17.8321,17.4237,17.1954,17.1631, & ! Gd-Yb
   &         14.5716,15.8758,13.8989,12.4834,11.4421, & ! Lu-
   &         10.2671, 8.3549, 7.8496, 7.3278, 7.4820, & ! -Hg
   &                 13.5124,11.6554,10.0959, 9.7340, 8.8584, 8.0125, & ! Tl-Rn
   & 29.8135,26.3157, & ! Fr,Ra
   &         19.1885,15.8542,16.1305,15.6161,15.1226,16.1576, 0.0000, & ! Ac-Am
   &          0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, & ! Cm-No
   &          0.0000, 0.0000, 0.0000, 0.0000, 0.0000, & ! Lr-
   &          0.0000, 0.0000, 0.0000, 0.0000, 5.4929, & ! -Cn
   &                  6.7286, 6.5144, 0.0000,10.3600, 0.0000, 8.6641 /) ! Nh-Og
   integer,private :: idum
!> @brief weighted <r4>/<r2> expectation values used for C6 -> C8 extrapolation
   real(wp),parameter :: r4r2(max_elem) = &
   &  sqrt(0.5_wp*(r2r4*(/(sqrt(real(idum,wp)),idum=1,max_elem)/)))

   integer, dimension(max_elem)      :: refn ! for D4
   integer, dimension(max_elem)      :: refs ! for D3 (generated on-the-fly)
   integer, dimension(7,max_elem)    :: refc
   real(wp),dimension(7,max_elem)    :: refq
   real(wp),dimension(7,max_elem)    :: refh
   real(wp),dimension(7,max_elem)    :: dftq,pbcq,gffq,solq,clsq
   real(wp),dimension(7,max_elem)    :: dfth,pbch,gffh,solh,clsh
   real(wp),dimension(7,max_elem)    :: hcount 
   real(wp),dimension(7,max_elem)    :: ascale
   real(wp),dimension(7,max_elem)    :: refcovcn
   real(wp),dimension(7,max_elem)    :: refcn
   integer, dimension(7,max_elem)    :: refsys 
   real(wp),dimension(23,7,max_elem) :: alphaiw
   real(wp),dimension(23,7,max_elem) :: refal
   real(wp),dimension(8)       :: secq
   real(wp),dimension(8)       :: dfts,pbcs,gffs,sols,clss
   real(wp),dimension(8)       :: sscale
   real(wp),dimension(8)       :: seccn
   real(wp),dimension(8)       :: seccnd3
   real(wp),dimension(23,8)    :: secaiw

   include 'param_ref.f'

contains

!> @brief prints molecular properties in a human readable format
!!
!! molecular polarizibilities and molecular C6/C8 coefficients are
!! printed together with the used partial charge, coordination number
!! atomic C6 and static polarizibilities.
subroutine prmolc6(mol,molc6,molc8,molpol,  &
           &       cn,covcn,q,qlmom,c6ab,c8ab,alpha,rvdw,hvol)
   use iso_fortran_env, only : id => output_unit
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   real(wp),intent(in)  :: molc6    !< molecular C6 coefficient in au
   real(wp),intent(in)  :: molc8    !< molecular C8 coefficient in au
   real(wp),intent(in)  :: molpol   !< molecular static dipole polarizibility
   real(wp),intent(in),optional :: cn(mol%nat)
   real(wp),intent(in),optional :: covcn(mol%nat)
   real(wp),intent(in),optional :: q(mol%nat)
   real(wp),intent(in),optional :: qlmom(3,mol%nat)
   real(wp),intent(in),optional :: c6ab(mol%nat,mol%nat)
   real(wp),intent(in),optional :: c8ab(mol%nat,mol%nat)
   real(wp),intent(in),optional :: alpha(mol%nat)
   real(wp),intent(in),optional :: rvdw(mol%nat)
   real(wp),intent(in),optional :: hvol(mol%nat)
   real(wp),parameter :: autoaa = 0.52917726_wp
   integer :: i
   if(present(cn).or.present(covcn).or.present(q).or.present(c6ab) &
   &   .or.present(alpha).or.present(rvdw).or.present(hvol)) then
   write(id,'(a)')
   write(id,'(7x,''   #   Z   '')',advance='no')
   if(present(cn))   write(id,'(''        CN'')',advance='no')
   if(present(covcn))write(id,'(''     covCN'')',advance='no')
   if(present(q))    write(id,'(''         q'')',advance='no')
   if(present(qlmom))write(id,   '(''   n(s)'')',advance='no')
   if(present(qlmom))write(id,   '(''   n(p)'')',advance='no')
   if(present(qlmom))write(id,   '(''   n(d)'')',advance='no')
   if(present(c6ab)) write(id,'(''      C6AA'')',advance='no')
   if(present(c8ab)) write(id,'(''      C8AA'')',advance='no')
   if(present(alpha))write(id,'(''      α(0)'')',advance='no')
   if(present(rvdw)) write(id,'(''    RvdW/Å'')',advance='no')
   if(present(hvol)) write(id,'(''    relVol'')',advance='no')
   write(*,'(a)')
   do i=1,mol%nat
      write(*,'(i11,1x,i3,1x,a2)',advance='no') &
      &     i,mol%at(i),mol%sym(i)
      if(present(cn))   write(id,'(f10.3)',advance='no')cn(i)
      if(present(covcn))write(id,'(f10.3)',advance='no')covcn(i)
      if(present(q))    write(id,'(f10.3)',advance='no')q(i)
      if(present(qlmom))write(id, '(f7.3)',advance='no')qlmom(1,i)
      if(present(qlmom))write(id, '(f7.3)',advance='no')qlmom(2,i)
      if(present(qlmom))write(id, '(f7.3)',advance='no')qlmom(3,i)
      if(present(c6ab)) write(id,'(f10.3)',advance='no')c6ab(i,i)
      if(present(c8ab)) write(id,'(f10.1)',advance='no')c8ab(i,i)
      if(present(alpha))write(id,'(f10.3)',advance='no')alpha(i)
      if(present(rvdw)) write(id,'(f10.3)',advance='no')rvdw(i)*autoaa
      if(present(hvol)) write(id,'(f10.3)',advance='no')hvol(i)
      write(*,'(a)')
   enddo
   endif
   write(id,'(/,12x,''Mol. C6AA /au·bohr⁶  :'',f18.6,'// &
   &         '/,12x,''Mol. C8AA /au·bohr⁸  :'',f18.6,'// &
   &         '/,12x,''Mol. α(0) /au        :'',f18.6,/)') &
   &          molc6,molc8,molpol
end subroutine prmolc6

!> @brief calculate molecular dispersion properties
!!
!! calculates molecular C6/C8 coefficients and molecular static
!! polarizibility, optionally return dipole polarizibilities
!! partitioned to atoms, C6AA coefficients for each atom,
!! radii derived from the polarizibilities and relative
!! volumes relative to the atom
subroutine mdisp(mol,ndim,q,g_a,g_c, &
           &     gw,c6abns,molc6,molc8,molpol,aout,cout,ccout,rout,vout)
!  use dftd4, only : thopi,gam, &
!  &  trapzd,zeta,r4r2, &
!  &  refn,refq,refal
use class_molecule
   implicit none
   type(molecule),intent(in) :: mol   !< molecular structure information
   integer, intent(in)  :: ndim       !< dimension of reference systems
   real(wp),intent(in)  :: q(mol%nat) !< partial charges
   real(wp),intent(in)  :: g_a        !< charge scaling height
   real(wp),intent(in)  :: g_c        !< charge scaling steepness
   real(wp),intent(in)  :: gw(ndim)
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   real(wp),intent(out) :: molc6  !< molecular C6 coefficient in au
   real(wp),intent(out) :: molc8  !< molecular C8 coefficient in au
   real(wp),intent(out) :: molpol !< molecular static dipole polarizibility
   real(wp),intent(out),optional :: aout(23,mol%nat)
   real(wp),intent(out),optional :: cout(mol%nat,mol%nat)
   real(wp),intent(out),optional :: ccout(mol%nat,mol%nat)
   real(wp),intent(out),optional :: rout(mol%nat)
   real(wp),intent(out),optional :: vout(mol%nat)

   integer  :: i,ii,ia,j,jj,ja,k,l
   integer, allocatable :: itbl(:,:)
   real(wp) :: qmod,oth,iz
   real(wp),allocatable :: zetvec(:)
   real(wp),allocatable :: rvdw(:)
   real(wp),allocatable :: phv(:)
   real(wp),allocatable :: c6ab(:,:)
   real(wp),allocatable :: c8ab(:,:)
   real(wp),allocatable :: aw(:,:)
   parameter (oth=1._wp/3._wp)
   
   allocate( zetvec(ndim),rvdw(mol%nat),phv(mol%nat),c6ab(mol%nat,mol%nat), &
   &         c8ab(mol%nat,mol%nat), aw(23,mol%nat),  source = 0.0_wp )
   allocate( itbl(7,mol%nat), source = 0 )

   molc6  = 0._wp
   molc8  = 0._wp
   molpol = 0._wp

   k = 0
   do i = 1, mol%nat
      ia = mol%at(i)
      iz = zeff(ia)
      do ii = 1, refn(ia)
         k = k+1
         itbl(ii,i) = k
         zetvec(k) = gw(k) * zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz)
         aw(:,i) = aw(:,i) + zetvec(k) * refal(:,ii,ia)
      enddo
!     van-der-Waals radius, alpha = 4/3 pi r**3 <=> r = (3/(4pi) alpha)**(1/3)
      rvdw(i) = (0.25_wp*thopi*aw(1,i))**oth
!     pseudo-hirshfeld volume
      phv(i) = aw(1,i)/refal(1,1,ia)
      c6ab(i,i) = thopi * trapzd(aw(:,i)**2)
      c8ab(i,i) = 3*r4r2(ia)**2*c6ab(i,i)
      molpol = molpol + aw(1,i)
      molc6  = molc6  + c6ab(i,i)
      molc8 = molc8 + 3*r4r2(ia)**2*c6ab(i,i)
      do j = 1, i-1
         ja = mol%at(j)
         c6ab(j,i) = thopi * trapzd(aw(:,i)*aw(:,j))
         c6ab(i,j) = c6ab(j,i)
         c8ab(j,i) = 3*r4r2(ia)*r4r2(ja)*c6ab(j,i)
         c8ab(i,j) = c8ab(j,i)
         molc6 = molc6 + 2*c6ab(j,i)
         molc8 = molc8 + 6*r4r2(ia)*r4r2(ja)*c6ab(j,i)
      enddo
   enddo

   if (present(aout)) aout = aw
   if (present(vout)) vout = phv
   if (present(rout)) rout = rvdw
   if (present(cout)) cout = c6ab
   if (present(ccout)) ccout = c8ab

end subroutine mdisp

subroutine prd4ref(mol)
   use iso_fortran_env, only : istdout => output_unit
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol

   integer :: i,ii,ia,j
   logical :: printed(118)

   printed = .false.

   write(istdout,'(a)')
   do i = 1, mol%nat
      ia = mol%at(i)
      if (printed(ia)) cycle
      write(istdout,'(a3,1x,a10,1x,a14,1x,a14,1x,a15)') mol%sym(i), &
         &   'q(ref)','CN(ref)','cov. CN(ref)','α(AIM,ref)'
      do ii = 1, refn(ia)
         write(istdout,'(4x,f10.7,5x,f10.7,5x,f10.7,5x,f10.7)') &
            &      refq(ii,ia),refcn(ii,ia),refcovcn(ii,ia),refal(1,ii,ia)
      enddo
      printed(ia) = .true.
   enddo
   write(istdout,'(a)')
end subroutine prd4ref

!> @brief charge scaling function
pure elemental function zeta(a,c,qref,qmod)
   implicit none
   real(wp),intent(in) :: qmod,qref
   real(wp),intent(in) :: a,c
   real(wp)            :: zeta

   intrinsic :: exp

   if (qmod.lt.0._wp) then
      zeta = exp( a )
   else
      zeta = exp( a * ( 1._wp - exp( c * ( 1._wp - qref/qmod ) ) ) )
   endif

end function zeta

!> @brief derivative of charge scaling function w.r.t. charge
pure elemental function dzeta(a,c,qref,qmod)
!  use dftd4, only : zeta
   implicit none
   real(wp),intent(in) :: qmod,qref
   real(wp),intent(in) :: a,c
   real(wp)            :: dzeta

   intrinsic :: exp

   if (qmod.lt.0._wp) then
      dzeta = 0._wp
   else
      dzeta = - a * c * exp( c * ( 1._wp - qref/qmod ) ) &
      &           * zeta(a,c,qref,qmod) * qref / ( qmod**2 )
   endif

end function dzeta

!> @brief numerical Casimir-Polder integration
pure function trapzd(pol)
   implicit none
   real(wp),intent(in) :: pol(23)
   real(wp)            :: trapzd

   real(wp)            :: tmp1, tmp2
   real(wp),parameter  :: freq(23) = (/ &
&   0.000001_wp,0.050000_wp,0.100000_wp, &
&   0.200000_wp,0.300000_wp,0.400000_wp, &
&   0.500000_wp,0.600000_wp,0.700000_wp, &
&   0.800000_wp,0.900000_wp,1.000000_wp, &
&   1.200000_wp,1.400000_wp,1.600000_wp, &
&   1.800000_wp,2.000000_wp,2.500000_wp, &
&   3.000000_wp,4.000000_wp,5.000000_wp, &
&   7.500000_wp,10.00000_wp /)
!  just precalculate all weights and get the job done
   real(wp),parameter :: weights(23) = 0.5_wp * (/ &
&  ( freq (2) - freq (1) ),  &
&  ( freq (2) - freq (1) ) + ( freq (3) - freq (2) ),  &
&  ( freq (3) - freq (2) ) + ( freq (4) - freq (3) ),  &
&  ( freq (4) - freq (3) ) + ( freq (5) - freq (4) ),  &
&  ( freq (5) - freq (4) ) + ( freq (6) - freq (5) ),  &
&  ( freq (6) - freq (5) ) + ( freq (7) - freq (6) ),  &
&  ( freq (7) - freq (6) ) + ( freq (8) - freq (7) ),  &
&  ( freq (8) - freq (7) ) + ( freq (9) - freq (8) ),  &
&  ( freq (9) - freq (8) ) + ( freq(10) - freq (9) ),  &
&  ( freq(10) - freq (9) ) + ( freq(11) - freq(10) ),  &
&  ( freq(11) - freq(10) ) + ( freq(12) - freq(11) ),  &
&  ( freq(12) - freq(11) ) + ( freq(13) - freq(12) ),  &
&  ( freq(13) - freq(12) ) + ( freq(14) - freq(13) ),  &
&  ( freq(14) - freq(13) ) + ( freq(15) - freq(14) ),  &
&  ( freq(15) - freq(14) ) + ( freq(16) - freq(15) ),  &
&  ( freq(16) - freq(15) ) + ( freq(17) - freq(16) ),  &
&  ( freq(17) - freq(16) ) + ( freq(18) - freq(17) ),  &
&  ( freq(18) - freq(17) ) + ( freq(19) - freq(18) ),  &
&  ( freq(19) - freq(18) ) + ( freq(20) - freq(19) ),  &
&  ( freq(20) - freq(19) ) + ( freq(21) - freq(20) ),  &
&  ( freq(21) - freq(20) ) + ( freq(22) - freq(21) ),  &
&  ( freq(22) - freq(21) ) + ( freq(23) - freq(22) ),  &
&  ( freq(23) - freq(22) ) /)

!!  do average between trap(1)-trap(22) .and. trap(2)-trap(23)
!   tmp1 = 0.5_wp * ( &
!&  ( freq (2) - freq (1) ) * ( pol (2) + pol (1) )+ &
!&  ( freq (4) - freq (3) ) * ( pol (4) + pol (3) )+ &
!&  ( freq (6) - freq (5) ) * ( pol (6) + pol (5) )+ &
!&  ( freq (8) - freq (7) ) * ( pol (8) + pol (7) )+ &
!&  ( freq(10) - freq (9) ) * ( pol(10) + pol (9) )+ &
!&  ( freq(12) - freq(11) ) * ( pol(12) + pol(11) )+ &
!&  ( freq(14) - freq(13) ) * ( pol(14) + pol(13) )+ &
!&  ( freq(16) - freq(15) ) * ( pol(16) + pol(15) )+ &
!&  ( freq(18) - freq(17) ) * ( pol(18) + pol(17) )+ &
!&  ( freq(20) - freq(19) ) * ( pol(20) + pol(19) )+ &
!&  ( freq(22) - freq(21) ) * ( pol(22) + pol(21) ))
!   tmp2 = 0.5_wp * ( &
!&  ( freq (3) - freq (2) ) * ( pol (3) + pol (2) )+ &
!&  ( freq (5) - freq (4) ) * ( pol (5) + pol (4) )+ &
!&  ( freq (7) - freq (6) ) * ( pol (7) + pol (6) )+ &
!&  ( freq (9) - freq (8) ) * ( pol (9) + pol (8) )+ &
!&  ( freq(11) - freq(10) ) * ( pol(11) + pol(10) )+ &
!&  ( freq(13) - freq(12) ) * ( pol(13) + pol(12) )+ &
!&  ( freq(15) - freq(14) ) * ( pol(15) + pol(14) )+ &
!&  ( freq(17) - freq(16) ) * ( pol(17) + pol(16) )+ &
!&  ( freq(19) - freq(18) ) * ( pol(19) + pol(18) )+ &
!&  ( freq(21) - freq(20) ) * ( pol(21) + pol(20) )+ &
!&  ( freq(23) - freq(22) ) * ( pol(23) + pol(22) ))

   trapzd = sum(pol*weights)

end function trapzd

!> @brief coordination number gaussian weight
pure elemental function cngw(wf,cn,cnref)
   implicit none
   real(wp),intent(in) :: wf,cn,cnref
   real(wp)            :: cngw ! CN-gaussian-weight

   intrinsic :: exp

   cngw = exp ( -wf * ( cn - cnref )**2 )

end function cngw

!> @brief derivative of gaussian weight w.r.t. coordination number
pure elemental function dcngw(wf,cn,cnref)
!  use dftd4, only : cngw
   implicit none
   real(wp),intent(in) :: wf,cn,cnref
   real(wp) :: dcngw

   dcngw = 2*wf*(cnref-cn)*cngw(wf,cn,cnref)

end function dcngw

!> @brief BJ damping function ala DFT-D3(BJ)
!!
!! f(n,rab) = sn*rab**n/(rab**n + R0**n)  w/ R0 = a1*sqrt(C6/C8)+a2
!! see: https://doi.org/10.1002/jcc.21759
pure elemental function fdmpr_bj(n,r,c) result(fdmp)
   implicit none
   integer, intent(in)  :: n  !< order
   real(wp),intent(in)  :: r  !< distance
   real(wp),intent(in)  :: c  !< critical radius
   real(wp) :: fdmp
   fdmp = 1.0_wp / ( r**n + c**n )
end function fdmpr_bj
!> @brief derivative of BJ damping function ala DFT-D3(BJ)
pure elemental function fdmprdr_bj(n,r,c) result(dfdmp)
   implicit none
   integer, intent(in)  :: n  !< order
   real(wp),intent(in)  :: r  !< distance
   real(wp),intent(in)  :: c  !< critical radius
   real(wp) :: dfdmp
   dfdmp = -n*r**(n-1) * fdmpr_bj(n,r,c)**2
end function fdmprdr_bj

!> @brief original DFT-D3(0) damping
!!
!! f(n,rab) = sn/(1+6*(4/3*R0/rab)**alp)  w/ R0 of unknown origin
pure elemental function fdmpr_zero(n,r,c,alp) result(fdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   integer, intent(in)  :: alp !< exponent
   real(wp),parameter   :: six = 6.0_wp
   real(wp) :: fdmp
   fdmp = 1.0_wp / (r**n*(1 + six * (c/r)**(n+alp)))
end function fdmpr_zero
!> @brief derivative of original DFT-D3(0) damping
pure elemental function fdmprdr_zero(n,r,c,alp) result(dfdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   integer, intent(in)  :: alp !< exponent
   real(wp),parameter   :: six = 6.0_wp
   real(wp) :: dfdmp
   dfdmp = -( n*r**(n-1)*(1+six*(c/r)**(alp)) &
             - alp*r**n/c*six*(c/r)**(alp-1) ) &
           * fdmpr_zero(n,r,c,alp)**2
!  fdmp = 1.0_wp / (r**n*(1 + 6.0_wp * (c/r)**(n+alp)))
end function fdmprdr_zero

!> @brief fermi damping function from TS and MBD methods
!!
!! f(n,rab) = sn/(1+exp[-alp*(rab/R0-1)]) w/ R0 as experimenal vdW-Radii
pure elemental function fdmpr_fermi(n,r,c,alp) result(fdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   integer, intent(in)  :: alp !< steepness
   real(wp) :: fdmp
   fdmp = 1.0_wp / (r**n*(1.0_wp+exp(-alp*(r/c - 1.0))))
end function fdmpr_fermi
!> @brief derivative of fermi damping function from TS and MBD methods
pure elemental function fdmprdr_fermi(n,r,c,alp) result(dfdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   integer, intent(in)  :: alp !< steepness
   real(wp) :: dfdmp
   dfdmp = -(-alp/c*r**n*exp(-alp*(r/c - 1.0)) &
             + n*r**(n-1)*(1.0_wp+exp(-alp*(r/c - 1.0)))) &
             * fdmpr_fermi(n,r,c,alp)**2
end function fdmprdr_fermi

!> @brief optimized power zero damping (M. Head-Gordon)
!!
!! f(n,rab) = sn*rab**(n+alp)/(rab**(n+alp) + R0**(n+alp))
!! see: https://dx.doi.org/10.1021/acs.jpclett.7b00176
pure elemental function fdmpr_op(n,r,c,alp) result(fdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   integer, intent(in)  :: alp !< optimized power
   real(wp) :: fdmp
   fdmp = r**alp / (r**(n+alp)*c**(n+alp))
end function fdmpr_op
!> @brief derivative optimized power zero damping (M. Head-Gordon)
pure elemental function fdmprdr_op(n,r,c,alp) result(dfdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   integer, intent(in)  :: alp !< optimized power
   real(wp) :: dfdmp
   dfdmp = (alp*r*(alp-1) - (n+alp)*r**alp*r**(n+alp-1)) &
           * fdmpr_op(n,r,c,alp)**2
!  fdmp = r**alp / (r**(n+alp)*c**(n+alp))
end function fdmprdr_op

!> @brief Sherrill's M-zero damping function
!!
!! f(n,rab) = sn/(1+6*(4/3*R0/rab+a2*R0)**(-alp))
!! see: https://dx.doi.org/10.1021/acs.jpclett.6b00780
pure elemental function fdmpr_zerom(n,r,c,rsn,alp) result(fdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   real(wp),intent(in)  :: rsn !< offset for critical radius
   integer, intent(in)  :: alp !< exponent
   real(wp),parameter   :: six = 6.0_wp
   real(wp) :: fdmp
   fdmp = 1.0_wp / (r**n*(1 + six * (r/c+rsn*c)**(-alp)))
end function fdmpr_zerom
!> @brief derivative of Sherrill's M-zero damping function
pure elemental function fdmprdr_zerom(n,r,c,rsn,alp) result(dfdmp)
   implicit none
   integer, intent(in)  :: n   !< order
   real(wp),intent(in)  :: r   !< distance
   real(wp),intent(in)  :: c   !< critical radius
   real(wp),intent(in)  :: rsn !< offset for critical radius
   integer, intent(in)  :: alp !< exponent
   real(wp),parameter   :: six = 6.0_wp
   real(wp) :: dfdmp
   dfdmp = -( n*r**(n-1)*(1+six*(r/c+rsn*c)**(-alp)) &
              - alp*r**n/c*six*(r/c+rsn*c)**(-alp-1) ) &
           * fdmpr_zerom(n,r,c,rsn,alp)**2
end function fdmprdr_zerom

!> @brief initialize the dftd4 module
subroutine d4init(mol,g_a,g_c,mode,ndim)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   real(wp),intent(in)  :: g_a,g_c
   integer, intent(in)  :: mode
   integer, intent(out) :: ndim

   integer  :: i,ia,is,icn,j
   integer  :: cncount(0:15)
   real(wp) :: sec_al(23),iz

   intrinsic :: nint

   select case(mode)
   case(p_refq_hirshfeld,p_refq_periodic)
!     print'(1x,''* using PBE0/def2-TZVP Hirshfeld charges'')'
      refq = dftq
      refh = dfth
      secq = dfts
!  case(2)
!     refq = pbcq
!     refh = pbch
!     secq = pbcs
   case(p_refq_gasteiger)
!     print'(1x,''* using classical Gasteiger charges'')'
      refq = gffq
      refh = gffh
      secq = gffs
   case(p_refq_goedecker)
      refq = clsq
      refh = clsh
      secq = clss
   case(p_refq_gfn2xtb_gbsa_h2o)
!     print'(1x,''* using GFN2-xTB//GBSA(H2O) charges'')'
      refq = solq
      refh = solh
      secq = sols
   end select

   ndim = 0
   refal = 0.0_wp

!* set up refc und refal, also obtain the dimension of the dispmat
   do i = 1, mol%nat
      cncount = 0
      cncount(0) = 1
      ia = mol%at(i)
      do j = 1, refn(ia)
         is = refsys(j,ia)
         iz = zeff(is)
         sec_al = sscale(is)*secaiw(:,is) &
         &  * zeta(g_a,gam(is)*g_c,secq(is)+iz,refh(j,ia)+iz)
         icn =nint(refcn(j,ia))
         cncount(icn) = cncount(icn) + 1
         refal(:,j,ia) = max(ascale(j,ia)*(alphaiw(:,j,ia)-hcount(j,ia)*sec_al),0.0_wp)
      enddo
      do j = 1, refn(ia)
         icn = cncount(nint(refcn(j,ia)))
         refc(j,ia) = icn*(icn+1)/2
      enddo
      ndim = ndim + refn(ia)
   enddo

end subroutine d4init

!> @brief get calculation dimension for DFT-D4 reference systems
subroutine d4dim(mol,ndim)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(out) :: ndim     !< total number of reference systems

   integer :: i

   ndim = 0

   do i = 1, mol%nat
      ndim = ndim + refn(mol%at(i))
   enddo

end subroutine d4dim

!> @brief basic D4 calculation
!!
!! obtain gaussian weights for the references systems based on
!! input CN and integrate reference C6 coefficients
subroutine d4(mol,ndim,wf,g_a,g_c,covcn,gw,c6abns)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim     !< calculation dimension
   real(wp),intent(in)  :: wf,g_a,g_c
   real(wp),intent(in)  :: covcn(mol%nat)  !< covalent coordination number
   real(wp),intent(out) :: gw(ndim)
   real(wp),intent(out) :: c6abns(ndim,ndim)

   integer  :: i,ia,is,icn,ii,iii,j,jj,ja,k,l
   integer,allocatable :: itbl(:,:)
   real(wp) :: twf,norm,aiw(23)

   intrinsic :: maxval

   allocate( itbl(7,mol%nat), source = 0 )

   gw = 0._wp
   c6abns = 0._wp

   k = 0
   do i = 1, mol%nat
      do ii = 1, refn(mol%at(i))
         k = k+1
         itbl(ii,i) = k
      enddo
   enddo

   do i = 1, mol%nat
      ia = mol%at(i)
      norm = 0.0_wp
      do ii = 1, refn(ia)
         do iii = 1, refc(ii,ia)
            twf = iii*wf
            norm = norm + cngw(twf,covcn(i),refcovcn(ii,ia))
         enddo
      enddo
      norm = 1._wp / norm
      do ii = 1, refn(ia)
         k = itbl(ii,i)
         do iii = 1, refc(ii,ia)
            twf = iii*wf
            gw(k) = gw(k) + cngw(twf,covcn(i),refcovcn(ii,ia)) * norm
         enddo
!    --- okay, if we run out of numerical precision, gw(k) will be NaN.
!        In case it is NaN, it will not match itself! So we can rescue
!        this exception. This can only happen for very high CNs.
         if (gw(k).ne.gw(k)) then
            if (maxval(refcovcn(:refn(ia),ia)).eq.refcovcn(ii,ia)) then
               gw(k) = 1.0_wp
            else
               gw(k) = 0.0_wp
            endif
         endif
         do j = 1, i-1
            ja = mol%at(j)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               aiw = refal(:,ii,ia)*refal(:,jj,ja)
               c6abns(l,k) = thopi * trapzd(aiw)
               c6abns(k,l) = c6abns(l,k)
            enddo
         enddo
      enddo
   enddo

end subroutine d4

!> @brief build a dispersion matrix (mainly for SCC calculations)
pure subroutine build_dispmat(mol,ndim,par,c6abns,dispmat)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   type(dftd_parameter),intent(in)  :: par
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   real(wp),intent(out) :: dispmat(ndim,ndim)

   integer  :: i,ii,ia,j,jj,ja,k,l
   integer, allocatable :: itbl(:,:)
   real(wp) :: c8abns,c10abns,r,r2,oor6,oor8,oor10,cutoff
   real(wp), parameter :: rthr = 72.0_wp ! slightly larger than in gradient

   allocate( itbl(7,mol%nat), source = 0 )

   dispmat = 0.0_wp

   k = 0
   do i = 1, mol%nat
      do ii = 1, refn(mol%at(i))
         k = k + 1
         itbl(ii,i) = k
      enddo
   enddo

   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         cutoff = par%a1*sqrt(3._wp*r4r2(mol%at(i))*r4r2(mol%at(j)))+par%a2
         r = norm2(mol%xyz(:,j)-mol%xyz(:,i))
         if (r.gt.rthr) cycle
!        oor6  = 1.0_wp/(r**6  + cutoff**6 )
!        oor8  = 1.0_wp/(r**8  + cutoff**8 )
!        oor10 = 1.0_wp/(r**10 + cutoff**10)
         oor6  = fdmpr_bj( 6,r,cutoff)
         oor8  = fdmpr_bj( 8,r,cutoff)
         oor10 = fdmpr_bj(10,r,cutoff)
         do ii = 1, refn(ia)
            k = itbl(ii,i)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               c8abns = 3.0_wp * r4r2(ia)*r4r2(ja) * c6abns(k,l)
               c10abns = 49.0_wp/40.0_wp * c8abns**2/c6abns(k,l)
               dispmat(k,l) = &
               &  - par%s6 * ( c6abns(k,l) * oor6 ) &
               &  - par%s8 * ( c8abns      * oor8 ) &
               &  - par%s8 * ( c10abns     * oor8 )
               dispmat(l,k) = dispmat(k,l)
            enddo
         enddo
      enddo
   enddo

end subroutine build_dispmat

!> @brief build a weighted dispersion matrix (mainly for SCC calculations)
subroutine build_wdispmat(mol,ndim,par,c6abns,gw,wdispmat)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   type(dftd_parameter),intent(in)  :: par
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   real(wp),intent(in)  :: gw(ndim)
   real(wp),intent(out) :: wdispmat(ndim,ndim)

   integer :: i,ii,ia,j,jj,ja,k,l
   integer, allocatable :: itbl(:,:)
   real(wp) :: c8abns,c10abns,r2,cutoff,oor6,oor8,oor10,r,gwgw,r4r2ij
   real(wp), parameter :: rthr = 72.0_wp ! slightly larger than in gradient
   real(wp), parameter :: gwcut = 1.0e-7_wp

   allocate( itbl(7,mol%nat), source = 0 )
 
   wdispmat = 0.0_wp

   k = 0
   do i = 1, mol%nat
      do ii = 1, refn(mol%at(i))
         k = k + 1
         itbl(ii,i) = k
      enddo
   enddo

   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         r4r2ij = 3.0_wp*r4r2(ia)*r4r2(ja)
         cutoff = par%a1*sqrt(r4r2ij)+par%a2
!        r2 = sum( (mol%xyz(:,j)-mol%xyz(:,i))**2 )
!        oor6  = 1.0_wp/(r2**3 + cutoff**6 )
!        oor8  = 1.0_wp/(r2**4 + cutoff**8 )
!        oor10 = 1.0_wp/(r2**5 + cutoff**10)
         r = norm2(mol%xyz(:,j)-mol%xyz(:,i))
         if (r.gt.rthr) cycle
         oor6  = fdmpr_bj( 6,r,cutoff)
         oor8  = fdmpr_bj( 8,r,cutoff)
         oor10 = fdmpr_bj(10,r,cutoff)
         do ii = 1, refn(ia)
            k = itbl(ii,i)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               gwgw = gw(k)*gw(l)
               if (gwgw.lt.gwcut) cycle
               c8abns  = r4r2ij * c6abns(k,l)
               c10abns = 49.0_wp/40.0_wp * r4r2ij**2 * c6abns(k,l)
               wdispmat(k,l) = gw(k)*gw(l) * ( &
               &  - par%s6  * ( c6abns(k,l)  * oor6 ) &
               &  - par%s8  * ( c8abns       * oor8 ) &
               &  - par%s10 * ( c10abns      * oor10) )
               wdispmat(l,k) = wdispmat(k,l)
               if (abs(c6abns(k,l)).lt.0.1_wp) then
               print*,ia,ja,c6abns(k,l),i,ii,j,jj
               endif
            enddo
         enddo
      enddo
   enddo

end subroutine build_wdispmat

!> @brief calculate contribution to the Fockian
subroutine disppot(mol,ndim,q,g_a,g_c,wdispmat,gw,hdisp)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   real(wp),intent(in)  :: q(mol%nat)
   real(wp),intent(in)  :: g_a,g_c
   real(wp),intent(in)  :: wdispmat(ndim,ndim)
   real(wp),intent(in)  :: gw(ndim)
   real(wp),intent(out) :: hdisp(mol%nat)

   integer  :: i,ii,k,ia
   real(wp) :: qmod,iz
   real(wp),parameter   :: gw_cut = 1.0e-7_wp
   real(wp),allocatable :: zetavec(:)
   real(wp),allocatable :: zerovec(:)
   real(wp),allocatable :: dumvec(:)

   intrinsic :: sum,dble

   allocate( zetavec(ndim),zerovec(ndim),dumvec(ndim), source = 0._wp )

   zetavec = 0.0_wp
   zerovec = 0.0_wp
   dumvec  = 0.0_wp
   hdisp   = 0.0_wp

   k = 0
   do i = 1, mol%nat
       ia = mol%at(i)
       iz = zeff(ia)
       do ii = 1, refn(ia)
          k = k + 1
          if (gw(k).lt.gw_cut) cycle
          zerovec(k) = dzeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz)
          zetavec(k) =  zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz)
      enddo
   enddo
!  create vector -> dispmat(ndim,dnim) * zetavec(ndim) = dumvec(ndim) 
   call dsymv('U',ndim,1._wp,wdispmat,ndim,zetavec,1,0._wp,dumvec,1)
!  call dgemv('N',ndim,ndim,1._wp,wdispmat,ndim,zetavec, &
!  &     1,0._wp,dumvec,1)
!  get atomic reference contributions
   k = 0
   do i = 1, mol%nat
      ia = mol%at(i)
      hdisp(i) = sum(dumvec(k+1:k+refn(ia))*zerovec(k+1:k+refn(ia)))
      k = k + refn(ia)
   enddo

   deallocate(zetavec,zerovec,dumvec)

end subroutine disppot

!> @brief calculate dispersion energy in SCC
function edisp_scc(mol,ndim,q,g_a,g_c,wdispmat,gw) result(ed)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   real(wp),intent(in)  :: q(mol%nat)
   real(wp),intent(in)  :: g_a,g_c
   real(wp),intent(in)  :: wdispmat(ndim,ndim)
   real(wp),intent(in)  :: gw(ndim)
   real(wp) :: ed

   integer  :: i,ii,k,ia
   real(wp) :: qmod,iz
   real(wp),parameter   :: gw_cut = 1.0e-7_wp
   real(wp),allocatable :: zetavec(:)
   real(wp),allocatable :: dumvec(:)

   intrinsic :: sum,dble

   allocate( zetavec(ndim),dumvec(ndim), source = 0._wp )

   ed = 0.0_wp

   k = 0
   do i = 1, mol%nat
       ia = mol%at(i)
       iz = zeff(ia)
       do ii = 1, refn(ia)
          k = k + 1
          if (gw(k).lt.gw_cut) cycle
          zetavec(k) =  zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz)
      enddo
   enddo
!  create vector -> dispmat(ndim,dnim) * zetavec(ndim) = dumvec(ndim) 
   call dsymv('U',ndim,0.5_wp,wdispmat,ndim,zetavec,1,0.0_wp,dumvec,1)
!  call dgemv('N',ndim,ndim,0.5_wp,wdispmat,ndim,zetavec, &
!  &           1,0.0_wp,dumvec,1)
   ed = dot_product(dumvec,zetavec)

   deallocate(zetavec,dumvec)

end function edisp_scc

!> @brief calculate D4 dispersion energy
!!
!! @param[in]      q       partial charges
!! @param[in]      par     damping parameters
!! @param[in]      g_a     charge scale height
!! @param[in]      g_c     charge scale steepness
!! @param[in]      gw      gaussian weights for references
!! @param[in]      c6abns  reference C6 coefficients
!! @param[in]      mbd     type of non-additivity correction
!! @param[out]     e       energy from gradient calculation
!! @param[out]     aout    dipole polarizibilities
subroutine edisp(mol,ndim,q,par,g_a,g_c, &
           &     gw,c6abns,mbd,E,aout,etwo,emany)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim     !< calculation dimension
   real(wp),intent(in)  :: q(mol%nat) 
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(in)  :: g_a,g_c
   real(wp),intent(in)  :: gw(ndim)
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   integer, intent(in)  :: mbd
   real(wp),intent(out) :: E
   real(wp),intent(out),optional :: aout(23,mol%nat)
   real(wp),intent(out),optional :: etwo
   real(wp),intent(out),optional :: emany

   integer  :: i,ii,ia,k,ij,l,j,jj,ja
   integer, allocatable :: itbl(:,:)
   real(wp) :: Embd,qmod,c6ij,c6ij_ns,oor6,oor8,oor10,r2,cutoff,iz,r
   real(wp),allocatable :: dispmat(:,:)
   real(wp),allocatable :: zetvec(:)
   real(wp),allocatable :: zerovec(:)
   real(wp),allocatable :: dumvec(:)
   real(wp),allocatable :: c6ab(:)
   real(wp),allocatable :: aw(:,:)
   real(wp),allocatable :: oor6ab(:,:)

   intrinsic :: present,sqrt,sum
   
   allocate( zetvec(ndim),aw(23,mol%nat),oor6ab(mol%nat,mol%nat), &
   &         zerovec(ndim),c6ab(mol%nat*(mol%nat+1)/2), &
   &         source = 0.0_wp )
   allocate( itbl(7,mol%nat), source = 0 )

   e = 0.0_wp

   k = 0
   do i = 1, mol%nat
      do ii = 1, refn(mol%at(i))
         k = k + 1
         itbl(ii,i) = k
      enddo
   enddo

   do i = 1, mol%nat
      ia = mol%at(i)
      iz = zeff(ia)
      do ii = 1, refn(ia)
         k = itbl(ii,i)
         zetvec(k) = gw(k) * zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz)
         zerovec(k) = gw(k) * zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,iz)
         aw(:,i) = aw(:,i) + zerovec(k) * refal(:,ii,ia)
      enddo
   enddo

!$OMP parallel private(i,j,ia,ja,ij,k,l,r,oor6,oor8,oor10,cutoff,c6ij,c6ij_ns) &
!$omp&         shared(c6ab) reduction(-:E)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         ij = i*(i-1)/2 + j
         r = norm2(mol%xyz(:,i)-mol%xyz(:,j))
!        r2 = sum( (mol%xyz(:,i)-mol%xyz(:,j))**2 )
         cutoff = par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ja))+par%a2
!        oor6 = 1._wp/(r2**3 + cutoff**6)
         oor6 = fdmpr_bj( 6,r,cutoff)
         oor6ab(i,j) = oor6
         oor6ab(j,i) = oor6
!        oor8  = 1._wp/(r2**4 + cutoff**8)
!        oor10 = 1._wp/(r2**5 + cutoff**10)
         oor8  = fdmpr_bj( 8,r,cutoff)
         oor10 = fdmpr_bj(10,r,cutoff)
         c6ij_ns = 0.0_wp
         c6ij = 0.0_wp
         do ii = 1, refn(ia)
            k = itbl(ii,i)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               c6ij_ns = c6ij_ns + zerovec(k)*zerovec(l)*c6abns(k,l)
               c6ij = c6ij + zetvec(k)*zetvec(l)*c6abns(k,l)
            enddo
         enddo
         c6ab(ij) = c6ij_ns
         E = E - c6ij*(par%s6*oor6 + par%s8*3._wp*r4r2(ia)*r4r2(ja)*oor8 &
         &      + par%s10*49.0_wp/40._wp*(3.0_wp*r4r2(ia)*r4r2(ja))**2*oor10 )
      enddo
   enddo
!$omp enddo
!$omp end parallel

   if (present(Etwo)) Etwo = E

   select case(mbd)
   case(p_mbd_rpalike) ! full RPA-like MBD
!     print'(1x,''* MBD effects calculated by RPA like scheme'')'
      call dispmb(mol,Embd,aw,oor6ab)
      Embd = par%s9*Embd
      E = E + Embd
   case(p_mbd_exact_atm) ! Axilrod-Teller-Muto three-body term
!     print'(1x,''* MBD effects calculated by ATM formula'')'
      call dispabc(mol,aw,par,Embd)
      E = E + Embd
   case(p_mbd_approx_atm) ! D3-like approximated ATM term
!     print'(1x,''* MBD effects approximated by ATM formula'')'
      call apprabc(mol,c6ab,par,Embd)
      E = E + Embd
   case default
      Embd = 0.0_wp
   end select

   if (present(Emany)) Emany = Embd

   if (present(aout)) then
      aout = 0._wp
      do i = 1, mol%nat
         ia = mol%at(i)
         do ii = 1, refn(ia)
            aout(:,i) = aout(:,i) + zetvec(k) * refal(:,ii,ia)
         enddo
      enddo
   endif

end subroutine edisp

!> @brief compute D4 gradient
!!
!! @param[in]      q       partial charges
!! @param[in]      dqdr    derivative of partial charges w.r.t. nuclear coordinates
!! @param[in]      cn      coordination number
!! @param[in]      dcndr   derivative of CNs w.r.t. nuclear coordinates
!! @param[in]      par     damping parameters
!! @param[in]      wf      gaussian weighting factor
!! @param[in]      g_a     charge scale height
!! @param[in]      g_c     charge scale steepness
!! @param[in]      c6abns  reference C6 coefficients
!! @param[in]      mbd     type of non-additivity correction
!! @param[in,out]  g       molecular gradient
!! @param[out]     eout    energy from gradient calculation
!! @param[out]     aout    dipole polarizibilities
!
! ∂E/∂rij = ∂/∂rij (W·D·W)
!         = ∂W/∂rij·D·W  + W·∂D/∂rij·W + W·D·∂W/∂rij
!
! ∂W/∂rij = ∂(ζ·w)/∂rij = ∂ζ/∂rij·w + ζ·∂w/∂rij
!         = ζ·∂w/∂CN·∂CN/∂rij + w·∂ζ/∂q·∂q/∂rij
!
subroutine dispgrad(mol,ndim,q,dqdr,cn,dcndr, &
           &        par,wf,g_a,g_c, &
           &        c6abns,mbd, &
           &        g,eout,aout)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim     !< calculation dimension
   real(wp),intent(in)  :: q(mol%nat)
   real(wp),intent(in)  :: dqdr(3,mol%nat,mol%nat)
   real(wp),intent(in)  :: cn(mol%nat)
   real(wp),intent(in)  :: dcndr(3,mol%nat,mol%nat)
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(in)  :: wf,g_a,g_c
!  real(wp),intent(in)  :: gw(ndim) ! calculate on-the-fly
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   integer, intent(in)  :: mbd
   real(wp),intent(inout)        :: g(3,mol%nat)
   real(wp),intent(out),optional :: eout
   real(wp),intent(out),optional :: aout(23,mol%nat)

   integer  :: i,ii,iii,j,jj,k,l,ia,ja,ij
   integer, allocatable :: itbl(:,:)
   real(wp) :: iz
   real(wp) :: qmod,eabc,ed
   real(wp) :: norm,dnorm
   real(wp) :: dexpw,expw
   real(wp) :: twf,tgw,r4r2ij
   real(wp) :: rij(3),r,r2,r4,r6,r8,R0
   real(wp) :: oor6,oor8,oor10,door6,door8,door10
   real(wp) :: c8abns,disp,x1,x2,x3
   real(wp) :: c6ij,dic6ij,djc6ij,dizij,djzij
   real(wp) :: rcovij,expterm,den
   real(wp) :: drdx(3),dtmp,gwk,dgwk
   real(wp),allocatable :: r2ab(:)
   real(wp),allocatable :: dc6dr(:)
   real(wp),allocatable :: dc6dcn(:)
   real(wp),allocatable :: zvec(:)
   real(wp),allocatable :: dzvec(:)
   real(wp),allocatable :: gw(:)
   real(wp),allocatable :: dgw(:)
   real(wp),allocatable :: dc6dq(:)
   real(wp),allocatable :: dzdq(:)
   real(wp) :: cn_thr,r_thr,gw_thr
   parameter(cn_thr = 1600.0_wp)
   parameter( r_thr=5000._wp)
   parameter(gw_thr=0.000001_wp)
   real(wp),parameter :: sqrtpi = 1.77245385091_wp
   real(wp),parameter :: hlfosqrtpi = 0.5_wp/1.77245385091_wp
!  timing
!  real(wp) :: time0,time1
!  real(wp) :: wall0,wall1

   intrinsic :: present,sqrt,sum,maxval,exp,abs

!  print'(" * Allocating local memory")'
   allocate( dc6dr(mol%nat*(mol%nat+1)/2),dc6dcn(mol%nat),  &
   &         r2ab(mol%nat*(mol%nat+1)/2),zvec(ndim),dzvec(ndim),  &
   &         gw(ndim),dgw(ndim),dc6dq(mol%nat),dzdq(ndim),  &
   &         source = 0.0_wp )
   allocate( itbl(7,mol%nat), source = 0 )

   ed = 0.0_wp

!  precalc
!  print'(" * Setting up index table")'
   k = 0
   do i = 1, mol%nat
      do ii = 1, refn(mol%at(i))
         k = k+1
         itbl(ii,i) = k
      enddo
   enddo

!  print'(" * Entering first OMP section")'
!$OMP parallel default(none) &
!$omp private(i,ii,iii,ia,iz,k,norm,dnorm,twf,tgw,dexpw,expw,gwk,dgwk)  &
!$omp shared (mol,refn,refc,refcovcn,itbl,refq,wf,cn,g_a,g_c,q) &
!$omp shared (gw,dgw,zvec,dzvec,dzdq)
!$omp do
   do i = 1, mol%nat
      ia = mol%at(i)
      iz = zeff(ia)
      norm  = 0.0_wp
      dnorm = 0.0_wp
      do ii=1,refn(ia)
         do iii = 1, refc(ii,ia)
            twf = iii*wf
            tgw = cngw(twf,cn(i),refcovcn(ii,ia))
            norm  =  norm + tgw
            dnorm = dnorm + 2*twf*(refcovcn(ii,ia)-cn(i))*tgw
         enddo
      enddo
      norm = 1._wp/norm
      do ii = 1, refn(ia)
         k = itbl(ii,i)
         dexpw=0.0_wp
         expw=0.0_wp
         do iii = 1, refc(ii,ia)
            twf = wf*iii
            tgw = cngw(twf,cn(i),refcovcn(ii,ia))
            expw  =  expw + tgw
            dexpw = dexpw + 2*twf*(refcovcn(ii,ia)-cn(i))*tgw
         enddo

         ! save
         gwk = expw*norm
         if (gwk.ne.gwk) then
            if (maxval(refcovcn(:refn(ia),ia)).eq.refcovcn(ii,ia)) then
               gwk = 1.0_wp
            else
               gwk = 0.0_wp
            endif
         endif
         zvec(k) = zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz) * gwk
         ! NEW: q=0 for ATM
         gw(k) =  zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,iz) * gwk

         dgwk = dexpw*norm-expw*dnorm*norm**2
         if (dgw(k).ne.dgw(k)) then
            dgw(k) = 0.0_wp
         endif
         dzvec(k) = zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz) * dgwk
         dzdq(k) = dzeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,q(i)+iz) * gwk
         ! NEW: q=0 for ATM
         dgw(k) = zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,iz) * dgwk
      enddo
   enddo
!$omp end do
!$omp end parallel

!  print'(" * Entering second OMP section")'
!$OMP parallel default(none) &
!$omp private(i,j,ia,ja,ij,k,l,c6ij,dic6ij,djc6ij,disp,dizij,djzij,  &
!$omp         rij,r2,r,r4r2ij,r0,oor6,oor8,oor10,door6,door8,door10)  &
!$omp shared(mol,refn,itbl,zvec,dzvec,c6abns,par,dzdq) &
!$omp shared(r2ab) reduction(+:dc6dr,dc6dcn,dc6dq,ed)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         ij = i*(i-1)/2 + j
         rij = mol%xyz(:,j) - mol%xyz(:,i)
         r2 = sum( rij**2 )
         r2ab(ij) = r2
         if (r2.gt.r_thr) cycle
         ! temps
         c6ij = 0.0_wp
         dic6ij = 0.0_wp
         djc6ij = 0.0_wp
         dizij = 0.0_wp
         djzij = 0.0_wp
         ! all refs
         do ii = 1, refn(ia)
            k = itbl(ii,i)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               c6ij = c6ij + zvec(k)*zvec(l)*c6abns(k,l)
               dic6ij = dic6ij + dzvec(k)*zvec(l)*c6abns(k,l)
               djc6ij = djc6ij + zvec(k)*dzvec(l)*c6abns(k,l)
               dizij = dizij + dzdq(k)*zvec(l)*c6abns(k,l)
               djzij = djzij + zvec(k)*dzdq(l)*c6abns(k,l)
            enddo
         enddo

         r = sqrt(r2)

         r4r2ij = 3*r4r2(ia)*r4r2(ja)
         r0 = par%a1*sqrt(r4r2ij) + par%a2

         oor6 = 1._wp/(r2**3+r0**6)
         oor8 = 1._wp/(r2**4+r0**8)
         oor10 = 1._wp/(r2**5+r0**10)
         door6 = -6*r2**2*r*oor6**2
         door8 = -8*r2**3*r*oor8**2
         door10 = -10*r2**4*r*oor10**2
!        oor6   = fdmpr_bj( 6,r,r0)
!        oor8   = fdmpr_bj( 8,r,r0)
!        oor10  = fdmpr_bj(10,r,r0)
!        door6  = fdmprdr_bj( 6,r,r0)
!        door8  = fdmprdr_bj( 8,r,r0)
!        door10 = fdmprdr_bj(10,r,r0)

         disp = par%s6*oor6 + par%s8*r4r2ij*oor8 &
         &    + par%s10*49.0_wp/40.0_wp*r4r2ij**2*oor10

         ! save
         dc6dq(i) = dc6dq(i) + dizij*disp
         dc6dq(j) = dc6dq(j) + djzij*disp
         dc6dcn(i) = dc6dcn(i) + dic6ij*disp
         dc6dcn(j) = dc6dcn(j) + djc6ij*disp
         dc6dr(ij) = dc6dr(ij) + c6ij*(par%s6*door6 + par%s8*r4r2ij*door8 &
         &                       + par%s10*49.0_wp/40.0_wp*r4r2ij**2*door10 )

         ed = ed - c6ij*disp
      enddo
   enddo
!$omp enddo
!$omp end parallel

!  select case(mbd)
!  case(1) ! full RPA-like MBD
!     print'(1x,''* MBD effects calculated by RPA like scheme'')'
!     call raise('W','MBD gradient not fully implemented yet')
!     call mbdgrad(mol,aw,daw,oor6ab,g,embd)
!  case(1,2) ! Axilrod-Teller-Muto three-body term
!     if(mbd.eq.1) then
!        call raise('W','MBD gradient not fully implemented yet')
!        print'(''MBD gradient not fully implemented yet'')'
!        print'(1x,''* calculate MBD effects with ATM formula instead'')'
!     else
!        print'(1x,''* MBD effects calculated by ATM formula'')'
!     endif
!     call dabcgrad(mol,ndim,par,dcn,gw,dgw,itbl,g,embd)
!  case(3) ! D3-like approximated ATM term
!     print'(1x,''* MBD effects approximated by ATM formula'')'
!  print'(" * Starting MBD gradient calculation")'
   if (mbd.ne.p_mbd_none) &
   &   call dabcappr(mol,ndim,par,  &
           &        r2ab,gw,dgw,c6abns,itbl,dc6dr,dc6dcn,eabc)
!  end select


!  print'(" * Entering third OMP section")'
!$OMP parallel default(none) &
!$omp private(i,j,ia,ja,ij,rij,r2,r,drdx,den,rcovij,  &
!$omp         expterm,dtmp) reduction(+:g) &
!$omp shared(mol,dc6dr,dc6dcn,dcndr)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         ij = i*(i-1)/2 + j

         rij = mol%xyz(:,j) - mol%xyz(:,i)
         r2 = sum( rij**2 )
         r = sqrt(r2)
         drdx = rij/r

         g(:,i) = g(:,i) + dc6dr(ij) * drdx! - dc6dcn(i) * dcndr(:,j,i)
         g(:,j) = g(:,j) - dc6dr(ij) * drdx! - dc6dcn(j) * dcndr(:,i,j)
      enddo
   enddo
!$omp enddo
!$omp end parallel

   call dgemv('n',3*mol%nat,mol%nat,-1.0_wp,dqdr,3*mol%nat,dc6dq,1,1.0_wp,g,1)
   call dgemv('n',3*mol%nat,mol%nat,-1.0_wp,dcndr,3*mol%nat,dc6dcn,1,1.0_wp,g,1)

!  print*,ed,eabc

!  print'(" * Dispersion all done, saving variables")'
   if (present(eout)) eout = ed + eabc

   if (present(aout)) then
      aout = 0._wp
      do i = 1, mol%nat
         ia = mol%at(i)
         do ii = 1, refn(ia)
            aout(:,i) = aout(:,i) + zvec(k) * refal(:,ii,ia)
         enddo
      enddo
   endif


end subroutine dispgrad

!> @brief calculates threebody dispersion energy from C6 coefficients
subroutine apprabc(mol,c6ab,par,E)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   real(wp),intent(in)  :: c6ab(mol%nat*(mol%nat+1)/2)
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(out) :: E

   integer  :: i,j,k,ia,ja,ka,ij,ik,jk
   real(wp) :: rij(3),rjk(3),rik(3),r2ij,r2jk,r2ik,cij,cjk,cik,cijk
   real(wp) :: atm,r2ijk,c9ijk,oor9ijk,rijk,fdmp
   real(wp) :: one,oth,six,thf
   parameter(one = 1._wp)
   parameter(oth = 1._wp/3._wp)
   parameter(six = 6._wp)
!  parameter(thf = 3._wp/4._wp)

   intrinsic :: sum,sqrt

   E = 0.0_wp

   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         ij = i*(i-1)/2 + j
         rij  = mol%xyz(:,j) - mol%xyz(:,i)
         r2ij = sum(rij**2)
         cij  = par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ja))+par%a2
         do k = 1, j-1
            ka = mol%at(k)
            ik = i*(i-1)/2 + k
            jk = j*(j-1)/2 + k
            rik   = mol%xyz(:,i) - mol%xyz(:,k)
            r2ik  = sum(rik**2)
            cik   = par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ka))+par%a2
            rjk   = mol%xyz(:,k) - mol%xyz(:,j)
            r2jk  = sum(rjk**2)
            cjk   = par%a1*sqrt(3._wp*r4r2(ja)*r4r2(ka))+par%a2
            r2ijk = r2ij*r2ik*r2jk
            rijk  = sqrt(r2ijk)
            cijk  = cij*cjk*cik
            c9ijk = par%s9*sqrt(c6ab(ij)*c6ab(jk)*c6ab(ik))
            atm = ( 0.375_wp * (r2ij+r2jk-r2ik) &
            &                * (r2ij+r2ik-r2jk) &
            &                * (r2ik+r2jk-r2ij) / r2ijk ) + 1._wp
            fdmp = one/(one+six*((cijk/rijk)**oth)**par%alp)
            oor9ijk = atm/rijk**3*fdmp
            E = E + c9ijk * oor9ijk
         enddo
      enddo
   enddo

end subroutine apprabc

!> @brief calculates threebody dispersion energy from dipole polarizibilities
subroutine dispabc(mol,aw,par,E)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   real(wp),intent(in)  :: aw(23,mol%nat)
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(out) :: E

   integer  :: i,j,k,ia,ja,ka
   real(wp) :: rij(3),rjk(3),rik(3),r2ij,r2jk,r2ik,cij,cjk,cik,cijk
   real(wp) :: atm,r2ijk,c9ijk,oor9ijk,rijk,fdmp
   real(wp) :: one,oth,six,thf
   parameter(one = 1._wp)
   parameter(oth = 1._wp/3._wp)
   parameter(six = 6._wp)
   parameter(thf = 3._wp/4._wp)

   intrinsic :: sum,sqrt

   E = 0.0_wp

   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         rij  = mol%xyz(:,j) - mol%xyz(:,i)
         r2ij = sum(rij**2)
         cij  = (par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ja))+par%a2)
         do k = 1, j-1
            ka = mol%at(k)
            rik   = mol%xyz(:,i) - mol%xyz(:,k)
            r2ik  = sum(rik**2)
            cik   = (par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ka))+par%a2)
            rjk   = mol%xyz(:,k) - mol%xyz(:,j)
            r2jk  = sum(rjk**2)
            cjk   = (par%a1*sqrt(3._wp*r4r2(ja)*r4r2(ka))+par%a2)
            r2ijk = r2ij*r2ik*r2jk
            rijk  = sqrt(r2ijk)
            cijk  = cij*cjk*cik
            c9ijk = par%s9*thopi*trapzd( aw(:,i)*aw(:,j)*aw(:,k) )
            atm = ( 0.375_wp * (r2ij+r2jk-r2ik) &
            &                * (r2ij+r2ik-r2jk) &
            &                * (r2ik+r2jk-r2ij) / r2ijk ) + 1._wp
            fdmp = one/(one+six*(thf*(cijk/rijk)**oth)**par%alp)
            oor9ijk = atm/rijk**3*fdmp
            E = E + c9ijk * oor9ijk
         enddo
      enddo
   enddo

end subroutine dispabc

!> @brief calculates threebody dispersion energy from C6 coefficients
subroutine abcappr(mol,ndim,g_a,g_c,par,gw,r2ab,c6abns,eabc)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   real(wp),intent(in)  :: g_a,g_c
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(in)  :: gw(ndim)
   real(wp),intent(in)  :: r2ab(mol%nat*(mol%nat+1)/2)
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   real(wp),intent(out) :: eabc

   integer  :: i,ii,ia,j,jj,ja,k,kk,ka,l,m,n
   integer  :: ij,jk,ik
   integer, allocatable :: itbl(:,:)
   real(wp),allocatable :: c6ab(:),zvec(:),c(:)
   real(wp) :: r2ij,r2jk,r2ik,iz
   real(wp) :: cij,cjk,cik,cijk
   real(wp) :: fdmp,dtmp,oor9tmp,c9tmp
   real(wp) :: atm,r2ijk,c9ijk,oor9ijk,rijk
   real(wp) :: drij(3),drjk(3),drik(3)
   real(wp) :: oorij,oorjk,oorik
   real(wp) :: dijfdmp,dikfdmp,djkfdmp
   real(wp) :: dijatm,dikatm,djkatm
   real(wp) :: dijoor9ijk,djkoor9ijk,dikoor9ijk
   real(wp) :: c6ij,dic6ij,djc6ij
   real(wp) :: dic9ijk,djc9ijk,dkc9ijk
   real(wp) :: x1,x2,x3,x4,x5,x6,x7,x8,x9
   real(wp) :: dum1,dum2,dum3
   real(wp) :: one,oth,six,thf
   parameter(one = 1._wp)
   parameter(oth = 1._wp/3._wp)
   parameter(six = 6._wp)
!  parameter(thf = 3._wp/4._wp)
   real(wp) :: r_thr,gw_thr
   parameter( r_thr=1600._wp)
   parameter(gw_thr=0.0001_wp)

   intrinsic :: sqrt

   allocate( c6ab(mol%nat*(mol%nat+1)/2),zvec(ndim),c(mol%nat*(mol%nat+1)/2),  &
   &         source = 0.0_wp )
   allocate( itbl(7,mol%nat), source = 0 )

   eabc = 0.0_wp

!  precalc
   k = 0
   do i = 1, mol%nat
      ia = mol%at(i)
      iz = zeff(ia)
      do ii = 1, refn(ia)
         k = k+1
         itbl(ii,i) = k
         ! NEW: q=0 for ATM
         zvec(k) = zeta(g_a,gam(ia)*g_c,refq(ii,ia)+iz,iz) * gw(k)
      enddo
   enddo

!$OMP parallel private(i,ia,j,ja,ij,r2ij,c6ij)  &
!$omp&         shared (c6ab,c)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
!        if(i.eq.j) cycle
         ja = mol%at(j)
         ij = i*(i-1)/2 + j

!        first check if we want this contribution
         r2ij = r2ab(ij)
         c(ij) = par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ja))+par%a2
         if(r2ij.gt.r_thr) cycle

         ! temps
         c6ij = 0.0_wp
         ! all refs
         do ii = 1, refn(ia)
            k = itbl(ii,i)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               c6ij = c6ij + zvec(k)*zvec(l)*c6abns(k,l)
            enddo
         enddo
         ! save
         c6ab(ij) = c6ij
      enddo
   enddo
!$omp enddo
!$omp end parallel

!$OMP parallel private(i,j,ij,ia,ja,k,ka,ik,jk,atm,fdmp,  &
!$omp&                 r2ij,cij,r2ik,r2jk,cik,cjk,r2ijk,rijk,cijk, &
!$omp&                 c9ijk,oor9ijk) &
!$omp&         reduction(+:eabc)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         ij = i*(i-1)/2 + j

!        first check if we want this contribution
         r2ij = r2ab(ij)
         if(r2ij.gt.r_thr) cycle
         cij  = c(ij)
         do k = 1, j-1
            ka = mol%at(k)
            ik = i*(i-1)/2 + k
            jk = j*(j-1)/2 + k
            r2ik  = r2ab(ik)
            r2jk  = r2ab(jk)
            if((r2ik.gt.r_thr).or.(r2jk.gt.r_thr)) cycle
            cik   = c(ik)
            cjk   = c(jk)
            r2ijk = r2ij*r2ik*r2jk
            rijk  = sqrt(r2ijk)
            cijk  = cij*cjk*cik

            atm = ((0.375_wp * (r2ij+r2jk-r2ik) &
            &                * (r2ij+r2ik-r2jk) &
            &                * (r2ik+r2jk-r2ij) / r2ijk ) + 1._wp)/(rijk**3)

            fdmp = one/(one+six*((cijk/rijk)**oth)**par%alp)

            c9ijk = par%s9*sqrt(c6ab(ij)*c6ab(jk)*c6ab(ik))

            oor9ijk = atm*fdmp
            eabc = eabc + c9ijk*oor9ijk

         enddo ! k/C
      enddo ! j/B
   enddo ! i/A
!$omp enddo
!$omp end parallel

   deallocate( c6ab,c,zvec )

end subroutine abcappr

!> @brief calculates threebody dispersion gradient from C6 coefficients
subroutine dabcappr(mol,ndim,par,r2ab,zvec,dzvec,c6abns,itbl,dc6dr,dc6dcn,eout)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(in)  :: r2ab(mol%nat*(mol%nat+1)/2)
   real(wp),intent(in)  :: zvec(ndim)
   real(wp),intent(in)  :: dzvec(ndim)
   real(wp),intent(in)  :: c6abns(ndim,ndim)
   integer, intent(in)  :: itbl(7,mol%nat)
   real(wp),intent(inout)        :: dc6dr(mol%nat*(mol%nat+1)/2)
   real(wp),intent(inout)        :: dc6dcn(mol%nat)
   real(wp),intent(out),optional :: eout

   integer  :: i,ii,ia,j,jj,ja,k,kk,ka,l,m,n
   integer  :: ij,jk,ik
   real(wp),allocatable :: c6ab(:),dc6ab(:,:)
   real(wp) :: r2ij,r2jk,r2ik
   real(wp) :: cij,cjk,cik,cijk
   real(wp) :: fdmp,dtmp,oor9tmp,c9tmp
   real(wp) :: atm,r2ijk,c9ijk,oor9ijk,rijk
   real(wp) :: drij(3),drjk(3),drik(3)
   real(wp) :: oorij,oorjk,oorik
   real(wp) :: dijfdmp,dikfdmp,djkfdmp
   real(wp) :: dijatm,dikatm,djkatm
   real(wp) :: dijoor9ijk,djkoor9ijk,dikoor9ijk
   real(wp) :: c6ij,dic6ij,djc6ij
   real(wp) :: dic9ijk,djc9ijk,dkc9ijk
   real(wp) :: x1,x2,x3,x4,x5,x6,x7,x8,x9
   real(wp) :: eabc
   real(wp) :: dum1,dum2,dum3
   real(wp) :: one,oth,six,thf
   parameter(one = 1._wp)
   parameter(oth = 1._wp/3._wp)
   parameter(six = 6._wp)
!  parameter(thf = 3._wp/4._wp)
   real(wp) :: r_thr,gw_thr
   parameter( r_thr=1600._wp)
   parameter(gw_thr=0.0001_wp)

   intrinsic :: present,sqrt

   allocate( c6ab(mol%nat*(mol%nat+1)/2),dc6ab(mol%nat,mol%nat),  &
   &         source = 0.0_wp )

   eabc = 0.0_wp

!$OMP parallel default(none) &
!$omp private(i,ia,j,ja,ij,r2ij,c6ij,dic6ij,djc6ij,k,l)  &
!$omp shared (mol,r2ab,refn,itbl,c6abns,zvec,dzvec) &
!$omp shared (c6ab,dc6ab)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
!        if(i.eq.j) cycle
         ja = mol%at(j)
         ij = i*(i-1)/2 + j

!        first check if we want this contribution
         r2ij = r2ab(ij)
         if(r2ij.gt.r_thr) cycle

         ! temps
         c6ij = 0.0_wp
         dic6ij = 0.0_wp
         djc6ij = 0.0_wp
         ! all refs
         do ii = 1, refn(ia)
            k = itbl(ii,i)
            do jj = 1, refn(ja)
               l = itbl(jj,j)
               c6ij = c6ij + zvec(k)*zvec(l)*c6abns(k,l)
               dic6ij = dic6ij + dzvec(k)*zvec(l)*c6abns(k,l)
               djc6ij = djc6ij + zvec(k)*dzvec(l)*c6abns(k,l)
            enddo
         enddo
         ! save
         c6ab(ij) = c6ij
         dc6ab(i,j) = dic6ij
         dc6ab(j,i) = djc6ij
      enddo
   enddo
!$omp enddo
!$omp end parallel

!$OMP parallel default(none) &
!$omp private(i,j,ij,ia,ja,k,ka,ik,jk,oorjk,oorik,atm,fdmp,  &
!$omp         r2ij,cij,oorij,r2ik,r2jk,cik,cjk,r2ijk,rijk,cijk, &
!$omp         dijatm,djkatm,dikatm,dtmp,dijfdmp,djkfdmp,dikfdmp,  &
!$omp         c9ijk,oor9ijk,dic9ijk,djc9ijk,dkc9ijk) &
!$omp shared(mol,r2ab,par,c6ab,dc6ab) &
!$omp reduction(+:eabc,dc6dr,dc6dcn)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
         ja = mol%at(j)
         ij = i*(i-1)/2 + j

!        first check if we want this contribution
         r2ij = r2ab(ij)
         if(r2ij.gt.r_thr) cycle
         cij  = par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ja))+par%a2
         oorij = 1._wp/sqrt(r2ij)
         do k = 1, j-1
            ka = mol%at(k)
            ik = i*(i-1)/2 + k
            jk = j*(j-1)/2 + k
            r2ik  = r2ab(ik)
            r2jk  = r2ab(jk)
            if((r2ik.gt.r_thr).or.(r2jk.gt.r_thr)) cycle
            cik   = par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ka))+par%a2
            cjk   = par%a1*sqrt(3._wp*r4r2(ja)*r4r2(ka))+par%a2
            r2ijk = r2ij*r2ik*r2jk
            rijk  = sqrt(r2ijk)
            cijk  = cij*cjk*cik
            oorjk = 1._wp/sqrt(r2jk)
            oorik = 1._wp/sqrt(r2ik)

            atm = ((0.375_wp * (r2ij+r2jk-r2ik) &
            &                * (r2ij+r2ik-r2jk) &
            &                * (r2ik+r2jk-r2ij) / r2ijk ) + 1._wp)/(rijk**3)
            dijatm=-0.375_wp*(r2ij**3+r2ij**2*(r2jk+r2ik) &
            &      +r2ij*(3._wp*r2jk**2+2._wp*r2jk*r2ik+3._wp*r2ik**2) &
            &      -5._wp*(r2jk-r2ik)**2*(r2jk+r2ik)) &
            &      /(r2ijk*rijk**3)*oorij
            djkatm=-0.375_wp*(r2jk**3+r2jk**2*(r2ik+r2ij) &
            &      +r2jk*(3._wp*r2ik**2+2._wp*r2ik*r2ij+3._wp*r2ij**2) &
            &      -5._wp*(r2ik-r2ij)**2*(r2ik+r2ij)) &
            &      /(r2ijk*rijk**3)*oorjk
            dikatm=-0.375_wp*(r2ik**3+r2ik**2*(r2jk+r2ij) &
            &      +r2ik*(3._wp*r2jk**2+2._wp*r2jk*r2ij+3._wp*r2ij**2) &
            &      -5._wp*(r2jk-r2ij)**2*(r2jk+r2ij)) &
            &      /(r2ijk*rijk**3)*oorik

            fdmp = one/(one+six*((cijk/rijk)**oth)**par%alp)
            dtmp = -(oth*six*par%alp*((cijk/rijk)**oth)**par%alp)*fdmp**2
            dijfdmp = dtmp*oorij
            djkfdmp = dtmp*oorjk
            dikfdmp = dtmp*oorik

            c9ijk = par%s9*sqrt(c6ab(ij)*c6ab(jk)*c6ab(ik))

            oor9ijk = atm*fdmp
            eabc = eabc + c9ijk*oor9ijk

            dc6dr(ij) = dc6dr(ij) + (atm*dijfdmp - dijatm*fdmp)*c9ijk
            dc6dr(ik) = dc6dr(ik) + (atm*dikfdmp - dikatm*fdmp)*c9ijk
            dc6dr(jk) = dc6dr(jk) + (atm*djkfdmp - djkatm*fdmp)*c9ijk
            dic9ijk = dc6ab(i,j)/c6ab(ij) + dc6ab(i,k)/c6ab(ik)
            djc9ijk = dc6ab(j,i)/c6ab(ij) + dc6ab(j,k)/c6ab(jk)
            dkc9ijk = dc6ab(k,j)/c6ab(jk) + dc6ab(k,i)/c6ab(ik)
            dc6dcn(i) = dc6dcn(i) - 0.5_wp*c9ijk*oor9ijk*dic9ijk
            dc6dcn(j) = dc6dcn(j) - 0.5_wp*c9ijk*oor9ijk*djc9ijk
            dc6dcn(k) = dc6dcn(k) - 0.5_wp*c9ijk*oor9ijk*dkc9ijk

         enddo ! k/C
      enddo ! j/B
   enddo ! i/A
!$omp enddo
!$omp end parallel

   if (present(eout)) eout=eabc

end subroutine dabcappr


!> @brief calculates threebody dispersion gradient from polarizibilities
!* here is the theory for the ATM-gradient (SAW, 180224)
! EABC = WA·WB·WC·DABC
! ∂EABC/∂X = ∂/∂X(WA·WB·WC·DABC)
!          = ∂WA/∂X·WB·WC·DABC + WA·∂WB/∂X·WC·DABC + WA·WB·∂WC/∂X·WC·DABC
!            + WA·WB·WC·∂DABC/∂X
! ∂/∂X =  ∂rAB/∂X·∂/∂rAB +  ∂rBC/∂X·∂/∂rBC +  ∂rCA/∂X·∂/∂rCA
!      = (δAX-δBX)∂/∂rAB + (δBX-δCX)∂/∂rBC + (δCX-δAX)∂/∂rCA
! ∂EABC/∂A = ∑A,ref ∑B,ref ∑C,ref
!            + (∂WA/∂rAB-∂WA/∂rCA)·WB·WC·DABC
!            + WA·∂WB/∂rAB·WC·DABC
!            - WA·WB·∂WC/∂rCA·DABC
!            + WA·WB·WC·(∂DABC/∂rAB-∂DABC/∂rCA)
! ∂EABC/∂B = ∑A,ref ∑B,ref ∑C,ref
!            - ∂WA/∂rAB·WB·WC·DABC
!            + WA·(∂WB/∂rBC-∂WB/∂rAB)·WC·DABC
!            + WA·WB·∂WC/∂rBC·DABC
!            + WA·WB·WC·(∂DABC/∂rBC-∂DABC/∂rAB)
! ∂EABC/∂C = ∑A,ref ∑B,ref ∑C,ref
!            + ∂WA/∂rCA·WB·WC·DABC
!            - WA·∂WB/∂rBC·WC·DABC
!            + WA·WB·(∂WC/∂rCA-∂WC/∂rBC)·DABC
!            + WA·WB·WC·(∂DABC/∂rCA-∂DABC/∂rBC)
! ∂WA/∂rAB = ∂CNA/∂rAB·∂WA/∂CNA w/ ζ=1 and WA=wA
! ATM = 3·cos(α)cos(β)cos(γ)+1
!     = 3/8(r²AB+r²BC-r²CA)(r²AB+r²CA-r²BC)(r²BC+r²CA-r²AB)/(r²BC·r²CA·r²AB)+1
! ∂ATM/∂rAB = 3/4(2r⁶AB-r⁶BC-r⁶CA-r⁴AB·r²BC-r⁴AB·r²CA+r⁴BC·r²CA+r²BC·r⁴CA)
!             /(r³AB·r²BC·r²CA)
! DABC = C9ABCns·f·ATM/(rAB·rBC·rCA)³
! f = 1/(1+6(¾·∛[RAB·RBC·RCA/(rAB·rBC·rCA)])¹⁶)
! ∂(f/(r³AB·r³BC·r³CA)/∂rAB = 
!   ⅓·((6·(16-9)·(¾·∛[RAB·RBC·RCA/(rAB·rBC·rCA)])¹⁶-9)·f²/(r⁴AB·r³BC·r³CA)
subroutine dabcgrad(mol,ndim,par,dcn,zvec,dzvec,itbl,g,eout)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   integer, intent(in)  :: ndim
   type(dftd_parameter),intent(in) :: par
   real(wp),intent(in)  :: dcn(mol%nat,mol%nat)
   real(wp),intent(in)  :: zvec(ndim)
   real(wp),intent(in)  :: dzvec(ndim)
   integer, intent(in)  :: itbl(7,mol%nat)
   real(wp),intent(inout)        :: g(3,mol%nat)
   real(wp),intent(out),optional :: eout

   integer  :: i,ii,ia,j,jj,ja,k,kk,ka,l,m,n
   real(wp) :: rij(3),rjk(3),rik(3)
   real(wp) :: r2ij,r2jk,r2ik
   real(wp) :: cij,cjk,cik,cijk
   real(wp) :: fdmp,dtmp,oor9tmp,c9tmp
   real(wp) :: atm,r2ijk,c9ijk,oor9ijk,rijk
   real(wp) :: drij(3),drjk(3),drik(3)
   real(wp) :: oorij,oorjk,oorik
   real(wp) :: dijfdmp,dikfdmp,djkfdmp
   real(wp) :: dijatm,dikatm,djkatm
   real(wp) :: dijoor9ijk,djkoor9ijk,dikoor9ijk
   real(wp) :: x1,x2,x3,x4,x5,x6,x7,x8,x9
   real(wp) :: eabc
   real(wp) :: dum1,dum2,dum3
   real(wp) :: one,oth,six,thf
   parameter(one = 1._wp)
   parameter(oth = 1._wp/3._wp)
   parameter(six = 6._wp)
   parameter(thf = 3._wp/4._wp)
   real(wp) :: r_thr,gw_thr
   parameter( r_thr=1600._wp)
   parameter(gw_thr=0.0001_wp)

   intrinsic :: present,sqrt,sum

   eabc = 0._wp

!$omp parallel private(ia,ja,ka,l,m,n, &
!$omp&         rij,rjk,rik,r2ij,r2jk,r2ik, &
!$omp&         cij,cjk,cik,cijk, &
!$omp&         fdmp,dtmp,oor9tmp,c9tmp, &
!$omp&         atm,r2ijk,c9ijk,oor9ijk,rijk, &
!$omp&         drij,drjk,drik,oorij,oorjk,oorik, &
!$omp&         dijfdmp,dikfdmp,djkfdmp, &
!$omp&         dijatm,dikatm,djkatm, &
!$omp&         dijoor9ijk,djkoor9ijk,dikoor9ijk, &
!$omp&         x1,x2,x3,x4,x5,x6,x7,x8,x9) &
!$omp&         reduction(+:g,eabc)
!$omp do schedule(dynamic)
   do i = 1, mol%nat
      ia = mol%at(i)
      do j = 1, i-1
!        if(i.eq.j) cycle
         ja = mol%at(j)
!    --- all distances, cutoff radii ---
         rij  = mol%xyz(:,j) - mol%xyz(:,i)
         r2ij = sum(rij**2)
         if(r2ij.gt.r_thr) cycle
         cij  = (par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ja))+par%a2)
         oorij = 1._wp/sqrt(r2ij)
         do k = 1, j-1
!           if(k.eq.j) cycle
!           if(i.eq.k) cycle
            ka = mol%at(k)
            rik   = mol%xyz(:,i) - mol%xyz(:,k)
            rjk   = mol%xyz(:,k) - mol%xyz(:,j)
            r2ik  = sum(rik**2)
            r2jk  = sum(rjk**2)
            if((r2ik.gt.r_thr).or.(r2jk.gt.r_thr)) cycle
            cik   = (par%a1*sqrt(3._wp*r4r2(ia)*r4r2(ka))+par%a2)
            cjk   = (par%a1*sqrt(3._wp*r4r2(ja)*r4r2(ka))+par%a2)
            r2ijk = r2ij*r2ik*r2jk
            rijk  = sqrt(r2ijk)
            cijk  = cij*cjk*cik
            oorjk = 1._wp/sqrt(r2jk)
            oorik = 1._wp/sqrt(r2ik)

            x2 = 0._wp
            x4 = 0._wp
            x6 = 0._wp
            c9ijk = 0._wp

!       --- sum up all references ---
            do ii = 1, refn(ia) ! refs of A
               l = itbl(ii,i)
               do jj = 1, refn(ja) ! refs of B
                  m = itbl(jj,j)
                  do kk = 1, refn(ka) ! refs of C
                     n = itbl(kk,k)
                     if ((zvec(l)*zvec(m)*zvec(n)).lt.gw_thr) cycle
                     c9tmp = par%s9*thopi*trapzd(refal(:,ii,ia)*refal(:,jj,ja) &
                     &                      *refal(:,kk,ka))

                     c9ijk = c9ijk + c9tmp*zvec(n)*zvec(m)*zvec(l)
!                --- intermediates ---
!                    ∂WA/∂CNA·WB·WC
                     x2 = x2 - dzvec(l)*zvec(m)*zvec(n)*c9tmp
!                    WA·∂WB/∂CNB·WC
                     x4 = x4 - dzvec(m)*zvec(l)*zvec(n)*c9tmp
!                    WA·WB·∂WC/∂CNC
                     x6 = x6 - dzvec(n)*zvec(m)*zvec(l)*c9tmp

                  enddo ! refs of k/C
               enddo ! refs of j/B
            enddo ! refs of i/A

!       --- geometrical term and r⁻³AB·r⁻³BC·r⁻³CA ---
!           ATM = 3·cos(α)cos(β)cos(γ)+1
!               = 3/8(r²AB+r²BC-r²CA)(r²AB+r²CA-r²BC)(r²BC+r²CA-r²AB)
!                 /(r²BC·r²CA·r²AB)+1
            atm = ((0.375_wp * (r2ij+r2jk-r2ik) &
            &                * (r2ij+r2ik-r2jk) &
            &                * (r2ik+r2jk-r2ij) / r2ijk ) + 1._wp)/(rijk**3)
            dijatm=-0.375_wp*(r2ij**3+r2ij**2*(r2jk+r2ik) &
            &      +r2ij*(3._wp*r2jk**2+2._wp*r2jk*r2ik+3._wp*r2ik**2) &
            &      -5._wp*(r2jk-r2ik)**2*(r2jk+r2ik)) &
            &      /(r2ijk*rijk**3)*oorij
            djkatm=-0.375_wp*(r2jk**3+r2jk**2*(r2ik+r2ij) &
            &      +r2jk*(3._wp*r2ik**2+2._wp*r2ik*r2ij+3._wp*r2ij**2) &
            &      -5._wp*(r2ik-r2ij)**2*(r2ik+r2ij)) &
            &      /(r2ijk*rijk**3)*oorjk
            dikatm=-0.375_wp*(r2ik**3+r2ik**2*(r2jk+r2ij) &
            &      +r2ik*(3._wp*r2jk**2+2._wp*r2jk*r2ij+3._wp*r2ij**2) &
            &      -5._wp*(r2jk-r2ij)**2*(r2jk+r2ij)) &
            &      /(r2ijk*rijk**3)*oorik

!       --- damping function ---
!           1/(1+6(¾·∛[RAB·RBC·RCA/(rAB·rBC·rCA)])¹⁶)
            fdmp = one/(one+six*(thf*(cijk/rijk)**oth)**par%alp)
            dtmp = -(oth*six*par%alp*(thf*(cijk/rijk)**oth)**par%alp)*fdmp**2
            dijfdmp = dtmp*oorij
            djkfdmp = dtmp*oorjk
            dikfdmp = dtmp*oorik

!       --- intermediates ---
!           ∂WA/∂rAB·WB·WC·DABC = ∂CNA/∂rAB·(∂WA/∂CNA·WB·WC)·DABC
            x1 = x2*dcn(i,j)*( atm*fdmp )
!           ∂WA/∂rCA·WB·WC·DABC = ∂CNA/∂rCA·(∂WA/∂CNA·WB·WC)·DABC
            x2 = x2*dcn(i,k)*( atm*fdmp )
!           WA·∂WB/∂rBC·WC·DABC = ∂CNB/∂rBC·(WA·∂WB/∂rBC·WC)·DABC
            x3 = x4*dcn(j,k)*( atm*fdmp )
!           WA·∂WB/∂rAB·WC·DABC = ∂CNB/∂rAB·(WA·∂WB/∂rAB·WC)·DABC
            x4 = x4*dcn(i,j)*( atm*fdmp )
!           WA·WB·∂WC/∂rCA·DABC = ∂CNC/∂rCA·(WA·WB·∂WC/∂rCA)·DABC
            x5 = x6*dcn(i,k)*( atm*fdmp )
!           WA·WB·∂WC/∂rBC·DABC = ∂CNC/∂rBC·(WA·WB·∂WC/∂rBC)·DABC
            x6 = x6*dcn(j,k)*( atm*fdmp )
!           WA·WB·WC·∂DABC/∂rAB
            x7 = c9ijk*( atm*dijfdmp-dijatm*fdmp )
!           WA·WB·WC·∂DABC/∂rBC
            x8 = c9ijk*( atm*djkfdmp-djkatm*fdmp )
!           WA·WB·WC·∂DABC/∂rCA
            x9 = c9ijk*( atm*dikfdmp-dikatm*fdmp )

!       --- build everything together ---
            eabc = eabc + c9ijk*atm*fdmp

!           ∂rAB/∂A = -∂rAB/∂B
            drij = rij*oorij
!           ∂rBC/∂B = -∂rBC/∂C
            drjk = rjk*oorjk
!           ∂rCA/∂C = -∂rCA/∂A
            drik = rik*oorik

!           ∂EABC/∂A =
!           + (∂WA/∂rAB-∂WA/∂rCA)·WB·WC·DABC
!           + WA·∂WB/∂rAB·WC·DABC
!           - WA·WB·∂WC/∂rCA·DABC
!           + WA·WB·WC·(∂DABC/∂rAB-∂DABC/∂rCA)
            g(:,i) = g(:,i) + ( &
            &        + (x1+x4+x7)*drij &
            &        - (x2+x5+x9)*drik )
!           ∂EABC/∂B =
!           - ∂WA/∂rAB·WB·WC·DABC
!           + WA·(∂WB/∂rBC-∂WB/∂rAB)·WC·DABC
!           + WA·WB·∂WC/∂rBC·DABC
!           + WA·WB·WC·(∂DABC/∂rBC-∂DABC/∂rAB)
            g(:,j) = g(:,j) + ( &
            &        - (x1+x4+x7)*drij &
            &        + (x3+x6+x8)*drjk )
!           ∂EABC/∂C =
!           + ∂WA/∂rCA·WB·WC·DABC
!           - WA·∂WB/∂rBC·WC·DABC
!           + WA·WB·(∂WC/∂rCA-∂WC/∂rBC)·DABC
!           + WA·WB·WC·(∂DABC/∂rCA-∂DABC/∂rBC)
            g(:,k) = g(:,k) + ( &
            &        + (x2+x5+x9)*drik &
            &        - (x3+x6+x8)*drjk )

         enddo ! k/C
      enddo ! j/B
   enddo ! i/A
!$omp enddo
!$omp endparallel

   if (present(eout)) eout=eabc

end subroutine dabcgrad

!> @brief calculate non additivity by RPA-like scheme
subroutine dispmb(mol,E,aw,oor6ab)
   use class_molecule
   implicit none
   type(molecule),intent(in) :: mol !< molecular structure information
   real(wp),intent(in)  :: aw(23,mol%nat)
   real(wp),intent(in)  :: oor6ab(mol%nat,mol%nat)
   real(wp),intent(out) :: E

   integer  :: i,j,ii,jj,k
   integer  :: info
   real(wp) :: tau(3,3),spur(23),d_,d2,r(3),r2,alpha
   real(wp) :: two(23),atm(23),d3
   real(wp),allocatable :: T (:,:)
   real(wp),allocatable :: A (:,:)
   real(wp),allocatable :: AT(:,:)
   real(wp),allocatable :: F (:,:)
   real(wp),allocatable :: F_(:,:)
   real(wp),allocatable :: d (:)
   real(wp),allocatable :: w (:)

   intrinsic :: sum,sqrt,minval,log

   allocate( T(3*mol%nat,3*mol%nat),  A(3*mol%nat,3*mol%nat), AT(3*mol%nat,3*mol%nat), &
   &         F(3*mol%nat,3*mol%nat), F_(3*mol%nat,3*mol%nat),  d(3*mol%nat), &
   &         w(12*mol%nat), &
   &         source = 0.0_wp )

   spur = 0.0_wp

   do i = 1, 3*mol%nat
      F(i,i) = 1.0_wp
   enddo

   do i = 1, mol%nat
      do j  = 1, i-1
         r  = mol%xyz(:,j) - mol%xyz(:,i)
         r2 = sum(r**2)
         do ii = 1, 3
            tau(ii,ii) = (3*r(ii)*r(ii)-r2)/r2
            do jj = ii+1, 3
               tau(ii,jj) = (3*r(ii)*r(jj))/r2
               tau(jj,ii) = tau(ii,jj)
            enddo
         enddo
         tau = tau*sqrt(oor6ab(i,j))
         T(3*i-2:3*i,3*j-2:3*j) = tau
         T(3*j-2:3*j,3*i-2:3*i) = tau
      enddo
   enddo

   !call prmat(6,T,3*mol%nat,3*mol%nat,'T')

   do k = 1, 23
      A = 0.0_wp
      do i =  1, mol%nat
         alpha = sqrt(aw(k,i))
         A(3*i-2,3*i-2) = alpha
         A(3*i-1,3*i-1) = alpha
         A(3*i  ,3*i  ) = alpha
      enddo

      AT  = 0.0d0 
      call dgemm('N','N',3*mol%nat,3*mol%nat,3*mol%nat,1.0_wp,A,3*mol%nat,T, &
  &             3*mol%nat,0.0_wp,F_,3*mol%nat)
      call dgemm('N','N',3*mol%nat,3*mol%nat,3*mol%nat,1.0_wp,F_,3*mol%nat,A, &
  &             3*mol%nat,0.0_wp,AT,3*mol%nat)

      F_ = F - AT

      d = 0.0d0
      call dsyev('N','U',3*mol%nat,F_,3*mol%nat,d,w,12*mol%nat,info)
      if (info.ne.0) then
!        call raise('W','MBD eigenvalue not solvable')
         print'(1x,''* MBD eigenvalue not solvable'')'
         E = 0.0_wp
         return
      endif
      if (minval(d).le.0.0d0) then
!        call raise('W','Negative MBD eigenvalue occurred')
         print'(1x,''* Negative MBD eigenvalue occurred'')'
         E = 0.0_wp
         return
      endif

      call dgemm('N','N',3*mol%nat,3*mol%nat,3*mol%nat,1.0_wp,AT,3*mol%nat,AT, &
  &             3*mol%nat,0.0_wp,F_,3*mol%nat)
!     call dgemm('N','N',3*mol%nat,3*mol%nat,3*mol%nat,1.0_wp,F_,3*mol%nat,AT, &
! &             3*mol%nat,0.0_wp,A,3*mol%nat)
       
      d_ = 1.0_wp; d2 = 0.0_wp!; d3 = 0.0_wp
      do i = 1, 3*mol%nat
         d_ = d_ * d(i)
         d2 = d2 - F_(i,i)
!        d3 = d3 - A(i,i)
      enddo
      spur(k) = log(d_) - d2*0.5
!     two(k) = d2/2.0_wp
!     atm(k) = d3/3.0_wp
   enddo

   E = trapzd(spur)*ooTPI
   !print*,'     full contribution', trapzd(spur)*ooTPI
   !print*,' manybody contribution', trapzd(spur-two)*ooTPI
   !print*,'  twobody contribution', trapzd(two)*ootpi
   !print*,'threebody contribution', trapzd(atm)*ootpi

   deallocate(T,A,AT,F,F_,d)
end subroutine dispmb

function refq2string(refq) result(string)
   implicit none
   integer,intent(in) :: refq
   character(len=:),allocatable :: string
   select case(refq)
   case default;                  string = 'unknown'
   case(p_refq_gfn2xtb);          string = 'GFN2'
   case(p_refq_gasteiger);        string = 'EEQ'
   case(p_refq_hirshfeld);        string = 'extern'
   case(p_refq_periodic);         string = 'EEQ'
   case(p_refq_gfn2xtb_gbsa_h2o); string = 'GFN2/GBSA'
   case(p_refq_goedecker);        string = 'EEQ'
   end select
end function refq2string

function lmbd2string(lmbd) result(string)
   implicit none
   integer,intent(in) :: lmbd
   character(len=:),allocatable :: string
   select case(lmbd)
   case default;           string = 'unknown'
   case(p_mbd_none);       string = 'none'
   case(p_mbd_rpalike);    string = 'RPA like'
   case(p_mbd_exact_atm);  string = 'ATM'
   case(p_mbd_approx_atm); string = 'ATM'
   end select
end function lmbd2string

end module dftd4
