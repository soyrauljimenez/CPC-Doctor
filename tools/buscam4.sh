#!/bin/bash
# Imprime la IP de la M4 Board de la red local.
#
#   M4=$(tools/buscam4.sh) || exit 1
#
# Orden de búsqueda: la variable M4 (si es una IP y responde), la última IP
# encontrada (guardada en .m4ip, fuera de git) y, si ninguna responde, un
# rastreo de la red local buscando la página "M4 Board".
DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$DIR/.m4ip"

es_m4() { curl -s -m 2 "http://$1/" 2>/dev/null | grep -q "M4 Board"; }

if [ -n "$M4" ] && [ "$M4" != "auto" ] && es_m4 "$M4"; then echo "$M4"; exit 0; fi
if [ -f "$CACHE" ] && es_m4 "$(cat "$CACHE")"; then cat "$CACHE"; exit 0; fi

# Red local: la de la interfaz de la ruta por defecto
if command -v route >/dev/null && route -n get default >/dev/null 2>&1; then
	IFACE=$(route -n get default | awk '/interface:/{print $2}')
	IP=$(ipconfig getifaddr "$IFACE" 2>/dev/null)               # macOS
else
	IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src") print $(i+1)}')  # Linux
fi
[ -n "$IP" ] || { echo "no encuentro la red local" >&2; exit 1; }
RED=${IP%.*}
echo "buscando la M4 en $RED.0/24..." >&2

TMP=$(mktemp)
for i in $(seq 1 254); do
	( es_m4 "$RED.$i" && echo "$RED.$i" >> "$TMP" ) &
done
wait
ENCONTRADA=$(head -1 "$TMP")
rm -f "$TMP"
[ -n "$ENCONTRADA" ] || { echo "no encuentro ninguna M4 en $RED.0/24 (¿está encendido el CPC?)" >&2; exit 1; }
echo "$ENCONTRADA" > "$CACHE"
echo "$ENCONTRADA"
