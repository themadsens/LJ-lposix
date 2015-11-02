--[[
 - @file lposix.lua
 - An adaptor from PUC-Rio lposix to ljsyscall
 -
 - $Id$
 -
 - (C) Copyright 2015 MadsenSoft, madsensoft.dk
--]]

local ffi     = require "ffi"
local bit     = require "bit"
local S       = require "syscall"
local MODE    = S.c.MODE
local lfs     = require "syscall.lfs"
local c2str   = ffi.string
local t       = S.t
local C       = ffi.C
local errno   = ffi.errno
local tolower = string.lower
local band    = bit.band
local osx     = ffi.os == "OSX"

-- Set tostring to work
local function num(t) return tonumber(tostring(t)) end

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
      for _,bit in ipairs { "R", "W", "X" } do
         mstr = mstr..(band(mode, MODE[bit..grp]) ~= 0 and tolower(bit) or "-")
      end
   end
   if bit.band(mode, MODE.SUID) ~= 0 then
      mstr = mstr:sub(1,2)..(band(mode, MODE.XUSR) and "s" or "S")..mstr:sub(4, 9)
   end
   if bit.band(mode, MODE.SGID) ~= 0 then
      mstr = mstr:sub(1,5)..(band(mode, MODE.XGRP) and "s" or "S")..mstr:sub(7, 9)
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
   local ret = { mode = modechopper(st.mode), type=typemap[st.typename],
                 _mode=st.mode, dev = st.dev.device }
   for _,nm in ipairs { "ino", "nlink", "uid", "gid", "size", "atime", "mtime", "ctime" } do
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
    enum const {
       utslen=256,
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
    enum const {
       utslen=65,
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

    int sysconf(int);


    struct	utsname {
        char	sysname[utslen];
        char	nodename[utslen];
        char	release[utslen];
        char	version[utslen];
        char	machine[utslen];
    };
    int uname(struct utsname *);
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
   return S.chmod(path, mode_munch(S.stat(path).mode))
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
setgid       = S.setgid, -- (gid),t

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
-- Make symbolic link to a file
symlink      = S.symlink, -- (path1, path2)

---
-- Get configurable system variables
sysconf      = function(f) 
   local t,i = {0, 1, 2, 3, 4, 7, 8, 29, 5, 6}, 0 -- glibc
   if ffi.os == "OSX" then
      t = {1, 2, 3, 4, 5, 6, 7, 8, 26, 27} -- OSX yosemite
   end
   local function n() i=i+1 return t[i] end
   local ret = {
      arg_max          = C.sysconf(n()), -- _SC_ARG_MAX
      child_max        = C.sysconf(n()), -- _SC_CHILD_MAX
      clk_tck          = C.sysconf(n()), -- _SC_CLK_TCK
      ngroups_max      = C.sysconf(n()), -- _SC_NGROUPS_MAX
      open_max         = C.sysconf(n()), -- _SC_OPEN_MAX
      job_control      = C.sysconf(n()), -- _SC_JOB_CONTROL
      saved_ids        = C.sysconf(n()), -- _SC_SAVED_IDS
      version          = C.sysconf(n()), -- _SC_VERSION
      stream_max       = C.sysconf(n()), -- _SC_STREAM_MAX
      tzname_max       = C.sysconf(n()), -- _SC_TZNAME_MAX
   }
   return f and ret[f] or ret
end,

---
-- Process times
times        = function() 
   local slf,cld,tck = S.getrusage(0), S.getrusage(-1), C.sysconf(osx and 3 or 2)
   local ret = {
      elapsed = num(S.gettimeofday()) * tck,
      utime   = num(slf.utime) * tck,
      stime   = num(slf.stime) * tck,
      cutime  = (num(slf.utime)+num(cld.utime)) * tck,
      cstime  = (num(slf.stime)+num(cld.stime)) * tck
   }
   return f and ret[f] or ret
end,

---
-- Set file creation mode mask
umask        = function(mask)
   local new = S.umask(0); S.umask(new)
   new = t.band(bit.bnot(new), 0x1ff)
   if mask then
      new = bit.band(mode_munch(new, mask), 0x1ff)
      if not new then return nil end
      S.umask(bit.bnot(new))
   end
   return modechopper(new)
end,

---
-- Get system identification
uname        = function(s) 
   local ut = ffi.new("struct utsname[1]")
   local e = C.uname(ut[0])
   s = s or "%s %n %r %v %m"
   return s:gsub("%%([mnrsv%%])", {
      ["%"] = "%",
      m = c2str(ut[0].machine),
      n = c2str(ut[0].nodename),
      r = c2str(ut[0].release),
      s = c2str(ut[0].sysname),
      v = c2str(ut[0].version),
   })

end,

---
-- Remove directory entry
unlink       = S.unlink, -- (path)

---
-- Set file times
utime        = function( path, mtime, atime) 
   if mtime and atime then
      return S.utimes(path, {atime, mtime})
   end
   return S.utimes(path)
end,

---
-- Wait for process termination
wait         = function(pid) 
   return retbool(S.waitpid(pid))
end,

---
-- Set environmant variable
setenv       = S.setenv, -- (name, value)

---
-- Unset environmant variable
unsetenv     = S.unsetenv, -- (name)

-- These are my non "standard" additions

---
-- Test whether a filename or pathname matches a shell-style pattern
fnmatch      = function() 
end,

---
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
_G.posix = M
return M

-- vim: set sw=3 sts=3 et:
