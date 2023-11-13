## Wortverlaufskurve(n) von DWDS beschriften (PDF)

```bash
./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --Hilfe # Hilfe des Programms anzeigen
# Nutzung:
#   ./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh [-h] [-s] "Wort"
#   ./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh "Wort1; Wort2; Wort3"
# 
# Wortverlaufskurve eines gegebenen Worts beschriften und als PDF abspeichern.
# 
# Verwendbare Wahlmöglichkeiten:
# -h,    --Hilfe             Hilfetext dieses Programms ausgeben.
#        --Suchcode          Suchencode, der tatsächlich abgefragt wird, z.B. "{'behände','behende','behänd','behend'}"
#                            Falls mehrere Wortabfragen, dann Trennung durch Strichpünktlein ; (Semikolon)
#        --seit_1946
# -b,    --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
# -e,    --Entwicklung       Zusatz-Meldungen zur Entwicklung ausgeben
#        --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
#        --farb-frei         Meldungen ohne Farben ausgeben
# 
# Technische Anmerkungen:
# 
# - abhängig von Befehl wget (Anfragen ins Netz)
# - abhängig von Befehl inkscape (SVG → PDF Umwandlung)
# - abhängig von Befehl gs (Ghostscript, PDF Verarbeitung)
# - abhängig von Befehl ps2pdf (Ghostscript, PDF Verarbeitung)
# - abhängig von Befehl pdftk (PDF Überlagerung)
# - abhängig von Befehl enscript (Text in PDF verwandeln)

# ein Wort abfragen
./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh lieblich

# mehrere Wörter abfragen
./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh "achten; allda; allenthalben"

# einen anderen Zeitbereich wählen: seit 1946
./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --seit_1946 Abendschein

./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --seit_1946 --Suchcode "{'Fräulein','Frl.'}" Fräulein
```

## Wortverlaufskurve(n) von DWDS beschriften (PNG)

Wortverlaufskurven beschriften und als beschriftetes Bild abspeichern

```bash
./Wortverlaufskurve-dwds-beschriften.sh --Hilfe # Hilfe des Programms anzeigen

./Wortverlaufskurve-dwds-beschriften.sh "wohl"  # ein Wort abfragen

# Für Wörter, die eine Sammelsuche darstellen, z.B. bei behände: verwende --Suchcodeliste
./Wortverlaufskurve-dwds-beschriften.sh --Suchcode "{'behände','behende','behänd','behend'}" behände

# mehrere Wörter abfragen
./Wortverlaufskurve-dwds-beschriften.sh "Gauch; Kuckuck"
```
