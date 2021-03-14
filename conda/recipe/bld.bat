
REM cmake -G"Ninja" ^
REM       -S%SRC_DIR% ^
REM       -Bbuild ^
REM       -DCMAKE_BUILD_TYPE=Release ^
REM       -DCMAKE_Fortran_COMPILER=ifort ^
REM       -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%" ^
REM       -DCMAKE_PREFIX_PATH="%LIBRARY_PREFIX%" ^
REM       -DCMAKE_INSTALL_LIBDIR="%LIBRARY_LIB%" ^
REM       -DCMAKE_INSTALL_INCLUDEDIR="%LIBRARY_INC%" ^
REM       -DCMAKE_INSTALL_BINDIR="%LIBRARY_BIN%" ^
REM       -DCMAKE_INSTALL_DATADIR="%LIBRARY_PREFIX%" ^
REM       -DCMAKE_Fortran_FLAGS="/wd4101 /wd4996 /static %CFLAGS%" ^
REM       -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON ^
REM       -DBUILD_SHARED_LIBS=ON ^
REM       -DBUILD_TESTING=OFF
REM if errorlevel 1 exit 1
REM 
REM REM build and install
REM cmake --build build ^
REM       --config Release ^
REM       --target install ^
REM       -- -j %CPU_COUNT% ^
REM       --verbose
REM if errorlevel 1 exit 1

REM load Intel compilers
for /f "tokens=* usebackq" %%f in (`dir /b "C:\Program Files (x86)\Intel\oneAPI\compiler\" ^| findstr /V latest ^| sort`) do @set "LATEST_VERSION=%%f"
echo %LATEST_VERSION%
@call "C:\Program Files (x86)\Intel\oneAPI\compiler\%LATEST_VERSION%\env\vars.bat"


set FC=ifort
set CC=icc

REM allows meson to find conda mkl_rt
set LIBRARY_PATH=%LIBRARY_LIB%

REM configure
meson_options=(
   "--prefix=%LIBRARY_PREFIX%"
   "--libdir=%LIBRARY_LIB%"
   "--buildtype=release"
   "--warnlevel=0"
   "-Dpython=true"
   "-Dc_args=/Qopenmp"
   "-Dfortran_args=/Qopenmp"
   "-Dlapack=mkl-rt"
   ".."
)

REM   "-Dfortran_link_args=-liomp5 -Wl,-Bstatic -lifport -lifcoremt_pic -limf -lsvml -lirc -lsvml -lirc_s -Wl,-Bdynamic"
REM   "-Dc_link_args=-liomp5 -static-intel"

mkdir _build
cd _build

REM build and test
meson "${meson_options[@]}"
if errorlevel 1 exit 1

REM Linux install
ninja test install
if errorlevel 1 exit 1

REM Python install
cp python/dftd4/_libdftd4.*%SHLIB_EXT% ../python/dftd4
cd ..
cp assets/parameters.toml python/dftd4/
cd python
"%PYTHON%" -m pip install . --no-deps -vvv
if errorlevel 1 exit 1
cd ..

