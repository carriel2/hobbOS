#!/usr/bin/env bash
# Teste da persistência do hobbOS, como num pendrive de verdade:
#   1. copia a ISO para o começo de um "pendrive" virtual de 4 GB (como o dd faria);
#   2. dá boot por USB, roda "hobbos-persistencia --criar" e confere a partição HOBBOS_DADOS;
#   3. reinicia pela entrada "com persistência" do menu, cria um arquivo;
#   4. reinicia de novo pela mesma entrada e confere que o arquivo continua lá.
#
# Uso: tests/persistence-test.sh ISO [bios|uefi] [PASTA_DE_SAIDA]
set -uo pipefail
ISO=${1:?informe o caminho da ISO}
MODE=${2:-bios}
OUT=${3:-./persist-$MODE}
HERE=$(cd "$(dirname "$0")" && pwd)
QGA="python3 $HERE/qga.py"
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
SOCK=$OUT/qga.sock MON=$OUT/monitor.sock
rm -f "$SOCK" "$MON" "$OUT"/*.png "$OUT/pendrive.img"

cp "$ISO" "$OUT/pendrive.img" && truncate -s 4G "$OUT/pendrive.img"

firmware=()
if [[ $MODE == uefi ]]; then
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$OUT/vars.fd"
  firmware=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
            -drive if=pflash,format=raw,file="$OUT/vars.fd")
fi
accel=(-enable-kvm -cpu host); [[ -w /dev/kvm ]] || accel=(-cpu max)

monitor() { python3 -c 'import socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.sendall((sys.argv[2]+"\n").encode()); time.sleep(0.6); s.close()' "$MON" "$1"; }
screenshot() { monitor "screendump $OUT/$1.png -f png"; }
guest() { $QGA "$SOCK" exec "$1" "${2:-60}"; }

liga() { # descrição  [persistência: sim|não]
  rm -f "$SOCK" "$MON"
  qemu-system-x86_64 "${accel[@]}" -smp 2 -m 2048 "${firmware[@]}" \
    -drive if=none,id=stick,format=raw,file="$OUT/pendrive.img" \
    -device qemu-xhci -device usb-storage,drive=stick,bootindex=0 \
    -display none -vga std -nic user,model=virtio-net-pci \
    -chardev socket,path="$SOCK",server=on,wait=off,id=qga0 \
    -device virtio-serial -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    -monitor unix:"$MON",server,nowait -daemonize -pidfile "$OUT/qemu.pid" || { echo "FALHA: QEMU"; exit 1; }
  if [[ ${2:-não} == sim ]]; then
    # menu de boot: a entrada "com persistência" é a segunda
    sleep 8; screenshot "menu-$1"
    monitor "sendkey down"; monitor "sendkey ret"
  fi
  local t=0
  until $QGA "$SOCK" ping >/dev/null 2>&1; do
    sleep 5; t=$((t + 5))
    (( t >= 300 )) && { screenshot "travou-$1"; echo "FALHA: $1: guest agent não respondeu"; exit 1; }
  done
  echo "ok: $1 no ar (${t}s)"
}
desliga() { guest "systemctl poweroff" 10 >/dev/null 2>&1; sleep 15; monitor quit 2>/dev/null; sleep 2; }

fails=0
check() { # descrição  comando  regex
  local out code; out=$(guest "$2" 120); code=$?
  if [[ $code -eq 0 && $out =~ $3 ]]; then echo "ok: $1 -> $(echo "$out" | tr '\n' ' ' | cut -c1-110)"
  else echo "FALHA: $1 (código $code) -> $(echo "$out" | tr '\n' ' ' | cut -c1-200)"; fails=$((fails + 1)); fi
}

echo "== $ISO ($MODE) como pendrive USB"
liga "boot normal"
check "dá para criar a persistência" "hobbos-persistencia --verificar" "Dá para criar"
check "persistência criada"          "hobbos-persistencia --criar"      "criada: /dev/sd[a-z]3"
check "partição HOBBOS_DADOS"        "blkid -L HOBBOS_DADOS"            "^/dev/sd[a-z]3"
check "três partições no pendrive"  "lsblk -rno TYPE /dev/\$(lsblk -no PKNAME \$(blkid -L HOBBOS_DADOS)) | grep -c part" "^3$"
desliga

liga "1º boot com persistência" sim
check "entrou com persistência"      "cat /proc/cmdline"                "cow_label=HOBBOS_DADOS"
check "camada gravável no pendrive"  "findmnt -no SOURCE /run/archiso/cowspace" "/dev/sd[a-z]3"
guest "runuser -u hobbos -- sh -c 'mkdir -p /home/hobbos/Documentos && echo guardado-pelo-hobbos > /home/hobbos/Documentos/teste-persistencia.txt'; pacman -Q fastfetch > /root/marca.txt; sync" 30 >/dev/null
desliga

liga "2º boot com persistência" sim
check "arquivo do usuário continua lá" "cat /home/hobbos/Documentos/teste-persistencia.txt" "guardado-pelo-hobbos"
check "arquivo do root continua lá"    "cat /root/marca.txt"                                 "fastfetch"
sleep 30; screenshot "desktop-persistente"
desliga

echo "== resultado: $fails falha(s). Capturas em $OUT"
exit $(( fails > 0 ))
