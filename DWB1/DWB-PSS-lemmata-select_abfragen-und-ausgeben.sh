#!/usr/bin/env bash
# Programm gründet auf Maciej Radzikowski’s englischer Vorlage https://betterdev.blog/minimal-safe-bash-script-template/
# ZUTUN stufe_textauszug (Nährstand, Lehrstand, Wehrstand)
# ZUTUN filter wortliste zum beschränken z.B. bei Suche *stand* alle "aufstand" usw. weglassen
# ZUTUN Grammatik ~ Schottel zusammenführen in Tabelle
# ZUTUN Prüfung Nennwort → Großschreibung
# ZUTUN Suche zü* Umlaute ersetzen nach &#x00fc; usw.

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
  ./$(basename "${BASH_SOURCE[0]}") [-h] [-s] [-H] [-O] -l "*wohl*"

Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
- Textdatei reine Wortliste (ohne Zusätzliches)
- Textdatei mit Grammatik-Einträgen
Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programm pandoc).
(Technische Abhängigkeiten: jq, pandoc, sed)

Verwendbare Wahlmöglichkeiten:
-h,  --Hilfe          Hilfetext dieses Programms ausgeben.

-l,-L, --Lemmaabfrage      Die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.
                           mehrere Suchwörter zugleich sind möglich: „*wohn*, *wöhn*“
-F     --Fundstellen       Fundstellen mit abfragen, jeden Stichworts

-H,    --HTML              HTML Datei erzeugen
-O,    --ODT               ODT Datei (für LibreOffice) erzeugen
       --Liste_Einzelabschnitte
                           Wörtertabelle als Wörterliste in Einzelabschnitte umschreiben (als Markdown-Text)
-T,    --Telegrammarkdown  MD Datei (für Text in Markdown bei Telegram) erzeugen
-b,    --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
-s,    --stillschweigend   Kaum Meldungen ausgeben
       --ohne              ohne Wörter (Wortliste z.B. --ohne 'aufstand, verstand' bei --Lemmaabfrage '*stand*')
       --entwickeln,--debug Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
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
        if [[ -e "${datei_utf8_html_gram_tidy-}" ]];then          rm -- "${datei_utf8_html_gram_tidy}"; fi
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
      case $stufe_einzeltabelle_in_einzelabschtitte in 1)
        if [[ -e "${datei_utf8_html_gram_tidy_worttabelle_odt-}" ]];then rm -- "${datei_utf8_html_gram_tidy_worttabelle_odt}"; fi
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
  datei_utf8_text_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage mit gram.txt"
  datei_utf8_reiner_text="${diese_json_speicher_datei%.*}-utf8_nur-Wörter.txt"
  datei_utf8_reiner_text_gram="${diese_json_speicher_datei%.*}-utf8_nur-Wörter mit gram.txt"
  datei_utf8_html_zwischenablage_gram="${diese_json_speicher_datei%.*}-utf8_Zwischenablage_Wortliste mit gram.html"
  datei_utf8_html_gram_tidy="${diese_json_speicher_datei%.*}-utf8_Wortliste mit gram_tidy.html"
    datei_utf8_html_gram_tidy_log="${diese_json_speicher_datei%.*}-utf8_Wortliste mit gram_tidy.html.log"
  datei_utf8_html_gram_tidy_worttabelle_odt="${datei_utf8_html_gram_tidy%.*}_Einzeltabelle.odt"
  datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte="${datei_utf8_html_gram_tidy%.*}_Einzelabschnitte.md"
  datei_utf8_odt_gram="${diese_json_speicher_datei%.*}_Wortliste mit gram.odt"
    datei_diese_wbnetzkwiclink="${datei_utf8_html_zwischenablage_gram}.wbnetzkwiclink.txt"
  datei_utf8_html_gram_tidy_markdown_telegram="${diese_json_speicher_datei%.*}-utf8_Wortliste mit gram_tidy_(Telegram).md"
}

parameter_abarbeiten() {
  # default values of variables set from params
  case $(date '+%m') in
  01|1) datum_heute_lang=$(date '+%_d. im Wintermonat (%B) %Y' | sed 's@^ *@@; s@Januar@& ~ röm. Gott Janus@;') ;;
  02|2) datum_heute_lang=$(date '+%_d. im Hornung (%B) %Y'     | sed 's@^ *@@; s@Februar@& ~ lat.: februare „reinigen“@; ') ;;
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
  ANWEISUNG_FORMAT_FREI=''
  abbruch_code_nummer=0
  anzahl_verarbeitete_eintraege=0
  anzahl_alle_eintraege=0
  stufe_aufraeumen_aufhalten=0
  stufe_dateienbehalten=0
  stufe_formatierung=0
  # Grundlage: rein Text, und mit Grammatik
  # zusätzlich
  # 2^0: 1-1 = 0 rein Text, und mit Grammatik
  # 2^1: 2-1 = 1 nur mit HTML
  #      3-1 = 2 nur mit ODT
  # 2^2: 4-1 = 3 mit HTML, mit ODT
  ANWEISUNG_HTML_ERZEUGEN=0
  ANWEISUNG_ODT_ERZEUGEN=0
  ANWEISUNG_TELEGRAM_MD_ERZEUGEN=0
  stufe_fundstellen=0
  stufe_textauszug=0
  # VERALTET: stufe_einzeltabelle_odt=0 # wird ersetzt mit $stufe_einzeltabelle_in_einzelabschtitte
  stufe_einzeltabelle_in_einzelabschtitte=0
  stufe_verausgaben=1
  stufe_markdown_telegram=0
  ohne_woerterliste=''
  ohne_woerterliste_text=''
  ohne_woerterliste_regex='' # siehe auch https://github.com/kkos/oniguruma/blob/master/doc/RE
  ohne_woerterliste_regex_xml=''
  zusatzbemerkungen_textdatei=''
  zusatzbemerkungen_htmldatei=''
  lemmaabfrage=''
  lemmaabfrage_api=''
  lemma_text=''
  json_speicher_datei=$(json_speicher_datei unbekannt)
  titel_text="Abfrageversuch „??“ aus Grimm-Wörterbuch"
  untertitel_text="$datum_heute_lang"
  # param=''

  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --[Hh][Ii][Ll][Ff][Ee]) stufe_aufraeumen_aufhalten=1; nutzung ;;
    --debug|--entwickeln) set -x ;;
    -b | --behalte_[Dd]ateien) stufe_dateienbehalten=1 ;;
    --farb-frei) ANWEISUNG_FORMAT_FREI=1 ;;
    -F | --[Ff]undstellen) stufe_fundstellen=1 ;;
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
      titel_text="Wörter-Abfrage „${lemma_text}“ aus Grimm-Wörterbuch"      
      shift
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
      shift
      ;;
    -H | --[Hh][Tt][Mm][Ll])
      ANWEISUNG_HTML_ERZEUGEN=1;
      case $stufe_formatierung in
      0) stufe_formatierung=1 ;;
      1|3) stufe_formatierung=$stufe_formatierung ;;
      2) stufe_formatierung=$(( $stufe_formatierung + 1 )) ;;
      *) stufe_formatierung=1 ;;
      esac
      ;;
    -O | --[Oo][Dd][Tt])
      ANWEISUNG_ODT_ERZEUGEN=1;
      case $stufe_formatierung in
      0) stufe_formatierung=2 ;;
      1) stufe_formatierung=$(( $stufe_formatierung + 2 )) ;;
      2|3) stufe_formatierung=$stufe_formatierung ;;
      *) stufe_formatierung=2 ;;
      esac
    ;;
    -A | --[Tt]extauszug) stufe_textauszug=1 ;; # ZUTUN
    -T | --[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm][Mm][Aa][Rr][Kk][Dd][Oo][Ww][Nn])
      ANWEISUNG_TELEGRAM_MD_ERZEUGEN=1;
      stufe_markdown_telegram=1
      # Stufe: 1 oder 3
      case $stufe_formatierung in
      0) stufe_formatierung=1 ;;
      1|3) stufe_formatierung=$stufe_formatierung ;;
      2) stufe_formatierung=$(( $stufe_formatierung + 1 )) ;;
      *) stufe_formatierung=1 ;;
      esac
    ;;    
    --[Ee][Ii][Nn][Zz][Ee][Ll][Tt][Aa][Bb][Ee][Ll][Ll][Ee])
      stufe_einzeltabelle_in_einzelabschtitte=1;
    ;;
    --[Ll][Ii][Ss][Tt][Ee]_[Ee][Ii][Nn][Zz][Ee][Ll][Aa][Bb][Ss][Cc][Hh][Nn][Ii][Tt][Tt][Ee])
      # Stufe: 0 oder 1
      stufe_einzeltabelle_in_einzelabschtitte=1;
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

  zusatzbemerkungen_htmldatei=$([[ "${ohne_woerterliste_regex}" == "" ]] && printf "" || printf "; in der Liste wurden folgende Wortverbindungen bewußt entfernt, d.h. ohne „${ohne_woerterliste}“.")
  
  zusatzbemerkungen_textdatei="Die Liste ist vorgruppiert geordnet nach den Grammatik-Angaben von Grimm, d.h. die Wörter sind nach Wortarten gruppiert: ohne Grammatik-Angabe, Eigenschaftswörter (Adjektive), Nennwörter (Substantive), Zeit- oder Tuwörter usw.."
  zusatzbemerkungen_textdatei=$([[ "${ohne_woerterliste_regex}" == "" ]] && printf "${zusatzbemerkungen_textdatei}" || printf "${zusatzbemerkungen_textdatei}\n\nIn der Liste wurden folgende Wortverbindungen bewußt entfernt, mit\n„${ohne_woerterliste_text}“.")
  zusatzbemerkungen_textdatei=$(echo "${zusatzbemerkungen_textdatei}" | fold --spaces)
  
  # tif [[ $(( ${ANWEISUNG_HTML_ERZEUGEN-0} + ${ANWEISUNG_ODT_ERZEUGEN} + ${ANWEISUNG_TELEGRAM_MD_ERZEUGEN} )) -eq 0 ]]; then
  #   stufe_formatierung=0;
  # fi
  # ZUTUN Stufen
  # 2^0: 1 minus 1 = 0 rein Text, und mit Grammatik
  # 2^1: 2 minus 1 = 1 nur mit HTML
  #      3 minus 1 = 2 nur mit ODT
  # 2^2: 4 minus 1 = 3 mit HTML, mit ODT
  #      5 minus 1 = 4 nur MD
  #      6 minus 1 = 5 nur MD, mit HTML
  #      7 minus 1 = 6 nur MD, mit ODT
  # 2^3: 8 minus 1 = 7 mit HTML, mit ODT, mit MD
 
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
  meldung  "${ORANGE}ENTWICKLUNG - stufe_formatierung:          $stufe_formatierung ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_fundstellen:           $stufe_fundstellen ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_verausgaben:           $stufe_verausgaben ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - stufe_dateienbehalten:       $stufe_dateienbehalten ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - lemmaabfrage:                $lemmaabfrage ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - lemmaabfrage_api:            $lemmaabfrage_api ${FORMAT_FREI}"
  meldung  "${ORANGE}ENTWICKLUNG - lemma_text:                  $lemma_text ${FORMAT_FREI}"
  echo -en "${ORANGE}ENTWICKLUNG - ohne_woerterliste_regex:     ${FORMAT_FREI}"; echo "$ohne_woerterliste_regex"
  echo -en "${ORANGE}ENTWICKLUNG - ohne_woerterliste_regex_xml: ${FORMAT_FREI}"; echo "$ohne_woerterliste_regex_xml"
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



if [[ -e "${json_speicher_datei}" ]];then
    anzahl_alle_eintraege=$(jq '.|length' "${json_speicher_datei}")
    case $stufe_verausgaben in
    0)  ;;
    1) 
      printf "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} %s Ergebnisse …\n" ${anzahl_alle_eintraege}
      meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text})" 
    ;;
    esac
    
    cat "${json_speicher_datei}" | jq  --arg ohne_woerterliste_regex "${ohne_woerterliste_regex_xml}" \
    -r '
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

  .
  | map({
    gram: (.gram), 
    Wort: (.label|Anfangsgrosz), # 
    wort: (.label), 
    wort_umlaut_geschrieben: (.label|Umlauteausschreiben)
  })
  | unique_by(.wort, .gram) | sort_by(.gram, .wort_umlaut_geschrieben ) 
  | .[] 
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
  elif (.gram|test("^ *f[_.,;]* *$|^ *f[_.,;]* *f[_.,;]* *$|^ *fem[_.,;]* *$"))
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
    elif (.gram|test("^ *f[_.,;]* +subst[. ]*$"))
    then "die \(.Wort);"
    elif (.gram|test("^ *subst[. ]* +f[_.,;]*$"))
    then "die \(.Wort);"
  elif (.gram|test("^ *m[_.,;]* *$"))
    then "der \(.Wort);"
    elif (.gram|test("^ *m[_.,;]*\\? *$"))
    then "?der \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
    then "der (o./u.a. die) \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +und +f[_.,;]* *$"))
    then "der u. die \(.Wort);"
    elif (.gram|test("^ *m[_.,;]* +m[_.,;]* *$"))
    then "der \(.Wort);"
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
    elif (.gram|test("^ *m[_.,;]* +subst[. ]*$"))
    then "der \(.Wort);"
    elif (.gram|test("^ *subst[. ]* +m[_.,;]*$"))
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
    
  elif (.gram|test("^ *nomen *$"))
    then "\(.Wort);"
  elif (.gram|test("^ *subst[. _.,;]*$"))
    then "\(.Wort);"

  else "\(.wort);"
  end
  ' > "${datei_utf8_text_zwischenablage}" \
  && printf "%s\n\n%s\n\n" "${titel_text} ($untertitel_text)" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text}" \
  && pandoc --from html --to plain --wrap=preserve "${datei_utf8_text_zwischenablage}" >> "${datei_utf8_reiner_text}"
else
  meldung_abbruch "${ORANGE}Datei '${json_speicher_datei}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi

# als reine Textausgabe (sortiert nach Grammatik, Wort)
case $stufe_verausgaben in
 0)  ;;
 1) 
 meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_reiner_text_gram})" 
 ;;
esac

cat "${json_speicher_datei}" | jq --arg ohne_woerterliste_regex "${ohne_woerterliste_regex_xml}" \
  ' def woerterbehalten: ["DWB1", "DWB2"];
  def Anfangsgrosz:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;")) # ä
      then "&#x00c4;" +  (.[8:] |ascii_downcase) # Ä
      elif (.|test("^(?i)&#x00f6;")) # ö
      then "&#x00d6;" +  (.[8:] |ascii_downcase) # Ö
      elif (.|test("^(?i)&#x00fc;")) # ü
      then "&#x00dc;" +  (.[8:] |ascii_downcase) # Ü
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

    # unique_by(.wort) schein ungünstig, wenn manche Wörter keine Grammatik haben
    
. | map({
    gram: (.gram), 
    Wort: (.label|Anfangsgrosz),# 
    wort: (.label), 
    wort_umlaut_geschrieben: (.label|Umlauteausschreiben)
  })
| unique_by(.wort, .gram) | sort_by(.gram, .wort_umlaut_geschrieben ) 
| .[] 
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
elif (.gram|test("^ *f[_.,;]* *$|^ *f[_.,;]* *f[_.,;]* *$|^ *fem[_.,;]* *$"))
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
  elif (.gram|test("^ *f[_.,;]* +subst[. ]*$"))
  then "die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *subst[. ]* +f[_.,;]*$"))
  then "die \(.Wort) (\(.gram));"

elif (.gram|test("^ *m[_.,;]* *$"))
  then "der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]*\\? *$"))
  then "?der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
  then "der (o./u.a. die) \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +und +f[_.,;]* *$"))
  then "der u. die \(.Wort) (\(.gram));"
  elif (.gram|test("^ *m[_.,;]* +m[_.,;]* *$"))
  then "der \(.Wort) (\(.gram));"
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
  elif (.gram|test("^ *m[_.,;]* +subst[. ]*$"))
  then "der \(.Wort) (\(.gram));"
  elif (.gram|test("^ *subst[. ]* +m[_.,;]*$"))
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

elif (.gram|test("^ *nomen *$"))
    then "\(.Wort) (\(.gram);"
elif (.gram|test("^ *subst[. _.,;]*$"))
  then "\(.Wort) (\(.gram));"

else "\(.wort) (\(.gram));"
end
  ' | sed -r 's@"@@g; ' | uniq > "${datei_utf8_text_zwischenablage_gram}"

if [[ -e "${datei_utf8_text_zwischenablage_gram}" ]];then
  anzahl_verarbeitete_eintraege=$(grep --count --invert-match '^\s*$' "${datei_utf8_text_zwischenablage_gram}")
  # (3.1.) Sonderzeichen, Umlaute dekodieren in lesbare Zeichen als UTF8
  printf "%s\n\n%s\n\n" "${titel_text} ($untertitel_text)" "${zusatzbemerkungen_textdatei}" > "${datei_utf8_reiner_text_gram}" \
  && pandoc --from html --to plain --wrap=preserve "${datei_utf8_text_zwischenablage_gram}" >> "${datei_utf8_reiner_text_gram}"
else
  meldung_abbruch "${ORANGE}Textdatei '${datei_utf8_reiner_text_gram}' fehlt oder konnte nicht erstellt werden (Abbruch)${FORMAT_FREI}"
fi

case $stufe_verausgaben in
 0)  ;;
 1) 
 meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} ${anzahl_verarbeitete_eintraege} Wörter aus ${anzahl_alle_eintraege} Ergebnissen" 
 ;;
esac

case $lemma_text in
…*…) if [[ -z "${ohne_woerterliste_regex-}" ]];then
  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>${lemma_text}</i> zu tun haben)${zusatzbemerkungen_htmldatei-.}"
  else
  bearbeitungstext_html="Liste leicht überarbeitet (es können dennoch Wörter enthalten sein, die nichts mit der Abfrage <i>${lemma_text}</i> zu tun haben)${zusatzbemerkungen_htmldatei-.}"
  fi
  ;;
…*)  if [[ -z "${ohne_woerterliste_regex-}" ]];then
  bearbeitungstext_html="Liste noch nicht übearbeitet (es können auch Wörter enthalten sein, die nichts mit der Endung <i>$lemma_text</i> gemein haben)${zusatzbemerkungen_htmldatei-.}" 
  else
  bearbeitungstext_html="Liste leicht übearbeitet (es können dennoch Wörter enthalten sein, die nichts mit der Endung <i>$lemma_text</i> gemein haben)${zusatzbemerkungen_htmldatei-.}" 
  fi
  ;;
