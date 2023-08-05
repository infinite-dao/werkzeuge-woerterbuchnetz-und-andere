#!/usr/bin/env bash
# Programm zum Abfragen der Wortverlaufskurven des Digitalen Wörterbuchs Deutscher Sprache (DWDS) 
# Abhängigkeit: convert von ImageMagick zur Bildverarbeitung
# Abhängigkeit: wget (Standardwerkzeug zum Abfragen von Netz-Adressen)

set -Eeuo pipefail
trap abschlussarbeiten SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
declare -a WORTLISTEN_EINGABE

abhaengigkeiten_pruefen() {
  local stufe_abbruch=0

  if ! [[ -x "$(command -v wget)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} wget ${ORANGE} zum Abspeichern von Netzdateien nicht gefunden: Bitte${FORMAT_FREI} wget ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v convert)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} convert ${ORANGE}nicht gefunden: Bitte convert (von ImageMagick) über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}

nutzung() {
  local diese_nutzung=''

  diese_nutzung=$( cat <<NUTZUNG
Nutzung:
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] "Wort"
  ./$(basename "${BASH_SOURCE[0]}") "Wort1; Wort2; Wort3"

Wortverlaufskurve eines gegebenen Worts beschriften und als PNG abspeichern.

Verwendbare Wahlmöglichkeiten:
-h,    --Hilfe             Hilfetext dieses Programms ausgeben.
-j,    --JPEG              Bild als JPEG ausgeben anstatt PNG.

-e,    --Entwicklung       Zusatz-Meldungen zur Entwicklung ausgeben
       --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
       --farb-frei         Meldungen ohne Farben ausgeben

Technische Anmerkungen:

- abhängig von Befehl ${BLAU}wget${FORMAT_FREI} (Anfragen ins Netz)
- abhängig von Befehl ${BLAU}convert${FORMAT_FREI} (Bildverarbeitung)

NUTZUNG
)
  echo -e "${diese_nutzung}" # mit Farbausgabe 

  abhaengigkeiten_pruefen
  exit
}


abschlussarbeiten() {
  trap - SIGINT SIGTERM ERR EXIT
  # aufzuräumendes für dieses Programm
  
  case "${stufe_fehler_abschlussarbeiten-0}" in 
  0) meldung "------------------------------${FORMAT_FREI}" ; ;;
  1)   
    if [[ $(ls -A *Wortverlaufskurve*.svg* 2>/dev/null | head -c1 | wc -c) -gt 0 ]];then
      echo -e "${GRUEN}Ende: Siehe Wortverlaufskurve(n) … ${FORMAT_FREI}"
      ls -lA *Wortverlaufskurve*.svg*
    else
      echo -e "${ORANGE}Ende: Keine Wortverlaufskurven gefunden … ${FORMAT_FREI}"
    fi
  ;;
  *) meldung "${ORANGE}Ende: irgendwas lief schief, stufe_fehler_abschlussarbeiten: $stufe_fehler_abschlussarbeiten … ${FORMAT_FREI}" ; ;;
  esac

}

farben_bereitstellen() {
  # file descriptor [[ -t 2 ]] : 0 → stdin / 1 → stdout / 2 → stderr
  if [[ -t 2 ]] && [[ -z "${ANWEISUNG_FORMAT_FREI-}" ]] && [[ "${ANWEISUNG_FORMAT-}" != "stumm" ]]; then
    FORMAT_FREI='\033[0m' ROT='\033[0;31m' GRUEN='\033[0;32m' ORANGE='\033[0;33m' BLAU='\033[0;34m' VEILCHENROT='\033[0;35m' HIMMELBLAU='\033[0;36m' GELB='\033[1;33m'
  else
    FORMAT_FREI='' ROT='' GRUEN='' ORANGE='' BLAU='' VEILCHENROT='' HIMMELBLAU='' GELB=''
  fi
}

meldung() {
  echo >&2 -e "${1-}"
}

