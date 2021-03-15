REM setlocal EnableDelayedExpansion
@echo on

REM       -DCMAKE_Fortran_FLAGS="/wd4101 /wd4996 /static %CFLAGS%" ^
REM       -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON ^
REM       -DBUILD_SHARED_LIBS=ON ^

REM load Intel compilers
for /f "tokens=* usebackq" %%f in (`dir /b "C:\Program Files (x86)\Intel\oneAPI\compiler\" ^| findstr /V latest ^| sort`) do @set "LATEST_VERSION=%%f"
echo %LATEST_VERSION%
@call "C:\Program Files (x86)\Intel\oneAPI\compiler\%LATEST_VERSION%\env\vars.bat"


set FC=ifort
set CC=icc
echo %FC%
echo %CC%
where %FC%
where %CC%
dir

REM allows meson to find conda mkl_rt
set LIBRARY_PATH=%LIBRARY_LIB%
echo %LIBRARY_PATH%

:: meson options
:: (set pkg_config_path so deps in host env can be found)
set ^"MESON_OPTIONS=^
  --prefix="%LIBRARY_PREFIX%" ^
  --libdir="%LIBRARY_LIB%" ^
  --pkg-config-path="%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig" ^
  --buildtype=release ^
  --backend=ninja ^
  -D python=true ^
  -D c_args=/Qopenmp ^
  -D fortran_args=/Qopenmp ^
  -D lapack=mkl-rt ^
 ^"

echo %MESON_OPTIONS%

REM   "-Dfortran_link_args=-liomp5 -Wl,-Bstatic -lifport -lifcoremt_pic -limf -lsvml -lirc -lsvml -lirc_s -Wl,-Bdynamic"
REM   "-Dc_link_args=-liomp5 -static-intel"

:: configure build using meson
:: %BUILD_PREFIX%\python.exe %BUILD_PREFIX%\Scripts\
meson setup builddir !MESON_OPTIONS!
if errorlevel 1 exit 1

:: print results of build configuration
:: %BUILD_PREFIX%\python.exe %BUILD_PREFIX%\Scripts\
meson configure builddir
if errorlevel 1 exit 1

:: Linux install
ninja -v -C builddir test install
if errorlevel 1 exit 1

dir builddir

:: Python install
cp builddir\python\dftd4\_libdftd4.*%SHLIB_EXT% python\dftd4\
cp assets/parameters.toml python\dftd4\
cd python
"%PYTHON%" -m pip install . --no-deps -vvv
if errorlevel 1 exit 1
cd ..

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
