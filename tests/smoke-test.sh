#!/usr/bin/env bash
# Smoke test da ISO do HobbOS: dá boot no QEMU e confere, por dentro do sistema live
# (via QEMU Guest Agent), se o desktop sobe e se idioma, teclado, fuso, rede, som e
# Firefox funcionam. Roda na VM de build (precisa de qemu-base, edk2-ovmf e python3).
#
# Uso: tests/smoke-test.sh ISO [bios|uefi] [PASTA_DE_SAIDA]
# Sai com 0 só se todas as checagens passarem. Deixa capturas de tela na pasta de saída.
set -uo pipefail

ISO=${1:?informe o caminho da ISO}
MODE=${2:-bios}
OUT=${3:-./smoke-$MODE}
HERE=$(cd "$(dirname "$0")" && pwd)
QGA="python3 $HERE/qga.py"

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
SOCK=$OUT/qga.sock
MON=$OUT/monitor.sock
rm -f "$SOCK" "$MON" "$OUT"/*.png

firmware=()
if [[ $MODE == uefi ]]; then
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$OUT/vars.fd"
  firmware=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
            -drive if=pflash,format=raw,file="$OUT/vars.fd")
fi

accel=(-enable-kvm -cpu host)
[[ -w /dev/kvm ]] || accel=(-cpu max)

qemu-system-x86_64 "${accel[@]}" -smp 2 -m 2048 \
  -cdrom "$ISO" -boot d "${firmware[@]}" \
  -display none -vga std \
  -nic user,model=virtio-net-pci \
  -audiodev none,id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0 \
  -chardev socket,path="$SOCK",server=on,wait=off,id=qga0 \
  -device virtio-serial -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -monitor unix:"$MON",server,nowait \
  -daemonize -pidfile "$OUT/qemu.pid" || { echo "FALHA: QEMU não iniciou"; exit 1; }

monitor() { python3 -c 'import socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.sendall((sys.argv[2]+"\n").encode()); time.sleep(1.5); s.close()' "$MON" "$1"; }
screenshot() { monitor "screendump $OUT/$1.png -f png"; }
cleanup() { monitor quit 2>/dev/null; sleep 1; }
trap cleanup EXIT

guest() { $QGA "$SOCK" exec "$1" "${2:-60}"; }
as_user() { guest "runuser -u hobbos -- env XDG_RUNTIME_DIR=/run/user/1000 DISPLAY=:0 XAUTHORITY=/home/hobbos/.Xauthority sh -c '$1'" "${2:-60}"; }

wait_for() { # descrição  segundos  comando-no-guest
  local desc=$1 secs=$2 cmd=$3 t=0
  until guest "$cmd" >/dev/null 2>&1; do
    sleep 5; t=$((t + 5))
    (( t >= secs )) && { echo "FALHA: $desc (esperou ${secs}s)"; return 1; }
  done
  echo "ok: $desc (${t}s)"
}

fails=0
check() { # descrição  comando-no-guest  [regex esperado na saída]
  local desc=$1 cmd=$2 expect=${3:-} out code
  out=$(guest "$cmd" 90); code=$?
  if [[ $code -eq 0 && ( -z $expect || $out =~ $expect ) ]]; then
    echo "ok: $desc -> $(echo "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    echo "FALHA: $desc (código $code) -> $(echo "$out" | tr '\n' ' ' | cut -c1-200)"
    fails=$((fails + 1))
  fi
}

echo "== $ISO ($MODE)"
t=0
until $QGA "$SOCK" ping; do
  sleep 5; t=$((t + 5))
  (( t >= 240 )) && { screenshot boot-travado; echo "FALHA: guest agent não respondeu em 240s"; exit 1; }
done
echo "ok: sistema no ar, guest agent respondendo (${t}s)"

wait_for "desktop XFCE do usuário hobbos" 180 "pgrep -u hobbos -x xfce4-session" || fails=$((fails + 1))
wait_for "painel e área de trabalho desenhados" 90 \
  "pgrep -u hobbos -x xfce4-panel && pgrep -u hobbos -x xfdesktop" || fails=$((fails + 1))
sleep 15 # tempo para o wallpaper ser aplicado e a tela redesenhar
screenshot desktop

check "idioma pt_BR"          "localectl status"                          "LANG=pt_BR.UTF-8"
check "locale pt_BR gerado"   "locale -a"                                 "pt_BR\.utf8"
check "teclado ABNT2 no X"    "localectl status"                          "X11 Layout: br"
check "teclado ABNT2 console" "cat /etc/vconsole.conf"                    "br-abnt2"
check "fuso America/Sao_Paulo" "timedatectl show -p Timezone --value"     "America/Sao_Paulo"
check "NetworkManager conectado" "nmcli -t -f STATE general"              "^connected"
check "acesso à internet (HTTPS)" "curl -sS -o /dev/null -w '%{http_code}' https://archlinux.org" "^(200|301|302)"
check "placa de som detectada" "cat /proc/asound/cards"                   "HDA"
out=$(as_user "wpctl inspect @DEFAULT_AUDIO_SINK@" 30); code=$?
if [[ $code -eq 0 && $out =~ node\.name\ =\ \"alsa_output ]]; then
  echo "ok: PipeWire com saída de áudio -> $(grep -o 'node.name = "[^"]*"' <<<"$out" | head -1)"
else
  echo "FALHA: PipeWire sem saída de áudio -> $(echo "$out" | tr '\n' ' ' | cut -c1-200)"; fails=$((fails + 1))
fi

# Visual retrô: tema, ícones, painel com Iniciar e wallpaper do HobbOS
user_check() { # descrição  comando-como-hobbos  regex
  local out code
  out=$(as_user "$2" 30); code=$?
  if [[ $code -eq 0 && $out =~ $3 ]]; then
    echo "ok: $1 -> $(echo "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    echo "FALHA: $1 (código $code) -> $(echo "$out" | tr '\n' ' ' | cut -c1-200)"; fails=$((fails + 1))
  fi
}
user_check "tema GTK HobbOS-Luna"   "xfconf-query -c xsettings -p /Net/ThemeName"        "^HobbOS-Luna"
user_check "tema de janelas HobbOS-Luna" "xfconf-query -c xfwm4 -p /general/theme"      "^HobbOS-Luna"
user_check "ícones nuoveXT2"        "xfconf-query -c xsettings -p /Net/IconThemeName"    "^nuoveXT2"
user_check "botão Iniciar no painel" "xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-title" "^Iniciar"
user_check "wallpaper do HobbOS"    "xfconf-query -c xfce4-desktop -l -v | grep last-image" "hobbos-colina\.png"

# Firefox: abre uma página e confere se o processo fica de pé
guest "runuser -u hobbos -- env XDG_RUNTIME_DIR=/run/user/1000 DISPLAY=:0 XAUTHORITY=/home/hobbos/.Xauthority setsid -f firefox https://archlinux.org >/dev/null 2>&1" 15 >/dev/null
sleep 30
screenshot firefox
check "Firefox aberto"        "pgrep -u hobbos -c firefox"                "^[1-9]"
check "Firefox em pt-BR instalado" "ls /usr/lib/firefox/browser/extensions/" "pt-BR"

echo "== resultado: $fails falha(s). Capturas em $OUT"
exit $(( fails > 0 ))
