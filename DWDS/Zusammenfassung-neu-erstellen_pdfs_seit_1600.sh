#!/bin/bash
# Entwurf eines Programms, einzelne PDF Wortverlaufskurven in ein Einzeldokument zusammenfügen.

set -Eeuo pipefail
trap aufraeumen SIGINT SIGTERM ERR EXIT

progr_verz=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

stufe_aufraeumen_aufhalten=0
abbruch_code_nummer=0

pdf_datei_zwischenablage="Zusammenfassung_Woerter_seit_1600_ruecklaeufig_Zwischenablage_$(date '+%Y%m%d').pdf"
pdf_datei_endfassung="Zusammenfassung - Wörter seit 1600 rückläufig (DTA u. DWDS, $(date '+%Y%m%d')).pdf"
latex_datei_endfassung="${pdf_datei_endfassung%.*}.tex"

pdf_erstellen_sh_programm="pdfjam_einzel-PDF-zusammenfuegen.sh"
info_urheber="Digitales Wörterbuch der Deutschen Sprache (dwds.de)"

info_schluesselwoerter=$( ls *DWDS-Wortverlauf\ seit\ 1600*.*pdf | sed 's@ - .*@@' | sort | uniq | tr '\n' ';' | sed --regexp-extended 's@;@; @g; s@\s+\([^()]+\)@@g; s@ +$@@' )
info_schluesselwoerter_latex_href=$( ls *DWDS-Wortverlauf\ seit\ 1600*.*pdf | sed 's@ - .*@@' | sort | uniq | sed -r 'h; s@([^()]+) \(.*$@\1@; s@(.+)@ \\href{https://dwds.de/wb/&}{@; G; s@\n@@g; s@([^ ]),([^ ])@\1, \2@g; s@$@};@' | tr '\n' ' '  )

n_schluesselwoerter=$( ls *DWDS-Wortverlauf\ seit\ 1600*.*pdf | sed 's@ - .*@@' | sort | uniq | wc -l )

info_titel="${n_schluesselwoerter} Beispielwörter langsam verschwindend seit 1600 – Korpus DWDS+DTA ($(date '+%Y%m%d'))"


