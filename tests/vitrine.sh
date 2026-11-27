#!/usr/bin/env bash
# Capturas de divulgação do hobbOS (roda na VM de build): boot em 1920x1080 gravado
# quadro a quadro, desktop com boas-vindas, menu Iniciar e uma cena com várias janelas.
# Uso: vitrine.sh ISO PASTA
set -uo pipefail
ISO=$1
OUT=$2
QGA="python3 $(cd "$(dirname "$0")" && pwd)/qga.py"
rm -rf "$OUT"; mkdir -p "$OUT/frames"
SOCK=$OUT/qga.sock MON=$OUT/monitor.sock
qemu-img create -q -f qcow2 "$OUT/disco.qcow2" 32G

cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$OUT/vars.fd"
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 3072 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$OUT/vars.fd" \
  -cdrom "$ISO" -boot d -display none -vga none -device VGA,edid=on,xres=1920,yres=1080 \
  -drive file="$OUT/disco.qcow2",if=virtio,format=qcow2 \
  -nic user,model=virtio-net-pci \
  -audiodev none,id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0 \
  -chardev socket,path="$SOCK",server=on,wait=off,id=qga0 \
  -device virtio-serial -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -no-shutdown -monitor unix:"$MON",server,nowait -daemonize -pidfile "$OUT/qemu.pid" || exit 1

# Gravador: um screendump a cada 0,25 s numa conexão só com o monitor
cat > "$OUT/grava.py" <<'PY'
import os, socket, sys, time
mon, pasta = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX); s.connect(mon); s.settimeout(0.05)
i = 0
while not os.path.exists(os.path.join(pasta, "PARA")):
    alvo = os.path.join(pasta, "frames", f"f{i:05d}.png")
    try: s.sendall(f"screendump {alvo} -f png\n".encode())
    except OSError: break
    i += 1
    with open(os.path.join(pasta, "quadro"), "w") as f: f.write(str(i))
    t = time.time()
    while time.time() - t < 0.25:
        try: s.recv(65536)
        except OSError: pass
try: s.sendall(b"quit\n")
except OSError: pass
PY
python3 "$OUT/grava.py" "$MON" "$OUT" & GRAVA=$!
marca() { echo "$1 $(cat "$OUT/quadro")" >> "$OUT/marcas.txt"; }
cp_ultimo() { sleep 2; local q; q=$(( $(cat "$OUT/quadro") - 4 )); cp "$OUT/frames/f$(printf %05d $q).png" "$OUT/$1.png"; echo "captura: $1"; }

guest() { $QGA "$SOCK" exec "$1" "${2:-60}"; }
U="runuser -u hobbos -- env XDG_RUNTIME_DIR=/run/user/1000 DISPLAY=:0 XAUTHORITY=/home/hobbos/.Xauthority"
user() { guest "$U sh -c '$1'" "${2:-60}"; }

marca inicio
until $QGA "$SOCK" ping >/dev/null 2>&1; do sleep 1; done
marca sistema
until guest "pgrep -u hobbos -x xfdesktop" >/dev/null 2>&1; do sleep 1; done
marca desktop
# Espera a janela de boas-vindas existir de verdade (nome na lista de janelas do X)
JAN=$(printf '%s\n' 'for i in $(seq 1 120); do' \
  '  for w in $(xprop -root _NET_CLIENT_LIST | grep -o "0x[0-9a-f]*"); do' \
  '    xprop -id $w WM_NAME | grep -q "$1" && exit 0; done; sleep 1; done; exit 1' | base64 -w0)
guest "echo $JAN | base64 -d > /tmp/janela.sh; chmod 755 /tmp/janela.sh"
guest "$U /tmp/janela.sh Bem-vindo" 150 >/dev/null
marca boasvindas
sleep 4
cp_ultimo 01-boas-vindas

# Menu Iniciar aberto
guest "pkill -u hobbos -f hobbos-boas-vindas" >/dev/null
sleep 2
user "xfce4-popup-whiskermenu" >/dev/null
sleep 3
cp_ultimo 02-iniciar
marca menu
user "xdotool key Escape" >/dev/null 2>&1

# Ferramentas para arrumar as janelas (só nesta gravação) e um disco com partições
guest "pacman -Sy --noconfirm --needed xdotool" 240 >/dev/null
user "xdotool key Escape" >/dev/null
guest "parted -s /dev/vda mklabel msdos mkpart primary ntfs 1MiB 20GiB mkpart primary ext4 20GiB 100% && mkntfs -Q -L Windows /dev/vda1 && mkfs.ext4 -q -L Dados /dev/vda2" 120 >/dev/null
guest "mkdir -p /mnt/w && mount /dev/vda1 /mnt/w && dd if=/dev/urandom of=/mnt/w/dados.bin bs=1M count=1500 status=none; umount /mnt/w" 300 >/dev/null

# Cena: terminal com fastfetch, GParted com o disco, Campo Minado e Paciência
user "setsid -f xfce4-terminal --geometry=96x26+40+40 >/dev/null 2>&1" >/dev/null
sleep 3
guest "$U setsid -f gparted /dev/vda >/dev/null 2>&1" 15 >/dev/null
sleep 12
user "xdotool search --sync --name \"/dev/vda - GParted\" windowsize 1000 520 windowmove 880 40" >/dev/null
user "setsid -f sol klondike >/dev/null 2>&1" >/dev/null
sleep 5
user "xdotool search --sync --class sol windowsize 760 430 windowmove 1110 590" >/dev/null 2>&1
user "setsid -f hobbos-campo-minado >/dev/null 2>&1" >/dev/null
sleep 4
user "xdotool search --sync --name \"^Campo Minado\$\" windowmove 640 560" >/dev/null
sleep 1
# Joga um pouco: abre o centro e marca duas bandeiras
geo=$(user "xdotool search --name \"^Campo Minado\$\" getwindowgeometry --shell")
eval "$(echo "$geo" | grep -E '^(X|Y|WIDTH|HEIGHT)=')"
bx=$(( X + 6 )); by=$(( Y + HEIGHT - 6 - 198 ))
cel() { echo "mousemove $(( bx + $1 * 22 + 11 )) $(( by + $2 * 22 + 11 )) click $3"; }
user "xdotool $(cel 4 4 1) sleep 0.4 $(cel 0 8 3) sleep 0.3 $(cel 8 0 3) sleep 0.3 mousemove 1500 320" >/dev/null
sleep 3
cp_ultimo 03-classico
marca cena

# Desligando (tela do Plymouth na saída)
guest "systemctl poweroff" 10 >/dev/null 2>&1
sleep 25
touch "$OUT/PARA"; wait $GRAVA
cat "$OUT/marcas.txt"
ls "$OUT"/*.png; ls "$OUT/frames" | wc -l
