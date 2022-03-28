#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

time1="$( date +"%r" )"

[ -z "$ARCHITECTURE" ] && ARCHITECTURE=$(dpkg --print-architecture)
case "$ARCHITECTURE" in
    aarch64) ARCHITECTURE=arm64;;
    arm) ARCHITECTURE=armhf;;
    amd64|x86_64) ARCHITECTURE=amd64;;
    *)  printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Unknown architecture :- $ARCHITECTURE"
        exit 1;;
esac

ARCHITECTURE=$ARCHITECTURE

UBUNTU_VERSION=21.10
dir=${HOME}/ubuntu-fs-${UBUNTU_VERSION}-${ARCHITECTURE}
external=$(mount | awk '{print $3}' | grep -e "^/storage/" | (grep -v -e "^/storage/emulated" || echo "/sdcard") | head -n1)
download=$external/Download
debarchive=$external/deb/ubuntu-${UBUNTU_VERSION}-${ARCHITECTURE}

base=${download}/ubuntu-base-${UBUNTU_VERSION}-base-${ARCHITECTURE}.tar.gz


##grant storage permission
until mkdir -p "$download";do
   printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Grant storage permission.\n"
   sleep 1
   am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux
   sleep 3
done
mkdir -p "$debarchive"

if [ -d "${dir}" ];then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Skipping the download\n"
    rm -rf "${dir}"
fi
while [ -z "$(command -v proot)" ];do
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Installing proot.\n"
    printf "\e[0m"
    if compgen -G "${termuxtmp}/proot_*.deb" >/dev/null && compgen -G "${termuxtmp}/libtalloc_*.deb" >/dev/null ;then
       apt install ${termuxtmp}/{proot,libtalloc}_*.deb
    else
       apt install -y proot || apt update -y
    fi
done
if [ ! -f "${base}" ];then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Downloading the ubuntu rootfs, please wait...\n"
    curl http://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCHITECTURE}.tar.gz --silent --show-error --output "${base}"
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Download complete!\n"

fi


mkdir -p $dir
cd $dir
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Decompressing the ubuntu rootfs, please wait...\n"
tar -zxf "${base}" --exclude='dev'||: --exclude=/usr/share/man/ --exclude=/usr/share/doc/ --exclude= -C "${dir}"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The ubuntu rootfs have been successfully decompressed!\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fixing the resolv.conf, so that you have access to the internet\n"
printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > etc/resolv.conf
stubs=()
stubs+=('usr/bin/groups')
for f in ${stubs[@]};do
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Writing stubs, please wait...\n"
echo -e "#!/bin/sh\nexit" > "$f"
done
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully wrote stubs!\n"

##disable man-db forever
cat <<"EOF" | tee etc/dpkg/dpkg.cfg.d/01_nodoc >/dev/null
# Delete locales
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/en/*
path-include=/usr/share/locale/ja/*
# Delete man pages
path-exclude=/usr/share/man/*
# Delete docs
path-exclude=/usr/share/doc/*
# Delete cron settings
path-exclude=/etc/cron.d/*
path-exclude=/etc/cron.daily/*
path-exclude=/etc/cron.hourly/*
path-exclude=/etc/cron.monthly/*
path-exclude=/etc/cron.weekly/*
# Delete background images
path-exclude=/usr/share/backgrounds/*
# Delete icons
path-exclude=/usr/share/icons/*
EOF

##disable apt translation-en
cat <<"EOF" | tee etc/apt/apt.conf.d/99translations >/dev/null
Acquire::Languages "none";
EOF

##disable security updates
sed -i -e 's@\(^deb http[:/.a-z/-]* [a-z]*-\)@# \1@g'  etc/apt/sources.list

##download deb package to external
rm -rf var/cache/apt/archives
mkdir -p var/cache/apt
ln -s ${debarchive} var/cache/apt/archives

listcache="var/lib/apt/lists"
rm -rf "$listcache"
mkdir -p "$(dirname $listcache)" "${debarchive}/lists"
ln -s "${debarchive}/lists" "$listcache"

##move cache to sd
rm -rf "${dir}/root/.cache"
mkdir -p "${external}/deb/cache"
ln -s "${external}/deb/cache" "${dir}/root/.cache"


bin=$HOME/bin
script=$bin/startubuntu-${UBUNTU_VERSION}-${ARCHITECTURE}.sh

printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Creating the start script, please wait...\n"
mkdir -p "${bin}"
cat > "$script" <<- EOM
#!/bin/bash
cd \$(dirname \$0)
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
## uncomment following line if you are having FATAL: kernel too old message.
#command+=" -k 4.14.81"
command+=" --link2symlink"
command+=" -0"
command+=" -r ${dir}"
command+=" -b /dev -b /proc -b /sys"
command+=" -b ${dir}/tmp:/dev/shm"
command+=" -b /data/data/com.termux"
command+=" -b /:/host-rootfs"
command+=" -b /sdcard"
command+=" -b /storage"
command+=" -b /mnt"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games:/root/bin"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" SD=\$(mount | awk '{print \$3}' | grep -e "^/storage/" | (grep -v -e "^/storage/emulated" || echo "/sdcard") | head -n1)"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM
chmod +x "$script"

##add ~/bin to PATH
bashrc='export PATH="$PATH:$HOME/bin"'
if ! grep -q "^$bashrc" "$HOME/.bashrc" 2>/dev/null ;then
   echo -e "$bashrc" | tee -a "$HOME/.bashrc" >/dev/null
fi

##disable keyboard layout asking
echo -en '# KEYBOARD CONFIGURATION FILE\n\n# Consult the keyboard(5) manual page.\n\nXKBMODEL="pc105"\nXKBLAYOUT="jp"\nXKBVARIANT=""\nXKBOPTIONS=""\n\nBACKSPACE="guess"\n' |
tee "${dir}/etc/default/keyboard" >/dev/null

##use eatmydata
"$script" apt-get update
"$script" apt-get install -y --no-install-recommends libeatmydata1
echo -e 'export LD_PRELOAD=${LD_PRELOAD:+"$LD_PRELOAD "}'"$("$script" dpkg -L "libeatmydata1" | grep -E "^/usr/lib/.*/libeatmydata.so$")" |
tee "${dir}/etc/profile.d/00-eatmydata.sh" > /dev/null
chmod +x "${dir}/etc/profile.d/00-eatmydata.sh"

