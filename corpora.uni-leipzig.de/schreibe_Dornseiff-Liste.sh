#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

abhaengigkeiten_pruefen() {
  local stufe_abbruch=0

  if ! [[ -x "$(command -v pandoc)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} pandoc ${ORANGE} zum Erstellen von Dokumenten in HTML, ODT, MD nicht gefunden: Bitte${FORMAT_FREI} pandoc ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v sed)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} sed ${ORANGE}nicht gefunden: Bitte sed über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  
  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}

nutzung() {

  local diese_nutzung=''
  diese_nutzung=$( cat <<NUTZUNG
Nutzung:
  ./$(basename "${BASH_SOURCE[0]}") [-H] -W "wohl Hilfe Not"

Die Dornseiff Bedeutungsgruppen von ${BLAU}corpora.uni-leipzig.de${FORMAT_FREI} abfragen und in einer 
Datei für Textverarbeitung (*.docx, *.odt) zusammenstellen. 

  Allgemein sind diese Gruppen von DORNSEIFF (1934: Der deutsche Wortschatz nach Sachgruppen) eingeteilt worden in: 
  1. Natur und Umwelt; 2. Leben; 3. Raum, Lage, Form; 4. Größe, Menge, Zahl; 
  5. Wesen, Beziehung, Geschehnis; 6. Zeit; 7. Sichtbarkeit, Licht, Farbe, Schall, 
    Temperatur, Gewicht, Aggregatzustände; 8. Ort und Ortsveränderung; 
  9. Wollen und Handeln; 10. Fühlen, Affekte, Charaktereigenschaften; 11. Das Denken; 
  12. Zeichen, Mitteilung, Sprache; 13. Wissenschaft; 14. Kunst und Kultur; 
  15. Menschliches Zusammenleben; 16. Essen und Trinken; 17. Sport und Freizeit; 
  18. Gesellschaft; 19. Geräte, Technik; 20. Wirtschaft, Finanzen; 21. Recht, Ethik; 
  22. Religion, Übersinnliches

Verwendbare Wahlmöglichkeiten:

  -W,    --Wortliste         eine Wortliste aus Einzelworten, z.B. "Hilfe Not" oder "Hilfe, Not"
  
  -A,    --Ablaufbericht     Befehlsvorschriften ausführlicher berichten, was es im Einzelnen ausführt
  -H,    --Hilfe             Hilfetext dieses Programms ausgeben
         --entwickeln        einzelne Befehlsausführungen ausgeben (zur Entwicklung der Befehlsvorschrift/Programmentwicklung)
         --farb-frei         Meldungen ohne Farben ausgeben

Technische Anmerkungen:

- diese Befehlsvorschrift überschreibt ${ORANGE}schon gemachte Abfragen ohne Warnhinweis${FORMAT_FREI}
- abhängig von Befehl ${BLAU}sed${FORMAT_FREI} (Textersetzungen)
- abhängig von Befehl ${BLAU}pandoc${FORMAT_FREI} (Umwandlung der Dateiformate)

NUTZUNG
)
  echo -e "${diese_nutzung}" # mit Farbausgabe 
  
  abhaengigkeiten_pruefen
  exit
}

aufraeumen() {
  trap - SIGINT SIGTERM ERR EXIT
  # aufzuräumendes für dieses Programm
  local diese_datei_liste=""
  case "${stufe_aufraeumen_aufhalten-}" in 0)
    null_zaehler=0
    case "${stufe_verausgaben-}" in 1) meldung "${GRUEN}Aufräumen: zwischengespeicherte Einzeldateien werden getilgt …${FORMAT_FREI}" ;; esac

    for wort in ${LISTE_WOERTER[@]}
    do
    einzelne_speicher_datei=$(html_speicher_datei_vom_wort "${wort}" ); 
      case "${stufe_verausgaben-}" in 1) meldung "${GRUEN}- tilge: ${BLAU}${einzelne_speicher_datei}${GRUEN} …${FORMAT_FREI}" ;; esac
      if [[ -f "${einzelne_speicher_datei}" ]];then rm "${einzelne_speicher_datei}"; fi
    done
    ;; 
  esac
  diese_datei_liste=$(find . -iname "${gesamt_datei_markdown-}" -or -iname "${gesamt_datei_docx-}" -or -iname "${gesamt_datei_odt-}" )
  if ! [[ -z "${diese_datei_liste-}" ]]; then 
    meldung "${GRUEN}Folgende Dateien sind übrig oder erstellt:${FORMAT_FREI}";
    ls -l $diese_datei_liste;
  fi
}