*…)  if [[ -z "${ohne_woerterliste_regex-}" ]];then
  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit dem Wortanfang <i>${lemma_text}</i> gemein haben)${zusatzbemerkungen_htmldatei-.}" 
  else
  bearbeitungstext_html="Liste leicht überarbeitet (es können dennoch Wörter enthalten sein, die nichts mit dem Wortanfang <i>${lemma_text}</i> gemein haben)${zusatzbemerkungen_htmldatei-.}" 
  fi
  ;;
  
*)  if [[ -z "${ohne_woerterliste_regex-}" ]];then
  bearbeitungstext_html="Liste noch nicht überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>${lemma_text}</i> zu tun haben)${zusatzbemerkungen_htmldatei-.}" 
  else
  bearbeitungstext_html="Liste leicht überarbeitet (es können dennoch Wörter enthalten sein, die nichts mit der Abfrage <i>${lemma_text}</i> zu tun haben)${zusatzbemerkungen_htmldatei-.}" 
  fi
;;
esac



html_technischer_hinweis_zur_verarbeitung="<p>Für die Techniker: Die Abfrage wurde mit <a href=\"https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/tree/main/DWB1#stichwörter-abfragen\"><code>DWB-PSS_lemmata-select_abfragen-und-ausgeben.sh</code> (siehe GitHub)</a> duchgeführt.</p>\n";
case $stufe_formatierung in
 0)  ;;
 1|2|3)
  case $stufe_verausgaben in
  0)  ;;
  1) 
  meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (${datei_utf8_html_zwischenablage_gram})" 
  if ! [[ "${ohne_woerterliste_regex}" == "" ]];then
  # meldung "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (ohne: ${ohne_woerterliste_regex})"
  echo -en "${GRUEN}Weiterverarbeitung → JSON${FORMAT_FREI} (ohne: "; echo "${ohne_woerterliste_regex_xml})"
  
  fi
  ;;
  esac
  #   --arg a v        set variable $a to value <v>;
  
  cat "${json_speicher_datei}" | jq --arg ohne_woerterliste_regex "${ohne_woerterliste_regex_xml}" \
    ' def woerterbehalten: ["DWB1", "DWB2"];
  def Anfangsgrosz:
    INDEX(woerterbehalten[]; .) as $wort_behalten
    | [splits("^ *") | select(length>0)]
    | map(
      if $wort_behalten[.] 
      then . 
      elif (.|test("^(?i)&#x00e4;")) # ä
      then "&#x00c4;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00f6;")) # ö
      then "&#x00d6;" +  (.[8:] |ascii_downcase) 
      elif (.|test("^(?i)&#x00fc;")) # ü
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
      label: (.label), 
      value: (.value), 
      gram: (.gram), 
      Wort: (.label|Anfangsgrosz), 
      wort: (.label), 
      wort_umlaut_geschrieben: (.label|Umlauteausschreiben)
    })
    | sort_by(.gram,.wort_umlaut_geschrieben)
    | .[] 
    | if ($ohne_woerterliste_regex|length) == 0
      then .
      elif (.label|test($ohne_woerterliste_regex))
      then empty
      else .
      end
    |  if .gram == null or .gram == ""
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td><!-- keine Grammatik angegeben --><!-- ohne Sprachkunst-Begriff --></td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]* *$|^ *adj[ectiv]*[_.,;]* adj[ectiv]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschaftswort, Beiwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]* f[.,;]*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort weiblich)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *adj[ectiv]*[_.,;]* m[.,;]*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort männlich)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *adj[ectiv]*[_.,;]* n[.,;]*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort sächlich)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  
  elif (.gram|test("^ *adj[ectiv]*[_.,;]*\\?[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ ?Eigenschaftswort, Beiwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *adj[ectiv]*[_.,;]* +u[nd.]* +adv[erb]*[_.,;]* *$|^ *adj[ectiv]*[_.,;]* +adv[erb]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschaftswort, Beiwort und Umstandswort, Zuwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif  (.gram|test("^ *adv[erbiell]*[_.,;]+ *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Umstandswort, Zuwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"


  elif  (.gram|test("^ *[kc]onj[unction]*[.,;] *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Fügewort, Bindewort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  
  elif  (.gram|test("^ *dim[inutiv]*[.,;] *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Verniedlichung, Verkleinerung</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  
  elif (.gram|test("^ *f[_.,;]* *$|^ *f[_.,;]* *f[_.,;]* *$|^ *fem[_.,;]* *$"))
  then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]*\\? *$"))
  then "<tr><td>\(.Wort), die?</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, ?weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: der)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: das)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* *$|^ *f[_.,;]* *n[_.,;]* *n[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: das)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +n[_.,;]* +m[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: das, der)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. sächlich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +m[_.,;]* +n[_.,;]* *$"))
  then "<tr><td>\(.Wort), die (o./u.a.: der, das)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich vermutlich – o./u.a. männlich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *f[_.,;]* +nomen +actionis[.]* *$"))
  then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort einer Handlung, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +nomen +agentis[.]* *$"))
  then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ nennwörtlich Machende, weiblich – hauptwörtlich …, namenswörtlich …</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *f[_.,;]* +subst[. ]*$"))
  then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *subst[. ]* +f[_.,;]*$"))
  then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *interj[.]?[;]? *$|^ *interjection[;]? *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Zwischenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *m[_.,;]* *$"))
    then "<tr><td>\(.Wort), der</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]*\\? *$"))
    then "<tr><td>\(.Wort), der?</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, ?männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.Wort), der (o./u.a.: die)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich vermutlich – o./u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +und +f[_.,;]* *$"))
    then "<tr><td>\(.Wort), der u. die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich u. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +m[_.,;]* *$"))
    then "<tr><td>\(.Wort), der</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* *$"))
    then "<tr><td>\(.Wort), der (o./u.a.: das)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich vermutlich – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +f[_.,;]* +n[_.,;]* *$"))
    then "<tr><td>\(.Wort), der (o./u.a.: die, das)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich vermutlich – o./u.a. weiblich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +n[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.Wort), der (o./u.a. das, die)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich vermutlich – o./u.a. sächlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    
    elif (.gram|test("^ *m[_.,;]* +nomen +actionis[.]* *$"))
    then "<tr><td>\(.Wort), der</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort einer Handlung, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +nomen +agentis[.]* *$"))
    then "<tr><td>\(.Wort), der</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ nennwörtlich Machender, männlich – hauptwörtlich …, namenswörtlich …</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *m[_.,;]* +subst[. ]*$"))
    then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *subst[. ]* +m[_.,;]*$"))
    then "<tr><td>\(.Wort), die</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    
  elif (.gram|test("^ *n[_.,;]* *$"))
    then "<tr><td>\(.Wort), das</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]*\\? *$"))
    then "<tr><td>\(.Wort), das?</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, ?sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* *$"))
    then "<tr><td>\(.Wort), das (o./u.a.: der)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, sächlich vermutlich – o./u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +n[_.,;]* *$"))
    then "<tr><td>\(.Wort), das (o./u.a.: das)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, sächlich vermutlich – o./u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.Wort), das (o./u.a.: die)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, sächlich vermutlich – o./u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +m[_.,;]* +f[_.,;]* *$"))
    then "<tr><td>\(.Wort), das (o./u.a.: der, die)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, sächlich vermutlich – o./u.a. männlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +f[_.,;]* +m[_.,;]* *$"))
    then "<tr><td>\(.Wort), das (o./u.a.: die, der)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort, sächlich vermutlich – o./u.a. weiblich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    
    elif (.gram|test("^ *n[_.,;]* +nomen +actionis[.]* *$"))
    then "<tr><td>\(.Wort), das</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort einer Handlung – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    elif (.gram|test("^ *n[_.,;]* +nomen +agentis[.]* *$"))
    then "<tr><td>\(.Wort), das</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ nennwörtlich Machendes, sächlich – hauptwörtlich …, namenswörtlich …</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

    elif (.gram|test("^ *nomen *$"))
    then "<tr><td>\(.Wort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
    

  elif  (.gram|test("^ *part[icz]*[.;]? *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Mittelwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj[.]? *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ mittelwörtliches Eigenschaftswort, Beiwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part[icpalesz]*[. -]+adj[ektiv]*[. ]+[oder ]*adv[erb]*.*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ mittelwörtliches Eigenschaftswort oder Umstandswort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *part.[ -]+adv.[ ]+adj.*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ mittelwörtliches Umstandswort oder Eigenschaftswort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *präp[_.,;]* *$|^ *pr&#x00e4;p[_.,;]* *$|^ *praep[os]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Vorwort, Verhältniswort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *praet.[;]? *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Vergangenheit</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *pron[omen]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Vornennwort, Fürwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif  (.gram|test("^ *refl[.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ sich-bezogenes Zeitwort, Tuwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *subst. *$"))
  then "<tr><td>\(.Wort)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Nennwort – Dingwort, Hauptwort, Namenwort, ?Eigenwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *subst. *inf[.]?$|^ *subst. *v[er]?b[.]?$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ nennwörtliches Zeitwort, Tuwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *v. +u. +subst. +n. *$"))
  then "<tr><td>\(.label); \(.label), das</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Tuwort und Nennwort sächlich (Tuwort: auch Zeitwort, Tätigkeitswort; Nennwort: auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *st[arkes][.]* +v[erbum]*[.,; ]*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ starkes Zeitwort (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *schw[aches][.]* +v[erbum]*[.,; ]*$|^ *sw[_.,;]* +vb[.,;]* *$|^ *swv[.,; ]*$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ schwaches Zeitwort (auch Tuwort, Zeitwort, Tätigkeitswort)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *untrennbares +v[erbum]*[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ untrennbares Zeitwort (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *trennb[ares]*[.]* +v[erbum]*[.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ trennbares Zeitwort  (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *v[_.,;]* *$|^ *vb[_.,;]* *$|^ *verb[_.,;]* *$|^ *verbum[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Zeitwort (auch Tuwort, Tätigkeitswort)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  
  elif (.gram|test("^ *verb[al]*[ .-]*adj[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschaftswort tuwörtlichen Ursprungs (oder Beiwort zeitwörtlichen Ursprungs)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *verb[al]*[ .-]*adj[_.,;]+[ -–—]+adv[_.,;]* *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Eigenschafts- oder Umstandswort tuwörtlichen Ursprungs</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  
  elif (.gram|test("^ *tr[ans]*[.] *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Tuwort oder Zeitwort ausstrahlend, übertragend („wen/was? → … !“; transitiv)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  elif (.gram|test("^ *intr[ans]*[.] *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Tuwort oder Zeitwort in sich („wen/was? → ??“ ist offen; intransitiv)</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  elif (.gram|test("^ *zahlw[ort]*[.;] *$"))
  then "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ Zahlwort</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"

  else "<tr><td>\(.label)</td><!--wbnetzkwiclink<td><wbnetzkwiclink>https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/\(.value)/textid/1/wordid/1</wbnetzkwiclink></td>wbnetzkwiclink--><td>\(.gram) ~ ?</td><td><small><a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB/\(.label)</a>, <a href=“https://www.woerterbuchnetz.de/DWB?lemid=\(.value)”>woerterbuchnetz.de/DWB?lemid=\(.value)</a></small></td></tr>"
  end
  ' | sed --regexp-extended "s@\"@@g;
  s@“([^“”]+)”@\"\1\"@g;
s@&#x00e4;@ä@g;
s@&#x00f6;@ö@g;
s@&#x00fc;@ü@g;
# soll JQ MACHEN s@<td>([^ ])([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>\U\1\L\2\E\3\4@g; # ersten Buchstaben Groß bei Nennwörtern
# soll JQ MACHEN s@<td>(&#x00e4;|&#196;|&auml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00C4;\L\2\E\3\4@g; # ä Ä 
# soll JQ MACHEN s@<td>(&#x00f6;|&#246;|&ouml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00D6;\L\2\E\3\4@g; # ö Ö
# soll JQ MACHEN s@<td>(&#x00fc;|&#252;|&uuml;)([^ ]+)(,? ?[^<>]*)(</td><td>[^<>]* ~ *Nennwort)@<td>&#x00DC;\L\2\E\3\4@g; # ü Ü 
1 i\<!DOCTYPE html>\n<html lang=\"de\" xml:lang=\"de\" xmlns=\"http://www.w3.org/1999/xhtml\">\n<head>\n<title></title>\n</head>\n<style type=\"text/css\" >\n#Wortliste-Tabelle td { vertical-align:top; }\n\n#Wortliste-Tabelle td:nth-child(2),\n#Wortliste-Tabelle td:nth-child(4),\n#Wortliste-Tabelle td:nth-child(5) { font-size:smaller; }\n\na.local { text-decoratcion:none; }\n</style>\n<body><p>${bearbeitungstext_html}</p><p>Diese Tabelle ist nach <i>Grammatik (Grimm)</i> buchstäblich vorsortiert gruppiert, also finden sich Tätigkeitswörter (Verben) beisammen, Eigenschaftswörter (Adjektive) beisammen, Nennwörter (Substantive), als auch Wörter ohne Angabe der Grammatik/Sprachkunst-Begriffe usw..</p><!-- hierher Abkürzungsverzeichnis einfügen --><p>Zur Sprachkunst oder Grammatik siehe vor allem <i style=\"font-variant:small-caps;\">Schottel (1663)</i> das ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href=\"https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6\">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table id=\"Wortliste-Tabelle\"><thead><tr><th>Wort</th><!--wbnetzkwiclink<th>Textauszug (gekürzt)</th>wbnetzkwiclink--><th>Grammatik (<i>Grimm</i>) ~ Sprachkunst, Sprachlehre (s. a. <i style=\"font-variant:small-caps;\">Schottel&nbsp;1663</i>)</th><th>Verknüpfungen</th></tr></thead><tbody>
$ a\</tbody><tfoot><tr><td colspan=\"4\" style=\"border-top:2px solid gray;border-bottom:0 none;\"></td>\n</tr></tfoot></table>${html_technischer_hinweis_zur_verarbeitung}\n</body>\n</html>
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
        meldung "${ORANGE}Etwas lief schief … exit code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI} (?wget, ?jq …)" ;;
      esac
      # echo "ENTWICKLUNG ${wbnetzkwiclink_regex_suchadresse}"
      echo "»${fundstelle_text}«" | sed --regexp-extended 's@»([ ;.:]+)@»…\1@g; s@«@…«@' > "${datei_diese_fundstelle}"
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
        pandoc \
        --variable=subtitle:"${untertitel_text}" \
        --from html \
        --to odt "${datei_utf8_html_gram_tidy}" \
        --output "${datei_utf8_odt_gram}" # siehe ~/.pandoc/reference.odt
      ;;
      [nN]|[nN][eE][iI][nN])
        echo " sichere ${datei_sicherung} …";
        mv "${datei_utf8_odt_gram}" "${datei_sicherung}"
        pandoc \
        --variable=subtitle:"${untertitel_text}" \
        --from html \
        --to odt "${datei_utf8_html_gram_tidy}" \
        --output "${datei_utf8_odt_gram}"
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
    pandoc \
    --variable=subtitle:"${untertitel_text}" \
    --from html \
    --to odt "${datei_utf8_html_gram_tidy}" \
    --output "${datei_utf8_odt_gram}"
  fi
  if [[ $stufe_einzeltabelle_in_einzelabschtitte -gt 0 ]];then 
    if [[ -e "${datei_utf8_html_gram_tidy}" ]];then    
            meldung "${GRUEN}Weiterverarbeitung: HTML → ODT → MD (Einzeltabelle → Einzelabschnitte)${FORMAT_FREI} (${datei_utf8_html_gram_tidy_worttabelle_odt})"
      if [[ ${stufe_fundstellen} -gt 0 ]];then
        sed --regexp-extended --silent '/<table +id="Wortliste-Tabelle"/,/<\/table>/p' "${datei_utf8_html_gram_tidy}" \
          | pandoc \
            --variable=subtitle:"${untertitel_text}" \
            --from html \
            --to odt \
            --output "${datei_utf8_html_gram_tidy_worttabelle_odt}" \
          && pandoc --to gfm "${datei_utf8_html_gram_tidy_worttabelle_odt}" \
            | awk --field-separator='|' 'BEGIN { 
            # OFS="|"; 
            sprachkunst=""; 
          } 
          function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s };
          function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s };
          function trim(s) { return rtrim(ltrim(s)); };
          FNR > 2 {
            if (sprachkunst == $4) { print trim($2)
            } else { 
              if (length(sprachkunst) > 0 ) {
                print "\n# " trim($4) "\n\n" trim($2) 
              } else {
                print "\n# ohne Begriffsangabe der Sprachkunde " trim($4) "\n\n" trim($2) 
              }
            } ;
          
          sprachkunst=$4; 
          } 
          ' > "${datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte}"
      else 
        sed --regexp-extended --silent '/<table +id="Wortliste-Tabelle"/,/<\/table>/p' "${datei_utf8_html_gram_tidy}" \
          | pandoc \
            --variable=subtitle:"${untertitel_text}" \
            --from html \
            --to odt \
            --output "${datei_utf8_html_gram_tidy_worttabelle_odt}" \
          && pandoc --to gfm "${datei_utf8_html_gram_tidy_worttabelle_odt}" \
            | awk --field-separator='|' 'BEGIN { 
            # OFS="|"; 
            sprachkunst=""; 
          } 
          function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s };
          function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s };
          function trim(s) { return rtrim(ltrim(s)); };
          FNR > 2 {
            if (sprachkunst == $3) { print trim($2)
            } else { 
              if (length(sprachkunst) > 0 ) {
                print "\n# " trim($3) "\n\n" trim($2) 
              } else {
                print "\n# ohne Begriffsangabe der Sprachkunde " trim($3) "\n\n" trim($2) 
              }
            } ;
          
          sprachkunst=$3; 
          } 
          ' > "${datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte}"
      fi

    else
    meldung  "${ORANGE}Kann ${datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte} nicht erstellen, da ${datei_utf8_html_gram_tidy} nicht zu finden war ...${FORMAT_FREI}"
    fi
  fi
  
  if [[ ${stufe_markdown_telegram:-0} -gt 0 ]];then 
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
