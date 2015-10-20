--[[
 - @file lposix.lua
 - An adaptor from PUC-Rio lposix to ljsyscall
 -
 - $Id$
 -
 - (C) Copyright 2015 MadsenSoft, madsensoft.dk
--]]

local ffi   = require "ffi"
local S     = require "syscall"
local lfs   = require "syscall.lfs"
local c2str = ffi.string
local t     = S.t
local C     = ffi.C
local errno = ffi.errno

-- used for char pointer returns, NULL is failure
local function retchp(ret, err)
  if ret == nil then return nil, t.error(err or errno()) end
  return c2str(ret)
-- used for int returns, NULL is failure
local function retbool(ret, err)
  if ret < 0 then return nil, t.error(err or errno()) end
  return true
end

local tmeta = { __index = table }
local function tnew(t) return setmetatable(t or {}, tmeta) end

ffi.cdef [[
   char * ttyname(int fildes);
   int execvp(const char *file, char *const argv[]);
]]

local M
M = {

---
-- Check access permissions of a file or pathname
access = S.access, -- (path, mode) 

---
-- Change current working directory
chdir = S.chdir -- (path)

---
-- Change file modes
chmod        = S.chmod, -- (path, mode)

---
-- Change owner and group of a file
chown        = S.chown, -- (path, owner, group)

---
-- Get name of associated terminal (tty) from file descriptor
ttyname      = function(fd) 
   return retchp(C.ttyname(tonumber(fd or 0)))
end,

---
-- Get name of associated terminal
ctermid      = function() 
   return M.ttyname(0)
end,

---
-- List contents of directory
dir          = function(path) 
   local ret = tnew {}
   for d in lfs.dir(path or ".") do
      ret:insert(d)
   end
   return ret
end,

---
-- List contents of directory
files        = function(path) 
   return lfs.dir(path or ".")
end,

---
-- Get error string and number
errno        = function() 
   return t.error(errno()), errno()
end,

---
-- Execute a file
exec         = function(path, arg1, ...) 
   assert(type(path) == "string")
   local a
   if type(arg1) == 'table' then
      a = tnew {path, expand(arg1)}
   else
      a = tnew {path, arg1, ...}
   end
   for _,s in ipairs(a) do assert(type(s) == 'string') end
   local cargv = t.string_array(#a + 1, a or {})
   cargv[#a] = nil -- LuaJIT does not zero rest of a VLA
   return retbool(C.execve(filename, cargv, cenvp))
end,

---
-- Create a new process
fork         = C.fork, -- ()

---
-- Get working directory pathname
getcwd       = lfs.currentdir, -- ()

---
-- Get environment variable
getenv       = S.getenv, -- (var)

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
}
return M

-- vim: set sw=3 sts=3 et:
