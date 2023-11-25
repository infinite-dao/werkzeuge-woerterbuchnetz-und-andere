#!/usr/bin/env bash
# Programm zum Abfragen der Wortverlaufskurven des Digitalen Wörterbuchs Deutscher Sprache (DWDS) 
# Abhängigkeit: magick von ImageMagick zur Bildverarbeitung
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
  if ! [[ -x "$(command -v magick)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} magick ${ORANGE}nicht gefunden: Bitte magick (von ImageMagick) über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
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
-h,   --Hilfe             Hilfetext dieses Programms ausgeben.
-j,   --JPEG              Bild als JPEG ausgeben anstatt PNG.
      --Suchcode          Suchencode, der tatsächlich abgefragt wird, z.B. "{'behände','behende','behänd','behend'}"
                           Falls mehrere Wortabfragen, dann Trennung durch Strichpünktlein ; (Semikolon)
      --seit_1946         Verlaufskurfe aus dem Wortkorpus „Zeitungen seit 1945/46“ erstellen
-b,   --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-e,   --Entwicklung       Zusatz-Meldungen zur Entwicklung ausgeben
      --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
      --farb-frei         Meldungen ohne Farben ausgeben

Technische Anmerkungen:

- abhängig von Befehl ${BLAU}wget${FORMAT_FREI} (Anfragen ins Netz)
- abhängig von Befehl ${BLAU}magick${FORMAT_FREI} (Bildverarbeitung)

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
    if [[ $(ls -A *DWDS-Wortverlauf*.svg* 2>/dev/null | head -c1 | wc -c) -gt 0 ]];then
      echo -e "${GRUEN}Ende: Siehe Wortverlaufskurve(n) … ${FORMAT_FREI}"
      ls -lA *DWDS-Wortverlauf*.svg* | grep --color=always --context=3 "${speicher_datei}"
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
  01|1) datum_heute_lang=$(date '+%_d. im Wintermonat (%B) %Y' | sed 's@^ *@@; s@Januar@& ~ röm. Gott Janus@;') ;;
  02|2) datum_heute_lang=$(date '+%_d. im Hornung (%B) %Y'     | sed 's@^ *@@; s@Februar@& ~ lat.: februare „reinigen"@; ') ;;
  03|3) datum_heute_lang=$(date '+%_d. im Lenzmonat (%B) %Y'   | sed 's@^ *@@; s@März@& ~ röm. Gott Mars@; ') ;;
  04|4) datum_heute_lang=$(date '+%_d. im Ostermonat (%B) %Y'  | sed 's@^ *@@; s@April@& ~ lat.: Aprilis@;') ;;
  05|5) datum_heute_lang=$(date '+%_d. im Wonnemonat (%B) %Y'  | sed 's@^ *@@; s@Mai@& ~ röm. Maius o. Göttin Maia@;') ;;
  06|6) datum_heute_lang=$(date '+%_d. im Brachmonat (%B) %Y'  | sed 's@^ *@@; s@Juni@& ~ röm. Göttin Juno@; ') ;;
  07|7) datum_heute_lang=$(date '+%_d. im Heumonat (%B) %Y'    | sed 's@^ *@@; s@Juli@& ~ röm. Julius (Caesar)@; ') ;;
  08|8) datum_heute_lang=$(date '+%_d. im Erntemonat (%B) %Y'  | sed 's@^ *@@; s@August@& ~ röm. Kaiser Augustus@; ') ;;
  09|9) datum_heute_lang=$(date '+%_d. im Herbstmonat (%B) %Y' | sed 's@^ *@@; s@September@& ~ lat.: Septimus, 7@; ') ;;
    10) datum_heute_lang=$(date '+%_d. im Weinmonat (%B) %Y'   | sed 's@^ *@@; s@Oktober@& ~ lat.: Octavus, 8@; ') ;;
    11) datum_heute_lang=$(date '+%_d. im Nebelmonat (%B) %Y'  | sed 's@^ *@@; s@November@& ~ lat.: Nonus, 9@; ') ;;
    12) datum_heute_lang=$(date '+%_d. im Weihemonat (%B) %Y'  | sed 's@^ *@@; s@Dezember@& ~ lat.: Decimus, 10@; ') ;;
  esac
  ausgabe_bild_format="png"
  abbruch_code_nummer=0
  stufe_dateienbehalten=0
  stufe_verausgaben=0
  stufe_seit_1946_suchen=0
  stufe_fehler_abschlussarbeiten=1
  suchcodeliste=""
  abgefragte_zusatz_woerter=""
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  # echo "jpeg" | sed "s@.@[\U\0\L\0]@g"
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_fehler_abschlussarbeiten=0; nutzung ;;
    --debug) set -x ;;
    -b | --behalte_[Dd]ateien) stufe_dateienbehalten=1 ;;
    -e | --Entwicklung) stufe_verausgaben=1 ;;
    --farb-frei) ANWEISUNG_FORMAT_FREI=1 ;;
    -[jJ] | --[Jj][Pp][Ee][Gg]) ausgabe_bild_format="jpeg"; ;;
    -[sS] | --[Ss][Vv][Gg])     ausgabe_bild_format="svg"; ;;
    --seit_194[56]) stufe_seit_1946_suchen=1 ;;
    --Suchcode) suchcodeliste="${2-}"; shift; ;;
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
  if [[ ${#suchcodeliste} -gt 0 ]];then  
    IFS=$';' # überschreibe for-Trenner → Zeilenumbruch oder ;
    read -a SUCHCODELISTE <<< "${suchcodeliste}"
    unset IFS # alten for-Trenner zurück
  else
    SUCHCODELISTE=()
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
  meldung  "${ORANGE}ENTWICKLUNG - SUCHCODELISTE:        ${SUCHCODELISTE[*]} ${FORMAT_FREI}"
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

# for wort_abfrage in "${WORTLISTEN_EINGABE[@]}"
n_woerter=${#WORTLISTEN_EINGABE[@]}
i_wort=1

for wort_index in "${!WORTLISTEN_EINGABE[@]}"
do
  if [[ $n_woerter -gt 1 ]];then
  meldung "${i_wort} von ${n_woerter} Wörtern abfragen …"
  fi
  wort_abfrage=$( echo "${WORTLISTEN_EINGABE[$wort_index]}" | xargs ) # Leerzeichen entfernen
  hat_such_code_abfrage=$([ ${#SUCHCODELISTE[$wort_index]} -gt 0 ] && echo 1 || echo 0 )
  
  if [[ ${hat_such_code_abfrage} -gt 0  ]];then
    abfrage_code=$( echo "${SUCHCODELISTE[$wort_index]}" | xargs ) # Leerzeichen entfernen
  else
    abfrage_code=$wort_abfrage
  fi
  if [[ "${wort_abfrage}" == "" ]];then
    meldung "Überspringen leere Worteingabe (${wort_abfrage}) …"  
    continue
  else
    # meldung "${GRUEN}Hole Wortverlaufskurve für „${wort_abfrage}“ …${FORMAT_FREI}"
  
    if [[ ${hat_such_code_abfrage} -gt 0 ]]; then
      abgefragte_zusatz_woerter=$( echo "$abfrage_code" | sed --regexp-extended  "y@{}@()@; s@' *, *'@, @g; s@[']@@g; s@^@ @" )
    fi
    if [[ $stufe_seit_1946_suchen -gt 0 ]];then
    dwds_datei="${wort_abfrage}${abgefragte_zusatz_woerter} - DWDS-Wortverlauf seit 1946 (Zeitungen).svg";
    else
    dwds_datei="${wort_abfrage}${abgefragte_zusatz_woerter} - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg";
    fi
    case $ausgabe_bild_format in 
      [Pp][Nn][Gg]) speicher_datei="${dwds_datei}.png"; ;;
      [Jj][Pp][Gg]|[Jj][Pp][Ee][Gg]) speicher_datei="${dwds_datei}.jpg"; ;;
      *) speicher_datei="${dwds_datei}.png"; ;;
    esac

    if [[ $stufe_seit_1946_suchen -gt 0 ]];then
      wget --user-agent="Mozilla" --quiet --show-progress \
        --output-document="${dwds_datei}" \
        "https://www.dwds.de/r/plot/image/?v=pres&q=${abfrage_code}" 
    else
      wget --user-agent="Mozilla" --quiet --show-progress \
        --output-document="${dwds_datei}" \
        "https://www.dwds.de/r/plot/image/?v=hist&q=${abfrage_code}" 
    fi
    if [[ $stufe_seit_1946_suchen -gt 0 ]];then
      text_beschriftung="${wort_abfrage} (Wortverlauf dwds.de: Zeitungen 1946…)";
    else
      text_beschriftung="${wort_abfrage} (Wortverlauf dwds.de: DTA+DWDS)"
    fi
    if [[ ${#abgefragte_zusatz_woerter} -gt 0 ]];then
      text_beschriftung="${text_beschriftung}\n${abgefragte_zusatz_woerter//,/+}"
    fi    
    magick \
      -density 300 \
      "${dwds_datei}" \
      -size %wx \
    -bordercolor '#0084C0' \
    -border 5 \
    -font 'Liberation-Serif' \
    -pointsize 10 \
      caption:"$text_beschriftung" \
          -gravity southwest -append \
    "${speicher_datei}";
    
    if [[ ${stufe_dateienbehalten:-0} -eq 0 ]];then
      case ${stufe_verausgaben:-0} in
      0)  ;;
      1) meldung "${ORANGE}Entferne${FORMAT_FREI} ${dwds_datei}" ;;
      esac
      rm "${dwds_datei}";
    else
      case ${stufe_verausgaben:-0} in
      0)  ;;
      1) meldung "${ORANGE}Behalte${FORMAT_FREI} ${dwds_datei}" ;;
      esac
    fi    
    i_wort=$(( i_wort + 1 ))
  fi
done

# Programm Logik hier Ende

# inkscape --file="gleichviel - DWDS-Wortverlauf seit 1946 (Zeitungen).svg" --without-gui --export-pdf="gleichviel - DWDS-Wortverlauf seit 1946 (Zeitungen).svg.pdf"

# 
# # inkscape --export-filename="gleichviel - DWDS-Wortverlauf seit 1946 (Zeitungen).svg.pdf" \
# #   "gleichviel - DWDS-Wortverlauf seit 1946 (Zeitungen).svg" 
# --export-filename=
