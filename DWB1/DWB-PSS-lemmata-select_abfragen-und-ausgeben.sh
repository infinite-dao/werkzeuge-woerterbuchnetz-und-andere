#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/
# ZUTUN stufe_textauszug (Nährstand, Lehrstand, Wehrstand)
# ZUTUN filter wortliste zum beschränken z.B. bei Suche *stand* alle "aufstand" usw. weglassen
# ZUTUN Grammatik ~ Schottel zusammenführen in Tabelle
# ZUTUN Prüfung Nennwort → Großschreibung

set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

abhaengigkeiten_pruefen() {
  local stufe_abbruch=0

  if ! [[ -x "$(command -v jq)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} jq ${ORANGE} zum Verarbeiten von JSON nicht gefunden: Bitte${FORMAT_FREI} jq ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v pandoc)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} pandoc ${ORANGE} zum Erstellen von Dokumenten in HTML, ODT nicht gefunden: Bitte${FORMAT_FREI} pandoc ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v sed)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} sed ${ORANGE}nicht gefunden: Bitte sed über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v tidy)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} tidy ${ORANGE} zum Aufhübschen und Prüfen von HTML-Dokumenten nicht gefunden: Bitte${FORMAT_FREI} tidy ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi

  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}

nutzung() {
  local diese_nutzung=''

  diese_nutzung=$( cat <<NUTZUNG
Nutzung:
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] [-H] [-O] -l "*fahren*"

Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
- Textdatei reine Wortliste (ohne Zusätzliches)
- Textdatei mit Grammatik-Einträgen
Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programm pandoc).
(Technische Abhängigkeiten: jq, pandoc, sed)

Verwendbare Wahlmöglichkeiten:
-h,  --Hilfe          Hilfetext dieses Programms ausgeben.

-l,-L, --Lemmaabfrage     Die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.
                          mehrere Suchwörter zugleich sind möglich: „*wohn*, *wöhn*“
-F     --Fundstellen      Fundstellen mit abfragen, jeden Stichworts

-H,    --HTML             HTML Datei erzeugen
-O,    --ODT              ODT Datei (für LibreOffice) erzeugen
-b,    --behalte_Dateien  Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-s,    --stillschweigend  Kaum Meldungen ausgeben
       --ohne             ohne Wörter (Wortliste z.B. --ohne 'aufstand, verstand' bei --Lemmaabfrage '*stand*')
       --debug            Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
       --farb-frei        Meldungen ohne Farben ausgeben

Technische Anmerkungen:

- abhängig von Befehl ${BLAU}jq${FORMAT_FREI} (JSON Verarbeitung)
- abhängig von Befehl ${BLAU}sed${FORMAT_FREI} (Textersetzungen)
- abhängig von Befehl ${BLAU}pandoc${FORMAT_FREI} (Umwandlung der Dateiformate)
  - es kann eine Vorlagedatei im eigenen Nutzerverzeichnis erstellt werden, als ${BLAU}~/.pandoc/reference.odt${FORMAT_FREI}

NUTZUNG
)

 echo -e "${diese_nutzung}" # mit Farbausgabe 
 abhaengigkeiten_pruefen
  exit
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
      if [[ -e "${json_speicher_datei-}" ]];then                 rm -- "${json_speicher_datei}"; fi
      if [[ -e "${datei_utf8_text_zwischenablage-}" ]];then      rm -- "${datei_utf8_text_zwischenablage}"; fi
      if [[ -e "${datei_utf8_text_zwischenablage_gram-}" ]];then rm -- "${datei_utf8_text_zwischenablage_gram}"; fi
      if [[ -e "${datei_utf8_html_zwischenablage_gram-}" ]];then rm -- "${datei_utf8_html_zwischenablage_gram}"; fi
      case $stufe_formatierung in 3)
        if [[ -e "${datei_utf8_html_gram_tidy_log-}" ]];then      rm -- "${datei_utf8_html_gram_tidy_log}"; fi
      esac
      case $stufe_formatierung in 2)
        if [[ -e "${datei_utf8_html_gram_tidy-}" ]];then         rm -- "${datei_utf8_html_gram_tidy}"; fi
        if [[ -e "${datei_utf8_html_gram_tidy_log-}" ]];then      rm -- "${datei_utf8_html_gram_tidy_log}"; fi
      ;;
      esac
      case $stufe_formatierung in 1)
        if [[ -e "${datei_utf8_odt_gram-}" ]];then               rm -- "${datei_utf8_odt_gram}"; fi
        if [[ -e "${datei_utf8_html_gram_tidy_log-}" ]];then      rm -- "${datei_utf8_html_gram_tidy_log}"; fi
      ;;
      esac      
      case $stufe_fundstellen in 1)
        if [[ -e "${datei_diese_wbnetzkwiclink-}" ]];then                      rm -- "${datei_diese_wbnetzkwiclink}"; fi
      esac
    fi
    case ${stufe_verausgaben:-0} in
    0)  ;;
    1)
      if [[ $( find . -maxdepth 1 -iname "${json_speicher_datei%.*}*" ) ]];then
      meldung "${ORANGE}Folgende Dateien sind erstellt worden:${FORMAT_FREI}" ;
      ls -l "${json_speicher_datei%.*}"*
      fi
      ;;
    esac
  fi
}