##set display variable
echo -n 'export DISPLAY=127.0.0.1:0 PULSE_SERVER=tcp:127.0.0.1:4713' |
tee "${dir}/etc/profile.d/00-display_var.sh" > /dev/null
chmod +x "${dir}/etc/profile.d/00-display_var.sh"

##root can use vlc
cat > "${dir}/etc/profile.d/00-root_vlc.sh" <<'EOM'
[ -f '/usr/bin/vlc' ] && '/bin/grep' -q 'geteuid' '/usr/bin/vlc' && '/bin/sed' -i 's/geteuid/getppid/' '/usr/bin/vlc'
EOM
chmod +x "${dir}/etc/profile.d/00-root_vlc.sh"

##avoid vlc first ask
"$script" '/bin/mkdir' -p "/root/.config/vlc"
cp "$(dirname "$0")/conf/vlcrc" "${dir}/root/.config/vlc/vlcrc"

##gcc flags
tee "${dir}/etc/profile.d/00-cflags.sh" >/dev/null <<'EOF'
export CFLAGS='-pipe -march=native -mtune=native'
export CXXFLAGS='-pipe -march=native -mtune=native'
EOF
chmod +x "${dir}/etc/profile.d/00-cflags.sh"

unwanted="tumbler ubuntu-report popularity-contest apport whoopsie apport-symptoms snap snapd apparmor synaptic rsyslog man-db yelp-xsl yelp"
wanted="htop ncdu nano vim bash-completion wget curl ffmpeg p7zip-full p7zip-rar python3-pip python3-requests python3-numpy python3-matplotlib python3-pandas python3-sklearn python3-pyftpdlib python3-bs4 unar pv aria2 nodejs npm ruby imagemagick command-not-found python3-websockets python3-mutagen python3-pycryptodome"
errors=""
#errors+=="udisks2 dbus libpam-systemd:$ARCHITECTURE policykit-1 networkd-dispatcher"
(
##disable tzdata asking
echo -e "export DEBIAN_FRONTEND=noninteractive"
echo -e "ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime"
echo -e "apt-get update \napt-get purge -y --auto-remove $unwanted \napt-mark hold $unwanted"
# echo -e "apt-get install --no-install-recommends -y $wanted $errors"
echo -e "rm -f $(for i in $errors;do echo /var/lib/dpkg/info/$i.postinst;done) \napt-get --fix-broken install"
echo -e "cd /root \nmkdir -p bin \ncd bin"
echo -e "pip3 install -U yt-dlp"
#echo -e "curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o yt-dlp &&\n chmod a+rx yt-dlp"
)| "$script" sh

printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The start script has been successfully created!\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fixing shebang of startubuntu.sh, please wait...\n"
termux-fix-shebang $script
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully fixed shebang of startubuntu.sh! \n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Making startubuntu.sh executable please wait...\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully made startubuntu.sh executable\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The installation has been completed! You can now launch Ubuntu with ./startubuntu.sh\n"
printf "\e[0m"


termux-wake-unlock
exit
