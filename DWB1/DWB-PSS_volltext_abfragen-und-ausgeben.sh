#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

abhaenigkeiten_pruefen() {
  local stufe_abbruch=0

  if ! [[ -x "$(command -v jq)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} jq ${ORANGE} zum Verarbeiten von JSON nicht gefunden: Bitte${FORMAT_FREI} jq ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v pandoc)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} pandoc ${ORANGE} zum Erstellen von Dokumenten in HTML, ODT, MD nicht gefunden: Bitte${FORMAT_FREI} pandoc ${ORANGE}über die Programm-Verwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
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
  cat <<NUTZUNG
Nutzung:
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] [-H] [-O] [-S "…"] -V "stupere"

Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
- Textdatei reine Wortliste (ohne Zusätzliches)
- Textdatei mit Grammatik-Einträgen
Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programm pandoc).

Verwendbare Wahlmöglichkeiten:
-h,    --Hilfe             Hilfetext dieses Programms ausgeben.

-v,-V  --Volltextabfrage   Pflichtfeld für die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.
-S     --Stichwortabfrage  zusätzliche Einschränkung der möglichen Stichworte, es werden nicht alle abgefragt, sondern
                           die hier angegebene Sucheinschränkung, einfache reguläre Ausdrücke anwendbar, z.B.:
                           --Stichwortabfrage "*lösen*" 
                           --Stichwortabfrage "*heili*, *heils*, *heilb*"
                            *        = 0 bis viele
                            ?        = 0 bis 1
                            [aeiou]+ = 1 bis viele Buchstaben: a oder e oder i, o, u oder mehrere in Verbindung zusammen
                            [a-f]+   = 1 bis viele Buchstaben: a oder b, c, d, e, f oder mehrere in Verbindung zusammen
-o,    --ohne              ohne diese Wörterliste – einfache reguläre Ausdrücke anwendbar
-e,    --eineinzig         Ergebnisliste verringern, daß nur jedes Stichwort einmal vorkommt
-H,    --HTML              HTML Datei erzeugen
-O,    --ODT               ODT Datei (für LibreOffice) erzeugen
-T,    --Telegrammarkdown  MD  Datei (für Text in Markdown bei Telegram) erzeugen
-b,    --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-s,    --stillschweigend   Kaum Meldungen ausgeben
       --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
       --farb-frei         Meldungen ohne Farben ausgeben

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
      1) meldung "${ORANGE}Abschluß: lösche unwichtige Dateien …${FORMAT_FREI}" ;;
      esac
      if [[ -e "${json_speicher_datei-}" ]];then                             rm -- "${json_speicher_datei}"; fi
      if [[ -e "${datei_utf8_text_zwischenablage-}" ]];then                  rm -- "${datei_utf8_text_zwischenablage}"; fi
      if [[ -e "${datei_utf8_text_zwischenablage_gram-}" ]];then             rm -- "${datei_utf8_text_zwischenablage_gram}"; fi
      if [[ -e "${datei_utf8_html_zwischenablage_gram-}" ]];then             rm -- "${datei_utf8_html_zwischenablage_gram}"; fi
      case $stufe_formatierung in 3)
        if [[ -e "${datei_utf8_html_gram_tidy_log-}" ]];then      rm -- "${datei_utf8_html_gram_tidy_log}"; fi
      esac
      case $stufe_formatierung in 2)
        if [[ -e "${datei_utf8_html_gram_tidy-}" ]];then         rm -- "${datei_utf8_html_gram_tidy}"; fi
        if [[ -e "${datei_utf8_html_gram_tidy_log-}" ]];then     rm -- "${datei_utf8_html_gram_tidy_log}"; fi
      ;;
      esac
      case $stufe_formatierung in 1)
        if [[ -e "${datei_utf8_odt_gram-}" ]];then               rm -- "${datei_utf8_odt_gram}"; fi
        if [[ -e "${datei_utf8_html_gram_tidy_log-}" ]];then     rm -- "${datei_utf8_html_gram_tidy_log}"; fi
      ;;
      esac
      if [[ -e "${json_speicher_all_query_datei-}" ]];then                   rm -- "${json_speicher_all_query_datei}"; fi
      if [[ -e "${json_speicher_allquery_datei_zwischenablage-}" ]];then     rm -- "${json_speicher_allquery_datei_zwischenablage}"; fi
      if [[ -e "${json_speicher_datei_zwischenablage-}" ]];then              rm -- "${json_speicher_datei_zwischenablage}"; fi
      if [[ -e "${json_speicher_vereinte_abfragen_zwischenablage-}" ]];then  rm -- "${json_speicher_vereinte_abfragen_zwischenablage}"; fi
      if [[ -e "${json_speicher_filter_ueber_textid_verknuepfen-}" ]];then   rm -- "${json_speicher_filter_ueber_textid_verknuepfen}"; fi
      if [[ -e "${datei_diese_wbnetzkwiclink-}" ]];then                      rm -- "${datei_diese_wbnetzkwiclink}"; fi

      # if [[ -e "${datei_utf8_html_gram_tidy_markdown_telegram}" ]];then               rm -- "${datei_utf8_html_gram_tidy_markdown_telegram}"; fi      
    fi
    case ${stufe_verausgaben:-0} in
    0)  ;;
    1)
      if [[ $( find . -maxdepth 1 -iname "${json_speicher_datei%.*}*" ) ]];then
      meldung "${ORANGE}Abschluß: Folgende Dateien sind erstellt worden:${FORMAT_FREI}" ;
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
# json_speicher_datei volltext_text mit_woerterliste_text
json_speicher_datei() {
  local volltextabfrage=${1-unbekannt}
  local stichwortabfrage=${2-}
  local diese_json_speicher_datei=''
  local diese_datei_vorsilbe=$(echo "$volltextabfrage" | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…+$@…@')
  local diese_datei_zeichenkette_stichwoerter=$(echo $stichwortabfrage | sed --regexp-extended 's@[,;]+@ @g; s@[[:punct:]]+@…@g; s@^…{2,}@@; s@ +@, @g; s@…+$@…@g; s@^([^, ]+, [^, ]+, [^, ]+), .+@\1 usw.@; ')
  
  if [[ -z "${stichwortabfrage-}" ]]; then
    diese_json_speicher_datei=$( printf "%s_Volltext-Abfrage-DWB1_%s.json" "${diese_datei_vorsilbe}" $(date '+%Y%m%d') );
  else
    diese_json_speicher_datei=$(printf "%s_im-Volltext_+_Stichwort-„%s“_DWB1_%s.json" \
      "${diese_datei_vorsilbe}" \
      "${diese_datei_zeichenkette_stichwoerter}" \
      $(date '+%Y%m%d'));
  fi
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
  datei_utf8_html_gram_tidy_log="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram_tidy.html.log"
  datei_utf8_html_gram_tidy_markdown_telegram="${diese_json_speicher_datei%.*}-utf8_Wortliste+gram_tidy_(Telegram).md"

  datei_utf8_odt_gram="${diese_json_speicher_datei%.*}_Wortliste+gram.odt"
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
  stufe_verausgaben=1
  stufe_formatierung=0
  stufe_markdown_telegram=0
  stufe_aufraeumen_aufhalten=0
  stufe_dateienbehalten=0
  stufe_stichwortabfrage=0
  # 0 = keine Stichworte begrenzen
  # 1 = Stichworte begrenzen (eineinzig)
  # 2 = mit tatsächlicher Stichwortliste oder ohne_woerterliste oder mit_woerterliste
  stufe_stichworte_eineinzig=0
  # Grundlage: rein Text, und mit Grammatik
  # zusätzlich
  # 2^0: 1-1 = 0 rein Text, und mit Grammatik
  # 2^1: 2-1 = 1 nur mit HTML
  #      3-1 = 2 nur mit ODT
  # 2^2: 4-1 = 3 mit HTML, mit ODT
  abbruch_code_nummer=0
  n_suchergebnisse_volltext=0
  n_suchergebnisse_volltext_mit_stichwort=0
  volltextabfrage=''
  volltext_text=''
  stichwortabfrage=''
  mit_woerterliste_text=''
  mit_woerterliste=''
  mit_woerterliste_regex=''
  
  hinweis_stichwortliste_html=""
  zusatzbemerkungen_textdatei=''

  ohne_woerterliste_regex='' # ZUTUN
  ohne_woerterliste='' # ZUTUN
  ohne_woerterliste_text='' # ZUTUN
  json_speicher_datei=$(json_speicher_datei unbekannt)
  titel_text="Volltextsuche „??“ aus Grimm-Wörterbuch ($datum_heute_lang)"
  # param=''

  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --[Hh]ilfe) stufe_aufraeumen_aufhalten=1; nutzung ;;
    --debug) set -x ;;
    -b | --behalte_Dateien) stufe_dateienbehalten=1 ;;
    -e | --eineinzig) 
      stufe_stichwortabfrage=1; 
      stufe_stichworte_eineinzig=1 
      ;;
    -s | --stillschweigend) stufe_verausgaben=0 ;;
    --farb-frei) FARB_FREI=1 ;;
    -[Vv] | --[Vv]olltextabfrage)  # Parameter
      volltextabfrage="${2-}"
      volltext_text=$(echo "$volltextabfrage" | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…{2,}$@@')
      shift
      ;;
    -S | --[Ss]tichwortabfrage)  # Parameter
      stichwortabfrage="${2-}"
      mit_woerterliste_text=$(echo "$stichwortabfrage" | sed --regexp-extended '
        s@\*+@ρεγεξ@g; 
        s@[[:punct:]]+@ @g; 
        s@ρεγεξ@…@g; 
        s@(^…{2,}|…{2,}$)@@; 
        s@[ ]+@, @g; 
        ')
      mit_woerterliste_regex=$(echo "$stichwortabfrage" | sed --regexp-extended '
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
      stufe_stichwortabfrage=2

      shift
      ;;
    -H | --[Hh][Tt][Mm][Ll])
      # Stufe: 1 oder 3
      case $stufe_formatierung in
      0) stufe_formatierung=1 ;;
      1|3) stufe_formatierung=$stufe_formatierung ;;
      2) stufe_formatierung=$(( $stufe_formatierung + 1 )) ;;
      *) stufe_formatierung=1 ;;
      esac
      ;;
    -O | --[Oo][Dd][Tt])
      # Stufe: 2 oder 3
      case $stufe_formatierung in
      0) stufe_formatierung=2 ;;
      1) stufe_formatierung=$(( $stufe_formatierung + 2 )) ;;
      2|3) stufe_formatierung=$stufe_formatierung ;;
      *) stufe_formatierung=2 ;;
      esac
    ;;
    -T | --[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm][Mm][Aa][Rr][Cc][Dd][Oo][Ww][Nn])
      # Stufe: 1 oder 3
      case $stufe_formatierung in
      0) stufe_formatierung=1 ;;
      1|3) stufe_formatierung=$stufe_formatierung ;;
      2) stufe_formatierung=$(( $stufe_formatierung + 1 )) ;;
      *) stufe_formatierung=1 ;;
      esac
      stufe_markdown_telegram=1
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
      stufe_stichwortabfrage=2
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

  argumente=("$@")

  # check required params and arguments
  # [[ -z "${param-}" ]] && meldung_abbruch "Missing required parameter: param"
  # [[ ${#argumente[@]} -eq 0 ]] && meldung "${ROT}Fehlendes Lemma, das abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung
  [[ -z "${volltextabfrage-}" ]] && meldung "${ROT}Fehlender Volltext, der abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung

  case $stufe_stichwortabfrage in
  0|1) json_speicher_datei=$(json_speicher_datei "$volltext_text");
     titel_text="Volltextsuche „$volltext_text“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
     ;;
  # 1) json_speicher_datei=$(json_speicher_datei "$volltext_text" "${mit_woerterliste_text}");
  #     titel_text="Volltextsuche „$volltext_text“ mit Stichwort „${mit_woerterliste_text}“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
  #     ;;
  2) json_speicher_datei=$(json_speicher_datei "$volltext_text" "${mit_woerterliste_text}");
     titel_text="Volltextsuche „$volltext_text“ mit Stichwort „${mit_woerterliste_text}“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
     ;;
  esac
  
  # keine Abfragen nur mit: * oder ?
  if [[ "${volltextabfrage-}" == "*" ]] || [[ "${volltextabfrage-}" =~ ^\*+$ ]] ;then
    meldung_abbruch "${ORANGE}Alles als Volltext abzufragen (--Volltextabfrage '${volltextabfrage}')  wird nicht unterstützt (Abbruch)${FORMAT_FREI}"
  fi
  if [[ "${volltextabfrage-}" == "?" ]] || [[ "${volltextabfrage-}" =~ ^[*?]+$ ]] ;then
    meldung_abbruch "${ORANGE}Fragezeichen oder mehrere *** als Volltext abzufragen (--Volltextabfrage '${volltextabfrage}')  wird nicht unterstützt (Abbruch)${FORMAT_FREI}"
  fi
  dateivariablen_filter_bereitstellen "${json_speicher_datei}"
  abhaenigkeiten_pruefen
  json_filter_code > "${json_speicher_filter_ueber_textid_verknuepfen}"
  
  zusatzbemerkungen_textdatei="Die Liste ist vorgruppiert geordnet nach den Grammatik-Angaben von Grimm,\nd.h. die Wörter sind nach Wortarten gruppiert: Eigenschaftswörter (Adjektive),\nNennwörter (Substantive), Tunwörter usw.."
  zusatzbemerkungen_textdatei=$([[ "${mit_woerterliste_regex}" == "" ]] \
    && printf "${zusatzbemerkungen_textdatei}" \
    || printf "${zusatzbemerkungen_textdatei}\n\nDie Liste wurde bewußt auf Worte mit „${mit_woerterliste_text}“\nbeschränkt.")
    
  zusatzbemerkungen_textdatei=$([[ "${ohne_woerterliste_regex}" == "" ]] \
    && printf "${zusatzbemerkungen_textdatei}" \
    || ( [[ ${#zusatzbemerkungen_textdatei} -gt 1 ]] \
      && printf "${zusatzbemerkungen_textdatei%.*},\n und bewußt ohne die Worte „${ohne_woerterliste_text}“\nweiter eingerenzt." \
      || printf "${zusatzbemerkungen_textdatei}" ) )
  
  case $stufe_stichworte_eineinzig in 1) 
    zusatzbemerkungen_textdatei=$( [[ ${#zusatzbemerkungen_textdatei} -gt 1 ]] \
      && printf "${zusatzbemerkungen_textdatei%.*},\n es wurden nur die ersten Fundstellen berücksichtigt,\n und alle weiteren Fundstellen innerhalb eines Stichwortes entfernt." \
      || printf "${zusatzbemerkungen_textdatei}" )
  ;; 
  esac
  
  case $stufe_stichwortabfrage in 
  1) 
    # hinweis_stichwortliste_html=", die Liste ist auf die Stichworte <i>${mit_woerterliste_text}</i> beschränkt." 
    case $stufe_stichworte_eineinzig in 
    0)
      hinweis_stichwortliste_html="" 
      ;;
    1) 
      hinweis_stichwortliste_html=", der Liste Stichworte wurde beschränkt auf die allersten Fundstellen." 
      ;;
    esac
  ;;
  2) # ZUTUN WEITER
    if [[ ${#mit_woerterliste_text} -gt 1 ]];then 
      hinweis_stichwortliste_html=", die Liste ist auf die Stichworte <i>${mit_woerterliste_text}</i> beschränkt." 
    fi
    if [[ ${#ohne_woerterliste_text} -gt 1 ]];then 
      hinweis_stichwortliste_html="${hinweis_stichwortliste_html%.*}, und bewußt ohne die Worte „<i>${ohne_woerterliste_text}</i>“ weiter eingerenzt."
    fi
    case $stufe_stichworte_eineinzig in 1) 
      hinweis_stichwortliste_html="${hinweis_stichwortliste_html%.*}&nbsp;&emdash; es wurden nur die ersten Fundstellen berücksichtigt, und alle weiteren Fundstellen innerhalb eines Stichwortes entfernt." 
      ;;
    esac
  ;;
  0|*) hinweis_stichwortliste_html='' ;; 
  esac


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
  meldung "${ORANGE}ENTWICKLUNG - stufe_formatierung:              $stufe_formatierung ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_verausgaben:               $stufe_verausgaben ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_stichwortabfrage:          $stufe_stichwortabfrage ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_stichworte_eineinzig:      $stufe_stichworte_eineinzig${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stufe_dateienbehalten:           $stufe_dateienbehalten ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - volltextabfrage:                 $volltextabfrage ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - volltext_text:                   $volltext_text ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - stichwortabfrage:                $stichwortabfrage ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - mit_woerterliste_text:           $mit_woerterliste_text ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - mit_woerterliste_regex:          $mit_woerterliste_regex ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - ohne_woerterliste_regex:         $ohne_woerterliste_regex ${FORMAT_FREI}"
  meldung "${ORANGE}ENTWICKLUNG - ohne_woerterliste_text:          $ohne_woerterliste_text ${FORMAT_FREI}"
  ;;
esac

# Programm Logik hier Anfang
# https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=*fug*;lemma,reflemma,variante=*fug*?token=Cs6lg4S7KFR6z9XZikhWY9oBSEBnt3ew&pageSize=20&pageNumber=1&_=1669804417852
case $stufe_verausgaben in
 0) wget \
      --quiet --wait 2 --random-wait "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage" \
      --output-document="${json_speicher_datei}" \
      && wget \
      --quiet --wait 2 --random-wait "https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=${volltextabfrage// /;all=}" \
      --output-document="${json_speicher_all_query_datei}";
 ;;
 1) 
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage)"
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=${volltextabfrage// /;all=})"
  wget --show-progress  --wait 2 --random-wait \
    --quiet "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage" \
    --output-document="${json_speicher_datei}" \
    && wget --show-progress  --wait 2 --random-wait \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=${volltextabfrage// /;all=}" \
      --output-document="${json_speicher_all_query_datei}";
 ;;
esac


case $stufe_verausgaben in
 0)  ;;
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text})" ;;
esac

if [[ -e "${json_speicher_datei}" ]];then
  # cat ./test/stupere.json | jq ' .result_count '
  # cat "${json_speicher_datei}" | jq ' .result_set[] | .lemma | tostring '
  n_suchergebnisse_volltext=$( cat "${json_speicher_datei}" | jq ' .result_count ' ) && abbruch_code_nummer=$?
  case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    meldung "${ORANGE}Irgendwas lief schief mit cat … jq. Abbruch Code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI}" ;;
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
  
  case $stufe_stichworte_eineinzig in 1)
    jq --slurp \
    --arg stufe_stichworte_eineinzig $stufe_stichworte_eineinzig \
    '. | if ($stufe_stichworte_eineinzig|tonumber) > 0
      then (sort_by(.gram, .lemma) |unique_by(.lemma,.gram))
      else .
      end
      | flatten[]
    ' "${json_speicher_vereinte_abfragen_zwischenablage}" > 'zeitweiliges.json' \
    && mv 'zeitweiliges.json' "${json_speicher_vereinte_abfragen_zwischenablage}"  ;;
  esac
  case $stufe_stichwortabfrage in 2) 
    jq \
  --arg mit_woerterliste_regex "${mit_woerterliste_regex}" \
    --arg ohne_woerterliste_regex "${ohne_woerterliste_regex}" \
    '. | if ($mit_woerterliste_regex|length) == 0
      then .
      elif (.lemma|test("\($mit_woerterliste_regex)"))
      then .
      else empty
      end
    | if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.lemma|test("\($ohne_woerterliste_regex)"))
      then empty
      else .
      end
  ' "${json_speicher_vereinte_abfragen_zwischenablage}" > 'zeitweiliges.json' \
  && mv 'zeitweiliges.json' "${json_speicher_vereinte_abfragen_zwischenablage}"
 
  ;; 
  esac
  
  n_suchergebnisse_volltext_mit_stichwort=$( jq '.|length' -s "${json_speicher_vereinte_abfragen_zwischenablage}" );
  
  if [[ ${n_suchergebnisse_volltext-0} -eq 0 ]];then
    meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' enthält $n_suchergebnisse_volltext Volltext-Suchergebnisse, $n_suchergebnisse_volltext_mit_stichwort Stichwort-Suchergebnisse (Abbruch)${FORMAT_FREI}"
  fi
  
  dieser_jq_filter_code='
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

  .result_set
  | map({gram: (.gram), Wort: (.lemma|Anfangsgrosz), wort: (.lemma)})
  | unique_by(.wort, .gram)  | sort_by(.gram, .wort) 
  | .[] 
