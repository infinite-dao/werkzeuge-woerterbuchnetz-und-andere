#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

abhaenigkeiten_pruefen() {
  local stufe_abbruch=0
  
  if ! [[ -x "$(command -v jq)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} jq ${ORANGE} zum Verarbeiten von JSON nicht gefunden: Bitte sed über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi  
  if ! [[ -x "$(command -v pandoc)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} pandoc ${ORANGE} zum Erstellen von Dokumenten in HTML, ODT nicht gefunden: Bitte sed über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v sed)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} sed ${ORANGE}nicht gefunden: Bitte sed über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v tidy)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} tidy ${ORANGE} zum Aufhübschen und Prüfen von HTML-Dokumenten nicht gefunden: Bitte sed über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi

  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}

nutzung() {
  cat <<NUTZUNG
Nutzung: 
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] [-H] [-O] -V "stupere"

Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
- Textdatei reine Wortliste (ohne Zusätzliches)
- Textdatei mit Grammatik-Einträgen
Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programm pandoc).

Verwendbare Wahlmöglichkeiten:
-h,    --Hilfe          Hilfetext dieses Programms ausgeben.

-v,-V  --Volltextabfrage   Die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.

-H,    --HTML             HTML Datei erzeugen
-O,    --ODT              ODT Datei (für LibreOffice) erzeugen
-b,    --behalte_Dateien  Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-s,    --stillschweigend  Kaum Meldungen ausgaben
       --debug            Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
       --farb-frei        Meldungen ohne Farben ausgeben

Technische Abhängigkeiten: 
- jq
- sed
- pandoc: es kann eine Vorlagedatei im eigenen Nutzerverzeichnis erstellt werden, als ~/.pandoc/reference.odt

NUTZUNG
  abhaenigkeiten_pruefen
  exit
}

json_filter_code() {
cat <<CODE
# https://stackoverflow.com/a/39836412 join two json files based on common key with jq utility or alternative way from command line
# hashJoin(a1; a2; field) expects a1 and a2 to be arrays of JSON objects
# and that for each of the objects, the field value is a string.
# A relational join is performed on "field".

# def hashJoin(a1; a2; field):
#   # hash phase:
#   (reduce a1[] as \$o ({};  . + { (\$o | field): \$o } )) as \$h1
#   | (reduce a2[] as \$o ({};  . + { (\$o | field): \$o } )) as \$h2
#   # join phase:
#   | reduce (\$h1|keys[]) as \$key
#       ([]; if \$h2|has(\$key) then . + [ \$h1[\$key] + \$h2[\$key] ] else . end) ;
# 
def hashJoin(a1; a2; key):
  def akey: key | if type == "string" then . else tojson end;
  def wrap: { (akey) : . } ;
  # hash phase:
  (reduce a1[] as \$o ({};  . + (\$o | wrap ))) as \$h1
  | (reduce a2[] as \$o 
      ( {};
        (\$o|akey) as \$v
        | if \$h1[\$v] then . + { (\$v): \$o } else . end )) as \$h2
  # join phase:
  | reduce (\$h2|keys[]) as \$key
      ([];  . + [ \$h1[\$key] + \$h2[\$key] ] ) ;
      
hashJoin( \$file1; \$file2; .textid)[]
CODE
}

aufraeumen() {
  trap - SIGINT SIGTERM ERR EXIT
  # aufzuräumendes für dieses Programm
  
  if [[ ${stufe_aufraeumen_aufhalten:-0} -eq 0 ]];then
    if [[ ${stufe_dateienbehalten:-0} -eq 0 ]];then
      case ${stufe_verausgaben:-0} in 
      0)  ;; 
      1) meldung "${ORANGE}Entferne unwichtige Dateien …${FORMAT_FREI}" ;;
      esac
      if [[ -e "${json_speicher_datei-}" ]];then                             rm -- "${json_speicher_datei}"; fi
      if [[ -e "${datei_utf8_text_zwischenablage-}" ]];then                  rm -- "${datei_utf8_text_zwischenablage}"; fi
      if [[ -e "${datei_utf8_text_zwischenablage_gram-}" ]];then             rm -- "${datei_utf8_text_zwischenablage_gram}"; fi
      if [[ -e "${datei_utf8_html_zwischenablage_gram-}" ]];then             rm -- "${datei_utf8_html_zwischenablage_gram}"; fi
      case $stufe_formatierung in 2)  
        if [[ -e "${datei_utf8_html_gram_tidy:-}" ]];then         rm -- "${datei_utf8_html_gram_tidy}"; fi
      ;;
      esac
      case $stufe_formatierung in 1)  
        if [[ -e "${datei_utf8_odt_gram:-}" ]];then               rm -- "${datei_utf8_odt_gram}"; fi
      ;;
      esac
      if [[ -e "${json_speicher_all_query_datei-}" ]];then                   rm -- "${json_speicher_all_query_datei}"; fi
      if [[ -e "${json_speicher_allquery_datei_zwischenablage-}" ]];then     rm -- "${json_speicher_allquery_datei_zwischenablage}"; fi
      if [[ -e "${json_speicher_datei_zwischenablage-}" ]];then              rm -- "${json_speicher_datei_zwischenablage}"; fi
      if [[ -e "${json_speicher_vereinte_abfragen_zwischenablage-}" ]];then  rm -- "${json_speicher_vereinte_abfragen_zwischenablage}"; fi
      if [[ -e "${json_speicher_filter_ueber_textid_verknuepfen-}" ]];then   rm -- "${json_speicher_filter_ueber_textid_verknuepfen}"; fi
      if [[ -e "${datei_diese_wbnetzkwiclink-}" ]];then                      rm -- "${datei_diese_wbnetzkwiclink}"; 
      fi
      
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
  fi
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

# json_speicher_datei volltext_text
json_speicher_datei() {
  local volltextabfrage=${1-unbekannt}
  local diese_json_speicher_datei=$(printf "%s…DWB1-Volltext-Abfrage-%s.json" \
    $(echo $volltextabfrage | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…+$@@') \
    $(date '+%Y%m%d'))    
  printf "${diese_json_speicher_datei}"
}


# dateivariablen_filter_bereitstellen json_speicher_datei
dateivariablen_filter_bereitstellen() {
  local diese_json_speicher_datei=${1-unbekannt}    
  datei_utf8_text_zwischenablage="${diese_json_speicher_datei%.*}-utf8_Zwischenablage.txt"
  datei_utf8_text_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage+gram.txt"
  datei_utf8_reiner_text="${diese_json_speicher_datei%.*}-utf8_nur-Wörter.txt"
  datei_utf8_reiner_text_gram="${diese_json_speicher_datei%.*}-utf8_nur-Wörter+gram.txt"
  
  datei_utf8_html_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage_Wortliste+gram.html"
    datei_diese_wbnetzkwiclink="${datei_utf8_html_zwischenablage_gram}.wbnetzkwiclink.txt"
    
  datei_utf8_html_gram_tidy="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram_tidy.html"
  datei_utf8_odt_gram="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram.odt"
  json_speicher_all_query_datei="${diese_json_speicher_datei%.*}.allquery.json"
  # Zwischenablage für JSON Verarbeitung
  json_speicher_allquery_datei_zwischenablage="${diese_json_speicher_datei%.*}.allquery.Zwischenablage.json"
  json_speicher_datei_zwischenablage="${diese_json_speicher_datei%.*}.Zwischenablage.json"
  json_speicher_vereinte_abfragen_zwischenablage="${diese_json_speicher_datei%.*}.Zwischenablag.vereinte-Abfragen.json"
  json_speicher_filter_ueber_textid_verknuepfen=json_ueber_textid_verknuepfen.jq
}

parameter_abarbeiten() {
  # default values of variables set from params
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
  stufe_verausgaben=1
  stufe_formatierung=0
  stufe_aufraeumen_aufhalten=0
  stufe_dateienbehalten=0
  # Grundlage: rein Text, und mit Grammatik
  # zusätzlich
  # 2^0: 1-1 = 0 rein Text, und mit Grammatik
  # 2^1: 2-1 = 1 nur mit HTML
  #      3-1 = 2 nur mit ODT
  # 2^2: 4-1 = 3 mit HTML, mit ODT
  n_suchergebnisse=0
  volltextabfrage=''
  volltext_text=''
  json_speicher_datei=$(json_speicher_datei unbekannt)
  titel_text="Volltextsuche „??“ aus Grimm-Wörterbuch ($datum_heute_lang)"
  # param=''
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_aufraeumen_aufhalten=1; nutzung ;;
    --debug) set -x ;;
    -b | --behalte_Dateien) stufe_dateienbehalten=1 ;;
    -s | --stillschweigend) stufe_verausgaben=0 ;;
    --farb-frei) FARB_FREI=1 ;;
    -[Vv] | --[Vv]olltextabfrage)  # Parameter
      volltextabfrage="${2-}" 
      volltext_text=$(echo "$volltextabfrage" | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…{2,}$@@')
      json_speicher_datei=$(json_speicher_datei $volltext_text)
      titel_text="Volltextsuche „$volltext_text“ aus Grimm-Wörterbuch ($datum_heute_lang)"
      shift
      ;;
    -H | --[Hh][Tt][Mm][Ll])
      case $stufe_formatierung in
      0) stufe_formatierung=1 ;;
      1|3) stufe_formatierung=$stufe_formatierung ;;
      2) stufe_formatierung=$(( $stufe_formatierung + 1 )) ;;
      *) stufe_formatierung=1 ;;
      esac
      ;;
    -O | --[Oo][Dd][Tt]) 
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
  [[ -z "${volltextabfrage-}" ]] && meldung "${ROT}Fehlendes Lemma, das abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung

  dateivariablen_filter_bereitstellen "${json_speicher_datei}"
  abhaenigkeiten_pruefen
  json_filter_code > "${json_speicher_filter_ueber_textid_verknuepfen}"
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
  meldung "${ORANGE}DEBUG - volltextabfrage: $volltextabfrage ${FORMAT_FREI}" 
  meldung "${ORANGE}DEBUG - volltext_text:   $volltext_text ${FORMAT_FREI}" 
  ;; 
