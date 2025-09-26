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
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} wget ${ORANGE} zum Abspeichern von Netzdateien nicht gefunden: Bitte${FORMAT_FREI} wget ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v inkscape)" ]]; then
    # flatpak list | grep --ignore-case --only-matching 'org.[^ ]*inkscape'
    if  [[ -x "$(command -v flatpak)" ]]; then
      if [[ -z "$(command flatpak list | grep --ignore-case --only-matching 'org.[^ ]*inkscape')" ]]; then
        printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} inkscape ${ORANGE}auch nicht in flatpak gefunden: Bitte Inkscape über die Programm-Verwaltung installieren, zur Umwandlung SVG → PDF.${FORMAT_FREI}\n"; stufe_abbruch=1;
      # else
      #   # flatpak und Inkscape gefunden
      fi
    else
      printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} inkscape ${ORANGE}nicht gefunden (auch nicht als flatpak): Bitte Inkscape über die Programm-Verwaltung installieren, zur Umwandlung SVG → PDF.${FORMAT_FREI}\n"; stufe_abbruch=1;
    fi
  fi

  if ! [[ -x "$(command -v gs)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} gs ${ORANGE}nicht gefunden: Bitte Ghostscript über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v ps2pdf)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} ps2pdf ${ORANGE}nicht gefunden: Bitte Ghostscript über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v pdftk)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} pdftk ${ORANGE}nicht gefunden: Bitte pdftk über die Programm-Verwaltung installieren oder vom Netz: https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v enscript)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} enscript ${ORANGE}nicht gefunden: Bitte über die Programm-Verwaltung installieren (Verwendung: Texte oder Textdateien in PostScript, HTML, u.a. umwandeln).${FORMAT_FREI}\n"; stufe_abbruch=1;
    # enscript --list-media
    #   bekannte Medien:
    #   Name             Weite  H?he    llx     lly     urx     ury
    #   ------------------------------------------------------------
    #   Letterdj         612    792     18      40      594     756
    #   A4dj             595    842     18      50      577     806
    #   EnvMonarch       279    540     18      36      261     504
    #   EnvDL            312    624     18      36      294     588
    #   EnvC5            459    649     18      36      441     613
    #   Env10            297    684     18      36      279     648
    #   EnvISOB5         499    709     18      36      463     673
    #   B5               516    729     18      36      498     693
    #   A5               421    595     18      36      403     559
    #   A4               595    842     18      36      577     806
    #   A3               842    1191    18      36      824     1155
    #
    # cat ~/.enscriptrc # Media: A6 nachträglich hinzugefügt
    #   Media: A6 298 421 18 36 280 385

  fi
  if ! [[ -x "$(command -v sed)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} sed ${ORANGE}nicht gefunden: Bitte über die Programm-Verwaltung installieren (Verwendung: Zeichenketten suchen und ersetzen).${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}

nutzung() {
  local diese_nutzung=''

  diese_nutzung=$( cat <<NUTZUNG
Nutzung:
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] "Wort"
  ./$(basename "${BASH_SOURCE[0]}") "Wort1; Wort2; Wort3"

Wortverlaufskurve eines gegebenen Worts beschriften und als PDF abspeichern.

Verwendbare Wahlmöglichkeiten:
-h,   --Hilfe             Hilfetext dieses Programms ausgeben.
      --Suchcode          Suchencode, der tatsächlich abgefragt wird, z.B. "{'behände','behende','behänd','behend'}"
                          Falls mehrere Wortabfragen, dann Trennung durch Strichpünktlein ; (Semikolon)
      --seit_1946         Verlaufskurfe aus dem Wortkorpus „Zeitungen seit 1945/46“ erstellen
-b,   --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-e,   --Entwicklung       Zusatz-Meldungen zur Entwicklung ausgeben
      --debug             Befehlsmeldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
      --farb-frei         Meldungen ohne Farben ausgeben

Technische Anmerkungen:

- abhängig von Befehl ${BLAU}wget${FORMAT_FREI} (Anfragen ins Netz)
- abhängig von Befehl ${BLAU}inkscape${FORMAT_FREI} (SVG → PDF Umwandlung)
- abhängig von Befehl ${BLAU}gs${FORMAT_FREI} (Ghostscript, PDF Verarbeitung)
- abhängig von Befehl ${BLAU}ps2pdf${FORMAT_FREI} (Ghostscript, PDF Verarbeitung)
- abhängig von Befehl ${BLAU}pdftk${FORMAT_FREI} (PDF Überlagerung)
- abhängig von Befehl ${BLAU}enscript${FORMAT_FREI} (Text in PDF verwandeln)

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
      datei_als_regex=$( echo "${speicher_datei}" | sed --regexp-extended ' s@([()])@\\\1@g; ' )

      # echo -e "${GRUEN}Ende: $datei_als_regex … ${FORMAT_FREI}"
      # ls -lA *DWDS-Wortverlauf*.svg* | grep --color=always --context=3 "^${datei_als_regex}"
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
  abbruch_code_nummer=0
  stufe_dateienbehalten=0
  stufe_verausgaben=0
  stufe_seit_1946_suchen=0
  stufe_fehler_abschlussarbeiten=1
  stufe_belasse_alte_verlaufskurve=0
  suchcodeliste=""
  abgefragte_zusatz_woerter=""
  inkscape_befehl=""
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  # echo "jpeg" | sed "s@.@[\U\0\L\0]@g"
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_fehler_abschlussarbeiten=0; nutzung ;;
    --debug) set -x ;;
    -b | --behalte_[Dd]ateien) stufe_dateienbehalten=1 ;;
    --belasse_alte_Verlaufskurve) stufe_belasse_alte_verlaufskurve=1 ;;
    -e | --Entwicklung) stufe_verausgaben=1 ;;
    --farb-frei) ANWEISUNG_FORMAT_FREI=1 ;;
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

  if [[ -x "$(command -v inkscape)" ]]; then
    inkscape_befehl='inkscape';
  else
    # flatpak list | grep --ignore-case --only-matching 'org.[^ ]*inkscape'
    # if  [[ -x "$(command -v flatpak)" ]]; then
    #   echo "ja flatpak kann befehligt werden";
    #   befehls_angabe_inkscape_fuer_flatpak="$(command flatpak list | grep --ignore-case --only-matching 'org.[^ ]*inkscape')";
    #   if  [[ -z "${befehls_angabe_inkscape_fuer_flatpak}" ]]; then
    #     echo "inkscape nicht befehligbar über flatpak";
    #   else
    #     inkscape_befehl="flatpak run ${befehls_angabe_inkscape_fuer_flatpak}"
    #     echo "ja inkscape kann befehligt werden über: ${inkscape_befehl}";
    #   fi
    # else
    #   echo "flatpak nicht befehligbar";
    # fi
    if  [[ -x "$(command -v flatpak)" ]]; then
      # echo "ja flatpak kann befehligt werden";
      befehls_angabe_inkscape_fuer_flatpak="$(command flatpak list | grep --ignore-case --only-matching 'org.[^ ]*inkscape')";
      if  [[ -z "${befehls_angabe_inkscape_fuer_flatpak}" ]]; then
        # echo "inkscape nicht befehligbar über flatpak";
        meldung_abbruch "${ROT}Inkscape in flatpak nicht gefunden (Abbruch).${FORMAT_FREI}"
      else
        inkscape_befehl="flatpak run ${befehls_angabe_inkscape_fuer_flatpak}"
        # echo "ja inkscape kann befehligt werden über: ${inkscape_befehl}";
      fi
    else
      meldung_abbruch "${ROT}Inkscape nicht gefunden, auch nicht als flatpak (Abbruch).${FORMAT_FREI}"
    fi
  fi # if inkscape_befehl


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
    
    speicher_datei="${dwds_datei}.pdf";
    zwischenspeicher_datei_1="${dwds_datei}.inkscape.pdf"; # inkscape Ausgabe
    zwischenspeicher_datei_2="${dwds_datei}.mit-Rand.pdf"; # mit Rand

    if [[ ${stufe_belasse_alte_verlaufskurve} -gt 0 ]];then    
      if [[ -e "${speicher_datei}" ]];then
      meldung "${GRUEN}Belasse alte vorhandene Datei${FORMAT_FREI} ${speicher_datei} …"
      continue
      fi
    fi
    
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
      text_beschriftung=$( echo -e "${text_beschriftung}\n${abgefragte_zusatz_woerter//,/+}" )
    fi    
    
    $inkscape_befehl --export-filename="${zwischenspeicher_datei_1}" "${dwds_datei}"
    # pdftk datei.pdf dump_data → z.B. PageMediaDimensions: 225 155
    ursprungs_breite_hoehe_punkte=$( pdftk "${zwischenspeicher_datei_1}" dump_data \
      | sed --silent --regexp-extended "/PageMediaDimensions:/ { s@PageMediaDimensions: *([0-9]+) ([0-9]+)@\1×\2@p }" )
    ursprungs_breite_punkte=$( echo "${ursprungs_breite_hoehe_punkte%×*}" )
    ursprungs_hoehe_punkte=$( echo "${ursprungs_breite_hoehe_punkte##*×}" )
    randzusatz_punkte=20

    # Diagramm-PDF+Unterrand hinzufügen && Text-PDF schreiben && Text-PDF + Diagramm-PDF überlagern und abspeichern
     gs -q -sDEVICE=pdfwrite -dBATCH -dNOPAUSE \
          -sOutputFile="${zwischenspeicher_datei_2}" \
          -dDEVICEWIDTHPOINTS="${ursprungs_breite_punkte}" \
          -dDEVICEHEIGHTPOINTS="$(( ursprungs_hoehe_punkte + randzusatz_punkte ))" \
          -dFIXEDMEDIA -c \
          "<< /CurrPageNum 1 def /Install {0 $randzusatz_punkte translate} bind  >> setpagedevice" \
          -f "${zwischenspeicher_datei_1}" \
      && echo "${text_beschriftung}" | \
        enscript --no-header --media='A6' --landscape --word-wrap --font="Times-Roman18" \
        --margins=250:0:0:0 -o- | \
        ps2pdf - | \
        pdftk "${zwischenspeicher_datei_2}" stamp - output "${speicher_datei}"
        # enscript --no-header --media='A6 298 421 18 36 280 385' --landscape --word-wrap --font="Times-Roman18" \
    
    if [[ ${stufe_dateienbehalten:-0} -eq 0 ]];then
      case ${stufe_verausgaben:-0} in
      0)  ;;
      1) meldung "${ORANGE}Entferne${FORMAT_FREI} ${dwds_datei}, ${zwischenspeicher_datei_1}, ${zwischenspeicher_datei_2}" ;;
      esac
      rm "${dwds_datei}";
      if [[ -e "${zwischenspeicher_datei_1}" ]];then rm "${zwischenspeicher_datei_1}"; fi
      if [[ -e "${zwischenspeicher_datei_2}" ]];then rm "${zwischenspeicher_datei_2}"; fi
    else
      case ${stufe_verausgaben:-0} in
      0)  ;;
      1) meldung "${ORANGE}Behalte${FORMAT_FREI} ${dwds_datei}, ${zwischenspeicher_datei_1}, ${zwischenspeicher_datei_2}" ;;
      esac
    fi    
    i_wort=$(( i_wort + 1 ))
  fi
done

# Programm Logik hier Ende