farben_bereitstellen() {
  # file descriptor [[ -t 2 ]] : 0 → stdin / 1 → stdout / 2 → stderr
  if [[ -t 2 ]] && [[ -z "${FARB_FREI-}" ]] && [[ "${AUSDRUCK-}" != "stumm" ]]; then
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

html_speicher_datei_vom_wort() {
  local dieses_wort="${*-unbekannt}"
  local diese_datei_vorsilbe=$(echo "$dieses_wort" | sed --regexp-extended 's@[[:punct:]]+@…@g; ')
  local diese_html_speicher_datei=$(printf "%s.dornseiff.html" "${diese_datei_vorsilbe}" )
  printf "${diese_html_speicher_datei}"
}

dateivariablen_bereitstellen() {
  gesamt_datei_markdown=$( printf "dornseiff.gesamt_%s.md" $(date '+%Y%m%d') )
  gesamt_datei_docx=$( printf "%s.docx" "$gesamt_datei_markdown" )
  gesamt_datei_odt=$( printf "%s.odt" "$gesamt_datei_markdown" )
}

parameter_abarbeiten() {
  # gesetzte Vorgabewerte
  stufe_verausgaben=0
  stufe_aufraeumen_aufhalten=1
  abbruch_code_nummer=0
  einzelne_speicher_datei="unbekannt.md"
  FARB_FREI=''
  LISTE_WOERTER=()
  null_zaehler=0
  LISTE_BEFEHL_ARGUMENTE=("$@")

  # param=''

  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -A | --Ablaufbericht) stufe_verausgaben=1 ;;
    --entwickeln) set -x ;;
    --farb-frei) FARB_FREI=1 ;;
    -[Hh] | --[Hh]ilfe) stufe_aufraeumen_aufhalten=1; nutzung ;;
    -W | --Wortliste)  # Parameter
      LISTE_WOERTER=($(echo "${2-}" | sed --regexp-extended "s@[, ]@\n@"))
      shift
      ;;
    #-p | --param) # example named parameter
    #  param="${2-}"
    #  shift
    #  ;;
    -?*) meldung_abbruch "Unbekannte Wahlmöglichkeit: $1 (Abbruch)" ;;
    *) break ;;
    esac
    shift
  done


  # check required params and arguments
  # [[ -z "${param-}" ]] && meldung_abbruch "Missing required parameter: param"
  # [[ ${#LISTE_BEFEHL_ARGUMENTE[@]} -eq 0 ]] && meldung "${ROT}Fehlendes Lemma, das abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung

  # meldung "ENTWICKLUNG: Befehlsargumente $LISTE_BEFEHL_ARGUMENTE, Anzahl: ${#LISTE_BEFEHL_ARGUMENTE[@]}"
  
  [[ "${#LISTE_BEFEHL_ARGUMENTE[@]}" -eq 0 ]] && meldung "${ROT}Fehlende Wortliste, die abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung
  
  [[ ${#LISTE_WOERTER[@]} -eq 0 ]] && meldung "${ROT}Wortliste leer, die abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung

  dateivariablen_bereitstellen
  
  stufe_aufraeumen_aufhalten=0

  return 0
}

farben_bereitstellen
parameter_abarbeiten "$@"

null_zaehler=0
for wort in ${LISTE_WOERTER[@]}
do  
  einzelne_speicher_datei=$(html_speicher_datei_vom_wort "${wort}" );
  case "${stufe_verausgaben-}" in 
  1) 
    meldung "${GRUEN}Befrage ${FORMAT_FREI}${wort}${GRUEN} an Netzseite ${BLAU}corpora.uni-leipzig.de/de/webservice${GRUEN} …${FORMAT_FREI}"
    meldung "${GRUEN}Erstelle aus HTML-Antwort eine ${BLAU}${einzelne_speicher_datei}.md${GRUEN} …${FORMAT_FREI}"
    wget --quiet --show-progress --random-wait --wait=1 "https://corpora.uni-leipzig.de/de/webservice/index?corpusId=deu_news_2021&action=loadWordSetBox&word=${wort}" -O "${einzelne_speicher_datei}" \
    && sed --in-place --regexp-extended " 
      s@<b>([0-9]+\.[0-9]+[^<>:]+)</b>@<b>\1:</b>@g; 
      s@(<[^<>]+>) *(Dornseiff-Bedeutungsgruppen) *(</[^<>]+>)@<h3>### ${wort}</h3>\n\1\2 von ${wort}:\3@;
      s@<a[^>]+href[^>]+javascript[^>]+> *(mehr|weniger) *</a>@@;
      " "${einzelne_speicher_datei}" \
    && pandoc --wrap=none --from=html --to=plain "${einzelne_speicher_datei}" \
      | sed --regexp-extended 's@  *@ @g; ' > "${einzelne_speicher_datei}.md"
  ;;
  *)
    wget --quiet --random-wait --wait=1 "https://corpora.uni-leipzig.de/de/webservice/index?corpusId=deu_news_2021&action=loadWordSetBox&word=${wort}" -O "${einzelne_speicher_datei}" \
    && sed --in-place --regexp-extended " 
      s@<b>([0-9]+\.[0-9]+[^<>:]+)</b>@<b>\1:</b>@g; 
      s@(<[^<>]+>) *(Dornseiff-Bedeutungsgruppen) *(</[^<>]+>)@<h3>### ${wort}</h3>\n\1\2 von ${wort}:\3@;
      s@<a[^>]+href[^>]+javascript[^>]+> *(mehr|weniger) *</a>@@;
      " "${einzelne_speicher_datei}" \
    && pandoc --wrap=none --from=html --to=plain "${einzelne_speicher_datei}" \
      | sed --regexp-extended 's@  *@ @g; ' > "${einzelne_speicher_datei}.md"
  ;;
  esac # stufe_verausgaben
  
  if [[ $(  cat "${einzelne_speicher_datei}.md" | tr -d '\n' | wc -l ) -eq 0 ]];then
    echo -e "### ${wort}\nKeine Dornseiff-Bedeutungsgruppen für *${wort}* gefunden." >> "${einzelne_speicher_datei}.md"
  fi

  case $null_zaehler in 
  0) cat "${einzelne_speicher_datei}.md" | sed --regexp-extended 's@^(- +)([0-9]+\.[0-9]+[^:]+):@\1**\2**:@g; ' > "${gesamt_datei_markdown}" ;;
  *) cat "${einzelne_speicher_datei}.md" | sed --regexp-extended '1 { s@^@\n@; }; s@^(- +)([0-9]+\.[0-9]+[^:]+):@\1**\2**:@g; ' >> "${gesamt_datei_markdown}" ;;
  esac
  null_zaehler=$(expr $null_zaehler + 1);
  if [[ $null_zaehler -eq ${#LISTE_WOERTER[@]} ]];then 
    case "${stufe_verausgaben-}" in 
    1) meldung "${GRUEN}Alles zusammenfügen in ${FORMAT_FREI}${gesamt_datei_docx}${GRUEN}, ${FORMAT_FREI}${gesamt_datei_odt}${GRUEN} … ${FORMAT_FREI}" ;;
    esac
    pandoc --from=markdown --to=docx "${gesamt_datei_markdown}" > "${gesamt_datei_docx}"
    pandoc --from=markdown --to=odt "${gesamt_datei_markdown}" > "${gesamt_datei_odt}"
  fi
done