farben_bereitstellen() {
  # file descriptor [[ -t 2 ]] : 0 → stdin / 1 → stdout / 2 → stderr
  if [[ -t 2 ]] && [[ -z "${FORMAT_FREI-}" ]] && [[ "${AUSDRUCK-}" != "stumm" ]]; then
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
  local lemmaabfrage="${*-unbekannt}"
  local diese_datei_vorsilbe=$(echo "$lemmaabfrage" | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…+$@…@')
  local diese_json_speicher_datei=$(printf "%s_Lemmata-Abfrage-DWB1_%s.json" "${diese_datei_vorsilbe}" $(date '+%Y%m%d') )
  printf "${diese_json_speicher_datei}"
}

# dateivariablen_bereitstellen json_speicher_datei
dateivariablen_bereitstellen() {
  local diese_json_speicher_datei="${*-unbekannt}"
  datei_utf8_text_zwischenablage="${diese_json_speicher_datei%.*}-utf8_Zwischenablage.txt"
  datei_utf8_text_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage+gram.txt"
  datei_utf8_reiner_text="${diese_json_speicher_datei%.*}-utf8_nur-Wörter.txt"
  datei_utf8_reiner_text_gram="${diese_json_speicher_datei%.*}-utf8_nur-Wörter+gram.txt"
  datei_utf8_html_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage_Wortliste+gram.html"
  datei_utf8_html_gram_tidy="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram_tidy.html"
    datei_utf8_html_gram_tidy_log="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram_tidy.html.log"
  datei_utf8_odt_gram="${diese_json_speicher_datei%.*}_Wortliste+gram.odt"
    datei_diese_wbnetzkwiclink="${datei_utf8_html_zwischenablage_gram}.wbnetzkwiclink.txt"

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
    12) datum_heute_lang=$(date '+%_d. Christmonat (%b.) %Y' | sed 's@^ *@@;') ;;
  esac

  abbruch_code_nummer=0
  stufe_aufraeumen_aufhalten=0
  stufe_dateienbehalten=0
  stufe_formatierung=0
  stufe_fundstellen=0
  stufe_textauszug=0
  stufe_verausgaben=1
  # Grundlage: rein Text, und mit Grammatik
  # zusätzlich
  # 2^0: 1-1 = 0 rein Text, und mit Grammatik
  # 2^1: 2-1 = 1 nur mit HTML
  #      3-1 = 2 nur mit ODT
  # 2^2: 4-1 = 3 mit HTML, mit ODT
  ohne_woerterliste=''
  ohne_woerterliste_text=''
  ohne_woerterliste_regex=''
  zusatzbemerkungen_textdatei=''
  zusatzbemerkungen_htmldatei=''
  lemmaabfrage=''
  lemmaabfrage_api=''
  lemma_text=''
  json_speicher_datei=$(json_speicher_datei unbekannt)
  titel_text="Abfrageversuch „??“ aus Grimm-Wörterbuch ($datum_heute_lang)"
  # param=''

  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_aufraeumen_aufhalten=1; nutzung ;;
    --debug) set -x ;;
    -b | --behalte_Dateien) stufe_dateienbehalten=1 ;;
    --farb-frei) FORMAT_FREI=1 ;;
    -F | --Fundstellen) stufe_fundstellen=1 ;;
    -s | --stillschweigend) stufe_verausgaben=0 ;;
    -[lL] | --[lL]emmaabfrage)  # Parameter
      lemmaabfrage=$( echo "${2-}" | sed --regexp-extended ' s@^[[:blank:]]+@@; s@[[:blank:]]+$@@; ' )
      lemmaabfrage_api=$( echo "$lemmaabfrage" | sed --regexp-extended '
        s/ +(ODER|OR) +/@OR@/g; 
        s/ +(UND|AND) +/@AND@/g; 
        s@[[:blank:]]@@g; 
        ' 
        )
      lemma_text=$( echo "$lemmaabfrage" | sed --regexp-extended ' 
        s@,@κομμα@g; # Komma später wieder zurückwandeln
        s@[[:punct:]]@…@g; 
        s@^…{2,}@@; 
        s@…{2,}$@@;
        s@κομμα@,@g;
        ' )
      json_speicher_datei=$( json_speicher_datei "${lemma_text}" )
      titel_text="Wörter-Abfrage „${lemma_text}“ aus Grimm-Wörterbuch (${datum_heute_lang})"
      shift
      ;;
    -o|--ohne)  # Parameter
      ohne_woerterliste="${2-}"
      ohne_woerterliste_text=$(echo "$ohne_woerterliste" | sed --regexp-extended '
        s@\*+@ρεγεξ@g; 
        s@\?+@φραγεζειχψεν@g; 
        s@\[([^][]+)-([^][]+)\]@λκλαμμερ\1βισ\2ρκλαμμερ@g;
        s@\[([^][-]+)\]@λκλαμμερ\1ρκλαμμερ@g;
        s@[[:punct:]]+@ @g; 
        s@ρεγεξ@…@g; 
        s@(^…{2,}|…{2,}$)@@; 
        s@φραγεζειχψεν@?@g;
        s@λκλαμμερ(.)βισ(.)ρκλαμμερ@[\1-\2]@g;
        s@λκλαμμερ([[:alpha:]]+)ρκλαμμερ@[\1]@g;
        s@[ ]+@, @g; 
      ')
      ohne_woerterliste_regex=$(echo "$ohne_woerterliste" | sed --regexp-extended '
        # einfache reg. Ausdrücke: 
        # Wort* → Wort.*  
        # W[oöœ]+rt* → W[oöœ]+rt.*
        # Waa?rt* → Waa?rt.*
        # Wort, anderesWort nochanderesWort → Wort|anderesWort|nochanderesWort
        s@\*+@ρεγεξστερν@g; 
        s@\^+@ρεγεξανφανγ@g; 
        s@\?+@φραγεζειχψεν@g; 
        s@\+@πλυσζειχψεν@g; 
        s@\[([^][]+)-([^][]+)\]@λκλαμμερ\1βισ\2ρκλαμμερ@g;
        s@\[([^][-]+)\]@λκλαμμερ\1ρκλαμμερ@g;
        s@\$+@ρεγεξενδε@g; 
        s@[[:punct:]]+@ @g; 
        s@ρεγεξστερν@.*@g; 
        s@ρεγεξανφανγ@^@g; 
        s@ρεγεξενδε@$@g; 
        s@φραγεζειχψεν@?@g;
        s@πλυσζειχψεν@+@g;
        s@λκλαμμερ(.)βισ(.)ρκλαμμερ@[\1-\2]@g;
        s@λκλαμμερ([[:alpha:]]+)ρκλαμμερ@[\1]@g;
        s@[ ]+@|@g; 
      ')
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
    -T | --[Tt]extauszug) stufe_textauszug=1 ;;
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

  if [[ ${#ohne_woerterliste_text} -gt 1 ]]; then
    json_speicher_datei=$( json_speicher_datei "${lemma_text} und ohne Wörter" )
  fi
  # keine Abfragen nur mit: * oder ?
  if [[ "${lemmaabfrage-}" == "*" ]] || [[ "${lemmaabfrage-}" =~ ^\*+$ ]] ;then
    meldung_abbruch "${ORANGE}Alle Lemmata abzufragen (--Lemmaabfrage '${lemmaabfrage}')  wird nicht unterstützt (Abbruch)${FORMAT_FREI}"
  fi
  if [[ "${lemmaabfrage-}" == "?" ]] || [[ "${lemmaabfrage-}" =~ ^[*?]+$ ]] ;then
    meldung_abbruch "${ORANGE}Alle Lemmata abzufragen (--Lemmaabfrage '${lemmaabfrage}')  wird nicht unterstützt (Abbruch)${FORMAT_FREI}"
  fi
  
  dateivariablen_bereitstellen $json_speicher_datei

  zusatzbemerkungen_htmldatei=$([[ "${ohne_woerterliste_regex}" == "" ]] && printf "" || printf "; der Liste wurden bewußt Wortverbindungen mit „${ohne_woerterliste}“ entnommen (diese wurden herausgefiltert).")
  
  zusatzbemerkungen_textdatei="Die Liste ist vorgruppiert geordnet nach den Grammatik-Angaben von Grimm,\nd.h. die Wörter sind nach Wortarten gruppiert: Eigenschaftswörter (Adjektive),\nNennwörter (Substantive), Tunwörter usw.."
  zusatzbemerkungen_textdatei=$([[ "${ohne_woerterliste_regex}" == "" ]] && printf "${zusatzbemerkungen_textdatei}" || printf "${zusatzbemerkungen_textdatei}\n\nDer Liste wurden bewußt Wortverbindungen mit „${ohne_woerterliste_text}“\nentnommen (diese wurden herausgefiltert).")
  
  
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
  meldung "${ORANGE}ENTWICKLUNG - stufe_formatierung:    $stufe_formatierung ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_fundstellen:     $stufe_fundstellen ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_verausgaben:     $stufe_verausgaben ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_dateienbehalten: $stufe_dateienbehalten ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - lemmaabfrage:          $lemmaabfrage ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - lemmaabfrage_api:      $lemmaabfrage_api ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - lemma_text:            $lemma_text ${FORMAT_FREI}"
  ;;
esac

# Programm Logik hier Anfang

# ZUTUN https://api.woerterbuchnetz.de/dictionaries/DWB/query/lemma,reflemma,variante=*theilen@OR@*teilen
# Problem: keine Grammatik gegeben
#   {
#     "formid": "Z13492",
#     "textidlist": [
#       [
#         64602688
#       ]
#     ],
#     "wordidlist": [
#       [
#         0
#       ]
#     ],
#     "wbsigle": "DWB",
#     "normlemma": "zwieteilen"
#   }
# ]
# dagegen: https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/${lemmaabfrage_api}/0/json
# [
#   {
#     "value": "A01587",
#     "label": "abtheilen",
#     "gram": ""
#   },

case $stufe_verausgaben in
 0)
  wget \
    --wait=2 --random-wait \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/${lemmaabfrage_api}/0/json" \
    --output-document="${json_speicher_datei}"
 ;;
 1)
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/${lemmaabfrage_api}/0/json)"
  wget --show-progress \
    --wait=2 --random-wait \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/${lemmaabfrage_api}/0/json" \
    --output-document="${json_speicher_datei}"
 ;;
esac


case $stufe_verausgaben in
 0)  ;;
 1) 
  printf "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} %s Ergebnisse …\n" $(jq '.|length' "${json_speicher_datei}")
  meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text})" 
 ;;