esac

# Programm Logik hier Anfang

case $stufe_verausgaben in 
 0)  
  wget \
    --quiet "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage" \
    --output-document="${json_speicher_datei}" \
    && wget \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=$volltextabfrage" \
    --output-document="${json_speicher_all_query_datei}"
 ;; 
 1) 
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage)" 
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=$volltextabfrage)" 
  wget --show-progress \
    --quiet "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage" \
    --output-document="${json_speicher_datei}" \
    && wget --show-progress \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=$volltextabfrage" \
    --output-document="${json_speicher_all_query_datei}"
    
 ;; 
esac


case $stufe_verausgaben in 
 0)  ;; 
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text})" ;;
esac

if [[ -e "${json_speicher_datei}" ]];then
  # cat ./test/stupere.json | jq ' .result_count '
  n_suchergebnisse=$( cat "${json_speicher_datei}" | jq ' .result_count ' ) && abbruch_code_nummer=$?
  # cat "${json_speicher_datei}" | jq ' .result_set[] | .lemma | tostring '
  case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    msg "${ORANGE}Irgendwas lief schief mit cat … jq. Abbruch Code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI}" ;;
  esac  
  if [[ ${n_suchergebnisse-0} -eq 0 ]];then
    meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' enthält $n_suchergebnisse Suchergebnisse (Abbruch)${FORMAT_FREI}"
  fi
  
  cat "${json_speicher_datei}" | jq ' .result_set[] | .lemma | tostring ' > "${datei_utf8_text_zwischenablage}" \
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
cat "${json_speicher_datei}" | jq ' .result_set | sort_by(.gram,.lemma )[] |  if .gram == null or .gram == ""
  then "\(.lemma);"
  else "\(.lemma) (\(.gram));"
  end
  ' | sed -r 's@"@@g; ' | uniq > "${datei_utf8_text_zwischenablage_gram}"
if [[ -e "${datei_utf8_text_zwischenablage_gram}" ]];then 
  # (3.1.) Sonderzeichen, Umlaute dekodieren in lesbare Zeichen als UTF8
  printf "%s\n\n" "${titel_text}" > "${datei_utf8_reiner_text_gram}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
else
  meldung_abbruch "${ORANGE}Textdatei '${datei_utf8_reiner_text_gram}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi


case $volltext_text in 
…*…) bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>${volltext_text}</i> zu tun haben)." ;;
…*)  bearbeitungstext_html="Liste noch nicht übearbeitet (es können auch Wörter enthalten sein, die nichts mit der Endung <i>$volltext_text</i> gemein haben)." ;;
*…)  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit dem Wortanfang <i>${volltext_text}</i> gemein haben)." ;;
*) bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>${volltext_text}</i> zu tun haben)." ;;
esac

