@set MYTHTVDIR=C:\mythTV
: Windowed mode. For 16:9 try 1024x576 or 1280x720
@set OPTW=-w -geometry 800x600
: Force Qt display if OpenGL or Direct3D crash
@rem set OPTQT=-O ThemePainter=qt
%MYTHTVDIR%\mythfrontend %OPTW% %OPTQT% %1 %2 %3 %4 %5 %6 %7 %8 %9