| if ($mit_woerterliste_regex|length) == 0
      then .
      elif (.wort|test("\($mit_woerterliste_regex)"))
      then .
      elif (.Wort|test("\($mit_woerterliste_regex)"))
      then .
      else empty
      end
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
  '
  cat "${json_speicher_datei}" | jq -r  \
    --arg mit_woerterliste_regex "${mit_woerterliste_regex}" \
    --arg ohne_woerterliste_regex "${ohne_woerterliste_regex}" \
    "${dieser_jq_filter_code}" > "${datei_utf8_text_zwischenablage}" \
  && printf "%s\n\n%s\n\n" "${titel_text}" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage}" >> "${datei_utf8_reiner_text}"
  # ZUTUN anfügen der eingeschrängten Wörterliste

else
  meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi

# als reine Textausgabe (sortiert nach Grammatik, Wort)
case $stufe_verausgaben in
 0)  ;;
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text_gram})" ;;
esac

dieser_jq_filter_code=' def woerterbehalten: ["DWB1", "DWB2"];
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

  .result_set
  | map({gram: (.gram), Wort: (.lemma|Anfangsgrosz), wort: (.lemma)})
  | unique_by(.wort, .gram)  | sort_by(.gram, .wort) 
  | .[] 
| if ($mit_woerterliste_regex|length) == 0
      then .
      elif (.wort|test("\($mit_woerterliste_regex)"))
      then .
      elif (.Wort|test("\($mit_woerterliste_regex)"))
      then .
      else empty
      end
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
    elif (.gram|test("^ *f[_.,;]* +subst. *$"))
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
  '

# cat "${json_speicher_datei}" | jq "${dieser_jq_filter_code}" | sed -r 's@"@@g; ' | uniq > "${datei_utf8_text_zwischenablage_gram}"

cat "${json_speicher_datei}" | jq -r  \
    --arg mit_woerterliste_regex "${mit_woerterliste_regex}" \
    --arg ohne_woerterliste_regex "${ohne_woerterliste_regex}" \
  "${dieser_jq_filter_code}" > "${datei_utf8_text_zwischenablage_gram}" \
  && printf "%s\n\n%s\n\n" "${titel_text}" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text_gram}" \
  && pandoc -f html -t plain "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
# ZUTUN anfügen der eingeschrängten Wörterliste
  
  # if [[ -e "${datei_utf8_text_zwischenablage_gram}" ]];then
  #   # (3.1.) Sonderzeichen, Umlaute dekodieren in lesbare Zeichen als UTF8
  #   printf "%s\n\n" "${titel_text}" > "${datei_utf8_reiner_text_gram}" \
  #   && pandoc -f html -t plain "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
  # else
  #   meldung_abbruch "${ORANGE}Textdatei '${datei_utf8_reiner_text_gram}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
  # fi


case $volltext_text in
…*…) bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Volltext-Abfrage <i>${volltext_text}</i> zu tun haben)${hinweis_stichwortliste_html-.}" ;;
…*)  bearbeitungstext_html="Liste noch nicht übearbeitet (es können auch Wörter enthalten sein, die nichts mit dem Wortende (im Volltext) <i>$volltext_text</i> gemein haben)${hinweis_stichwortliste_html-.}" ;;
*…)  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit dem Wortanfang (im Volltext) <i>${volltext_text}</i> gemein haben)${hinweis_stichwortliste_html-.}" ;;
*)   bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Volltext-Abfrage <i>${volltext_text}</i> zu tun haben)${hinweis_stichwortliste_html-.}" ;;
esac

html_technischer_hinweis_zur_verarbeitung="<p>Für die Techniker: Die Abfrage wurde mit <a href=\"https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-de/tree/main/DWB1#dwb-pss_volltext_abfragen-und-ausgebensh\"><code>DWB-PSS_volltext_abfragen-und-ausgeben.sh</code> (siehe GitHub)</a> duchgeführt.</p>\n";


case $stufe_formatierung in
 0)  ;;
 1|2|3)
  case $stufe_verausgaben in
  0)  ;;
  1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" ;;
  esac
  jq  \
  ' . |  sort_by(.gram,.lemma)[] |  if .gram == null or .gram == ""
  then "<tr><td>\(.lemma)</td><td><!-- keine Grammatik angegeben --><!-- ohne Sprachkunst-Begriff --></td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adje?c?t?[_.,;]* *$|^ *adje?c?t?[_.,;]* adje?c?t?[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Eigenschaftswort, Beiwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adje?c?t?[_.,;]*\\?[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ ?Eigenschaftswort, Beiwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adj[_.,;]* +und +adv[_.,;]* *$|^ *adj[_.,;]* +u. +adv[_.,;]* *$|^ *adj[_.,;]* +adv[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Eigenschaftswort, Beiwort und Umstandswort, Zuwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif  (.gram|test("^ *adv[_.,;] *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Umstandswort, Zuwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *f[_.,;]* *$|^ *fem[_.,;]* *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram) ~ Nennwort, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]*\\? *$"))
  then "<tr><td>\(.lemma), die?</td><td>\(.gram) ~ Nennwort, ?weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.lemma), die o. der</td><td>\(.gram) ~ Nennwort, weiblich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.lemma), die o. das</td><td>\(.gram) ~ Nennwort, weiblich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
  then "<tr><td>\(.lemma), die o. das</td><td>\(.gram) ~ Nennwort, weiblich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.lemma), die o. das o. der</td><td>\(.gram) ~ Nennwort, weiblich o. sächlich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.lemma), die o. das o. der</td><td>\(.gram) ~ Nennwort, weiblich o. männlich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *f[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram) ~ Nennwort einer Handlung, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram) ~ Nennwort-Machende, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +subst. *$"))
  then "<tr><td>\(.lemma), die</td><td>\(.gram) ~ Nennwort, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *interj[.]?[;]? *$|^ *interjection[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Zwischenwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *m[_.,;]* *$"))
  then "<tr><td>\(.lemma), der</td><td>\(.gram) ~ Nennwort, männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]*\\? *$"))
  then "<tr><td>\(.lemma), der?</td><td>\(.gram) ~ Nennwort, ?männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.lemma), der o. die</td><td>\(.gram) ~ Nennwort, männlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* und +f[_.,;]* *$"))
  then "<tr><td>\(.lemma), der u. die</td><td>\(.gram) ~ Nennwort, männlich u. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.lemma), der o. das</td><td>\(.gram) ~ Nennwort, männlich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.lemma), der o. die o. das</td><td>\(.gram) ~ Nennwort, männlich o. weiblich o. sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.lemma), der o. das o. die</td><td>\(.gram) ~ Nennwort, männlich o. sächlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.lemma), der</td><td>\(.gram) ~ Nennwort einer Handlung, männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.lemma), der</td><td>\(.gram) ~ Nennwort-Machender, männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

elif (.gram|test("^ *n[_.,;]* *$"))
  then "<tr><td>\(.lemma), das</td><td>\(.gram) ~ Nennwort, sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]*\\? *$"))
  then "<tr><td>\(.lemma), das?</td><td>\(.gram) ~ Nennwort, ?sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.lemma), das o. der</td><td>\(.gram) ~ Nennwort, sächlich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.lemma), das o. die</td><td>\(.gram) ~ Nennwort, sächlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.lemma), das o. der o. die</td><td>\(.gram) ~ Nennwort, sächlich o. männlich o. weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.lemma), das o. der o. die</td><td>\(.gram) ~ Nennwort, sächlich o. weiblich o. männlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.lemma), das</td><td>\(.gram) ~ Nennwort einer Handlung, sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.lemma), das</td><td>\(.gram) ~ Nennwort-Machendes, sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *part[icz]*[.]?[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Mittelwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*.[ -]+adj. *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ mittelwörtliches Eigenschaftswort, Beiwort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj[ektiv]*[. ]+[oder ]*adv[erb]*.*$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ mittelwörtliches Eigenschaftswort oder Umstandswort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part.[ -]+adv.[ ]+adj.*$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ mittelwörtliches Umstandswort oder Eigenschaftswort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *pr&#x00e4;p[_.,;]* *$|^ *praep[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Vorwort, Verhältniswort</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *praet.[;]? *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Vergangenheit</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *subst. *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Nennwort (auch Dingwort, Hauptwort, Namenwort, Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *v. +u. +subst. +n. *$"))
  then "<tr><td>\(.lemma); \(.lemma), das</td><td>\(.gram) ~ Tunwort und Nennwort sächlich (Tunwort: auch Zeitwort, Tätigkeitswort; Nennwort: auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *schwaches +verbum *$|^ *sw[_.,;]* +vb[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Tunwort schwach (auch Zeitwort, Tätigkeitswort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *v[_.,;]* *$|^ *vb[_.,;]* *$|^ *verb[_.,;]* *$|^ *verbum[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Tunwort (auch Zeitwort, Tätigkeitswort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *verbal[-]*adj[_.,;]+[ -–—]adv[_.,;]* *$"))
  then "<tr><td>\(.lemma)</td><td>\(.gram) ~ Eigenschafts- oder Umstandswort tunwörtlichen Ursprungs</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  else "<tr><td>\(.lemma)</td><td>\(.gram) ~ ?</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.lemma)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

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
s@<td>([^ ])([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>\U\1\L\2\E\3\4@g; # ersten Buchstaben Groß bei Nennwörtern
s@<td>(&#x00e4;|&#196;|&auml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00C4;\L\2\E\3\4@g; # ä Ä 
s@<td>(&#x00f6;|&#246;|&ouml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00D6;\L\2\E\3\4@g; # ö Ö
s@<td>(&#x00fc;|&#252;|&uuml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00DC;\L\2\E\3\4@g; # ü Ü 

1 i\<!DOCTYPE html>\n<html lang=\"de\" xml:lang=\"de\" xmlns=\"http://www.w3.org/1999/xhtml\">\n<head>\n<title></title>\n</head>\n<body><p>${bearbeitungstext_html}</p><p><i style=\"font-variant:small-caps;\">Schottel (1663)</i> ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><!-- hierher Abkürzungsverzeichnis einfügen --><p>Man beachte die Formatierungen der Fundstellen im DWB1: <i>schräge Schrift</i> deutet meistens auf Erklärungen, Beschreibungen der GRIMMs selbst, während nicht-schräge (aufrechte Schrift) entweder ein Lemma (Wort im Wörterbuch) ist, oder meistens Beispiele aus Literatur sind (Textstellen zitierter Literatur oft auch Quellenangabe, Gedichtzeilentext u.ä.). Diese Tabelle ist nach <i>Grammatik (Grimm)</i> buchstäblich vorsortiert gruppiert, also finden sich Tunwörter (Tätigkeitswörter, Verben) beisammen, Eigenschaftswörter (Adjektive) beisammen, Nennwörter (Hauptwörter, Substantive), als auch die Wörter bei denen GRIMM keine Angabe der Grammatik/Sprachkunst-Begriffe gemacht haben oder sie vergessen wurden.</p><table id=\"Wortliste-Tabelle\"><tr><th>Wort</th><th>Grammatik (<i>Grimm</i>) ~ Sprachkunst, Sprachlehre (s. a. <i style=\"font-variant:small-caps;\">Schottel&nbsp;1663</i>)</th><th>Fundstelle (gekürzt)</th><th>Haupteintrag</th><th>Verknüpfung Textstelle</th></tr>
$ a\</table>${html_technischer_hinweis_zur_verarbeitung}\n</body>\n</html>
" | sed --regexp-extended '
  s@<th>@<th style="border-top:2px solid gray;border-bottom:2px solid gray;">@g;
  ' \
  > "${datei_utf8_html_zwischenablage_gram}"


  case $stufe_verausgaben in
  0)  ;;
  1) 
    case $stufe_stichwortabfrage in
    0) 
      meldung "${GRUEN}Weiterverarbeitung → HTML (wbnetzkwiclink: ${ORANGE}$n_suchergebnisse_volltext Fundstellen${GRUEN} abfragen)${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" 
      ;;
    1|2)       
      meldung "${GRUEN}Weiterverarbeitung → HTML (wbnetzkwiclink: ${ORANGE}$n_suchergebnisse_volltext_mit_stichwort Fundstellen (aus $n_suchergebnisse_volltext Volltext-Funden)${GRUEN} abfragen)${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" 
    ;;
    esac

  ;;
  esac

  i_textverknuepfung=1;
  n_textverknuepfung=$( grep --count '<wbnetzkwiclink>[^<>]*</wbnetzkwiclink>' "${datei_utf8_html_zwischenablage_gram}" ) && abbruch_code_nummer=$?
  case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    msg "${ORANGE}Irgendwas lief schief mit grep. Abbruch Code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI}" ;;
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
      wget --wait 5 --random-wait --quiet --no-check-certificate -O - "$wbnetzkwiclink"  | jq  --arg textid ${textid-0} --join-output ' .[]
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
    ) && this_exit_code=$?
    
    case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
      meldung "${ORANGE}Etwas lief schief … exit code: ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT} (?wget, ?jq …)" ;;
    esac
  
    echo "»${fundstelle_text}«" | sed --regexp-extended 's@»([ ;.:]+)@»…\1@g; ' > "${datei_diese_fundstelle}"
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

  case $stufe_verausgaben in
  0)  ;;
  1) meldung "${GRUEN}Weiterverarbeitung → JSON → HTML${FORMAT_FREI} (tidy: ${datei_utf8_html_gram_tidy})" ;;
  esac
  tidy -quiet -output "${datei_utf8_html_gram_tidy}"  "${datei_utf8_html_zwischenablage_gram}" 2> "${datei_utf8_html_gram_tidy_log}" || this_exit_code=$?

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
  1) 
    meldung "${GRUEN}Weiterverarbeitung: HTML → ODT${FORMAT_FREI} (${datei_utf8_odt_gram})"
    if [[ -e ~/.pandoc/reference.odt ]]; then
    meldung "${GRUEN}Weiterverarbeitung: HTML → ODT, die Vorlage${FORMAT_FREI} ~/.pandoc/reference.odt ${GRUEN}wird für das Programm${FORMAT_FREI} pandoc ${GRUEN}wahrscheinlich verwendet${FORMAT_FREI}"
    fi
  ;;
  esac

  if [[ -e "${datei_utf8_odt_gram}" ]];then
    # stat --print="%x" Datei ergibt "2022-11-09 23:58:34.685526884 +0100"
    datum=$( stat --print="%x" "${datei_utf8_odt_gram}" | sed --regexp-extended 's@^([^ ]+) ([^ .]+)\..*@\1_\2@' )
    datei_sicherung=${datei_utf8_odt_gram%.*}_${datum}.odt

    meldung  "${ORANGE}Überschreibe vorhandene Textverarbeitungsdatei${FORMAT_FREI} ${datei_utf8_odt_gram} ${ORANGE}?${FORMAT_FREI}"
    meldung  "  ${ORANGE}Falls „nein“, dann erfolgt Sicherung als${FORMAT_FREI}"
    meldung  "  → $datei_sicherung ${ORANGE}(würde also umbenannt)${FORMAT_FREI}"
    echo -en "  ${ORANGE}Jetzt überschreiben (JA/nein):${FORMAT_FREI} "
    read janein
    if [[ -z ${janein// /} ]];then janein="ja"; fi
    case $janein in
      [jJ]|[jJ][aA])
        printf "  (überschreibe ODT)\n"
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
  if [[ $stufe_markdown_telegram -gt 0 ]];then 
    case $stufe_verausgaben in
    0)  ;;
    1) 
      meldung "${GRUEN}Weiterverarbeitung: HTML → HTML.MD${FORMAT_FREI} (${datei_utf8_html_gram_tidy_markdown_telegram})"
    ;;
    esac
    
    if [[ -e  "${datei_utf8_html_gram_tidy}" ]]; then 
      pandoc --wrap=none -f html -t markdown "${datei_utf8_html_gram_tidy}" | \
        sed --regexp-extended '
          s@\*\*@FETTSCHRIFT@g; s@\*@__@g; 
          s@FETTSCHRIFT@**@g; 
          s@\[([^][]+)\]\{.smallcaps\}@\U\1\E@g; 
          s@([^…]|[^.]{3})«@\1…«@g; 
          s@__( +)__@\1@g; 
          ' > "${datei_utf8_html_gram_tidy_markdown_telegram}"
    else
      meldung "${ORANGE}Fehler: HTML Datei nicht gefunden, ${datei_utf8_html_gram_tidy}${FORMAT_FREI} …"
    fi
  fi
  
;;
esac

# Programm Logik hier Ende