# kombiniere json_speicher_all_query_datei und json_speicher_datei für wbnetzkwiclink mit richtiger Fund-Textstelle
# jq flatten JSON
# kombiniere über textid
# nutze verknüpftes JSON
jq '[
  [
    [ .[] 
      | {fid:.formid, tid:(.textidlist|flatten),wid:(.wordidlist|flatten)} 
      | {fid:.fid, path_kwic_fid_tid:"/kwic/\(.fid)/textid/\(.tid[])"}
    ],
    [ .[] 
      | {fid:.formid, tid:(.textidlist|flatten),wid:(.wordidlist|flatten)} 
      | {fid:.fid, textid:(.tid[])}
    ],
    [ .[] 
      | {fid:.formid, tid:(.textidlist|flatten),wid:(.wordidlist|flatten)} 
      | {fid:.fid, path_wid:"/wordid/\(.wid[])"}
    ]
  ] 
  | (transpose | map(add))
  | .[] | {textid: .textid, wbnetzkwiclink_all_result:"https://api.woerterbuchnetz.de/dictionaries/DWB\(.path_kwic_fid_tid)\(.path_wid)"}
]
|flatten[]
' "${json_speicher_all_query_datei}" > "${json_speicher_allquery_datei_zwischenablage}"

jq '.result_set | flatten[]' "${json_speicher_datei}" > "${json_speicher_datei_zwischenablage}"

jq -n \
  --slurpfile file1 "${json_speicher_allquery_datei_zwischenablage}" \
  --slurpfile file2 "${json_speicher_datei_zwischenablage}" \
  -f "${json_speicher_filter_ueber_textid_verknuepfen}" > "${json_speicher_vereinte_abfragen_zwischenablage}"