esac

if [[ -e "${json_speicher_datei}" ]];then
    cat "${json_speicher_datei}" | jq  --arg ohne_woerterliste_regex "${ohne_woerterliste_regex}" \
    -r '
  def woerterbehalten: ["DWB1", "DWB2"];
  def Anfangsgrosz:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^&#x00e4;"))
      then "&#x00C4;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^&#x00f6;"))
      then "&#x00D6;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^&#x00fc;"))
      then "&#x00DC;" +  (.[8:] |ascii_downcase) 
      else (.[:1]|ascii_upcase) + (.[1:] |ascii_downcase) 
      end
      )
    | join("");

  .
  | map({gram: (.gram), Wort: (.label|Anfangsgrosz), wort: (.label)})
  | unique_by(.wort) | sort_by(.gram,.wort ) 
  | .[] 
| if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.wort|test("\($ohne_woerterliste_regex)"))
      then empty
      elif (.Wort|test("\($ohne_woerterliste_regex)"))
      then empty
      else .
      end
  | if .gram == null or .gram == ""
  then "\(.wort);"
  elif (.gram|test("^ *f[_.,;]* *$|^ *fem[_.,;]* *$"))
  then "die \(.Wort);"
    elif (.gram|test("^ *f[_.,;]*\\? *$"))
    then "?die \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
    then "die o. der \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
    then "die o. das \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
    then "die o. das \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
    then "die o. das o. der \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
    then "die o. der o. das \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +nomen +actionis[.]* *$"))
    then "die \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +nomen +agentis[.]* *$"))
    then "die \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +subst. *$"))
    then "die \(.Wort);"
  elif (.gram|test("^ *m[_.,;]* *$"))
    then "der \(.Wort);"
    elif (.gram|test("^ *m[_.,;]*\\? *$"))
    then "?der \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
    then "der o. die \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* und +f[_.,;]* *$"))
    then "der u. die \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
    then "der o. das \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
    then "der o. die o. das \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
    then "der o. das o. die \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
    then "der \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
    then "der \(.Wort);"
  elif (.gram|test("^ *n[_.,;]* *$"))
    then "das \(.Wort);"
    elif (.gram|test("^ *n[_.,;]*\\? *$"))
    then "?das \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
    then "das o. der \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
    then "das o. die \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
    then "das o. der o. die \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
    then "das o. die o. der \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
    then "das \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
    then "das \(.Wort);"
  else "\(.wort);"
  end
  ' > "${datei_utf8_text_zwischenablage}" \
  && printf "%s\n\n%s\n\n" "${titel_text}" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage}" >> "${datei_utf8_reiner_text}"
