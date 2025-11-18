# Storage and Partitions

## Storage Overview

### Disk Usage
```
Filesystem                                Size  Used Avail Use% Mounted on
none                                      3.9G     0  3.9G   0% /usr/lib/modules/6.6.87.2-microsoft-standard-WSL2
none                                      3.9G  4.0K  3.9G   1% /mnt/wsl
none                                      3.9G  612K  3.9G   1% /mnt/wsl/docker-desktop/shared-sockets/host-services
/dev/sdd                                  129M   66M   54M  55% /mnt/wsl/docker-desktop/docker-desktop-user-distro
/dev/loop0                                690M  690M     0 100% /mnt/wsl/docker-desktop/cli-tools
drivers                                   238G  176G   63G  74% /usr/lib/wsl/drivers
/dev/sdf                                 1007G  803M  955G   1% /
none                                      3.9G   88K  3.9G   1% /mnt/wslg
none                                      3.9G     0  3.9G   0% /usr/lib/wsl/lib
rootfs                                    3.9G  2.7M  3.9G   1% /init
none                                      3.9G     0  3.9G   0% /dev
none                                      3.9G  480K  3.9G   1% /run
none                                      3.9G     0  3.9G   0% /run/lock
none                                      3.9G     0  3.9G   0% /run/shm
none                                      3.9G   92K  3.9G   1% /mnt/wslg/versions.txt
none                                      3.9G   92K  3.9G   1% /mnt/wslg/doc
C:\                                       238G  176G   63G  74% /mnt/c
D:\                                       239G  201G   39G  85% /mnt/d
E:\                                       932G  191G  742G  21% /mnt/e
tmpfs                                     1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
tmpfs                                     1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs                                     793M  8.0K  793M   1% /run/user/1000
tmpfs                                     793M  8.0K  793M   1% /run/user/0
C:\Program Files\Docker\Docker\resources  238G  176G   63G  74% /Docker/host
```

### Partition Table
```
NAME  MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0   7:0    0 689.3M  1 loop /mnt/wsl/docker-desktop/cli-tools
loop1   7:1    0 698.1M  1 loop 
sda     8:0    0 388.4M  1 disk 
sdb     8:16   0   186M  1 disk 
sdc     8:32   0     2G  0 disk [SWAP]
sdd     8:48   0 143.5M  0 disk /mnt/wsl/docker-desktop/docker-desktop-user-distro
sde     8:64   0     1T  0 disk 
sdf     8:80   0     1T  0 disk /mnt/wslg/distro
                                /
```

