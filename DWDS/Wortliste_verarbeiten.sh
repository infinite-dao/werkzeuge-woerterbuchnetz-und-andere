#!/bin/bash
farben_bereitstellen() {
  # file descriptor [[ -t 2 ]] : 0 → stdin / 1 → stdout / 2 → stderr
  if [[ -t 2 ]] && [[ -z "${ANWEISUNG_FORMAT_FREI-}" ]] && [[ "${ANWEISUNG_FORMAT-}" != "stumm" ]]; then
    FORMAT_FREI='\033[0m' ROT='\033[0;31m' GRUEN='\033[0;32m' ORANGE='\033[0;33m' BLAU='\033[0;34m' VEILCHENROT='\033[0;35m' HIMMELBLAU='\033[0;36m' GELB='\033[1;33m'
  else
    FORMAT_FREI='' ROT='' GRUEN='' ORANGE='' BLAU='' VEILCHENROT='' HIMMELBLAU='' GELB=''
  fi
}
farben_bereitstellen

meldung() {
  echo >&2 -e "${1-}"
}

meldung_abbruch() {
  local meldung=$1
  local code=${2-1} # default exit status 1
  meldung "$meldung"
  exit "$code"
}

abhaengigkeiten_pruefen() {
  local stufe_abbruch=0

  if ! [[ -x "$(command -v wget)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} wget ${ORANGE} zum Abspeichern von Netzdateien nicht gefunden: Bitte${FORMAT_FREI} wget ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
#   if ! [[ -x "$(command -v inkscape)" ]]; then
#     printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} inkscape ${ORANGE}nicht gefunden: Bitte Inkscape über die Programm-Verwaltung installieren, zur Umwandlung SVG → PDF.${FORMAT_FREI}\n"; stufe_abbruch=1;
#   fi
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
  fi
  if ! [[ -x "$(command -v sed)" ]]; then
    printf "${ORANGE}Befehlswerkzeug${FORMAT_FREI} sed ${ORANGE}nicht gefunden: Bitte über die Programm-Verwaltung installieren (Verwendung: Zeichenketten suchen und ersetzen).${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}
abhaengigkeiten_pruefen

nutzung_und_ende() {
  local diese_nutzung=''

# ZUTUN
#   -b,   --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden

  diese_nutzung=$( cat <<NUTZUNG
Nutzung:
  ./$(basename "${BASH_SOURCE[0]}") "Wortliste_verschwindend_seit_1600.txt"

Wortverlaufskurven aus einer Wortliste erstellen und als PDF abspeichern.
Es wird versucht eine Zusammenfassung aller Wortkurven zu erstellen.

Verwendbare Wahlmöglichkeiten:
-h,   --Hilfe             Hilfetext dieses Programms ausgeben.
      --seit_1946         Verlaufskurfe aus dem Wortkorpus „Zeitungen seit 1945/46“ erstellen

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


beiwerte_abarbeiten() {
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
  stufe_fehler_abschlussarbeiten=1
  stufe_seit_1946_suchen=0
  abgefragte_zusatz_woerter=""
  datei_wortliste="Wortliste.txt"
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  # echo "jpeg" | sed "s@.@[\U\0\L\0]@g"
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_fehler_abschlussarbeiten=0; nutzung_und_ende ;;
    --debug) set -x ;;
    -b | --behalte_[Dd]ateien) stufe_dateienbehalten=1 ;;
    -e | --Entwicklung) stufe_verausgaben=1 ;;
    --seit_194[56]) stufe_seit_1946_suchen=1 ;;
    --farb-frei) ANWEISUNG_FORMAT_FREI=1 ;;
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
  if [[ ${#ARGUMENTE[@]} -eq 0 ]]; then
    if ! [[ -e "${datei_wortliste}" ]]; then
    meldung "${ORANGE}Fehlende Dateivorgabe ${FORMAT_FREI}${datei_wortliste}${ORANGE}, die abgefragt werden soll (Abbruch).${FORMAT_FREI}" 
    nutzung_und_ende
    fi
  elif [[ "${ARGUMENTE[0]}" ]] ;then
    datei_wortliste="${ARGUMENTE[0]}"
    if ! [[ -e "${datei_wortliste}" ]]; then
    meldung "${ORANGE}Angegebene Datei ${FORMAT_FREI}${datei_wortliste}${ORANGE} konnte nicht gefunden werden (Abbruch).${FORMAT_FREI}" 
    nutzung_und_ende
    fi  
  elif [[ ${#ARGUMENTE[@]} -gt 1 ]];then
    datei_wortliste="${ARGUMENTE[-1]}"
    if ! [[ -e "${datei_wortliste}" ]]; then
    meldung "${ORANGE}Es wurden viele Argumente beigegeben, das letzte als die angegebene Datei ${FORMAT_FREI}${datei_wortliste}${ORANGE} konnte nicht gefunden werden (Abbruch).${FORMAT_FREI}" 
    nutzung_und_ende
    fi  
  fi
  return 0
}

farben_bereitstellen
beiwerte_abarbeiten "$@"

IFS=$'\n'
for diese_zeile_ohne_suchcode in $( \
  grep --ignore-case --invert-match '[)]' "${datei_wortliste}" \
  | grep --ignore-case --extended-regexp '^[-—*]\s+\w+' \
  | sort );do
  # meldung "$diese_zeile_ohne_suchcode"
  dieses_wort_einzeln=$( echo "${diese_zeile_ohne_suchcode}" \
    | sed --regexp-extended "
      s@^[-—*]\s+(\w+.*)\$@\1@; 
      s@^\s*@@; s@\s*\$@@;
      s@\s*[(][^()]+[)]\s*@@;
      "  )
  meldung "${GRUEN}Verarbeite${FORMAT_FREI} ${dieses_wort_einzeln} …";
  if [[ ${stufe_seit_1946_suchen} -gt 0 ]];then
    Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --belasse_alte_Verlaufskurve --seit_1946 "${dieses_wort_einzeln}"
  else
    Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --belasse_alte_Verlaufskurve "${dieses_wort_einzeln}"
  fi
done
unset IFS

IFS=$'\n'
for diese_zeile_mit_suchcode in $( \
  grep --ignore-case '[)]' "${datei_wortliste}" \
  | grep --ignore-case --extended-regexp '^[-—*]\s+\w+' \
  | sort \
  );do
  dieses_wort_mit_suchcode=$( echo "${diese_zeile_mit_suchcode}" \
    | sed --regexp-extended "
      s@^[-—*][[:blank:]]+(\w+.*)\$@\1@;
      s@[(].*@@;
      s@^[[:blank:]]*@@; s@[[:blank:]]*\$@@;
      "  )
  dieser_suchcode=$( echo "${diese_zeile_mit_suchcode}" | \
    sed --silent --regexp-extended "
    /\w+[[:blank:]]*,[[:blank:]]*\w+/{
      s@^[-—*][[:blank:]]+(\w+)\b[[:blank:]]+\(([^()]+)\).*\$@\2@; 
      s@^[[:blank:]]+@@; s@[[:blank:]]+\$@@; 
      s@^@{'@; 
      s@\$@'}@; 
      s@[[:blank:]]*,[[:blank:]]*@','@g;
      s@[[:blank:]]*@@g;
      p;
    }
  " );
  meldung "${GRUEN}Verarbeite${FORMAT_FREI} ${dieses_wort_mit_suchcode} mit Suchcode ${dieser_suchcode} …";
  if [[ ${stufe_seit_1946_suchen} -gt 0 ]];then
    
    Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --belasse_alte_Verlaufskurve \
    --Suchcode "${dieser_suchcode}" --seit_1946 "${dieses_wort_mit_suchcode}"
  else
    Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --belasse_alte_Verlaufskurve \
    --Suchcode "${dieser_suchcode}" "${dieses_wort_mit_suchcode}"
  fi

done
unset IFS
if [[ ${stufe_seit_1946_suchen} -gt 0 ]];then
meldung "${GRUEN}Erstelle Zusammenfassung für Zeitungskorpus ${FORMAT_FREI}"
  if ! [[ -e  Zusammenfassung-neu-erstellen_pdfs_seit_1946.sh ]]; then
    printf "${ORANGE}Programm${FORMAT_FREI} Zusammenfassung-neu-erstellen_pdfs_seit_1946.sh ${ORANGE}nicht gefunden, kann keine Zusammenfassung erstellen.${FORMAT_FREI}\n";
  else
    ./Zusammenfassung-neu-erstellen_pdfs_seit_1946.sh
  fi
else
meldung "${GRUEN}Erstelle Zusammenfassung für Korpus DWDS + DTA ${FORMAT_FREI}"
  if ! [[ -e Zusammenfassung-neu-erstellen_pdfs_seit_1600.sh ]]; then
    printf "${ORANGE}Programm${FORMAT_FREI} Zusammenfassung-neu-erstellen_pdfs_seit_1600.sh ${ORANGE}nicht gefunden, kann keine Zusammenfassung erstellen.${FORMAT_FREI}\n";
  else
    ./Zusammenfassung-neu-erstellen_pdfs_seit_1600.sh
  fi
fi

case $stufe_dateienbehalten in [1-9])
  meldung "${ORANGE}Warnung: die Wahl --behalte_Dateien ist noch nicht eingebaut, damit es dennoch funktioniert, kann man derzeit nur in den Vorschriften Zusammenfassung-neu-erstellen….sh den Wandelwert dort händisch auf \$stufe_aufraeumen_aufhalten=1 setzen." ;;
esac

meldung "${GRUEN}Ende${FORMAT_FREI}"