else
  meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi

# als reine Textausgabe (sortiert nach Grammatik, Wort)
case $stufe_verausgaben in
 0)  ;;
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text_gram})" ;;
esac

cat "${json_speicher_datei}" | jq --arg ohne_woerterliste_regex "${ohne_woerterliste_regex}" \
  ' def woerterbehalten: ["DWB1", "DWB2"];
  def Anfangsgrosz:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^&#x00e4;"))
      then "&#x00C4;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^&#x00f6;"))
      then "&#x00D6;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^&#x00fc;"))
      then "&#x00DC;" +  (.[8:] |ascii_downcase) 
      else (.[:1]|ascii_upcase) + (.[1:] |ascii_downcase) 
      end
      )
    | join("");

. | map({gram: (.gram), Wort: (.label|Anfangsgrosz), wort: (.label)})
| unique_by(.wort) | sort_by(.gram,.wort ) 
| .[] 
| if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.wort|test("\($ohne_woerterliste_regex)"))
      then empty
      elif (.Wort|test("\($ohne_woerterliste_regex)"))
      then empty
      else .
      end
| if .gram == null or .gram == ""
then "\(.wort);"
elif (.gram|test("^ *f[_.,;]* *$|^ *fem[_.,;]* *$"))
then "die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]*\\? *$"))
  then "?die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
  then "die o. der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
  then "die o. das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
  then "die o. das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
  then "die o. das o. der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
  then "die o. der o. das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +nomen +actionis[.]* *$"))
  then "die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *f[_.,;]* +nomen +agentis[.]* *$"))
  then "die \(.Wort) (\(.gram));"