meldung_abbruch() {
  local meldung=$1
  local code=${2-1} # default exit status 1
  meldung "$meldung"
  exit "$code"
}


parameter_abarbeiten() {
  # default values of variables set from params
  case $(date '+%m') in
  01|1) datum_heute_lang=$(date '+%_d. Wintermonat (%b.) %Y' | sed 's@^ *@@;');;
  02|2) datum_heute_lang=$(date '+%_d. Hornung (%b.) %Y'     | sed 's@^ *@@;') ;;
  03|3) datum_heute_lang=$(date '+%_d. Lenzmonat (%b.) %Y'   | sed 's@^ *@@;') ;;
  04|4) datum_heute_lang=$(date '+%_d. Ostermonat (%b.) %Y'  | sed 's@^ *@@;') ;;
  05|5) datum_heute_lang=$(date '+%_d. Wonnemonat (%b.) %Y'  | sed 's@^ *@@;') ;;
  06|6) datum_heute_lang=$(date '+%_d. Brachmonat (%b.) %Y'  | sed 's@^ *@@;') ;;
  07|7) datum_heute_lang=$(date '+%_d. Heumonat (%b.) %Y'    | sed 's@^ *@@;') ;;
  08|8) datum_heute_lang=$(date '+%_d. Erntemonat (%b.) %Y'  | sed 's@^ *@@;') ;;
  09|9) datum_heute_lang=$(date '+%_d. Herbstmonat (%b.) %Y' | sed 's@^ *@@;') ;;
    10) datum_heute_lang=$(date '+%_d. Weinmonat (%b.) %Y'   | sed 's@^ *@@;') ;;
    11) datum_heute_lang=$(date '+%_d. Nebelmonat (%b.) %Y'  | sed 's@^ *@@;') ;;
    12) datum_heute_lang=$(date '+%_d. Weihemonat (%b.) %Y'  | sed 's@^ *@@;') ;;
  esac
  ausgabe_bild_format="png"
  abbruch_code_nummer=0
  
  stufe_verausgaben=0
  stufe_fehler_abschlussarbeiten=1
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  # echo "jpeg" | sed "s@.@[\U\0\L\0]@g"
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_fehler_abschlussarbeiten=0; nutzung ;;
    --debug) set -x ;;
    -e | --Entwicklung) stufe_verausgaben=1 ;;
    --farb-frei) ANWEISUNG_FORMAT_FREI=1 ;;
    -[jJ] | --[Jj][Pp][Ee][Gg]) ausgabe_bild_format="jpeg"; ;;

    #-p | --param) # example named parameter
    #  param="${2-}"
    #  shift
    #  ;;
    -?*) meldung "Unbekannte Wahlmöglichkeit: $1 (bleibt unbeachtet, weiter …)" ;;
    *) break ;;
    esac
    shift
  done

  ARGUMENTE=("$@")
  [[ ${#ARGUMENTE[@]} -eq 0 ]] && meldung "${ROT}Fehlendes Wort oder Wortliste, die abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung
  if [[ "${ARGUMENTE[0]}" ]] ;then
    # my_string="Ubuntu;Linux Mint;Debian;Arch;Fedora"
    IFS=$';' # überschreibe for-Trenner → Zeilenumbruch oder ;
    read -ra WORTLISTEN_EINGABE <<< "${ARGUMENTE[0]}"
    unset IFS # alten for-Trenner zurück
    # meldung "${GRUEN}verarbeitetes erstes ARGUMENT: ${WORTLISTEN_EINGABE[*]} ${FORMAT_FREI}"
  elif [[ ${#ARGUMENTE[@]} -gt 1 ]];then
    meldung "${ORANGE}Wir vermuten, daß gegebene Argumente Wörter-Abfragen sein sollen. Wir versuchen sie bei DWDS einzeln abzufragen …${FORMAT_FREI}"
    IFS=$';' # überschreibe for-Trenner → Zeilenumbruch oder ;
    read -ra WORTLISTEN_EINGABE <<< "${ARGUMENTE[@]}"
    unset IFS # alten for-Trenner zurück
  else
    meldung_abbruch "${ROT}Argumente nicht verstanden: ${ARGUMENTE[@]} (Abbruch).${FORMAT_FREI}"  
  fi
  return 0
}

farben_bereitstellen
parameter_abarbeiten "$@"

# meldung "${ORANGE}DEBUG: Read parameters:${FORMAT_FREI}"
# meldung "${ORANGE}DEBUG: - listflag:  ${listflag}${FORMAT_FREI}"
# meldung "${ORANGE}DEBUG: - arguments: ${argumente[*]-}${FORMAT_FREI}"
# meldung "${ORANGE}DEBUG: - param:     ${param}${FORMAT_FREI}"
case $stufe_verausgaben in
 0)  ;;
 1)
  meldung  "${ORANGE}ENTWICKLUNG - datum_heute_lang:     ${datum_heute_lang} ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - WORTLISTEN_EINGABE:   ${WORTLISTEN_EINGABE[*]} ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - ausgabe_bild_format:  $ausgabe_bild_format ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_verausgaben:    $stufe_verausgaben ${FORMAT_FREI}"
  ;;
esac

# # # # # # # # # # # Programm Logik hier Anfang

# wort_abfrage="grundgütig"; 
# wort_abfrage="spintisieren"; 
# dwds_datei="${wort_abfrage}.svg";
# speicher_datei="${wort_abfrage}.svg.png";
# 
# wget --user-agent="Mozilla" --quiet --show-progress --output-document="${dwds_datei}" \
#   "https://www.dwds.de/r/plot/image/?v=hist&q=${wort_abfrage}" 
# 
# convert -density 300 "${dwds_datei}" \
#  -bordercolor '#0084C0' \
#  -border 5 \
#  -gravity South \
#  -splice 0x55 \
#  -gravity southwest \
#  -font 'Liberation-Serif' \
#  -annotate +10+0 "${wort_abfrage} (Wortverlaufskurve dwds.de)"  "${speicher_datei}"

for wort_abfrage in "${WORTLISTEN_EINGABE[@]}"
do
  wort_abfrage=$( echo "${wort_abfrage}" | xargs ) # Leerzeichen entfernen
  if [[ "${wort_abfrage}" == "" ]];then
    meldung "Überspringen leere Worteingabe (${wort_abfrage}) …"  
    continue
  else
    # meldung "${GRUEN}Hole Wortverlaufskurve für „${wort_abfrage}“ …${FORMAT_FREI}"  
    dwds_datei="${wort_abfrage} - Wortverlaufskurve DWDS.svg";
    case $ausgabe_bild_format in 
      [Pp][Nn][Gg]) speicher_datei="${dwds_datei}.png"; ;;
      [Jj][Pp][Gg]|[Jj][Pp][Ee][Gg]) speicher_datei="${dwds_datei}.jpg"; ;;
      *) speicher_datei="${dwds_datei}.png"; ;;
    esac

    wget --user-agent="Mozilla" --quiet --show-progress \
       --output-document="${dwds_datei}" \
      "https://www.dwds.de/r/plot/image/?v=hist&q=${wort_abfrage}" 

    if [[ ${#wort_abfrage} -gt 14 ]];then
      y_splice=110; text_beschriftung="${wort_abfrage}\n(Wortverlaufskurve dwds.de)";
    else
      y_splice=55; text_beschriftung="${wort_abfrage} (Wortverlaufskurve dwds.de)"
    fi
      
    convert -density 300 "${dwds_datei}" \
    -bordercolor '#0084C0' \
    -border 5 \
    -gravity South \
    -splice 0x${y_splice} \
    -gravity southwest \
    -font 'Liberation-Serif' \
    -annotate +10+0 "${text_beschriftung}"  "${speicher_datei}";
    
    rm "${dwds_datei}";
  fi
done

# Programm Logik hier Ende
