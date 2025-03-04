!> @brief general IO-operations and string parsing library
module mctc_readin
   use iso_fortran_env, wp => real64
   implicit none

   character(len=:),allocatable :: xhome
   character(len=:),allocatable :: xpath

   character,private,parameter :: flag = '$'
   character,private,parameter :: space = ' '
   character,private,parameter :: equal = '='
   character,private,parameter :: hash = '#'
   character,private,parameter :: dot = '.'
   character,private,parameter :: comma = ','
   character,private,parameter :: minus = '-'
   character(len=*),private,parameter :: flag_end = '$end'

! ------------------------------------------------------------------[SAW]-
!  this function returns a logical and is always evaluated for its
!  side effect (parsing the given string for its real/int/bool value)
   interface get_value
   module procedure get_int_value
   module procedure get_int_array_value
   module procedure get_real_value
   module procedure get_real_array_value
   module procedure get_bool_value
   end interface get_value

contains

! ------------------------------------------------------------------[SAW]-
!  I could use rdpath directly, but this would require access to xpath,
!  so I use xfind as a wrapper with access to the xpath variable to
!  circumvent this. Also as a gimmick, I do not return a logical, but
!  some file name. xfind succeeds if fname.ne.name, but if you inquire
!  for fname in case of failure, you might hit a local file, which you
!  than can read. This is intended as a feature (just saying).
function xfind(name) result(fname)
   use mctc_systools, only : rdpath
   character(len=*),intent(in)  :: name
   character(len=:),allocatable :: fname
   character(len=:),allocatable :: dum
   logical :: exist

   call rdpath(xpath,name,dum,exist)
   if (exist) then
      fname = dum
   else
      fname = name
   endif

end function xfind

! ------------------------------------------------------------------[SAW]-
!  wrapper around getline from the MCTC lib that strips comments
!  automatically und removes all leading and trailing whitespace
subroutine strip_line(in,line,err)
   use mctc_systools, only : getline
   implicit none
   integer,intent(in)  :: in
   character(len=:),allocatable,intent(out) :: line
   integer,intent(out) :: err
   integer :: ic

   call getline(in,line,iostat=err)
   if (err.ne.0) return
!  check for comment characters
   ic = index(line,hash)
   if (ic.eq.1) then
      line = ''
      return
   else if (ic.gt.1) then
      line = line(:ic-1)
   endif
   line = trim(adjustl(line))

end subroutine strip_line

! ------------------------------------------------------------------[SAW]-
!  same as strip_line, but has the additional function of copying to
!  one unit while reading from another, which is helpful for backing up
!  files you plan to replace in the next step of you program.
!  Funnily this subroutine exist way before strip_line...
subroutine mirror_line(in,out,line,err)
   use mctc_systools, only : getline
   implicit none
   integer,intent(in)  :: in
   integer,intent(in)  :: out
   character(len=:),allocatable,intent(out) :: line
   integer,intent(out) :: err
   integer :: ic

   call getline(in,line,iostat=err)
   if (err.ne.0) return
!  now write the line to the copy, we write what we read, not what we see
!  if (out.ne.-1) write(out,'(a)') trim(line)
!  check for comment characters
   ic = index(line,hash)
   if (ic.eq.1) then
      line = ''
      return
   else if (ic.gt.1) then
      line = line(:ic-1)
   endif
!  now write the line to the copy, we write what we see, not what we read
   if (out.ne.-1) write(out,'(a)') trim(line)
!  strip line from space, but after printing
   line = trim(adjustl(line))

end subroutine mirror_line

!> @brief takes a string and search a name for a file that is not already present
function find_new_name(fname) result(newname)
   character(len=*),intent(in)  :: fname
   character(len=:),allocatable :: newname
   character(len=5) :: dum ! five digit number must be enough
   character,parameter :: hash = '#'
   character,parameter :: dot = '.'
   integer :: i
   logical :: exist

   i = 0
   do
      i = i+1
      write(dum,'(i0)') i
      newname = hash//trim(dum)//dot//fname
      inquire(file=newname,exist=exist)
      if (.not.exist) return
   enddo

