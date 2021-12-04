#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

log(){
   printf "\033[0;34m$1\033[0m\n"
}

##detect external sdcard path
external="$( (mount | awk '{print $3}' | grep -e "^/storage/" | grep -v -e "^/storage/emulated" | head -n1) || echo "/sdcard")"

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
termuxtmp="$external/deb"
rm -rf "$debcache"
mkdir -p "$(dirname $debcache)"
ln -s "$termuxtmp" "$debcache"
unset debcache termuxtmp

##Add SD variable
log "Addin SD variable"
string="export SD=\"\$((mount | awk '{print \$3}' | grep -e \"^/storage/\" | grep -v -e \"^/storage/emulated\" | head -n1) || echo \"/sdcard\")\""
bashrc="$HOME/.bashrc"
if  [ -f "$bashrc" ] || ! grep -q "^${string}" "${bashrc}"; then
   echo "${string}" | tee -a "${bashrc}" >/dev/null
fi
unset string bashrc

##Disable man-db
log "Disabling man-db"
dpkgconf=" $PREFIX/etc/dpkg/dpkg.cfg.d/01_nodoc"
strings=""
mkdir -p "$(dirname $dpkgconf)"
echo "# Delete man pages
path-exclude=$PREFIX/share/man/*
# Delete docs
path-exclude=$PREFIX/share/doc/*
path-include=$PREFIX/share/doc/*/copyright" |
while read string;do
   if [ -f "$dpkgconf" ] || ! grep -q "^${string}" "${dpkgconf}" ; then
      strings="${string}\n"
   fi
done
if [ -n "${strings}" ]; then
   echo -en "$strings" | tee -a "$dpkgconf" >/dev/null
fi
unset strings dpkgconf

##Add ~/bin to PATH
log "Adding ~/bin to PATH"
mkdir -p "$HOME/bin"
bashrc="$HOME/.bashrc"
string='export PATH="$PATH:$HOME/bin"'
if [ -f "$bashrc" ] || ! grep -zoPq "^$bashrc" "$HOME/.bashrc"; then
   echo -e "$string" | tee -a "$HOME/.bashrc" >/dev/null
fi
unset bin bashrc string

##Install yt-dlp to ~/bin
log "Installing yt-dlp to ~/bin"
curl --retry 5 -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o "$HOME/bin/yt-dlp"
chmod a+rx "$HOME/bin/yt-dlp"

##Install favorites
log "Installing favorites"
pkgs="ffmpeg bash-completion nano wget"
pkg install -y $pkgs
unset pkgs

##Put termux-url-opener
log "Putting termux-url-opener"
cat <<"EOF" | tee "$HOME/bin/termux-url-opener"
#!/data/data/com.termux/files/usr/bin/bash
url="$1"
SD="$((mount | awk '{print $3}' | grep -e "^/storage/" | grep -v -e "^/storage/emulated" | head -n1) || echo "/sdcard")"
dir="$SD/Movies"
yt-dlp -o "$dir/%(title)s.%(ext)s" "$url" || sleep 1m
EOF

termux-wake-unlock
exit
