@echo off
rem ======================================================================
rem = $Id: fetch.cmd,v 1.2 1996/08/12 23:26:50 Madsen Exp $
rem =
rem = Collect files for LibA2
rem ======================================================================
setlocal

set file=Disk.pm
set source=e:\lib\local\perl\AppleII
set dest=lib\AppleII
gosub getFile

set file=ProDOS.pm
gosub getFile

set source=e:\Util\bin
set dest=bin
set file=awp2txt.pl
gosub getFile

set file=prodos.pl
gosub getFile

set file=pro_fmt.pl
gosub getFile

set file=pro_opt.pl
gosub getFile

ren /q readme.pl README.PL
echo Building README...
README.PL

quit 0

:getFile
iff exist %dest\%file then
  iff %@fileage[%dest\%file] == %@fileage[%source\%file] then
    echo %file unchanged
    return
  endiff
endiff
iff %@attrib[%source\%file, R] != 1 then
  echo %file not locked!
  quit 1
endiff
vernum.pl -d3 %dest %source\%file
return

rem Local Variables:
rem   tmtrack-file-task: "LibA2: fetch.cmd"
rem End:
