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
local MODE  = S.c.MODE
local lfs   = require "syscall.lfs"
local c2str = ffi.string
local t     = S.t
local C     = ffi.C
local errno = ffi.errno
local tolower = string.lower

-- used for char pointer returns, NULL is failure
local function retchp(ret, err)
   if ret == nil then return nil, strerr(err or errno()) end
   return c2str(ret)
end

-- used for int returns, NULL is failure
local function retbool(ret, err)
   if ret < 0 then return nil, strerr(err or errno()) end
   return true
end

-- used for int returns, NULL is failure
local function retnum(ret, err)
   ret  = tonumber(ret) or -1
   if ret < 0 then return nil, strerr(err or errno()) end
   return ret
end

local tmeta = { __index = table }
local function tnew(t) return setmetatable(t or {}, tmeta) end

local function strerr(e)
   local str = t.error(e)
   return type(str) == "string" and str or ""
end

local function str_array(sp, n)
   local n = n or 0
   if sp[n] == nil then return end
   return c2str(sp[n]), str_array(sp, n+1)
end

function modechopper(mode)
   local bitnames = { "R", "W", "X" }
   local bitout = { "r", "w", "x" }
   local bitgroups = { "USR", "GRP", "OTH" }

   local mstr = ""
   for _,grp in ipairs { "USR", "GRP", "OTH" } do
      for _,bit in { "R", "W", "X" } do
         mstr = mstr..(bit.band(mode, MODE[bit..grp]) ~= 0 and tolower(bit) or "-")
      end
   end
   if bit.band(mode, MODE.SUID) ~= 0 then
      mstr = mstr:sub(1,2)..(bit.band(mode, MODE.XUSR) and "s" or "S")..mstr:sub(4, 9)
   if bit.band(mode, MODE.SGID) ~= 0 then
      mstr = mstr:sub(1,5)..(bit.band(mode, MODE.XGRP) and "s" or "S")..mstr:sub(7, 9)
   end
   return mstr
end

local typemap = {
  file             = "regular",
  directory        = "directory",
  link             = "link",
  socket           = "socket",
  ["char device"]  = "character device",
  ["block device"] = "block device",
  ["named pipe"]   = "fifo",
  other            = "?"
}
local function statmap(st, f)
   local ret = { mode = modechopper(st.mode), type=typemap[st.typename], _mode=st.mode }
   for _,nm in ipairs { "ino", "dev", "nlink", "uid", "gid", "size", "atime", "mtime", "ctime" } do
      ret[nm] = st[nm]
   end
   return f and ret[f] or ret
end

ffi.cdef( ffi.os == "OSX" and [[
   struct passwd {
       char    *pw_name;       /* user name */
       char    *pw_passwd;     /* encrypted password */
       uid_t   pw_uid;         /* user uid */
       gid_t   pw_gid;         /* user gid */
       time_t  pw_change;      /* password change time */
       char    *pw_class;      /* user access class */
       char    *pw_gecos;      /* Honeywell login info */
       char    *pw_dir;        /* home directory */
       char    *pw_shell;      /* default shell */
       time_t  pw_expire;      /* account expiration */
       int     pw_fields;      /* internal: fields filled in */
    };
]] or [[
   struct passwd {
       char    *pw_name;       /* user name */
       char    *pw_passwd;     /* encrypted password */
       uid_t   pw_uid;         /* user uid */
       gid_t   pw_gid;         /* user gid */
       char    *pw_gecos;      /* Honeywell login info */
       char    *pw_dir;        /* home directory */
       char    *pw_shell;      /* default shell */
    };
]])

ffi.cdef [[
   char * ttyname(int fildes);

   int execvp(const char *file, char *const argv[]);

   struct group {
      char    *gr_name;
      char    *gr_passwd;
      gid_t   gr_gid;
      char    **gr_mem;
   };
   int getgrnam_r(const char *name, struct group *grp, char *buffer, size_t bufsize, struct group **result);
   int getgrgid_r(gid_t gid, struct group *grp, char *buffer, size_t bufsize, struct group **result);
   
   char *getlogin(void);
    int getpwnam_r(const char *name, struct passwd *pwd, char *buffer, size_t bufsize, struct passwd **result);
    int getpwuid_r(uid_t uid, struct passwd *pwd, char *buffer, size_t bufsize, struct passwd **result);

]]

local M
M = {

---
-- Check access permissions of a file or pathname
access = S.access, -- (path, mode) 

---
-- Change current working directory
chdir = S.chdir, -- (path)

---
-- Change file modes
chmod        = function(path, mode)
   return S.stat(path, mode_munch(S.stat(path).mode))
end,

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
   return strerr(errno()), errno()
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
fork         = S.fork, -- ()

---
-- Get working directory pathname
getcwd       = lfs.currentdir, -- ()

---
-- Get environment variable
getenv       = S.getenv, -- (var)

---
-- Group database operations
getgroup     = function(g) 
   local e
   local c = ffi.new("char[1024]"); 
   local r = ffi.new("struct group")  
   local rp = ffi.new("struct group*[1]", r)  
   errno(0)
   if type(g) == 'string' then
      e = C.getgrnam_r(g, r, c, 1024, rp)
   elseif type(g) == 'number' then
      e = C.getgrgid_r(g, r, c, 1024, rp)
   end
   if rp[0] == nil then return nil, strerr(errno()) end
   return { name = c2str(r.gr_name), gid = tonumber(r.gr_gid), str_array(r.gr_mem) }
end,

---
-- Get login name
getlogin     = function() 
   return retchp(C.getlogin())
end,

---
-- Password database
getpasswd    = function(u, f) 
   local e
   local c = ffi.new("char[2048]"); 
   local r = ffi.new("struct passwd")  
   local rp = ffi.new("struct passwd*[1]", r)  
   errno(0)
   if type(u) == 'string' then
      e = C.getpwnam_r(u, r, c, 2048, rp)
   elseif type(u) == 'number' then
      e = C.getpwuid_r(u, r, c, 2048, rp)
   end
   if rp[0] == nil then return nil, strerr(errno()) end
   local ret = { name   = c2str(r.pw_name),
                 uid    = tonumber(r.pw_uid),
                 gid    = tonumber(r.pw_gid),
                 dir    = c2str(r.pw_dir),
                 shell  = c2str(r.pw_shell),
                 gecos  = c2str(r.pw_gecos),
                 passwd = c2str(r.pw_passwd) }
   return f and ret[f] or ret
end,

---
-- Various process idents
getprocessid = function(f) 
   ret = {
      egid = S.getegid(),
      euid = S.geteuid(),
      gid = S.getgid(),
      uid = S.getuid(),
      pgrp = S.getpgrp(),
      pid = S.getpid(),
      ppid = S.getppid(),
      sid = S.getsid(0)
   }
   return f and ret[f] or ret
end,

---
-- Send signal to a process
kill         = S.kill, -- (pid, sig)

---
-- Make a hard file link
link         = S.link, -- (path1, path2)

---
-- Make a directory file
mkdir        = S.mkdir, -- (path, mode)

---
-- Make a fifo file
mkfifo        = S.mkfifo, -- (path, mode)

---
-- Get configurable pathname variables
pathconf     = function(path, conf) 
   errno(0)
   if conf then
      return S.pathconf(path, S.c.PC[conf:upper()])
   end
   ret = {}
   for _,nm in ipairs { "link_max", "max_canon", "max_input", "name_max", "path_max",
                        "pipe_buf", "chown_restricted", "no_trunc", "vdisable" } 
   do ret[nm] = S.pathconf(path, S.c.PC[nm:upper()]) or -1 end
   return ret
end,

---
-- Set environment string
putenv       = function(s) 
   return S.setenv(string.match(s, "([^=]+)=(.+)"))
end,

---
-- Read value of a symbolic link
readlink     = S.readlink, -- (path) 

---
-- Remove a directory file
rmdir        = S.rmdir, -- (path)

---
-- Set group id
setgid       = S.setgid, -- (gid)

---
-- Set user id
setuid       = S.setuid, -- (uid)

---
-- Suspend for an interval in seconds
sleep        = S.sleep, -- (sec)

---
-- Get file status
stat         = function(path, f) 
   return statmap(S.stat(path), f)
end,

---
-- Get file or symlink status
lstat        = function(path, f) 
   return statmap(S.lstat(path), f)
end,

---
-- Get file of fdesc status
fstat        = function(fdesc, f) 
   return statmap(S.fstat(fdesc), f)
end,

---
--
--
symlink      = function() 
end,

---
--
--
sysconf      = function() 
end,

---
--
--
times        = function() 
end,

---
--
--
umask        = function() 
end,

---
--
--
uname        = function() 
end,

---
--
--
unlink       = function() 
end,

---
--
--
utime        = function() 
end,

---
--
--
wait         = function() 
end,

---
--
--
setenv       = function() 
end,

---
--
--
unsetenv     = function() 
end,

---
--
--
statf        = function() 
end,

---
--
--
fstat        = function() 
end,

---
--
--
fnmatch      = function() 
end,

---
--
--
match        = function() 
end,

---
--
--
dup          = function() 
end,

---
--
--
read         = function() 
end,

---
--
--
write        = function() 
end,

---
--
--
close        = function() 
end,

---
--
--
waitpid      = function() 
end,

---
--
--
pipe         = function() 
end,

---
--
--
setsid       = function() 
end,

---
--
--
setpgid      = function() 
end,
}
return M

-- vim: set sw=3 sts=3 et:
