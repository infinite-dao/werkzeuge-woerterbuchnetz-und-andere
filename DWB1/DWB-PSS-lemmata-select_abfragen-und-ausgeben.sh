#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

case $(date '+%m') in 
01|1) datum_heute_lang=$(date '+%_d. Wintermonat (%B) %Y' | sed 's@^ *@@;');;
02|2) datum_heute_lang=$(date '+%_d. Hornung (%B) %Y'     | sed 's@^ *@@;') ;;
03|3) datum_heute_lang=$(date '+%_d. Lenzmonat (%B) %Y'   | sed 's@^ *@@;') ;;
04|4) datum_heute_lang=$(date '+%_d. Ostermonat (%B) %Y'  | sed 's@^ *@@;') ;;
05|5) datum_heute_lang=$(date '+%_d. Wonnemonat (%B) %Y'  | sed 's@^ *@@;') ;;
06|6) datum_heute_lang=$(date '+%_d. Brachmonat (%B) %Y'  | sed 's@^ *@@;') ;;
07|7) datum_heute_lang=$(date '+%_d. Heumonat (%B) %Y'    | sed 's@^ *@@;') ;;
08|8) datum_heute_lang=$(date '+%_d. Erntemonat (%B) %Y'  | sed 's@^ *@@;') ;;
09|9) datum_heute_lang=$(date '+%_d. Herbstmonat (%B) %Y' | sed 's@^ *@@;') ;;
  10) datum_heute_lang=$(date '+%_d. Weinmonat (%B) %Y'   | sed 's@^ *@@;') ;;
  11) datum_heute_lang=$(date '+%_d. Nebelmonat (%B) %Y'  | sed 's@^ *@@;') ;;
  12) datum_heute_lang=$(date '+%_d. Christmonat (%B) %Y' | sed 's@^ *@@;') ;;
esac

nutzung() {
  cat <<NUTZUNG
Nutzung: 
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] [-H] [-O] -l "*fahren*"

Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
- Textdatei reine Wortliste (ohne Zusätzliches)
- Textdatei mit Grammatik-Einträgen
Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programm pandoc).

Verwendbare Wahlmöglichkeiten:
-h, --hilfe          Hilfetext dieses Programms ausgeben.

-l, --lemmaabfrage   Die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.

-H, --HTML             HTML Datei erzeugen
-O, --ODT              ODT Datei (für LibreOffice) erzeugen
-b, --behalte_Dateien  Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-s, --stillschweigend  Kaum Meldungen ausgaben
    --debug            Print script debug infos (commands executed)
    --farb-frei        Meldungen ohne Farben ausgeben
(technische Abhängigkeiten: jq, pandoc, sed)
NUTZUNG
  exit
}


aufraeumen() {
  trap - SIGINT SIGTERM ERR EXIT
  # aufzuräumendes für dieses Programm
  if [[ ${stufe_dateienbehalten:-0} -eq 0 ]];then
    case ${stufe_verausgaben:-0} in 
    0)  ;; 
    1) meldung "${ORANGE}Entferne unwichtige Dateien …${FORMAT_FREI}" ;;
    esac
    if [[ -e "${json_speicher_datei:-}" ]];then                 rm -- "${json_speicher_datei}"; fi
    if [[ -e "${datei_utf8_text_zwischenablage:-}" ]];then      rm -- "${datei_utf8_text_zwischenablage}"; fi
    if [[ -e "${datei_utf8_text_zwischenablage_gram:-}" ]];then rm -- "${datei_utf8_text_zwischenablage_gram}"; fi
    if [[ -e "${datei_utf8_html_zwischenablage_gram:-}" ]];then rm -- "${datei_utf8_html_zwischenablage_gram}"; fi
    case $stufe_formatierung in 2)  
      if [[ -e "${datei_utf8_html_gram_tidy:-}" ]];then         rm -- "${datei_utf8_html_gram_tidy}"; fi
    ;;
    esac
    case $stufe_formatierung in 1)  
      if [[ -e "${datei_utf8_odt_gram:-}" ]];then               rm -- "${datei_utf8_odt_gram}"; fi
    ;;
    esac
  fi
  case ${stufe_verausgaben:-0} in 
  0)  ;; 
  1) 
    if [[ $( find . -maxdepth 1 -iname "${json_speicher_datei%.*}*" ) ]];then
    meldung "${ORANGE}Folgende Dateien sind erstellt worden:${FORMAT_FREI}" ; 
    ls -l ${json_speicher_datei%.*}*  
    fi
    ;;
  esac
}

farben_bereitstellen() {
  if [[ -t 2 ]] && [[ -z "${FARB_FREI-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
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

# json_speicher_datei lemma_text
json_speicher_datei() {
  local lemmaabfrage=${1-unbekannt}
  local diese_json_speicher_datei=$(printf "%s…lemmata-select-DWB-%s.json" \
    $(echo $lemmaabfrage | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…+$@@') \
    $(date '+%Y%m%d'))    
  printf "${diese_json_speicher_datei}"
}

# dateivariablen_bereitstellen json_speicher_datei
dateivariablen_bereitstellen() {
  local diese_json_speicher_datei=${1-unbekannt}    
  datei_utf8_text_zwischenablage="${diese_json_speicher_datei%.*}-utf8_Zwischenablage.txt"
  datei_utf8_text_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage+gram.txt"
  datei_utf8_reiner_text="${diese_json_speicher_datei%.*}-utf8_nur-Wörter.txt"
  datei_utf8_reiner_text_gram="${diese_json_speicher_datei%.*}-utf8_nur-Wörter+gram.txt"
  datei_utf8_html_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage_Wortliste+gram.html"
  datei_utf8_html_gram_tidy="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram_tidy.html"
  datei_utf8_odt_gram="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram.odt"
}

parameter_abarbeiten() {
  # default values of variables set from params
  stufe_verausgaben=1
  stufe_formatierung=0
  stufe_dateienbehalten=0
  # Grundlage: rein Text, und mit Grammatik
  # zusätzlich
  # 2^0: 1-1 = 0 rein Text, und mit Grammatik
  # 2^1: 2-1 = 1 nur mit HTML
  #      3-1 = 2 nur mit ODT
  # 2^2: 4-1 = 3 mit HTML, mit ODT
  lemmaabfrage=''
  lemma_text=''
  json_speicher_datei=$(json_speicher_datei unbekannt)
  titel_text="Abfrageversuch „??“ aus Grimm-Wörterbuch ($datum_heute_lang)"
  # param=''
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --hilfe) nutzung ;;
    --debug) set -x ;;
    -b | --behalte_Dateien) stufe_dateienbehalten=1 ;;
    -s | --stillschweigend) stufe_verausgaben=0 ;;
    --farb-frei) FARB_FREI=1 ;;
    -l | --lemmaabfrage)  # Parameter
      lemmaabfrage="${2-}" 
      lemma_text=$(echo "$lemmaabfrage" | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…{2,}$@@')
      json_speicher_datei=$(json_speicher_datei $lemma_text)
      titel_text="Wörter-Abfrage „$lemma_text“ aus Grimm-Wörterbuch ($datum_heute_lang)"
      shift
      ;;
    -H | --HTML)
      case $stufe_formatierung in
      0) stufe_formatierung=1 ;;
      1|3) stufe_formatierung=$stufe_formatierung ;;
      2) stufe_formatierung=$(( $stufe_formatierung + 1 )) ;;
      *) stufe_formatierung=1 ;;
      esac
      ;;
    -O | --ODT) 
      case $stufe_formatierung in
      0) stufe_formatierung=2 ;;
      1) stufe_formatierung=$(( $stufe_formatierung + 2 )) ;;
      2|3) stufe_formatierung=$stufe_formatierung ;;
      *) stufe_formatierung=2 ;;
      esac
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

  argumente=("$@")

  # check required params and arguments
  # [[ -z "${param-}" ]] && meldung_abbruch "Missing required parameter: param"
  # [[ ${#argumente[@]} -eq 0 ]] && meldung "${ROT}Fehlendes Lemma, das abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung
  [[ -z "${lemmaabfrage-}" ]] && meldung "${ROT}Fehlendes Lemma, das abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung

  dateivariablen_bereitstellen $json_speicher_datei
  
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
  meldung "${ORANGE}DEBUG - stufe_formatierung:    $stufe_formatierung ${FORMAT_FREI}"
  meldung "${ORANGE}DEBUG - stufe_verausgaben:     $stufe_verausgaben ${FORMAT_FREI}" 
  meldung "${ORANGE}DEBUG - stufe_dateienbehalten: $stufe_dateienbehalten ${FORMAT_FREI}" 
  meldung "${ORANGE}DEBUG - lemmaabfrage: $lemmaabfrage ${FORMAT_FREI}" 
  meldung "${ORANGE}DEBUG - lemma_text:   $lemma_text ${FORMAT_FREI}" 
  ;; 
esac

# Programm Logik hier Anfang

case $stufe_verausgaben in 
 0)  
  wget \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/$lemmaabfrage/0/json" \
    --output-document="${json_speicher_datei}"
 ;; 
 1) 
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/$lemmaabfrage/0/json)" 
  wget --show-progress \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/$lemmaabfrage/0/json" \
    --output-document="${json_speicher_datei}"
 ;; 
esac


case $stufe_verausgaben in 
 0)  ;; 
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text})" ;;
esac

if [[ -e "${json_speicher_datei}" ]];then
  cat "${json_speicher_datei}" | jq '.[] | .label | tostring' > "${datei_utf8_text_zwischenablage}" \
  && printf "%s\n\n" "${titel_text}" > "${datei_utf8_reiner_text}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage}" >> "${datei_utf8_reiner_text}" \
  && sed --regexp-extended --in-place 's@"([^"]+)"@\1;@g' "${datei_utf8_reiner_text}"
else
  meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi

# als reine Textausgabe (sortiert nach Grammatik, Wort)
case $stufe_verausgaben in 
 0)  ;; 
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text_gram})" ;;
esac

cat "${json_speicher_datei}" | jq ' sort_by(.gram,.label)[] |  if .gram == null or .gram == ""
  then "\(.label);"
  else "\(.label) (\(.gram));"
  end
  ' | sed -r 's@"@@g; ' | uniq > "${datei_utf8_text_zwischenablage_gram}"
if [[ -e "${datei_utf8_text_zwischenablage_gram}" ]];then 
  # (3.1.) Sonderzeichen, Umlaute dekodieren in lesbare Zeichen als UTF8
  printf "%s\n\n" "${titel_text}" > "${datei_utf8_reiner_text_gram}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
else
  meldung_abbruch "${ORANGE}Textdatei '${datei_utf8_reiner_text_gram}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi

case $stufe_formatierung in 
 0)  ;; 
 1|2|3) 
  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" ;;
  esac
  cat "${json_speicher_datei}" | jq ' sort_by(.gram,.label)[] |  if .gram == null or .gram == ""
  then "<tr><td>\(.label)</td><td><!-- keine Grammatik angegeben --></td><td><!-- ohne Sprachkunst-Begriff --></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *n[.]? *$"))
  then "<tr><td>\(.label), das</td><td>\(.gram)</td><td>Nennwort, sächlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *n[.]?\\? *$"))
  then "<tr><td>\(.label), das?</td><td>\(.gram)</td><td>Nennwort, ?sächlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *n[.]? *m[.]? *$"))
  then "<tr><td>\(.label), das o. der</td><td>\(.gram)</td><td>Nennwort, sächlich o. männlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *f[.]? *$"))
  then "<tr><td>\(.label), die</td><td>\(.gram)</td><td>Nennwort, weiblich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[.]?\\? *$"))
  then "<tr><td>\(.label), die?</td><td>\(.gram)</td><td>Nennwort, ?weiblich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[.]? *n[.]? *$|^ *f[.]? *n[.]? *n[.]? *$"))
  then "<tr><td>\(.label), die o. das</td><td>\(.gram)</td><td>Nennwort, weiblich o. sächlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[.]? *m[.]? *$"))
  then "<tr><td>\(.label), die o. der</td><td>\(.gram)</td><td>Nennwort, weiblich o. männlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *f. +subst. *$"))
  then "<tr><td>\(.label), die</td><td>\(.gram)</td><td>Nennwort, weiblich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *m[.]? *$"))
  then "<tr><td>\(.label), der</td><td>\(.gram)</td><td>Nennwort, männlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *m[.]? *f[.]? *$"))
  then "<tr><td>\(.label), der o. die</td><td>\(.gram)</td><td>Nennwort, männlich o. weiblich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *m[.]? *n[.]? *$"))
  then "<tr><td>\(.label), der o. das</td><td>\(.gram)</td><td>Nennwort, männlich o. sächlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *m[.]?\\? *$"))
  then "<tr><td>\(.label), der?</td><td>\(.gram)</td><td>Nennwort, ?männlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adj. +und +adv. *$|^ *adj. +u. +adv. *$|^ *adj. +adv. *$"))
  then "<tr><td>\(.label)</td><td>\(.gram)</td><td>Eigenschaftswort, Beiwort und Zuwort, Umstandswort</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *adj[.]?[;]? *$"))
  then "<tr><td>\(.label)</td><td>\(.gram)</td><td>Eigenschaftswort, Beiwort</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  
  elif  (.gram|test("^ *adv[.]?[;]? *$"))
  then "<tr><td>\(.label)</td><td>\(.gram)</td><td>Zuwort, Umstandswort</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *part[.]?[;]? *$"))
  then "<tr><td>\(.label)</td><td>\(.gram)</td><td>Mittelwort</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part[iz]?.[ -]+adj. *$"))
  then "<tr><td>\(.label)</td><td>\(.gram)</td><td>Mittelwort und Eigenschaftswort, Beiwort</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *v. +u. +subst. +n. *$"))
  then "<tr><td>\(.label); \(.label), das</td><td>\(.gram)</td><td>Zeitwort, Tätigkeitswort und Nennwort sächlich</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  
  elif (.gram|test("^ *v. *$|^ *vb. *$|^ *verb. *$"))
  then "<tr><td>\(.label)</td><td>\(.gram)</td><td>Zeitwort, Tätigkeitswort</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  else "<tr><td>\(.label)</td><td>\(.gram)</td><td>?</td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  end
  ' | sed -r 's@"@@g; 
  s@“([^“”]+)”@"\1"@g; 