case $stufe_formatierung in 
 0)  ;; 
 1|2|3) 
  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" ;;
  esac
  jq ' . |  sort_by(.gram,.lemma)[] |  if .gram == null or .gram == ""
  then "<tr><td>\(.lemma)</td><td><!-- keine Grammatik angegeben --></td><td><!-- ohne Sprachkunst-Begriff --></td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adj. +und +adv. *$|^ *adj. +u. +adv. *$|^ *adj. +adv. *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Eigenschaftswort, Beiwort und Zuwort, Umstandswort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *adj[.]?[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Eigenschaftswort, Beiwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif  (.gram|test("^ *adv[.]?[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Zuwort, Umstandswort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *f[.]?[;]? *$|^ *fem[.]?[;]? *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram)</td><td>Nennwort, weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[.]?\\? *$"))
  then "<tr><td>\(.lemma), die?</td><td>\(.gram)</td><td>Nennwort, ?weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.lemma), die o. der</td><td>\(.gram)</td><td>Nennwort, weiblich o. männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[.]? *n[.]? *n[.]? *$"))
  then "<tr><td>\(.lemma), die o. das</td><td>\(.gram)</td><td>Nennwort, weiblich o. sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f., +n., +m. *$"))
  then "<tr><td>\(.lemma), die o. das o. der</td><td>\(.gram)</td><td>Nennwort, weiblich o. sächlich o. männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f., +m., +n. *$"))
  then "<tr><td>\(.lemma), die o. das o. der</td><td>\(.gram)</td><td>Nennwort, weiblich o. männlich o. sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *f.[,]? +nomen actionis *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram)</td><td>Nennwort einer Handlung, weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f.[,]? +nomen agentis *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram)</td><td>Nennwort-Machende, weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f. +subst. *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram)</td><td>Nennwort, weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *interj[.]?[;]? *$|^ *interjection[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Zwischenwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *m[_.,;]* *$"))
  then "<tr><td>\(.lemma), der</td><td>\(.gram)</td><td>Nennwort, männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.lemma), der o. die</td><td>\(.gram)</td><td>Nennwort, männlich o. weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.lemma), der o. das</td><td>\(.gram)</td><td>Nennwort, männlich o. sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[.]?\\? *$"))
  then "<tr><td>\(.lemma), der?</td><td>\(.gram)</td><td>Nennwort, ?männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m., +f., +n. *$"))
  then "<tr><td>\(.lemma), der o. die o. das</td><td>\(.gram)</td><td>Nennwort, männlich o. weiblich o. sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m., +n., +f. *$"))
  then "<tr><td>\(.lemma), der o. das o. die</td><td>\(.gram)</td><td>Nennwort, männlich o. sächlich o. weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m.[,]? +nomen actionis *$"))
  then "<tr><td>\(.lemma), der</td><td>\(.gram)</td><td>Nennwort einer Handlung, männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m.[,]? +nomen agentis *$"))
  then "<tr><td>\(.lemma), der</td><td>\(.gram)</td><td>Nennwort-Machender, männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif (.gram|test("^ *n[_.,;]* *$"))
  then "<tr><td>\(.lemma), das</td><td>\(.gram)</td><td>Nennwort, sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[.]?\\? *$"))
  then "<tr><td>\(.lemma), das?</td><td>\(.gram)</td><td>Nennwort, ?sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.lemma), das o. der</td><td>\(.gram)</td><td>Nennwort, sächlich o. männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n., +m., +f. *$"))
  then "<tr><td>\(.lemma), das o. der o. die</td><td>\(.gram)</td><td>Nennwort, sächlich o. männlich o. weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n., +f., +m. *$"))
  then "<tr><td>\(.lemma), das o. der o. die</td><td>\(.gram)</td><td>Nennwort, sächlich o. weiblich o. männlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n., +f.[;]? *$"))
  then "<tr><td>\(.lemma), das o. die</td><td>\(.gram)</td><td>Nennwort, sächlich o. weiblich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif  (.gram|test("^ *part[icz]*[.]?[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Mittelwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part[icz]*.[ -]+adj. *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Mittelwort und Eigenschaftswort, Beiwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *präp[.]?[;]? *$|^ *praep[.]?[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Vorwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif (.gram|test("^ *praet.[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Vergangenheit</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *subst. *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Nennwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *v. +u. +subst. +n. *$"))
  then "<tr><td>\(.lemma); \(.lemma), das</td><td>\(.gram)</td><td>Zeitwort, Tätigkeitswort und Nennwort sächlich</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif (.gram|test("^ *v.[;]? *$|^ *vb.[;]? *$|^ *verb.[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>Zeitwort, Tätigkeitswort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  else "<tr><td>\(.lemma)</td><td>\(.gram)</td><td>?</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  end
  ' --slurp "${json_speicher_vereinte_abfragen_zwischenablage}" \
  | sed -r "s@\"@@g; 
  s@“([^“”]+)”@\"\1\"@g; 
s@&#x00e4;@ä@g;
s@&#x00f6;@ö@g;
s@&#x00fc;@ü@g;

s@api.woerterbuchnetz.de/open-api/dictionaries/DWB/kwic/@api.woerterbuchnetz.de/dictionaries/DWB/kwic/@g; # ohne /open-api/
s@<wbnetzkwiclink>@\n&@g; s@</wbnetzkwiclink>@&\n@g # für leichteres JSON Einfügen und wieder weglöschen
s@woerterbuchnetz.de//\?@woerterbuchnetz.de/?@g;

  # s@<td>([^ ])([^ ]+)(, [d][eia][res][^<>]*)</td>@<td>\U\1\L\2\E\3</td>@g; # ersten Buchstaben Groß bei Nennwörtern
s@<td>([^ ])([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]*</td><td> *Nennwort)@<td>\U\1\L\2\E\3\4@g; # ersten Buchstaben Groß bei Nennwörtern
1 i\<!DOCTYPE html>\n<html lang=\"de\" xml:lang=\"de\" xmlns=\"http://www.w3.org/1999/xhtml\">\n<head>\n<title></title>\n</head>\n<body><p>${bearbeitungstext_html}</p><p><i style=\"font-variant:small-caps;\">Schottel (1663)</i> ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table id=\"Wortliste-Tabelle\"><tr><th>Wort</th><th>Grammatik<br/>(<i>Grimm</i>)</th><th>Sprachkunst, Sprachlehre<br/>(s. a. <i style=\"font-variant:small-caps;\">Schottel 1663</i>)</th><th>Fundstelle (gekürzt)</th><th>Haupteintrag</th><th>Verknüpfung Textstelle</th></tr>
$ a\</table>\n</body>\n</html>

s@<th>@<th style=\"border-top:2px solid gray;border-bottom:2px solid gray;\">@g
" | uniq > "${datei_utf8_html_zwischenablage_gram}"

  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung → HTML (wbnetzkwiclink: $n_suchergebnisse Fundstellen)${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" ;;
  esac

  i_textverknuepfung=1;
  n_textverknuepfung=$( grep --count '<wbnetzkwiclink>[^<>]*</wbnetzkwiclink>' "${datei_utf8_html_zwischenablage_gram}" )
  
  echo "" > "${datei_diese_wbnetzkwiclink}"
  
  for wbnetzkwiclink_text in $( grep --only-matching '<wbnetzkwiclink>[^<>]*</wbnetzkwiclink>' "${datei_utf8_html_zwischenablage_gram}" );do
    datei_diese_fundstelle="${datei_utf8_html_zwischenablage_gram}.fundstelle_text.$i_textverknuepfung.txt"
    case $i_textverknuepfung in 1) echo '' > "${datei_diese_fundstelle}" ;; esac

    if [[ $(( $i_textverknuepfung % 100 )) -eq 0 ]];then printf '. %04d\n' $i_textverknuepfung; else printf '.'; fi
    
    wbnetzkwiclink=$( echo $wbnetzkwiclink_text | sed --regexp-extended 's@<wbnetzkwiclink>([^<>]+)</wbnetzkwiclink>@\1@' )
    printf "$wbnetzkwiclink\n" >> "${datei_diese_wbnetzkwiclink}"
    wbnetzkwiclink_escaped=$(echo $wbnetzkwiclink_text | sed 's@/@\\/@g; ' )
    # https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/A07187/textid/697253/wordid/2
    textid=$( echo "${wbnetzkwiclink}" | sed --regexp-extended 's@.+/textid/([[:digit:]]+)/.+@\1@;' )
    
    fundstelle_text=$(
      wget --quiet --no-check-certificate -O - "$wbnetzkwiclink"  | jq  --arg textid ${textid-0} --join-output ' .[] 
      | if (.textid|tonumber) == ($textid|tonumber) 
      then "<b class=\"gefunden-hervorheben\" id=\"textid-\($textid)\">\(.word)</b>"
      elif .typeset == "italics"
      then ( 
        if .charposition == "super" 
        then "<i><sup>\(.word)</sup></i>" 
        else "<i>\(.word)</i>" 
        end
      )
      elif .typeset == "caps"
      then (
        if .charposition == "super" 
        then "<span style=\"font-variant:small-caps\"><sup>\(.word)</sup></span>"
        else "<span style=\"font-variant:small-caps\">\(.word)</span>"
        end
      )
      elif .typeset == "recte"
      then (
        if .charposition == "super" 
        then "<sup>\(.word)</sup>"
        elif (.elementtype|test("sensemark[1-9]+"))
        then "<b>\(.word)</b>"
        else "\(.word)"
        end
      )
      else (
        if .charposition == "super" 
        then "<sup>\(.word)</sup>"
        elif (.elementtype|test("sensemark[1-9]+"))
        then "<b>\(.word)</b>"
        else "\(.word)"
        end
      )
      end 
      ' | sed --regexp-extended 's@</i><i>@@g'
    )
    echo "»${fundstelle_text}«" > "${datei_diese_fundstelle}"
    # sed --in-place '/<\/body>/e cat Abkürzungen-GRIMM-Tabelle-DWB2.html' "${datei_utf8_html_zwischenablage_gram}"
    sed --in-place "/${wbnetzkwiclink_escaped}/r ${datei_diese_fundstelle}" "${datei_utf8_html_zwischenablage_gram}"
    sed --in-place "/${wbnetzkwiclink_escaped}/d" "${datei_utf8_html_zwischenablage_gram}"
    
    rm -- "${datei_diese_fundstelle}"
    
    i_textverknuepfung=$(( $i_textverknuepfung + 1 ))
  done

  # Falls HTML-Datei mit Tabelle vorhanden ist
  if [[ -e "Abkürzungen-GRIMM-Tabelle-DWB2.html"  ]];then 
  sed --in-place '/<\/body>/e cat Abkürzungen-GRIMM-Tabelle-DWB2.html' "${datei_utf8_html_zwischenablage_gram}"

  sed --in-place 's@<table *id="Wortliste-Tabelle">@<p>Siehe auch das <a href="#sec-GRIMM_Abkuerzungen">Abkürzungsverzeichnis</a>.</p>\n&@' "${datei_utf8_html_zwischenablage_gram}"
  fi
  
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
esac # stufe stufe_formatierung

case $stufe_formatierung in 
 0)  ;; 
 2|3) 
  case $stufe_verausgaben in 
  0)  ;; 
  1) meldung "${GRUEN}Weiterverarbeitung: HTML → ODT${FORMAT_FREI} (${datei_utf8_odt_gram})" 
  if [[ -e ~/.pandoc/reference.odt ]]; then
  meldung "${GRUEN}Weiterverarbeitung: HTML → ODT, die Vorlage${FORMAT_FREI} ~/.pandoc/reference.odt ${GRUEN}wird für das Programm${FORMAT_FREI} pandoc ${GRUEN}wahrscheinlich verwendet${FORMAT_FREI}" 
  fi
  ;;
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
        pandoc -f html -t odt "${datei_utf8_html_gram_tidy}" > "${datei_utf8_odt_gram}" # siehe ~/.pandoc/reference.odt
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
