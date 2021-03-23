setlocal EnableDelayedExpansion
@echo on

REM       -DCMAKE_Fortran_FLAGS="/wd4101 /wd4996 /static %CFLAGS%" ^
REM       -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON ^
REM       -DBUILD_SHARED_LIBS=ON ^

REM load Intel compilers
for /f "tokens=* usebackq" %%f in (`dir /b "C:\Program Files (x86)\Intel\oneAPI\compiler\" ^| findstr /V latest ^| sort`) do @set "LATEST_VERSION=%%f"
echo %LATEST_VERSION%
@call "C:\Program Files (x86)\Intel\oneAPI\compiler\%LATEST_VERSION%\env\vars.bat"


@echo on
set FC=ifort
set CC=icl

:: works
:: ifort /help
:: findstr /i "Intel" %BUILD_PREFIX%\Lib\site-packages\mesonbuild\environment.py

cp %RECIPE_DIR%\environment.py %BUILD_PREFIX%\Lib\site-packages\mesonbuild\environment.py

REM allows meson to find conda mkl_rt
set LIBRARY_PATH=%LIBRARY_LIB%
echo %LIBRARY_PATH%

:: meson options
:: (set pkg_config_path so deps in host env can be found)
::  .. ^
::  -D c_args=/Qopenmp ^
::  -D fortran_args=/Qopenmp ^

:: set pkg-config path so that host deps can be found
:: (set as env var so it's used by both meson and during build with g-ir-scanner)
set "PKG_CONFIG_PATH=%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig"

:: get mixed path (forward slash) form of prefix so host prefix replacement works
set "LIBRARY_PREFIX_M=%LIBRARY_PREFIX:\=/%"

::  --pkg-config-path="%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig" ^

set ^"MESON_OPTIONS=^
  --prefix="%LIBRARY_PREFIX_M%" ^
  --libdir="%LIBRARY_LIB%" ^
  --default-library=static^
  --buildtype=release ^
  --backend=ninja ^
  --errorlogs ^
  -D openmp=ture ^
  -D python=true ^
  -D lapack=mkl-rt ^
  -Dfortran_args="/wd4101 /wd4996 %FFLAGS%" ^
  -Dc_args="%CFLAGS%" ^
  -Dfortran_link_args="/Qopenmp /static" ^
  -Dc_link_args="/Qopenmp /static" ^
 ^"

::  --prefix="%LIBRARY_PREFIX%" ^

echo MESON_OPTIONS
echo !MESON_OPTIONS!

:: configure build using meson
:: %BUILD_PREFIX%\python.exe %BUILD_PREFIX%\Scripts\
meson setup _build !MESON_OPTIONS!
if errorlevel 1 exit 1

:: print results of build configuration
:: %BUILD_PREFIX%\python.exe %BUILD_PREFIX%\Scripts\
meson configure _build
if errorlevel 1 exit 1

echo DIR
:: copy nul _build\dftd4.lib > nul
copy "" _build\dftd4.lib > nul
dir _build
type _build\dftd4.lib

::-j %CPU_COUNT%
ninja -v -C _build
if errorlevel 1 exit 1

::-j %CPU_COUNT%
ninja -C _build install
if errorlevel 1 exit 1

:: :: configure build using meson
:: :: %BUILD_PREFIX%\python.exe %BUILD_PREFIX%\Scripts\
:: meson setup _build . !MESON_OPTIONS!
:: ::meson !MESON_OPTIONS!
:: if errorlevel 1 exit 1
:: 
:: :: print results of build configuration
:: :: %BUILD_PREFIX%\python.exe %BUILD_PREFIX%\Scripts\
:: meson configure _build
:: if errorlevel 1 exit 1
:: 
:: :: Linux install
:: ninja -v -C _build test install
:: if errorlevel 1 exit 1
:: 
:: dir builddir
:: 
:: :: Python install
:: cp builddir\python\dftd4\_libdftd4.*%SHLIB_EXT% python\dftd4\
:: cp assets/parameters.toml python\dftd4\
:: cd python
:: "%PYTHON%" -m pip install . --no-deps -vvv
:: if errorlevel 1 exit 1
:: cd ..

:: ####



REM ninja -v -C builddir
REM if errorlevel 1 exit 1
REM
REM ninja -C builddir install
REM if errorlevel 1 exit 1

:: meson doesn't put the Python files in the right place, and there's no way to override
:: cd %LIBRARY_PREFIX%\lib\python*
:: cd site-packages
:: move *.egg-info %PREFIX%\Lib\site-packages
:: move cairo %PREFIX%\Lib\site-packages\cairo