### Mount Points
```
none /usr/lib/modules/6.6.87.2-microsoft-standard-WSL2 overlay rw,nosuid,nodev,noatime,lowerdir=/modules,upperdir=/lib/modules/6.6.87.2-microsoft-standard-WSL2/rw/upper,workdir=/lib/modules/6.6.87.2-microsoft-standard-WSL2/rw/work,uuid=on 0 0
none /mnt/wsl tmpfs rw,relatime 0 0
none /mnt/wsl/docker-desktop/shared-sockets/guest-services tmpfs rw,nosuid,nodev,mode=755 0 0
none /mnt/wsl/docker-desktop/shared-sockets/host-services tmpfs rw,nosuid,nodev,mode=755 0 0
/dev/sdd /mnt/wsl/docker-desktop/docker-desktop-user-distro ext4 rw,relatime,discard,errors=remount-ro,data=ordered 0 0
/dev/loop0 /mnt/wsl/docker-desktop/cli-tools iso9660 ro,relatime,nojoliet,check=s,map=n,blocksize=2048,iocharset=utf8 0 0
drivers /usr/lib/wsl/drivers 9p ro,nosuid,nodev,noatime,aname=drivers;fmask=222;dmask=222,cache=5,access=client,msize=65536,trans=fd,rfd=8,wfd=8 0 0
/dev/sdf / ext4 rw,relatime,discard,errors=remount-ro,data=ordered 0 0
none /mnt/wslg tmpfs rw,relatime 0 0
/dev/sdf /mnt/wslg/distro ext4 ro,relatime,discard,errors=remount-ro,data=ordered 0 0
none /usr/lib/wsl/lib overlay rw,nosuid,nodev,noatime,lowerdir=/gpu_lib_packaged:/gpu_lib_inbox,upperdir=/gpu_lib/rw/upper,workdir=/gpu_lib/rw/work,uuid=on 0 0
rootfs /init rootfs ro,size=4050652k,nr_inodes=1012663 0 0
none /dev devtmpfs rw,nosuid,relatime,size=4050652k,nr_inodes=1012663,mode=755 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,noatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,noatime 0 0
devpts /dev/pts devpts rw,nosuid,noexec,noatime,gid=5,mode=620,ptmxmode=000 0 0
none /run tmpfs rw,nosuid,nodev,mode=755 0 0
none /run/lock tmpfs rw,nosuid,nodev,noexec,noatime 0 0
none /run/shm tmpfs rw,nosuid,nodev,noatime 0 0
none /dev/shm tmpfs rw,nosuid,nodev,noatime 0 0
none /run/user tmpfs rw,nosuid,nodev,noexec,noatime,mode=755 0 0
binfmt_misc /proc/sys/fs/binfmt_misc binfmt_misc rw,relatime 0 0
cgroup2 /sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate 0 0
none /mnt/wslg/versions.txt overlay rw,relatime,lowerdir=/systemvhd,upperdir=/system/rw/upper,workdir=/system/rw/work,uuid=on 0 0
none /mnt/wslg/doc overlay rw,relatime,lowerdir=/systemvhd,upperdir=/system/rw/upper,workdir=/system/rw/work,uuid=on 0 0
none /tmp/.X11-unix tmpfs ro,relatime 0 0
C:\134 /mnt/c 9p rw,noatime,aname=drvfs;path=C:\;uid=1000;gid=1000;symlinkroot=/mnt/,cache=5,access=client,msize=65536,trans=fd,rfd=6,wfd=6 0 0
D:\134 /mnt/d 9p rw,noatime,aname=drvfs;path=D:\;uid=1000;gid=1000;symlinkroot=/mnt/,cache=5,access=client,msize=65536,trans=fd,rfd=6,wfd=6 0 0
E:\134 /mnt/e 9p rw,noatime,aname=drvfs;path=E:\;uid=1000;gid=1000;symlinkroot=/mnt/,cache=5,access=client,msize=65536,trans=fd,rfd=6,wfd=6 0 0
none /run/user tmpfs rw,relatime 0 0
tracefs /sys/kernel/tracing tracefs rw,nosuid,nodev,noexec,relatime 0 0
sunrpc /run/rpc_pipefs rpc_pipefs rw,relatime 0 0
debugfs /sys/kernel/debug debugfs rw,nosuid,nodev,noexec,relatime 0 0
mqueue /dev/mqueue mqueue rw,nosuid,nodev,noexec,relatime 0 0
hugetlbfs /dev/hugepages hugetlbfs rw,nosuid,nodev,relatime,pagesize=2M 0 0
tmpfs /run/credentials/systemd-journald.service tmpfs ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,noswap 0 0
fusectl /sys/fs/fuse/connections fusectl rw,nosuid,nodev,noexec,relatime 0 0
configfs /sys/kernel/config configfs rw,nosuid,nodev,noexec,relatime 0 0
tmpfs /run/credentials/getty@tty1.service tmpfs ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,noswap 0 0
tmpfs /run/user/1000 tmpfs rw,nosuid,nodev,relatime,size=811132k,nr_inodes=202783,mode=700,uid=1000,gid=1000 0 0
tmpfs /mnt/wslg/run/user/1000 tmpfs rw,nosuid,nodev,relatime,size=811132k,nr_inodes=202783,mode=700,uid=1000,gid=1000 0 0
tmpfs /run/user/0 tmpfs rw,nosuid,nodev,relatime,size=811132k,nr_inodes=202783,mode=700 0 0
tmpfs /mnt/wslg/run/user/0 tmpfs rw,nosuid,nodev,relatime,size=811132k,nr_inodes=202783,mode=700 0 0
none /mnt/wsl/docker-desktop-bind-mounts/kali-linux/docker.sock tmpfs rw,nosuid,nodev,mode=755 0 0
C:\134Program\040Files\134Docker\134Docker\134resources /Docker/host 9p rw,noatime,aname=drvfs;path=C:\Program Files\Docker\Docker\resources;symlinkroot=/mnt/,cache=5,access=client,msize=65536,trans=fd,rfd=3,wfd=3 0 0
```