elif (.gram|test("^ *m[_.,;]* *$"))
  then "der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]*\\? *$"))
  then "?der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
  then "der o. die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* und +f[_.,;]* *$"))
  then "der u. die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
  then "der o. das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
  then "der o. die o. das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
  then "der o. das o. die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
  then "der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
  then "der \(.Wort) (\(.gram));"

elif (.gram|test("^ *n[_.,;]* *$"))
  then "das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]*\\? *$"))
  then "?das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
  then "das o. der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
  then "das o. die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
  then "das o. der o. die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
  then "das o. die o. der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
  then "das \(.Wort) (\(.gram));"
  elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
  then "das \(.Wort) (\(.gram));"

else "\(.wort) (\(.gram));"
end
  ' | sed -r 's@"@@g; ' | uniq > "${datei_utf8_text_zwischenablage_gram}"

if [[ -e "${datei_utf8_text_zwischenablage_gram}" ]];then
  # (3.1.) Sonderzeichen, Umlaute dekodieren in lesbare Zeichen als UTF8
  printf "%s\n\n%s\n\n" "${titel_text}" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text_gram}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
else
  meldung_abbruch "${ORANGE}Textdatei '${datei_utf8_reiner_text_gram}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi


case $lemma_text in
…*…) bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>${lemma_text}</i> zu tun haben)${zusatzbemerkungen_htmldatei-.}" ;;
…*)  bearbeitungstext_html="Liste noch nicht übearbeitet (es können auch Wörter enthalten sein, die nichts mit der Endung <i>$lemma_text</i> gemein haben)${zusatzbemerkungen_htmldatei-.}" ;;
*…)  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit dem Wortanfang <i>${lemma_text}</i> gemein haben)${zusatzbemerkungen_htmldatei-.}" ;;
*) bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>${lemma_text}</i> zu tun haben)${zusatzbemerkungen_htmldatei-.}" ;;
esac



html_technischer_hinweis_zur_verarbeitung="<p>Für die Techniker: Die Abfrage wurde mit <a href=\"https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/tree/main/DWB1#dwb-pss_lemmata-select_abfragen-und-ausgebensh\"><code>DWB-PSS_lemmata-select_abfragen-und-ausgeben.sh</code> (siehe GitHub)</a> duchgeführt.</p>\n";
case $stufe_formatierung in
 0)  ;;
 1|2|3)
  case $stufe_verausgaben in
  0)  ;;
  1) 
  meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" 
  if ! [[ "${ohne_woerterliste_regex}" == "" ]];then
  meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (ohne: $ohne_woerterliste_regex)"
  fi
  ;;
  esac
  #   --arg a v        set variable $a to value <v>;
  
  cat "${json_speicher_datei}" | jq --arg ohne_woerterliste_regex "${ohne_woerterliste_regex}" \
    ' sort_by(.gram,.label)[] 
    | if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.label|test("\($ohne_woerterliste_regex)"))
      then empty
      else .
      end
    |  if .gram == null or .gram == ""
  then "<tr><td>\(.label)</td><td><!-- keine Grammatik angegeben --><!-- ohne Sprachkunst-Begriff --></td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adje?c?t?[_.,;]* *$|^ *adje?c?t?[_.,;]* adje?c?t?[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Eigenschaftswort, Beiwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adje?c?t?[_.,;]*\\?[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ ?Eigenschaftswort, Beiwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adj[_.,;]* +und +adv[_.,;]* *$|^ *adj[_.,;]* +u. +adv[_.,;]* *$|^ *adj[_.,;]* +adv[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Eigenschaftswort, Beiwort und Umstandswort, Zuwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif  (.gram|test("^ *adv[_.,;] *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Umstandswort, Zuwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *f[_.,;]* *$|^ *fem[_.,;]* *$"))
  then "<tr><td>\(.label), die</td><td>\(.gram) ~ Nennwort, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]*\\? *$"))
  then "<tr><td>\(.label), die?</td><td>\(.gram) ~ Nennwort, ?weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.label), die o. der</td><td>\(.gram) ~ Nennwort, weiblich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.label), die o. das</td><td>\(.gram) ~ Nennwort, weiblich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
  then "<tr><td>\(.label), die o. das</td><td>\(.gram) ~ Nennwort, weiblich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.label), die o. das o. der</td><td>\(.gram) ~ Nennwort, weiblich o. sächlich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.label), die o. das o. der</td><td>\(.gram) ~ Nennwort, weiblich o. männlich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *f[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.label), die</td><td>\(.gram) ~ Nennwort einer Handlung, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.label), die</td><td>\(.gram) ~ Nennwort-Machende, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +subst. *$"))
  then "<tr><td>\(.label), die</td><td>\(.gram) ~ Nennwort, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *interj[.]?[;]? *$|^ *interjection[;]? *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Zwischenwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *m[_.,;]* *$"))
    then "<tr><td>\(.label), der</td><td>\(.gram) ~ Nennwort, männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]*\\? *$"))
    then "<tr><td>\(.label), der?</td><td>\(.gram) ~ Nennwort, ?männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.label), der o. die</td><td>\(.gram) ~ Nennwort, männlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* und +f[_.,;]* *$"))
    then "<tr><td>\(.label), der u. die</td><td>\(.gram) ~ Nennwort, männlich u. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
    then "<tr><td>\(.label), der o. das</td><td>\(.gram) ~ Nennwort, männlich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
    then "<tr><td>\(.label), der o. die o. das</td><td>\(.gram) ~ Nennwort, männlich o. weiblich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.label), der o. das o. die</td><td>\(.gram) ~ Nennwort, männlich o. sächlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
    then "<tr><td>\(.label), der</td><td>\(.gram) ~ Nennwort einer Handlung, männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
    then "<tr><td>\(.label), der</td><td>\(.gram) ~ Nennwort-Machender, männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* *$"))
    then "<tr><td>\(.label), das</td><td>\(.gram) ~ Nennwort, sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]*\\? *$"))
    then "<tr><td>\(.label), das?</td><td>\(.gram) ~ Nennwort, ?sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
    then "<tr><td>\(.label), das o. der</td><td>\(.gram) ~ Nennwort, sächlich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.label), das o. die</td><td>\(.gram) ~ Nennwort, sächlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.label), das o. der o. die</td><td>\(.gram) ~ Nennwort, sächlich o. männlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
    then "<tr><td>\(.label), das o. der o. die</td><td>\(.gram) ~ Nennwort, sächlich o. weiblich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
    then "<tr><td>\(.label), das</td><td>\(.gram) ~ Nennwort einer Handlung (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
    then "<tr><td>\(.label), das</td><td>\(.gram) ~ Nennwort-Machendes (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *part[icz]*[.]?[;]? *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Mittelwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj. *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ mittelwörtliches Eigenschaftswort, Beiwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj[ektiv]*[. ]+[oder ]*adv[erb]*.*$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ mittelwörtliches Eigenschaftswort oder Umstandswort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part.[ -]+adv.[ ]+adj.*$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ mittelwörtliches Umstandswort oder Eigenschaftswort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *präp[_.,;]* *$|^ *pr&#x00e4;p[_.,;]* *$|^ *praep[os]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Vorwort, Verhältniswort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *praet.[;]? *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Vergangenheit</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *pron[omen]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Vornennwort, Fürwort</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *subst. *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Nennwort (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *v. +u. +subst. +n. *$"))
  then "<tr><td>\(.label); \(.label), das</td><td>\(.gram) ~ Tunwort und Nennwort sächlich (Tunwort: auch Zeitwort, Tätigkeitswort; Nennwort: auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *v[_.,;]* *$|^ *vb[_.,;]* *$|^ *verb[_.,;]* *$|^ *verbum[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Tunwort (auch Zeitwort, Tätigkeitswort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  
  elif (.gram|test("^ *verbal[-]*adj[_.,;]+[ -–—]+adv[_.,;]* *$"))
  then "<tr><td>\(.label)</td><td>\(.gram) ~ Eigenschafts- oder Umstandswort tunwörtlichen Ursprungs</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  
  else "<tr><td>\(.label)</td><td>\(.gram) ~ ?</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>www.woerterbuchnetz.de/DWB/\(.label)</a></small></td><td><small><a href=“https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)”>https://www.woerterbuchnetz.de?sigle=DWB&amp;lemid=\(.value)</a></small></td></tr>"
  end
  ' | sed -r "s@\"@@g;
  s@“([^“”]+)”@\"\1\"@g;