s@&#x00e4;@ä@g;
s@&#x00f6;@ö@g;
s@&#x00fc;@ü@g;
s@<td>([^ ])([^ ]+)(, [d][eia][res][^<>]*)</td>@<td>\U\1\L\2\3</td>@g; # ersten Buchstaben Groß bei Nennwörtern
1 i\<!DOCTYPE html>\n<html lang="de" xml:lang="de" xmlns="http://www.w3.org/1999/xhtml">\n<head>\n<title></title>\n</head>\n<body><p><i style="font-variant:small-caps;">Schottel (1663)</i> ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href="https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href="https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table><tr><th>Wort</th><th>Grammatik</th><th>Sprachkunst/<br/>Sprachlehre (s. a. <i style="font-variant:small-caps;">Schottel 1663</i>)</th><th>Verknüpfung1</th><th>Verknüpfung2</th></tr>
$ a\</table>\n</body>\n</html>
' | uniq > "${datei_utf8_html_zwischenablage_gram}"
  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung → JSON → HTML${FORMAT_FREI} (tidy: ${datei_utf8_html_gram_tidy})" ;;
  esac
  tidy -quiet -output "${datei_utf8_html_gram_tidy}"  "${datei_utf8_html_zwischenablage_gram}" || this_exit_code=$?

  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung: Titel in HTML dazu${FORMAT_FREI}" ;;
  esac
  sed --in-place "s@<title></title>@<title>$titel_text</title>@;" \
    "${datei_utf8_html_gram_tidy}"

 ;;
esac

case $stufe_formatierung in 
 0)  ;; 
 2|3) 
  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung: HTML → ODT${FORMAT_FREI} (${datei_utf8_odt_gram})" ;;
  esac
  
  if [[ -e "${datei_utf8_odt_gram}" ]];then
    # stat --print="%x" Datei ergibt "2022-11-09 23:58:34.685526884 +0100"
    datum=$( stat --print="%x" "${datei_utf8_odt_gram}" | sed --regexp-extended 's@^([^ ]+) ([^ .]+)\..*@\1_\2@' )
    datei_sicherung=${datei_utf8_odt_gram%.*}_${datum}.odt
    
    meldung  "${ORANGE}Vorhandene${FORMAT_FREI} ${datei_utf8_odt_gram} ${ORANGE}überschreiben?${FORMAT_FREI}"
    meldung  "  ${ORANGE}Falls „nein“, dann erfolgt Sicherung als${FORMAT_FREI}"
    meldung  "  → $datei_sicherung ${ORANGE}(wird also umbenannt)${FORMAT_FREI}"
    echo -en "  ${ORANGE}Jetzt überschreiben (ja/NEIN):${FORMAT_FREI} "
    read janein
    if [[ -z ${janein// /} ]];then janein="nein"; fi
    case $janein in
      [jJ]|[jJ][aA])
        echo " überschreibe ODT …"
        pandoc -f html -t odt "${datei_utf8_html_gram_tidy}" > "${datei_utf8_odt_gram}"
      ;;
      [nN]|[nN][eE][iI][nN])
        echo " sichere ${datei_sicherung} …";
        mv "${datei_utf8_odt_gram}" "${datei_sicherung}"
        pandoc -f html -t odt "${datei_utf8_html_gram_tidy}" > "${datei_utf8_odt_gram}"
      ;;
      *) 
        if [[ -z ${janein// /} ]];then
          echo -e "\033[0;32m# Stop\033[0m"
        else
          echo "# Eingabe nicht (als ja oder nein) erkannt „${janein}“ (Stop)"
        fi
        exit 1
      ;;
    esac
  else
    pandoc -f html -t odt "${datei_utf8_html_gram_tidy}" > "${datei_utf8_odt_gram}"
  fi
;;
esac

# Programm Logik hier Ende
