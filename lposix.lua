--[[
 - @file lposix.lua
 - An adaptor from PUC-Rio lposix to ljsyscall
 -
 - $Id$
 -
 - (C) Copyright 2015 MadsenSoft, madsensoft.dk
--]]

local ffi = require "ffi"
local S = require "syscall"
local C = ffi.C

return {

---
-- Check access permissions of a file or pathname
access = S.access -- function(path, mode) 

---
-- Change current working directory
chdir = S.chdir -- chdir(path)

---
--
--
chmod        = function() 
end

---
--
--
chown        = function() 
end

---
--
--
ctermid      = function() 
end

---
--
--
dir          = function() 
end

---
--
--
errno        = function() 
end

---
--
--
exec         = function() 
end

---
--
--
files        = function() 
end

---
--
--
fork         = function() 
end

---
--
--
getcwd       = function() 
end

---
--
--
getenv       = function() 
end

---
--
--
getgroup     = function() 
end

---
--
--
getlogin     = function() 
end

---
--
--
getpasswd    = function() 
end

---
--
--
getprocessid = function() 
end

---
--
--
kill         = function() 
end

---
--
--
link         = function() 
end

---
--
--
mkdir        = function() 
end

---
--
--
mkfifo       = function() 
end

---
--
--
pathconf     = function() 
end

---
--
--
putenv       = function() 
end

---
--
--
readlink     = function() 
end

---
--
--
rmdir        = function() 
end

---
--
--
setgid       = function() 
end

---
--
--
setuid       = function() 
end

---
--
--
sleep        = function() 
end

---
--
--
stat         = function() 
end

---
--
--
symlink      = function() 
end

---
--
--
sysconf      = function() 
end

---
--
--
times        = function() 
end

---
--
--
ttyname      = function() 
end

---
--
--
umask        = function() 
end

---
--
--
uname        = function() 
end

---
--
--
unlink       = function() 
end

---
--
--
utime        = function() 
end

---
--
--
wait         = function() 
end

---
--
--
setenv       = function() 
end

---
--
--
unsetenv     = function() 
end

---
--
--
statf        = function() 
end

---
--
--
fstat        = function() 
end

---
--
--
fnmatch      = function() 
end

---
--
--
match        = function() 
end

---
--
--
dup          = function() 
end

---
--
--
read         = function() 
end

---
--
--
write        = function() 
end

---
--
--
close        = function() 
end

---
--
--
waitpid      = function() 
end

---
--
--
pipe         = function() 
end

---
--
--
setsid       = function() 
end

---
--
--
setpgid      = function() 
end


ULL,			NULL}
};

-- vim: set sw=3 sts=3 et:
