#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/
# ZUTUN --Telegrammarkdown wird nicht erzeugt wenn --ODT fehlt
# ZUTUN https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/issues/1
# - verstehen https://api.woerterbuchnetz.de/dictionaries/Meta/lemmata/lemma/säuseln/0/json aller Wörterbücher Haupteinträge
# - verstehen https://api.woerterbuchnetz.de/dictionaries/Meta/fulltext/säuseln/0/json aller Wörterbücher Haupteinträge


set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

abhaengigkeiten_pruefen() {
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
  local diese_nutzung=''

  diese_nutzung=$( cat <<NUTZUNG
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
       --Einzeltabelle     die Wörtertabelle allein in eine gesonderte Datei speichern
-b,    --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-s,    --stillschweigend   Kaum Meldungen ausgeben
       --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
       --farb-frei         Meldungen ohne Farben ausgeben

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
      ls -l "${json_speicher_datei%.*}"*
      fi
      ;;
    esac
  fi
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
  datei_utf8_html_gram_tidy_worttabelle_odt="${datei_utf8_html_gram_tidy%.*}_einzeltabelle.odt"
  

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
  01|1) datum_heute_lang=$(date '+%_d. im Wintermonat (%B) %Y' | sed 's@^ *@@; s@Januar@& ~ röm: Gott Janus@;') ;;
  02|2) datum_heute_lang=$(date '+%_d. im Hornung (%B) %Y'     | sed 's@^ *@@; s@Februar@& ~ lat: februare „reinigen“@; ') ;;
  03|3) datum_heute_lang=$(date '+%_d. im Lenzmonat (%B) %Y'   | sed 's@^ *@@; s@März@& ~ röm: Gott Mars@; ') ;;
  04|4) datum_heute_lang=$(date '+%_d. im Ostermonat (%B) %Y'  | sed 's@^ *@@; s@April@& ~ lat: Aprilis@;') ;;
  05|5) datum_heute_lang=$(date '+%_d. im Wonnemonat (%B) %Y'  | sed 's@^ *@@; s@Mai@& ~ röm: Maius o. Göttin Maia@;') ;;
  06|6) datum_heute_lang=$(date '+%_d. im Brachmonat (%B) %Y'  | sed 's@^ *@@; s@Juni@& ~ röm: Göttin Juno@; ') ;;
  07|7) datum_heute_lang=$(date '+%_d. im Heumonat (%B) %Y'    | sed 's@^ *@@; s@Juli@& ~ röm: Julius (Caesar)@; ') ;;
  08|8) datum_heute_lang=$(date '+%_d. im Erntemonat (%B) %Y'  | sed 's@^ *@@; s@August@& ~ röm: Kaiser Augustus@; ') ;;
  09|9) datum_heute_lang=$(date '+%_d. im Herbstmonat (%B) %Y' | sed 's@^ *@@; s@September@& ~ lat: Septimus, 7@; ') ;;
    10) datum_heute_lang=$(date '+%_d. im Weinmonat (%B) %Y'   | sed 's@^ *@@; s@Oktober@& ~ lat: Octavus, 8@; ') ;;
    11) datum_heute_lang=$(date '+%_d. im Nebelmonat (%B) %Y'  | sed 's@^ *@@; s@November@& ~ lat: Nonus, 9@; ') ;;
    12) datum_heute_lang=$(date '+%_d. im Weihemonat (%B) %Y'  | sed 's@^ *@@; s@Dezember@& ~ lat: Decimus, 10@; ') ;;
  esac
  ANWEISUNG_FORMAT_FREI=''
  stufe_verausgaben=1
  stufe_formatierung=0
  stufe_markdown_telegram=0
  stufe_einzeltabelle_odt=0
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
  anzahl_alle_eintraege=0
  abbruch_code_nummer=0
  n_suchergebnisse_volltext=0
  n_suchergebnisse_volltext_mit_stichwort=0
  volltextabfrage_api=''
  volltext_text=''
  stichwortabfrage=''
  mit_woerterliste_text=''
  mit_woerterliste=''
  mit_woerterliste_regex=''
  mit_woerterliste_regex_xml=''
  
  hinweis_stichwortliste_html=""
  zusatzbemerkungen_textdatei=''

  ohne_woerterliste_regex='' # ZUTUN, siehe auch https://github.com/kkos/oniguruma/blob/master/doc/RE
  ohne_woerterliste_regex_xml='' # ZUTUN
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
    --farb-frei) ANWEISUNG_FORMAT_FREI=1 ;;
    -[Vv] | --[Vv]olltextabfrage)  # Parameter
      volltextabfrage_api="${2-}"
      volltext_text=$(echo "$volltextabfrage_api" | sed --regexp-extended 's@[[:punct:]]@…@g; s@^…{2,}@@; s@…{2,}$@@')
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
        s@(&#)(x[0-9a-f]+)(;)@hexadecimalanfang\2hexadecimalende@g; # hexadecimal
        s@[[:punct:]]+@ @g; 
        s@ρεγεξστερν@.*@g; 
        s@ρεγεξανφανγ@^@g; 
        s@ρεγεξενδε@$@g; 
        s@φραγεζειχψεν@?@g;
        s@πλυσζειχψεν@+@g;
        s@λκλαμμερ(.)βισ(.)ρκλαμμερ@[\1-\2]@g;
        s@λκλαμμερ([[:alpha:]]+)ρκλαμμερ@[\1]@g;
        s@(hexadecimalanfang)(x[0-9a-f]+)(hexadecimalende)@\&#\2;@g; # hexadecimal
        s@[ ]+@|@g; 
        s@\|([[:alpha:]])@|\\b\1@g; # beachte Wortgrenzen
        s@([[:alpha:]])\|@\1\\b|@g; 
        s@^([[:alpha:]])@\\b\1@; 
        s@([[:alpha:]])$@\1\\b@; 
      ')
      mit_woerterliste_regex_xml=$(echo "$mit_woerterliste_regex" | sed --regexp-extended '
        s@ü@\&#x00fc;@g;
        s@Ü@\&#x00dc;@g;
        s@ö@\&#x00f6;@g;
        s@Ö@\&#x00d6;@g;
        s@ä@\&#x00e4;@g;
        s@Ä@\&#x00c4;@g;
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
    --[Ee][Ii][Nn][Zz][Ee][Ll][Tt][Aa][Bb][Ee][Ll][Ll][Ee])
      # Stufe: 0 oder 1
      stufe_einzeltabelle_odt=1;
    ;;
    -T | --[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm][Mm][Aa][Rr][Kk][Dd][Oo][Ww][Nn])
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
        s@(&#)(x[0-9a-f]+)(;)@hexadecimalanfang\2hexadecimalende@g; # hexadecimal
        s@[[:punct:]]+@ @g; 
        s@ρεγεξ@…@g; 
        s@(^…{2,}|…{2,}$)@@; 
        s@φραγεζειχψεν@?@g;
        s@λκλαμμερ(.)βισ(.)ρκλαμμερ@[\1-\2]@g;
        s@λκλαμμερ([[:alpha:]]+)ρκλαμμερ@[\1]@g;
        s@(hexadecimalanfang)(x[0-9a-f]+)(hexadecimalende)@\&#\2;@g; # hexadecimal
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
        s@(&#)(x[0-9a-f]+)(;)@hexadecimalanfang\2hexadecimalende@g; # hexadecimal
        s@[[:punct:]]+@ @g; 
        s@ρεγεξστερν@.*@g; 
        s@ρεγεξανφανγ@^@g; 
        s@ρεγεξενδε@$@g; 
        s@φραγεζειχψεν@?@g;
        s@πλυσζειχψεν@+@g;
        s@λκλαμμερ(.)βισ(.)ρκλαμμερ@[\1-\2]@g;
        s@λκλαμμερ([[:alpha:]]+)ρκλαμμερ@[\1]@g;
        s@(hexadecimalanfang)(x[0-9a-f]+)(hexadecimalende)@\&#\2;@g; # hexadecimal
        s@[ ]+@|@g; 
        s@\|([[:alpha:]])@|\\b\1@g; # beachte Wortgrenzen
        s@([[:alpha:]])\|@\1\\b|@g; 
        s@^([[:alpha:]])@\\b\1@; 
        s@([[:alpha:]])$@\1\\b@; 
      ')
      ohne_woerterliste_regex_xml=$(echo "$ohne_woerterliste_regex" | sed --regexp-extended '
        s@ü@\&#x00fc;@g;
        s@Ü@\&#x00dc;@g;
        s@ö@\&#x00f6;@g;
        s@Ö@\&#x00d6;@g;
        s@ä@\&#x00e4;@g;
        s@Ä@\&#x00c4;@g;
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
  [[ -z "${volltextabfrage_api-}" ]] && meldung "${ROT}Fehlender Volltext, der abgefragt werden soll (Abbruch).${FORMAT_FREI}" && nutzung

  case $stufe_stichwortabfrage in
  0|1) 
    if [[ ${#ohne_woerterliste_text} -gt 1 ]]; then
      json_speicher_datei=$( json_speicher_datei "${volltext_text} und ohne Wörter" )
    else
      json_speicher_datei=$(json_speicher_datei "$volltext_text");      
    fi
     titel_text="Volltextsuche „$volltext_text“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
     ;;
  # 1) json_speicher_datei=$(json_speicher_datei "$volltext_text" "${mit_woerterliste_text}");
  #     titel_text="Volltextsuche „$volltext_text“ mit Stichwort „${mit_woerterliste_text}“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
  #     ;;
  2)
    if [[ ${#ohne_woerterliste_text} -gt 1 ]]; then
      json_speicher_datei=$( json_speicher_datei "${volltext_text} und ohne Wörter" "${mit_woerterliste_text}")
    else
      json_speicher_datei=$(json_speicher_datei "$volltext_text" "${mit_woerterliste_text}");
    fi
    if [[ ${#mit_woerterliste_text} -gt 1 ]]; then
      titel_text="Volltextsuche „$volltext_text“ mit Stichwort „${mit_woerterliste_text}“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
    else
      titel_text="Volltextsuche „$volltext_text“ aus Grimm-Wörterbuch ($datum_heute_lang)"; 
    fi
     ;;
  esac
  
  # keine Abfragen nur mit: * oder ?
  if [[ "${volltextabfrage_api-}" == "*" ]] || [[ "${volltextabfrage_api-}" =~ ^\*+$ ]] ;then
    meldung_abbruch "${ORANGE}Alles als Volltext abzufragen (--Volltextabfrage '${volltextabfrage_api}')  wird nicht unterstützt (Abbruch)${FORMAT_FREI}"
  fi
  if [[ "${volltextabfrage_api-}" == "?" ]] || [[ "${volltextabfrage_api-}" =~ ^[*?]+$ ]] ;then
    meldung_abbruch "${ORANGE}Fragezeichen oder mehrere *** als Volltext abzufragen (--Volltextabfrage '${volltextabfrage_api}')  wird nicht unterstützt (Abbruch)${FORMAT_FREI}"
  fi
  dateivariablen_filter_bereitstellen "${json_speicher_datei}"
  abhaengigkeiten_pruefen
  json_filter_code > "${json_speicher_filter_ueber_textid_verknuepfen}"
  
  zusatzbemerkungen_textdatei="Die Liste ist vorgruppiert geordnet nach den Grammatik-Angaben von Grimm,\nd.h. die Wörter sind nach Wortarten gruppiert: Eigenschaftswörter (Adjektive),\nNennwörter (Substantive), Zeitwörter oder Tuwörter usw.."
  zusatzbemerkungen_textdatei=$([[ "${mit_woerterliste_regex}" == "" ]] \
    && printf "${zusatzbemerkungen_textdatei}" \
    || printf "${zusatzbemerkungen_textdatei}\n\nDie Liste wurde bewußt auf Worte mit „${mit_woerterliste_text}“\nbeschränkt.")
    
  zusatzbemerkungen_textdatei=$([[ "${ohne_woerterliste_regex}" == "" ]] \
    && printf "${zusatzbemerkungen_textdatei}" \
    || ( [[ ${#zusatzbemerkungen_textdatei} -gt 1 ]] \
      && printf "${zusatzbemerkungen_textdatei%.*}, und bewußt ohne die Worte „${ohne_woerterliste_text}“ weiter eingerenzt." \
      || printf "${zusatzbemerkungen_textdatei}" ) )
  
  case $stufe_stichworte_eineinzig in 1) 
    zusatzbemerkungen_textdatei=$( [[ ${#zusatzbemerkungen_textdatei} -gt 1 ]] \
      && printf "${zusatzbemerkungen_textdatei%.*},\n es wurden nur die ersten Fundstellen berücksichtigt,\n und alle weiteren Fundstellen innerhalb eines Stichwortes entfernt." \
      || printf "${zusatzbemerkungen_textdatei}" )
  ;; 
  esac
  
  zusatzbemerkungen_textdatei=$(echo "${zusatzbemerkungen_textdatei}" | fold --spaces)
  
  case $stufe_stichwortabfrage in 
  1) 
    # hinweis_stichwortliste_html=", die Liste ist auf die Stichworte <i>${mit_woerterliste_text}</i> beschränkt." 
    case $stufe_stichworte_eineinzig in 
    0)
      hinweis_stichwortliste_html="" 
      ;;
    1) 
      hinweis_stichwortliste_html="; die Fundstellen wurden begrenzt auf die jeweils nur allerste innerhalb eines Stichwortes." 
      ;;
    esac
  ;;
  2) # ZUTUN WEITER
    if [[ ${#mit_woerterliste_text} -gt 1 ]];then 
      hinweis_stichwortliste_html=", die Liste ist auf die Stichworte <i>${mit_woerterliste_text}</i> beschränkt." 
    fi
    if [[ ${#ohne_woerterliste_text} -gt 1 ]];then 
      hinweis_stichwortliste_html="${hinweis_stichwortliste_html%.*}, und absichtlich ohne die Worte „<i>${ohne_woerterliste_text}</i>“ weiter eingerenzt."
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
  meldung  "${ORANGE}ENTWICKLUNG - stufe_formatierung:              $stufe_formatierung ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_verausgaben:               $stufe_verausgaben ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_stichwortabfrage:          $stufe_stichwortabfrage ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_stichworte_eineinzig:      $stufe_stichworte_eineinzig${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_dateienbehalten:           $stufe_dateienbehalten ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - volltextabfrage_api:             $volltextabfrage_api ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - volltext_text:                   $volltext_text ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stichwortabfrage:                $stichwortabfrage ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - mit_woerterliste_text:           $mit_woerterliste_text ${FORMAT_FREI}"
  echo -en "${ORANGE}ENTWICKLUNG - mit_woerterliste_regex:          ${FORMAT_FREI}"; echo "$mit_woerterliste_regex"
  echo -en "${ORANGE}ENTWICKLUNG - mit_woerterliste_regex_xml:      ${FORMAT_FREI}"; echo "$mit_woerterliste_regex_xml"
  echo -en "${ORANGE}ENTWICKLUNG - ohne_woerterliste_regex:         ${FORMAT_FREI}"; echo "$ohne_woerterliste_regex"
  echo -en "${ORANGE}ENTWICKLUNG - ohne_woerterliste_regex_xml:     ${FORMAT_FREI}"; echo "$ohne_woerterliste_regex_xml"
  meldung  "${ORANGE}ENTWICKLUNG - ohne_woerterliste_text:          $ohne_woerterliste_text ${FORMAT_FREI}"
  ;;
esac

# Programm Logik hier Anfang
# https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=*fug*;lemma,reflemma,variante=*fug*?token=Cs6lg4S7KFR6z9XZikhWY9oBSEBnt3ew&pageSize=20&pageNumber=1&_=1669804417852
case $stufe_verausgaben in
 0) wget \
      --quiet --wait=2 --random-wait "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage_api" \
      --output-document="${json_speicher_datei}" \
      && wget \
      --quiet --wait=2 --random-wait "https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=${volltextabfrage_api// /;all=}" \
      --output-document="${json_speicher_all_query_datei}";
 ;;
 1) 
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage_api)"
  meldung "${GRUEN}Abfrage an api.woerterbuchnetz.de …${FORMAT_FREI} (https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=${volltextabfrage_api// /;all=})"
  wget --show-progress  --wait 2 --random-wait \
    --quiet "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/$volltextabfrage_api" \
    --output-document="${json_speicher_datei}" \
    && wget --show-progress  --wait 2 --random-wait \
    --quiet "https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=${volltextabfrage_api// /;all=}" \
      --output-document="${json_speicher_all_query_datei}";
 ;;
esac


case $stufe_verausgaben in
 0)  ;;
 1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text})" ;;
esac

# ZUTUN Suche "altes Wort" → all-api:"altes_Wort"
if [[ -e "${json_speicher_datei}" ]];then
  # cat ./test/stupere.json | jq ' .result_count '
  # cat "${json_speicher_datei}" | jq ' .result_set[] | .lemma | tostring '
  n_suchergebnisse_volltext=$( cat "${json_speicher_datei}" | jq ' .result_count ' ) && abbruch_code_nummer=$?
  case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    meldung "${ORANGE}Irgendwas lief schief mit cat … jq. Abbruch Code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI}" ;;
  esac
  
  # kombiniere json_speicher_all_query_datei und json_speicher_datei für wbnetzkwiclink mit richtiger Fund-Textstelle
    # -----------------------------
    # https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=altes_Wort
    # - funktioniert, aber gram usw. fehlt
    # - Idee: aufdröseln ~ Einzelwort-Abfragen → jq dann vereifachen lassen (fulltext_altes.json + fulltext_Wort.json = fulltext_altes_Wort.json)
    #   https://api.woerterbuchnetz.de/dictionaries/DWB/query/all=säuseln
    # -----------------------------
    #   {
    #     "formid": "A05985",
    #     "textidlist": [
    #       [
    #         552337
    #       ]
    #     ],
    #     "wordidlist": [
    #       [
    #         46
    #       ]
    #     ],
    #     "wbsigle": "DWB",
    #     "normlemma": "aeu"
    #   },  
    # -----------------------------
    # https://api.woerterbuchnetz.de/open-api/dictionaries/DWB2/fulltext/säuseln  
    # -----------------------------
    # ${json_speicher_datei}
    #   "result_set": [
    #   {
    #     "sigle": "DWB",
    #     "lemma": "&#x00e4;u",
    #     "gram": "",
    #     "wbnetzid": "A05985",
    #     "textid": "552337",
    #     "match": "saeuseln",
    #     "wbnetzlink": "https://woerterbuchnetz.de//?sigle=DWB&lemid=A05985&textid=552337",
    #     "wbnetzkwiclink": "https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/kwic/552337"
    #   },
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
  
#   if [[ ${n_suchergebnisse_volltext} -eq 0 ]] && [[ $(jq '[.[]|(.normlemma)?]|length' ${json_speicher_all_query_datei}) -gt 0 ]]; then
#   # hashJoin( \$file1; \$file2; .textid)[]
#   else
  jq -n \
    --slurpfile file1 "${json_speicher_allquery_datei_zwischenablage}" \
    --slurpfile file2 "${json_speicher_datei_zwischenablage}" \
    -f "${json_speicher_filter_ueber_textid_verknuepfen}" > "${json_speicher_vereinte_abfragen_zwischenablage}"  
#   fi
  
  #   anzahl_alle_eintraege=$(jq '.|length' "${json_speicher_vereinte_abfragen_zwischenablage}")
  #   case $stufe_verausgaben in
  #   0)  ;;
  #   1) 
  #     meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} %s Ergebnisse gesamt …" ${anzahl_alle_eintraege}
  #   ;;
  #   esac
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
  --arg mit_woerterliste_regex "${mit_woerterliste_regex_xml}" \
    --arg ohne_woerterliste_regex "${ohne_woerterliste_regex_xml}" \
    '. | if ($mit_woerterliste_regex|length) == 0
      then .
      elif (.lemma|test($mit_woerterliste_regex))
      then .
      else empty
      end
    | if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.lemma|test($ohne_woerterliste_regex))
      then empty
      else .
      end
  ' "${json_speicher_vereinte_abfragen_zwischenablage}" > 'zeitweiliges.json' \
  && mv 'zeitweiliges.json' "${json_speicher_vereinte_abfragen_zwischenablage}"
 
  ;; 
  esac
  
  n_suchergebnisse_volltext_mit_stichwort=$( jq --slurp '.' "${json_speicher_vereinte_abfragen_zwischenablage}" | jq '.|length' );
  
  if [[ ${n_suchergebnisse_volltext-0} -eq 0 ]];then
    meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' enthält $n_suchergebnisse_volltext Volltext-Suchergebnisse, $n_suchergebnisse_volltext_mit_stichwort Stichwort-Suchergebnisse (Abbruch)${FORMAT_FREI}"
  elif [[ ${n_suchergebnisse_volltext-0} -gt 0 ]];then
    printf "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} %s Ergebnisse gesamt …\n" ${n_suchergebnisse_volltext}
  fi
  
  dieser_jq_filter_code='
  def woerterbehalten: ["DWB1", "DWB2"];
  def Anfangsgrosz:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;"))
      then "&#x00c4;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;"))
      then "&#x00d6;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;"))
      then "&#x00dc;" +  (.[8:] |ascii_downcase) 
      else (.[:1]|ascii_upcase) + (.[1:] |ascii_downcase) 
      end
      )
    | join("");
    
  def Umlauteausschreiben:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;"))
      then "ae" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00c4;"))
      then "AE" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;"))
      then "oe" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00d6;"))
      then "Oe" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;"))
      then "ue" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00dc;"))
      then "UE" +  (.[8:] |ascii_downcase) 
      else . 
      end
      )
    | join("");

  .result_set
  | map({
    gram: (.gram), 
    Wort: (.lemma|Anfangsgrosz), 
    wort: (.lemma), 
    wort_umlaut_geschrieben: (.lemma|Umlauteausschreiben)
  })
  | unique_by(.wort, .gram)  | sort_by(.gram, .wort_umlaut_geschrieben) 
  | .[] 
| if ($mit_woerterliste_regex|length) == 0
      then .
      elif (.wort|test($mit_woerterliste_regex))
      then .
      elif (.Wort|test($mit_woerterliste_regex))
      then .
      else empty
      end
| if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.wort|test($ohne_woerterliste_regex))
      then empty
      elif (.Wort|test($ohne_woerterliste_regex))
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
    then "die (o./u.a. der) \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
    then "die (o./u.a. das) \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
    then "die (o./u.a. das) \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
    then "die (o./u.a. das, der) \(.Wort);"
    elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
    then "die (o./u.a. der, das) \(.Wort);"
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
    then "der (o./u.a. die) \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +und +f[_.,;]* *$"))
    then "der u. die \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
    then "der (o./u.a. das) \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
    then "der (o./u.a. die, das) \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
    then "der (o./u.a. das, die) \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
    then "der \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
    then "der \(.Wort);"
  elif (.gram|test("^ *n[_.,;]* *$"))
    then "das \(.Wort);"
    elif (.gram|test("^ *n[_.,;]*\\? *$"))
    then "?das \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
    then "das (o./u.a. der) \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +n[_.,;]* *$"))
    then "das (o./u.a. das) \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
    then "das (o./u.a. die) \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
    then "das (o./u.a. der, die) \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
    then "das (o./u.a. die, der) \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
    then "das \(.Wort);"
    elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
    then "das \(.Wort);"
  else "\(.wort);"
  end
  '
  cat "${json_speicher_datei}" | jq -r  \
    --arg mit_woerterliste_regex "${mit_woerterliste_regex_xml}" \
    --arg ohne_woerterliste_regex "${ohne_woerterliste_regex_xml}" \
    "${dieser_jq_filter_code}" > "${datei_utf8_text_zwischenablage}" \
  && printf "%s\n\n%s\n\n" "${titel_text}" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text}" \
  && pandoc --from html --to plain --wrap=preserve "${datei_utf8_text_zwischenablage}" >> "${datei_utf8_reiner_text}"
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
      elif (.|test("^(?i)&#x00e4;"))
      then "&#x00c4;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;"))
      then "&#x00d6;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;"))
      then "&#x00dc;" +  (.[8:] |ascii_downcase) 
      else (.[:1]|ascii_upcase) + (.[1:] |ascii_downcase) 
      end
      )
    | join("");

  def Umlauteausschreiben:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;"))
      then "ae" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00c4;"))
      then "AE" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;"))
      then "oe" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00d6;"))
      then "Oe" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;"))
      then "ue" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00dc;"))
      then "UE" +  (.[8:] |ascii_downcase) 
      else . 
      end
      )
    | join("");

  .result_set
  | map({
      gram: (.gram), 
      Wort: (.lemma|Anfangsgrosz), 
      wort: (.lemma), 
      wort_umlaut_geschrieben: (.lemma|Umlauteausschreiben)
    })
  | unique_by(.wort, .gram)  | sort_by(.gram, .wort_umlaut_geschrieben) 
  | .[] 
| if ($mit_woerterliste_regex|length) == 0
      then .
      elif (.wort|test($mit_woerterliste_regex))
      then .
      elif (.Wort|test($mit_woerterliste_regex))
      then .
      else empty
      end
| if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.wort|test($ohne_woerterliste_regex))
      then empty
      elif (.Wort|test($ohne_woerterliste_regex))
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
  then "die (o./u.a. der) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
  then "die (o./u.a. das) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
  then "die (o./u.a. das) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
  then "die (o./u.a. das, der) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
  then "die (o./u.a. der, das) \(.Wort) (\(.gram));"
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
  then "der (o./u.a. die) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *m[_.,;]* +und +f[_.,;]* *$"))
    then "der u. die \(.Wort) (\(.gram));"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
  then "der (o./u.a. das) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
  then "der (o./u.a. die, das) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
  then "der (o./u.a. das, die) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
    then "der \(.Wort) (\(.gram));"
    elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
    then "der \(.Wort) (\(.gram));"

  elif (.gram|test("^ *n[_.,;]* *$"))
    then "das \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]*\\? *$"))
    then "?das \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
    then "das (o./u.a. der) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +n[_.,;]* *$"))
    then "das (o./u.a. das) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
    then "das (o./u.a. die) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
    then "das (o./u.a. der, die) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
    then "das (o./u.a. die, der) \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
    then "das \(.Wort) (\(.gram));"
    elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
    then "das \(.Wort) (\(.gram));"

  else "\(.wort) (\(.gram));"
  end
  '

# cat "${json_speicher_datei}" | jq "${dieser_jq_filter_code}" | sed -r 's@"@@g; ' | uniq > "${datei_utf8_text_zwischenablage_gram}"

cat "${json_speicher_datei}" | jq -r  \
    --arg mit_woerterliste_regex "${mit_woerterliste_regex_xml}" \
    --arg ohne_woerterliste_regex "${ohne_woerterliste_regex_xml}" \
  "${dieser_jq_filter_code}" > "${datei_utf8_text_zwischenablage_gram}" \
  && printf "%s\n\n%s\n\n" "${titel_text}" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text_gram}" \
  && pandoc --from html --to plain --wrap=preserve "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
# ZUTUN anfügen der eingeschrängten Wörterliste
  
  # if [[ -e "${datei_utf8_text_zwischenablage_gram}" ]];then
  #   # (3.1.) Sonderzeichen, Umlaute dekodieren in lesbare Zeichen als UTF8
  #   printf "%s\n\n" "${titel_text}" > "${datei_utf8_reiner_text_gram}" \
  #   && pandoc --from html --to plain --wrap=preserve "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
  # else
  #   meldung_abbruch "${ORANGE}Textdatei '${datei_utf8_reiner_text_gram}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
  # fi


case $volltext_text in
…*…) bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch viele Wörter enthalten sein, die nichts mit der Volltext-Abfrage <i>${volltext_text}</i> zu tun haben)${hinweis_stichwortliste_html-.}" ;;
…*)  bearbeitungstext_html="Liste noch nicht übearbeitet (es können auch viele Wörter enthalten sein, die nichts mit dem Wortende (im Volltext) <i>$volltext_text</i> gemein haben)${hinweis_stichwortliste_html-.}" ;;
*…)  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch viele Wörter enthalten sein, die nichts mit dem Wortanfang (im Volltext) <i>${volltext_text}</i> gemein haben)${hinweis_stichwortliste_html-.}" ;;
*)   bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch viele Wörter enthalten sein, die nichts mit der Volltext-Abfrage <i>${volltext_text}</i> zu tun haben)${hinweis_stichwortliste_html-.}" ;;
esac

html_technischer_hinweis_zur_verarbeitung="<p>Für die Techniker: Die Abfrage wurde mit <a href=\"https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/tree/main/DWB1#volltextsuche-innerhalb-von-stichwörterbeiträgen\"><code>DWB-PSS_volltext_abfragen-und-ausgeben.sh</code> (siehe GitHub)</a> duchgeführt.</p>\n";


case $stufe_formatierung in
 0)  ;;
 1|2|3)
  case $stufe_verausgaben in
  0)  ;;
  1) meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" ;;
  esac
  jq  \
  ' def woerterbehalten: ["DWB1", "DWB2"];
  def Anfangsgrosz:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;"))
      then "&#x00c4;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;"))
      then "&#x00d6;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;"))
      then "&#x00dc;" +  (.[8:] |ascii_downcase) 
      else (.[:1]|ascii_upcase) + (.[1:] |ascii_downcase) 
      end
      )
    | join("");

  def Umlauteausschreiben:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;"))
      then "ae" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00c4;"))
      then "AE" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;"))
      then "oe" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00d6;"))
      then "Oe" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;"))
      then "ue" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00dc;"))
      then "UE" +  (.[8:] |ascii_downcase) 
      else . 
      end
      )
    | join("");

 . | map({
    gram: (.gram), 
    Wort: (.lemma|Anfangsgrosz), 
    wort: (.lemma), 
    wort_umlaut_geschrieben: (.lemma|Umlauteausschreiben),
    wbnetzkwiclink_all_result: (.wbnetzkwiclink_all_result),
    wbnetzid: (.wbnetzid),
    wbnetzlink: (.wbnetzlink)
  })
  |  sort_by(.gram, .wort_umlaut_geschrieben)[] 
  |  if .gram == null or .gram == ""
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td><!-- keine Grammatik angegeben --><!-- ohne Sprachkunst-Begriff --></td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]* *$|^ *adj[ectiv]*[_.,;]* adj[ectiv]*[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschaftswort, Beiwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]* f[.,;]*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort weiblich)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *adj[ectiv]*[_.,;]* m[.,;]*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort männlich)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *adj[ectiv]*[_.,;]* n[.,;]*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort sächlich)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]*\\?[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ ?Eigenschaftswort, Beiwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]* +u[nd.]* +adv[erb]*[_.,;]* *$|^ *adj[ectiv]*[_.,;]* +adv[erb]*[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschaftswort, Beiwort und Umstandswort, Zuwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif  (.gram|test("^ *adv[erb]*[_.,;]+ *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Umstandswort, Zuwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *[kc]onj[unction]*[.,;] *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Fügewort, Bindewort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *dim[inutiv]*[.,;] *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Verniedlichung, Verkleinerung</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif (.gram|test("^ *f[_.,;]* *$|^ *fem[_.,;]* *$"))
  then "<tr><td>\(.Wort), die</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]*\\? *$"))
  then "<tr><td>\(.Wort), die?</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, ?weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: der)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: das)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: das)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: das, der)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. sächlich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: der, das)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. männlich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *f[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.Wort), die</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort einer Handlung, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.Wort), die</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort-Machende, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +subst. *$"))
  then "<tr><td>\(.Wort), die</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, weiblich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *interj[.]?[;]? *$|^ *interjection[;]? *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zwischenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *m[_.,;]* *$"))
  then "<tr><td>\(.Wort), der</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]*\\? *$"))
  then "<tr><td>\(.Wort), der?</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, ?männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.Wort), der (o./u.a.: die)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, männlich vermutlich  – o./u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +und +f[_.,;]* *$"))
  then "<tr><td>\(.Wort), der u. die</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, männlich u. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), der (o./u.a.: das)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, männlich vermutlich  – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), der (o./u.a.: die, das)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, männlich vermutlich – o./u.a. weiblich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.Wort), der (o./u.a. das, die)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, männlich vermutlich – o./u.a. sächlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.Wort), der</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort einer Handlung, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.Wort), der</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort-Machender, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

elif (.gram|test("^ *n[_.,;]* *$"))
  then "<tr><td>\(.Wort), das</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]*\\? *$"))
  then "<tr><td>\(.Wort), das?</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, ?sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.Wort), das (o./u.a.: der)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, sächlich vermutlich  – o./u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), das (o./u.a.: das)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, sächlich vermutlich  – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.Wort), das (o./u.a.: die)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, sächlich vermutlich  – o./u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
  then "<tr><td>\(.Wort), das (o./u.a.: der, die)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, sächlich vermutlich  – o./u.a. männlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.Wort), das (o./u.a.: die, der)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort, sächlich vermutlich – o./u.a. weiblich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.Wort), das</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort einer Handlung, sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.Wort), das</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort-Machendes, sächlich (auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *part[icz]*[.;]? *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Mittelwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj[.]? *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ mittelwörtliches Eigenschaftswort, Beiwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj[ektiv]*[. ]+[oder ]*adv[erb]*.*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ mittelwörtliches Eigenschaftswort oder Umstandswort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *part.[ -]+adv.[ ]+adj.*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ mittelwörtliches Umstandswort oder Eigenschaftswort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *präp[_.,;]* *$|^ *pr&#x00e4;p[_.,;]* *$|^ *praep[os]*[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Vorwort, Verhältniswort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *praet.[;]? *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Vergangenheit</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *pron[omen]*[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Vornennwort, Fürwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif  (.gram|test("^ *refl[.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ sich-bezogenes Tuwort oder Zeitwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *subst. *$"))
  then "<tr><td>\(.Wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Nennwort (auch Dingwort, Hauptwort, Namenwort, Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *subst. *inf[.]?$|^ *subst. *v[er]?b[.]?$"))
  then "<tr><td>\(.Wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ nennwörtliches Tuwort, Zeitwort, Tätigkeitswort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.Wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *v. +u. +subst. +n. *$"))
  then "<tr><td>\(.wort); \(.Wort), das</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Tuwort und Nennwort sächlich (Tuwort: auch Zeitwort, Tätigkeitswort; Nennwort: auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *st[arkes][.]* +v[erbum]*[.,; ]*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ starkes Zeitwort (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *schw[aches][.]* +v[erbum]*[.,; ]*$|^ *sw[_.,;]* +vb[.,;]* *$|^ *swv[.,; ]*$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ schwaches Zeitwort (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *untrennbares +v[erbum]*[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zeitwort untrennbar (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *trennb[ares]*[.]* +v[erbum]*[.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zeitwort trennbar (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif (.gram|test("^ *v[_.,;]* *$|^ *vb[_.,;]* *$|^ *verb[_.,;]* *$|^ *verbum[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zeitwort (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *verb[al]*[ .-]*adj[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschafts- oder Umstandswort tuwörtlichen Ursprungs</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  elif (.gram|test("^ *verb[al]*[ .-]*adj[_.,;]+[ -–—]+adv[_.,;]* *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Eigenschafts- oder Umstandswort tuwörtlichen Ursprungs</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

  elif (.gram|test("^ *tr[ans]*[.] *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zeitwort oder Tuwort auf wen/was beziehend (transitiv)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"  
  elif (.gram|test("^ *intr[ans]*[.] *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zeitwort oder Tuwort ohne wen/was Bezug (intransitiv)</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  elif (.gram|test("^ *zahlw[ort]*[.;] *$"))
  then "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ Zahlwort</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"
  
  else "<tr><td>\(.wort)</td><td><wbnetzkwiclink>\(.wbnetzkwiclink_all_result)</wbnetzkwiclink></td><td>\(.gram) ~ ?</td><td><small><a href=“https://woerterbuchnetz.de/?sigle=DWB&lemid=\(.wbnetzid)”>https://woerterbuchnetz.de/DWB/\(.wort)</a></small></td><td><small><a href=“\(.wbnetzlink)”>\(.wbnetzlink)</a></small></td></tr>"

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
# sollte jq bewerkstelligen # s@<td>([^ ])([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>\U\1\L\2\E\3\4@g; # ersten Buchstaben Groß bei Nennwörtern
# sollte jq bewerkstelligen # s@<td>(&#x00e4;|&#196;|&auml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00C4;\L\2\E\3\4@g; # ä Ä 
# sollte jq bewerkstelligen # s@<td>(&#x00f6;|&#246;|&ouml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00D6;\L\2\E\3\4@g; # ö Ö
# sollte jq bewerkstelligen # s@<td>(&#x00fc;|&#252;|&uuml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00DC;\L\2\E\3\4@g; # ü Ü 

1 i\<!DOCTYPE html>\n<html lang=\"de\" xml:lang=\"de\" xmlns=\"http://www.w3.org/1999/xhtml\">\n<head>\n<title></title>\n</head>\n<style type=\"text/css\" >\n#Wortliste-Tabelle td { vertical-align:top; }\n\n#Wortliste-Tabelle td:nth-child(2),\n#Wortliste-Tabelle td:nth-child(4),\n#Wortliste-Tabelle td:nth-child(5) { font-size:smaller; }\n\na.local { text-decoratcion:none; }\n</style>\n<body><p>${bearbeitungstext_html}</p><p>Man beachte die Formatierungen der Fundstellen im DWB1: <i>schräge Schrift</i> deutet meistens auf Erklärungen, Beschreibungen der GRIMMs selbst, während nicht-schräge (aufrechte Schrift) entweder ein Lemma (Wort im Wörterbuch) ist, oder meistens Beispiele aus Literatur sind (Textstellen zitierter Literatur oft auch Quellenangabe, Gedichtzeilentext u.ä.). Diese Tabelle ist nach <i>Grammatik (Grimm)</i> buchstäblich vorsortiert gruppiert, also finden sich Zeitwörter (Tuwörter, Tätigkeitswörter, Verben) beisammen, Eigenschaftswörter (Adjektive) beisammen, Nennwörter (Hauptwörter, Substantive), als auch die Wörter bei denen GRIMM keine Angabe der Grammatik/Sprachkunst-Begriffe gemacht haben oder sie vergessen wurden.</p><!-- hierher Abkürzungsverzeichnis einfügen --><p>Zur Sprachkunst oder Grammatik siehe vor allem <i style=\"font-variant:small-caps;\">Schottel (1663)</i> das ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table id=\"Wortliste-Tabelle\"><thead><tr><th>Wort</th><th>Fundstelle (gekürzt)</th><th>Grammatik (<i>Grimm</i>) ~ Sprachkunst, Sprachlehre (s. a. <i style=\"font-variant:small-caps;\">Schottel&nbsp;1663</i>)</th><th>Haupteintrag</th><th>Verknüpfung Textstelle</th></tr></thead><tbody>
$ a\</tbody><tfoot><tr><td colspan=\"5\" style=\"border-top:2px solid gray;border-bottom:0 none;\"></td>\n</tr></tfoot></table>${html_technischer_hinweis_zur_verarbeitung}\n</body>\n</html>
" | sed --regexp-extended '
  s@<th>@<th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">@g;
  s@<body>@<body style="font-family: Antykwa Torunska, serif; background: white;">@;
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
    ) && abbruch_code_nummer=$?
    
    case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
      meldung "${ORANGE}Etwas lief schief bei den Fundstellen … exit code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI} (?wget, ?jq, ?sed …)";
        abbruch_code_nummer=0;
      ;;
    esac
  
    echo "»${fundstelle_text}«" | sed --regexp-extended 's@»([ ;.:]+)@»…\1@g; ' > "${datei_diese_fundstelle}"
    # sed --in-place '/<\/body>/e cat Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html' "${datei_utf8_html_zwischenablage_gram}"
    sed --in-place "/${wbnetzkwiclink_regex_suchadresse}/r ${datei_diese_fundstelle}" "${datei_utf8_html_zwischenablage_gram}"
    sed --in-place "/${wbnetzkwiclink_regex_suchadresse}/d" "${datei_utf8_html_zwischenablage_gram}"

    rm -- "${datei_diese_fundstelle}"

    i_textverknuepfung=$(( $i_textverknuepfung + 1 ))
  done

  # Falls HTML-Datei mit Tabelle vorhanden ist
  if [[ -e "Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html"  ]];then
  sed --in-place '/<\/body>/e cat Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html' "${datei_utf8_html_zwischenablage_gram}"

  sed --in-place 's@<!-- *hierher Abkürzungsverzeichnis einfügen *-->@<p>Siehe auch das <a class="local" href="#sec-GRIMM_Abkuerzungen">Abkürzungsverzeichnis</a>.</p>\n@' "${datei_utf8_html_zwischenablage_gram}"
  fi

  case $stufe_verausgaben in
  0)  ;;
  1) meldung "${GRUEN}Weiterverarbeitung → JSON → HTML${FORMAT_FREI} (tidy: ${datei_utf8_html_gram_tidy})" ;;
  esac
  tidy -quiet -output "${datei_utf8_html_gram_tidy}"  "${datei_utf8_html_zwischenablage_gram}" 2> "${datei_utf8_html_gram_tidy_log}" || abbruch_code_nummer=$?

  case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    meldung "${ORANGE}Etwas lief schief bei der Weiterverarbeitung → JSON → HTML … exit code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI} (?tidy …)";
      abbruch_code_nummer=0;
    ;;
  esac

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
  
  if [[ $stufe_einzeltabelle_odt -gt 0 ]];then 
    if [[ -e "${datei_utf8_html_gram_tidy}" ]];then    
      meldung "${GRUEN}Weiterverarbeitung: HTML → ODT (Einzeltabelle)${FORMAT_FREI} (${datei_utf8_html_gram_tidy_worttabelle_odt})"
      
      sed --regexp-extended --silent '/<table +id="Wortliste-Tabelle"/,/<\/table>/p' "${datei_utf8_html_gram_tidy}" \
        | pandoc -f html -t odt -o "${datei_utf8_html_gram_tidy_worttabelle_odt}"
    else
    meldung  "${ORANGE}Kann ${datei_utf8_html_gram_tidy_worttabelle_odt} nicht erstellen, da ${datei_utf8_html_gram_tidy} nicht zu findene war ...${FORMAT_FREI}"
    fi
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
        sed --regexp-extended "
          s@\*\*@FETTSCHRIFT@g; s@\*@__@g; 
          s@FETTSCHRIFT@**@g; 
          s@\[([^][]+)\]\{.smallcaps\}@\U\1\E@g; 
          s@\{[.]small\}@@g;
          s@([^…]|[^.]{3})«@\1…«@g; 
          s@__( +)__@\1@g; 
          s@\^@@g; # <sup></sup>
          s@\\\\([~'.])@\1@g;
          s@\\\\\[@[@g; s@\\\\\]@]@g;
          " > "${datei_utf8_html_gram_tidy_markdown_telegram}"
    else
      meldung "${ORANGE}Fehler: HTML Datei nicht gefunden, ${datei_utf8_html_gram_tidy}${FORMAT_FREI} …"
    fi
  fi
  
;;
esac

# Programm Logik hier Ende