end function find_new_name

function get_int_value(val,dum) result(status)
   implicit none
   character(len=*),intent(in) :: val
   integer,intent(out) :: dum
   integer :: err
   logical :: status
   
!  call value(val,dum,ios=err)
   read(val,*,iostat=err) dum
   if (err.eq.0) then
      status = .true.
   else
      call raise('S','could not parse '''//val//'''')
      status = .false.
   endif
end function get_int_value

function get_real_value(val,dum) result(status)
   implicit none
   character(len=*),intent(in) :: val
   real(wp),intent(out) :: dum
   integer :: err
   logical :: status
   
!  call value(val,dum,ios=err)
   read(val,*,iostat=err) dum
   if (err.eq.0) then
      status = .true.
   else
      call raise('S','could not parse '''//val//'''')
      status = .false.
   endif
end function get_real_value

function get_bool_value(val,dum) result(status)
   implicit none
   character(len=*),intent(in) :: val
   logical,intent(out) :: dum
   logical :: status
   
   select case(val)
   case('Y','y','Yes','yes','T','t','true','True','1')
      status = .true.
      dum = .true.
   case('N','n','No','no','F','f','false','False','0')
      status = .true.
      dum = .false.
   case default
      call raise('S','could not parse '''//val//'''')
      status = .false.
   end select

end function get_bool_value

function get_int_array_value(val,dum) result(status)
   implicit none
   character(len=*),intent(in) :: val
   integer,intent(out) :: dum(:)
   integer :: i,err
   logical :: status
  
!  call value(val,dum,ios=err)
   read(val,*,iostat=err) (dum(i),i=1,size(dum,1))
   if (err.eq.0) then
      status = .true.
   else
      call raise('S','could not parse '''//val//'''')
      status = .false.
   endif

end function get_int_array_value

function get_real_array_value(val,dum) result(status)
   implicit none
   character(len=*),intent(in) :: val
   real(wp),intent(out) :: dum(:)
   integer :: i,err
   logical :: status
  
!  call value(val,dum,ios=err)
   read(val,*,iostat=err) (dum(i),i=1,size(dum,1))
   if (err.eq.0) then
      status = .true.
   else
      call raise('S','could not parse '''//val//'''')
      status = .false.
   endif

end function get_real_array_value

pure elemental function bool2int(bool) result(int)
   logical,intent(in) :: bool
   integer :: int
   if (bool) then
      int = 1
   else
      int = 0
   endif
end function bool2int

pure function bool2string(bool) result(string)
   logical,intent(in) :: bool
   character(len=:),allocatable :: string
   if (bool) then
      string = 'true'
   else
      string = 'false'
   endif
end function bool2string

function get_list_value(val,dum,n) result(status)
   implicit none
   character(len=*),intent(in) :: val
   integer,intent(out) :: dum(:)
   integer,intent(out) :: n
   integer :: i,j,k,l,err
   logical :: status
  
   i = index(val,minus)
   if (i.eq.0) then
      read(val,*,iostat=err) dum(1)
      if (err.ne.0) then
         call raise('S','could not parse '''//val//'''')
         status = .false.
         return
      endif
      n = 1
      status = .true.
   else
      read(val(:i-1),*,iostat=err) j
      if (err.ne.0) then
         call raise('S','could not parse '''//val(:i-1)//''' in '''//val//'''')
         status = .false.
         return
      endif
      read(val(i+1:),*,iostat=err) k
      if (err.ne.0) then
         call raise('S','could not parse '''//val(i+1:)//''' in '''//val//'''')
         status = .false.
         return
      endif
      if (k.lt.j) then
         call raise('S','end is lower than start in list '''//val//'''')
         status = .false.
         return
      endif
      if ((k-j).gt.size(dum,1)) then
         call raise('S','too many list items in '''//val//'''')
         status = .false.
         return
      endif
      n = 0
      do i = j, k
         n = n+1
         dum(n) = i
      enddo
      status = .true.
   endif
end function get_list_value

end module mctc_readin
