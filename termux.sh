#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

log(){
   printf "\033[0;34m$1\033[0m\n"
}

##detect external sdcard path
external="$(mount | awk '{print $3}' | grep -e "^/storage/" | (grep -v -e "^/storage/emulated" || echo "/sdcard") | head -n1)"

##Disable login message
log "Disabling login message"
echo -n | tee $HOME/../usr/etc/motd >/dev/null

##Enable fullscreen
log "Enabling fullscreen"
string="fullscreen = true"
termuxprop="$HOME/.termux/termux.properties"
if ! grep -q "^${string}" "${termuxprop}"; then
   echo "${string}" | tee -a "${termuxprop}" >/dev/null
fi
unset string termuxprop

##Move Termux deb package to external
log "Moving Termux deb package to external"
debcache="$HOME/../../cache/apt/archives"
termuxtmp="$external/deb/termux"
rm -rf "$debcache"
mkdir -p "$(dirname $debcache)" "$termuxtmp"
ln -s "$termuxtmp" "$debcache"
unset debcache termuxtmp

##Add SD variable
log "Adding SD variable"
string="export SD=\"\$(mount | awk '{print \$3}' | grep -e \"^/storage/\" | (grep -v -e \"^/storage/emulated\" || echo \"/sdcard\") | head -n1)\""
bashrc="$HOME/.bashrc"
if ! [ -f "$bashrc" ] || ! grep -q "^${string}" "${bashrc}"; then
   echo "${string}" | tee -a "${bashrc}" >/dev/null
fi
unset string bashrc

##Disable man-db
log "Disabling man-db"
dpkgconf="$PREFIX/etc/dpkg/dpkg.cfg.d/01_nodoc"
mkdir -p "$(dirname $dpkgconf)"
echo "# Delete man pages
path-exclude=$PREFIX/share/man/*
# Delete docs
path-exclude=$PREFIX/share/doc/*
path-include=$PREFIX/share/doc/*/copyright" |
while read string; do
   if ! [ -f "$dpkgconf" ] || ! grep -q "^${string}" "${dpkgconf}" ; then
      echo "$string"
   fi
done | tee -a "$dpkgconf" >/dev/null
unset dpkgconf

##Add ~/bin to PATH
log "Adding ~/bin to PATH"
mkdir -p "$HOME/bin"
bashrc="$HOME/.bashrc"
string='export PATH="$PATH:$HOME/bin"'
if ! [ -f "$bashrc" ] || ! grep -zoPq "^$bashrc" "$HOME/.bashrc"; then
   echo -e "$string" | tee -a "$HOME/.bashrc" >/dev/null
fi
unset bin bashrc string

##Force apt to trust the repo
log "Forcing apt to trust the repo"
sed -i -e 's@^deb h@deb [trusted=yes] h@g' "$PREFIX/etc/apt/sources.list"

##Install favorites
log "Installing favorites"
#pkgs="openssh "
pkgs="bash-completion ffmpeg nano wget python ncdu htop x11-repo termux-api p7zip command-not-found "
apt update -y
apt install -y $pkgs
unset pkgs

##Install yt-dlp to ~/bin
log "Installing yt-dlp to ~/bin"
##curl --retry 5 -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o "$HOME/bin/yt-dlp"
##chmod a+rx "$HOME/bin/yt-dlp"
pip install -U --no-deps yt-dlp

##Put termux-url-opener
log "Putting termux-url-opener"
cat <<"EOF" | tee "$HOME/bin/termux-url-opener" >/dev/null
#!/data/data/com.termux/files/usr/bin/bash
url="$1"
SD="$(mount | awk '{print $3}' | grep -e "^/storage/" | (grep -v -e "^/storage/emulated" || echo "/sdcard") | head -n1)"
dir="$SD/Movies"
"${PREFIX}/bin/yt-dlp" -o "${dir}/%(title)s.%(ext)s" "$url" || sleep 1m
EOF

##Move cache dir to SD
log "Moving cache dir to SD"
mkdir -p "$external/deb/cache"
rm -rf "$HOME/.cache"
ln -s "$external/deb/cache" "$HOME/.cache"

##Configure ssh
#log "Configuring ssh"
#sshconf="$PREFIX/etc/ssh/sshd_config"
#passwd="123456"
#log "Changing password to ${passwd}"
#echo -e "${passwd}\n${passwd}" | passwd
#echo "X11Forwarding yes" |
#while read string; do
#   if ! grep -q "^${string}" "${sshconf}" ; then
#      echo "$string"
#   fi
#done | tee -a "$sshconf" >/dev/null
#mkdir -p "$HOME/.termux/boot"
#echo -en '#!/data/data/com.termux/files/usr/bin/sh\nsshd' | tee "$HOME/.termux/boot/00start_ssh" >/dev/null
#unset passwd



termux-wake-unlock
exit
