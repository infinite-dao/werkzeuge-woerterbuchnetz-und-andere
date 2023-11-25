
## Mehrere Wortverlaufskurven von DWDS Zusammenfassen

Wortverlaufskurven aus Wortlisten erstellen lassen, und diese zusammenzufassen, dies ist wie folgt möglich.

```bash
./Wortliste_verarbeiten.sh --Hilfe
  # Nutzung:
  #   ./Wortliste_verarbeiten.sh "Wortliste_verschwindend_seit_1600.txt"
  # 
  # Wortverlaufskurven aus einer Wortliste erstellen und als PDF abspeichern.
  # Es wird versucht eine Zusammenfassung aller Wortkurven zu erstellen.
  # 
  # Verwendbare Wahlmöglichkeiten:
  # -h,   --Hilfe             Hilfetext dieses Programms ausgeben.
  #       --seit_1946         Verlaufskurfe aus dem Wortkorpus „Zeitungen seit 1945/46“ erstellen
  # -b,   --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
  # 
  # -e,   --Entwicklung       Zusatz-Meldungen zur Entwicklung ausgeben
  #       --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
  #       --farb-frei         Meldungen ohne Farben ausgeben
  # 
  # Technische Anmerkungen:
  # 
  # - abhängig von Befehl wget (Anfragen ins Netz)
  # - abhängig von Befehl inkscape (SVG → PDF Umwandlung)
  # - abhängig von Befehl gs (Ghostscript, PDF Verarbeitung)
  # - abhängig von Befehl ps2pdf (Ghostscript, PDF Verarbeitung)
  # - abhängig von Befehl pdftk (PDF Überlagerung)
  # - abhängig von Befehl enscript (Text in PDF verwandeln)

./Wortliste_verarbeiten.sh Wortliste_verschwindend_seit_1600.txt
./Wortliste_verarbeiten.sh --seit_1946 Wortliste_verschwindend_seit_1946.txt
```

Es gibt auch die Programme, die nur eine Zusammenfassung zusammestellen aus schon vorhandenen Kurven:

```bash
./Zusammenfassung-neu-erstellen_pdfs_seit_1600.sh # für Verlaufskurfen seit 1600
./Zusammenfassung-neu-erstellen_pdfs_seit_1946.sh # für Verlaufskurfen seit 1646
```

## Einzelne Wortverlaufskurve(n) von DWDS beschriften (PDF)

Einzelne Wortverlaufskurven lassen sich wie folgt erzeugen:

```bash
./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh --Hilfe # Hilfe des Programms anzeigen
  # Nutzung:
  #   ./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh [-h] [-s] "Wort"
  #   ./Wortverlaufskurve-dwds-beschriften_inkscape-pdf-Werkzeuge.sh "Wort1; Wort2; Wort3"
  # 
  # Wortverlaufskurve eines gegebenen Worts beschriften und als PDF abspeichern.
  # 
  # Verwendbare Wahlmöglichkeiten:
  # Verwendbare Wahlmöglichkeiten:
  # -h,   --Hilfe             Hilfetext dieses Programms ausgeben.
  #       --Suchcode          Suchencode, der tatsächlich abgefragt wird, z.B. "{'behände','behende','behänd','behend'}"
  #                           Falls mehrere Wortabfragen, dann Trennung durch Strichpünktlein ; (Semikolon)
  #       --seit_1946         Verlaufskurfe aus dem Wortkorpus „Zeitungen seit 1945/46“ erstellen
  # -b,   --behalte_Dateien   Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
  # -e,   --Entwicklung       Zusatz-Meldungen zur Entwicklung ausgeben
  #       --debug             Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
  #       --farb-frei         Meldungen ohne Farben ausgeben
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

## Einzelne Wortverlaufskurve(n) von DWDS beschriften (PNG)

Wortverlaufskurven beschriften und als beschriftetes Bild abspeichern

```bash
./Wortverlaufskurve-dwds-beschriften.sh --Hilfe # Hilfe des Programms anzeigen

./Wortverlaufskurve-dwds-beschriften.sh "wohl"  # ein Wort abfragen

# Für Wörter, die eine Sammelsuche darstellen, z.B. bei behände: verwende --Suchcodeliste
./Wortverlaufskurve-dwds-beschriften.sh --Suchcode "{'behände','behende','behänd','behend'}" behände

# mehrere Wörter abfragen
./Wortverlaufskurve-dwds-beschriften.sh "Gauch; Kuckuck"
```