abhaengigkeiten_pruefen() {
  local stufe_abbruch=0

  if ! [[ -x "$(command -v pdfjam)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} pdfjam ${ORANGE} zum Verarbeiten von PDF-Seiten (TeX-Live) nicht gefunden: Bitte${FORMAT_FREI} pdfjam ${ORANGE} aus TeX-Live o.ä. installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  if ! [[ -x "$(command -v xelatex)" ]]; then
    printf "${ORANGE}Kommando${FORMAT_FREI} xelatex ${ORANGE} zum Verarbeiten von XeLaTeX in PDF-Seiten (TeX-Live) nicht gefunden: Bitte${FORMAT_FREI} xelatex ${ORANGE} aus TeX-Live o.ä. installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  fi
  # pdftk als Notlösung um PDF Seitenanzahl zu erfassen, falls pdfjam Probleme macht
  # if ! [[ -x "$(command -v pdftk)" ]]; then
  #   printf "${ORANGE}Kommando${FORMAT_FREI} pdftk ${ORANGE} zum Verarbeiten von PDF-Informationen nicht gefunden: Bitte${FORMAT_FREI} pdftk ${ORANGE} vermittels der Programmverwaltung installieren.${FORMAT_FREI}\n"; stufe_abbruch=1;
  # fi

  case $stufe_abbruch in [1-9]) printf "${ORANGE}(Abbruch)${FORMAT_FREI}\n"; exit 1;; esac
}
abhaengigkeiten_pruefen

aufraeumen() {
  trap - SIGINT SIGTERM ERR EXIT
  # aufzuräumendes für dieses Programm

  if [[ ${stufe_aufraeumen_aufhalten:-0} -eq 0 ]];then
    if [[ -e "${pdf_datei_endfassung}" ]];then
      meldung "${GRUEN}Unnötige Dateien austilgen …${FORMAT_FREI}"
      if [[ -e "${pdf_datei_zwischenablage}" ]]; then rm "${pdf_datei_zwischenablage}"; fi
      if [[ -e "${pdf_erstellen_sh_programm}" ]]; then rm "${pdf_erstellen_sh_programm}"; fi      
      find . -iname "${pdf_datei_endfassung%.*}*" -not -iname "${pdf_datei_endfassung}" -exec rm "{}" ";"
    fi
  else
    meldung "${ORANGE}Behalte alle überflüssigen Dateien (*.tex, Zwischenablage u.ä.)${FORMAT_FREI}"
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

vorlage_pdflatex() {
  local diese_vorlage=''

  # % Falls sonderbarerweise unter XeLaTeX pages=- er nur die erste PDF-Seite, 
  # % kann man mit pdftk die genaue Seitenanzahl \$pdfseite_letzte vorausberechnen lassen und dann mit der folgenden 
  # % Anweisung einschließlich der von-bis-Seitenangabe dennoch die Einzelseiten einbinden, dies
  # % ist nur eine Notlösung
  # %    \\\includepdf[pages={1-${pdfseite_letzte}}]{\\\detokenize{"${pdf_datei_zwischenablage%.*}".pdf}} 

  diese_vorlage=$( cat <<VORLAGE
\\documentclass[12pt]{scrartcl}
\\usepackage{fontspec}
\\usepackage{microtype}
\\usepackage{pdfpages}
\\usepackage[german]{babel}
\\usepackage{xcolor}
\\\definecolor{darkblue}{rgb}{0,0,.5}

% \\usepackage{multicol}
% \\setlength{\\\columnsep}{1cm}

\\usepackage{hyperref}
\\hypersetup
{%
  pdftitle = {${info_titel}},
  pdfsubject = {Wörter seit 1600 verschwindend oder rückläufig},
  pdfauthor = {${info_urheber}; ANDREAS aus dem Hause PLANK},
  pdfkeywords = {${info_schluesselwoerter}},
  urlcolor=blue!30!black,%,
  breaklinks=true,
  citecolor=blue!30!black,
  linkcolor=black,%
  colorlinks=true
}
\\urlstyle{rm}

\\\titlehead{${info_titel}}
\\\title{Seit 1600 verschwindende Wörter}
\\\subtitle{Korpus DWDS+DTA}
\\\author{${info_urheber} \\\and ANDREAS aus dem Hause PLANK}
\\\date{${datum_heute_lang// (/\\\\\\ (}}
\\\begin{document}
\\maketitle
% \\\begin{multicols}{2}
% [
\\\section{Wörter langsam verschwindend}
Dies ist eine Beispiel-Auswahl an Wörtern die vielleicht langsam ins Vergessen geraten, oder aus dem Alltag verschwinden, sie ist zwar willkürlich gewählt, dennoch hoffentlich aufschlußreich ;-). Die folgenden ${n_schluesselwoerter} Wörter wurden vom Digitalen Wörterbuch der Deutschen Sprache (\\href{https://dwds.de}{dwds.de}) abgefragt, und daraus die anschließenden abnehmenden Wortverlaufskurven dargestellt:
% ]

\\\hyphenpenalty=10000 \\\exhyphenpenalty=10000 \\\sloppy
${info_schluesselwoerter_latex_href}

% \\\end{multicols}

\\\includepdf[pages=-,addtotoc={1,section,1,Wortverlaufskurven,wortverlaufskurven1}]{${pdf_datei_zwischenablage%.*}.pdf} 

\\\end{document}

VORLAGE
)

 echo -e "${diese_vorlage}" # einschließlich tatsächlicher Wandelwerte
}


# cd "${PWD}"

case $(date '+%m') in
01|1) datum_heute_lang=$(date '+%_d. im Wintermonat %Y (%B)' | sed 's@^ *@@; s@Januar@& = röm. Gott Janus@;') ;;
02|2) datum_heute_lang=$(date '+%_d. im Hornung %Y (%B)'     | sed 's@^ *@@; s@Februar@& = lat. februare „reinigen“@; ') ;;
03|3) datum_heute_lang=$(date '+%_d. im Lenzmonat %Y (%B)'   | sed 's@^ *@@; s@März@& = röm. Gott Mars@; ') ;;
04|4) datum_heute_lang=$(date '+%_d. im Ostermonat %Y (%B)'  | sed 's@^ *@@; s@April@& = lat. Aprilis@;') ;;
05|5) datum_heute_lang=$(date '+%_d. im Wonnemonat %Y (%B)'  | sed 's@^ *@@; s@Mai@& = röm. Maius o. Göttin Maia@;') ;;
06|6) datum_heute_lang=$(date '+%_d. im Brachmonat %Y (%B)'  | sed 's@^ *@@; s@Juni@& = röm. Göttin Juno@; ') ;;
07|7) datum_heute_lang=$(date '+%_d. im Heumonat %Y (%B)'    | sed 's@^ *@@; s@Juli@& = röm. Julius (Caesar)@; ') ;;
08|8) datum_heute_lang=$(date '+%_d. im Erntemonat %Y (%B)'  | sed 's@^ *@@; s@August@& = röm. Kaiser Augustus@; ') ;;
09|9) datum_heute_lang=$(date '+%_d. im Herbstmonat %Y (%B)' | sed 's@^ *@@; s@September@& = lat. Septimus, 7@; ') ;;
  10) datum_heute_lang=$(date '+%_d. im Weinmonat %Y (%B)'   | sed 's@^ *@@; s@Oktober@& = lat. Octavus, 8@; ') ;;
  11) datum_heute_lang=$(date '+%_d. im Nebelmonat %Y (%B)'  | sed 's@^ *@@; s@November@& = lat. Nonus, 9@; ') ;;
  12) datum_heute_lang=$(date '+%_d. im Weihemonat %Y (%B)'  | sed 's@^ *@@; s@Dezember@& = lat. Decimus, 10@; ') ;;
esac


meldung "${GRUEN}Erstellen von${FORMAT_FREI} ${pdf_datei_zwischenablage} …"

meldung "${GRUEN}PDF Erstellung vorschreiben ${BLAU}${pdf_erstellen_sh_programm}${FORMAT_FREI} (pdfjam) …"

echo '#!/bin/bash' > "${pdf_erstellen_sh_programm}"
echo '' >> "${pdf_erstellen_sh_programm}"
echo 'pdfjam --quiet \' >> "${pdf_erstellen_sh_programm}"
# ls -Q *DWDS-Wor*seit*.svg.pdf | sort | sed 's@$@ \\@; s@^@  @'
ls -Q *DWDS-Wor*seit*1600*.svg.pdf | sort | sed 's@$@ \\@; s@^@  @' >> "${pdf_erstellen_sh_programm}"

echo " --pdfauthor '${info_urheber}' \\"  >> "${pdf_erstellen_sh_programm}"
echo " --pdfkeywords \"${info_schluesselwoerter}\" --pdftitle \"${info_titel}\" \\"      >> "${pdf_erstellen_sh_programm}"
echo " --frame true  --nup 3x6 --outfile \"${pdf_datei_zwischenablage}\""      >> "${pdf_erstellen_sh_programm}"

chmod u+x "${pdf_erstellen_sh_programm}"

meldung "${GRUEN}Zusammenfassung PDF selbst erstellen (pdfjam)${FORMAT_FREI}…"

./"${pdf_erstellen_sh_programm}"


# Notlösung $pdfseite_letzte für $vorlage_pdflatex und bestimmte Seitenangabe pages={1-$pdfseite_letzte}
# pdfseite_letzte=$( pdftk "${pdf_datei_zwischenablage}" dump_data \
#       | sed --silent --regexp-extended "/NumberOfPages:/ { s@NumberOfPages: *([0-9]+)@\1@p }" )

# pdfjam  \
#   "Abkomme - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "ablohnen - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "abwesen - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "achten - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "allda - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "allenthalben - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "allgemach - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "also - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "Ankunft - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "anrichten - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "ansehen - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "aufwarten - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "ausbündig - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#   "behände (behände,behende,behänd,behend) - DWDS-Wortverlauf seit 1600 (DTA,DWDS).svg.pdf" \
#  --pdfauthor 'Digitales Wörterbuch der Deutschen Sprache (dwds.de)' \
#  --pdfkeywords "${info_schluesselwoerter}" --pdftitle "${info_titel}" \
#  --frame true  --nup 3x6 --outfile "${pdf_datei_zwischenablage}"

# -------------------
# 98 Beispielwörter langsam verschwindend seit 1600 (Korpus-Zeitungen, 20231108)
# 
# Abkomme; ablohnen; abwesen; achten; allda; allenthalben; allgemach; also; Ankunft; anrichten; ansehen; aufwarten; ausbündig; behände; beriechen; Brünnlein; Büchlein; da; darob; daselbst; dein; deinethalben; dergestalt; ehrbar; Ehrbarkeit; ehrenfest; Eidam; eilfertig; Eltern; Englein; entraten; erzeigen; Fähnlein; feil; flugs; Fräulein; friedsam; Fünklein; fürwahr; Geduld; gedulden; Geist; geloben; gemach; geschwind; geziemen; girren; gläubig; Glimpf; glimpflich; Hag; Händlein; heischen; Herz; Herzlein; herzlich; irdisch; jähling; Kästlein; Kindlein; Labsal; Lämplein; Leib; Lichtlein; lieblich; Liedlein; Lob; Mägdlein; Mündlein; Nachkomme; Odem; offenbaren; Rat; Reich; richten; Ringlein; Röslein; Schäflein; Schätzlein; Schifflein; schleunig; selig; Söhnlein; Sprüchlein; stracks; Stündlein; tauglich; Töchterlein; unserethalben; unsertwegen; Vater; vergeben; weise; Weltmensch; Werk; wohlan; wollen; Wörtlein; 

vorlage_pdflatex > "${latex_datei_endfassung}"

# pdflatex -synctex=1 -interaction=nonstopmode "${latex_datei_endfassung}"
xelatex -synctex=1 -interaction=nonstopmode "${latex_datei_endfassung}" && abbruch_code_nummer=$?

case $abbruch_code_nummer in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
  meldung "${ORANGE}Irgendwas lief schief mit xelatex. Abbruch Code: ${abbruch_code_nummer} $(kill -l $abbruch_code_nummer)${FORMAT_FREI}" ;;
esac

# pdflatex

meldung "${GRUEN}-------------------${FORMAT_FREI}"
meldung "${GRUEN}${info_titel}${FORMAT_FREI}"
meldung ""
meldung "${GRUEN}${info_schluesselwoerter}${FORMAT_FREI}"
meldung "${GRUEN}-------------------${FORMAT_FREI}"

# if [[ -e "${pdf_datei_zwischenablage}" ]];then
#   rm "${pdf_datei_zwischenablage}"
# fi

meldung "${GRUEN}Siehe Datei${FORMAT_FREI} ${pdf_datei_endfassung}"