s@&#x00e4;@ä@g;
s@&#x00f6;@ö@g;
s@&#x00fc;@ü@g;
s@<td>([^ ])([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>\U\1\L\2\E\3\4@g; # ersten Buchstaben Groß bei Nennwörtern
s@<td>(&#x00e4;|&#196;|&auml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00C4;\L\2\E\3\4@g; # ä Ä 
s@<td>(&#x00f6;|&#246;|&ouml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00D6;\L\2\E\3\4@g; # ö Ö
s@<td>(&#x00fc;|&#252;|&uuml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00DC;\L\2\E\3\4@g; # ü Ü 
1 i\<!DOCTYPE html>\n<html lang=\"de\" xml:lang=\"de\" xmlns=\"http://www.w3.org/1999/xhtml\">\n<head>\n<title></title>\n</head>\n<body><p>${bearbeitungstext_html}</p><!-- hierher Abkürzungsverzeichnis einfügen --><p>Diese Tabelle ist nach <i>Grammatik (Grimm)</i> buchstäblich vorsortiert gruppiert, also finden sich Tätigkeitswörter (Verben) beisammen, Eigenschaftswörter (Adjektive) beisammen, Nennwörter (Substantive), als auch Wörter ohne Angabe der Grammatik/Sprachkunst-Begriffe usw..</p><p>Zur Sprachkunst oder Grammatik siehe vor allem <i style=\"font-variant:small-caps;\">Schottel (1663)</i> das ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table id=\"Wortliste-Tabelle\"><thead><tr><th>Wort</th><th>Grammatik (<i>Grimm</i>) ~ Sprachkunst, Sprachlehre (s. a. <i style=\"font-variant:small-caps;\">Schottel&nbsp;1663</i>)</th><!--wbnetzkwiclink<th>Textauszug (gekürzt)</th>wbnetzkwiclink--><th>Verknüpfung1</th><th>Verknüpfung2</th></tr></thead><tbody>
$ a\</tbody></table>${html_technischer_hinweis_zur_verarbeitung}\n</body>\n</html>
" | sed --regexp-extended '
  s@<th>@<th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">@g;
  s@<body>@<body style="font-family: Antykwa Torunska, serif; background: white;">@;
  ' > "${datei_utf8_html_zwischenablage_gram}"
 
  meldung "${ORANGE}ENTWICKLUNG: sed ${datei_utf8_html_zwischenablage_gram} ${FORMAT_FREI}"
      
  case $stufe_fundstellen in
  1)  
  sed --in-place '# für sed später der wbnetzkwiclink in einzelner Zeile
  s@\(<wbnetzkwiclink>\)@\n\1@g; 
  s@\(</wbnetzkwiclink>\)@\1\n@g; 
  s@<!--wbnetzkwiclink@@g; 
  s@wbnetzkwiclink-->@@g; 
  ' "${datei_utf8_html_zwischenablage_gram}" 
  
    # Fundstellen Anfang
    meldung "${ORANGE}ENTWICKLUNG: Fundstellen${FORMAT_FREI}"
    # ZUTUN table is Missing
    i_textverknuepfung=1;
    abbruch_code_nummer=0
    n_textverknuepfung=$( grep --count '<wbnetzkwiclink>[^<>]*</wbnetzkwiclink>' "${datei_utf8_html_zwischenablage_gram}" ) && abbruch_code_nummer=$?
    case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
      meldung "${ORANGE}Irgendwas lief schief mit grep. Abbruch Code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI}" ;;
    esac
    case $stufe_verausgaben in
    0)  ;;
    1) meldung "${GRUEN}Weiterverarbeitung → JSON → HTML${FORMAT_FREI} ($n_textverknuepfung Fundstellen)" ;;
    esac
       
    echo "" > "${datei_diese_wbnetzkwiclink}"

    for wbnetzkwiclink_text in $( grep --only-matching '<wbnetzkwiclink>[^<>]*</wbnetzkwiclink>' "${datei_utf8_html_zwischenablage_gram}" );do
      datei_diese_fundstelle="${datei_utf8_html_zwischenablage_gram}.fundstelle_text.$i_textverknuepfung.txt"
      case $i_textverknuepfung in 1) echo '' > "${datei_diese_fundstelle}" ;; esac

      # echo $wbnetzkwiclink_text
      # Punkte pro 100 Bearbeitungsschritte ausgeben
      if [[ $(( $i_textverknuepfung % 100 )) -eq 0 ]];then
      printf '. %04d\n' $i_textverknuepfung;
      else
        if [[ ${i_textverknuepfung-0} -eq ${n_textverknuepfung--1} ]];then printf '.\n'; else printf '.'; fi
      fi

      wbnetzkwiclink=$( echo $wbnetzkwiclink_text | sed --regexp-extended 's@<wbnetzkwiclink>([^<>]+)</wbnetzkwiclink>@\1@' )
      printf "%s\n" "$wbnetzkwiclink" >> "${datei_diese_wbnetzkwiclink}"
      wbnetzkwiclink_regex_suchadresse=$(echo $wbnetzkwiclink_text | sed 's@/@\\/@g; ' )
      # https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/A07187/textid/697253/wordid/2
      textid=$( echo "${wbnetzkwiclink}" | sed --regexp-extended 's@.+/textid/([[:digit:]]+)/.+@\1@;' )

      fundstelle_text=$(
        wget --wait=2 --random-wait --quiet --no-check-certificate -O - "$wbnetzkwiclink"  | jq  --arg textid ${textid-0} --join-output ' .[]
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
      ) && abbruch_code_nummer=$?
      
      case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
        meldung "${ORANGE}Etwas lief schief … exit code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${NOFORMAT} (?wget, ?jq …)" ;;
      esac
      # echo "ENTWICKLUNG ${wbnetzkwiclink_regex_suchadresse}"
      echo "»${fundstelle_text}«" | sed --regexp-extended 's@»([ ;.:]+)@»…\1@g; s@«@…«@' > "${datei_diese_fundstelle}"
      # sed --in-place '/<\/body>/e cat Abkürzungen-GRIMM-Tabelle-DWB2.html' "${datei_utf8_html_zwischenablage_gram}"
      sed --in-place "/${wbnetzkwiclink_regex_suchadresse}/r ${datei_diese_fundstelle}" "${datei_utf8_html_zwischenablage_gram}"
      sed --in-place "/${wbnetzkwiclink_regex_suchadresse}/d" "${datei_utf8_html_zwischenablage_gram}"
      rm -- "${datei_diese_fundstelle}"

      i_textverknuepfung=$(( $i_textverknuepfung + 1 ))
    done
    # Falls HTML-Datei mit Tabelle vorhanden ist
    if [[ -e "Abkürzungen-GRIMM-Tabelle-DWB2.html"  ]];then
    sed --in-place '/<\/body>/e cat Abkürzungen-GRIMM-Tabelle-DWB2.html' "${datei_utf8_html_zwischenablage_gram}"

    sed --in-place 's@<!-- *hierher Abkürzungsverzeichnis einfügen *-->@<p>Siehe auch das <a href="#sec-GRIMM_Abkuerzungen">Abkürzungsverzeichnis</a>.</p>\n@' "${datei_utf8_html_zwischenablage_gram}"
    fi
    # Fundstellen Ende
  ;;  
  0)
    sed --in-place 's@<!--wbnetzkwiclink.*wbnetzkwiclink-->@@g' "${datei_utf8_html_zwischenablage_gram}"
  ;;
  esac
  

  case $stufe_verausgaben in
  0)  ;;
  1) meldung "${GRUEN}Weiterverarbeitung → JSON → HTML${FORMAT_FREI} (tidy: ${datei_utf8_html_gram_tidy})" ;;
  esac
  tidy -quiet -output "${datei_utf8_html_gram_tidy}"  "${datei_utf8_html_zwischenablage_gram}" 2> "${datei_utf8_html_gram_tidy_log}" || abbruch_code_nummer=$?

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
  1) meldung "${GRUEN}Weiterverarbeitung: HTML → ODT${FORMAT_FREI} (${datei_utf8_odt_gram})"
  if [[ -e ~/.pandoc/reference.odt ]]; then
  meldung "${GRUEN}Weiterverarbeitung: HTML → ODT, die Vorlage ~/.pandoc/reference.odt wird für das Programm${FORMAT_FREI} pandoc ${GRUEN}wahrscheinlich verwendet${FORMAT_FREI}"
  fi
  ;;
  esac

  if [[ -e "${datei_utf8_odt_gram}" ]];then
    # stat --print="%x" Datei ergibt "2022-11-09 23:58:34.685526884 +0100"
    datum=$( stat --print="%x" "${datei_utf8_odt_gram}" | sed --regexp-extended 's@^([^ ]+) ([^ .]+)\..*@\1_\2@' )
    datei_sicherung=${datei_utf8_odt_gram%.*}_${datum}.odt

    meldung  "${ORANGE}Vorhandene${FORMAT_FREI} ${datei_utf8_odt_gram} ${ORANGE}überschreiben?${FORMAT_FREI}"
    meldung  "  ${ORANGE}Falls „nein“, dann erfolgt Sicherung als${FORMAT_FREI}"
    meldung  "  → $datei_sicherung ${ORANGE}(würde also umbenannt)${FORMAT_FREI}"
    echo -en "  ${ORANGE}Jetzt überschreiben (JA/nein):${FORMAT_FREI} "
    read janein
    if [[ -z ${janein// /} ]];then janein="ja"; fi
    case $janein in
      [jJ]|[jJ][aA])
        echo "  überschreibe ODT …"
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
