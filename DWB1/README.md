# Grimm Wörterbuch DWB1

https://woerterbuchnetz.de/DWB/

## Stichwörter abfragen

`DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh` – Dieses Programm fragt Lemmata (Hauptwörter-Einträge) ab über eine Programm-Schnitt-Stelle (PSS, enl. API), und es werden verschiedene Dateien erzeugt, in denen reinweg die nur gefundenen Wörter stehen, oder eine ausführliche Wortlisten-Tabelle:
- Textdatei nur aus Wörtern und mit Sprachkunst-Angabe (Grammatik) – diese werden immer erstellt
- hinzufügbar (<abbr title="Offenkundiges Dokument Textformat">ODT</abbr>): Offenkundiges Dokument Textformat als Wortlisten-Tabelle 
- hinzufügbar (HTML): Netzseite als Wortlisten-Tabelle
- uvam.

```bash
# Hilfe anzeigen lassen mit allen Wahlmöglichkeiten (Optionen)
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh --Hilfe
```
    Nutzung:
      ./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh [-h] [-s] [-H] [-O] -l "*wohl*"

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
          --Liste_Einzelabschnitte
                              Wörtertabelle als Wörterliste in Einzelabschnitte umschreiben (als Markdown-Text)
    -b,    --behalte_Dateien  Behalte auch die unwichtigen Datein, die normalerweise gelöscht werden
    -s,    --stillschweigend  Kaum Meldungen ausgeben
          --ohne             ohne Wörter (Wortliste z.B. --ohne 'aufstand, verstand' bei --Lemmaabfrage '*stand*')
          --entwickeln,--debug Kommando-Meldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
          --farb-frei        Meldungen ohne Farben ausgeben

    Technische Anmerkungen:

    - abhängig von Befehl jq (JSON Verarbeitung)
    - abhängig von Befehl sed (Textersetzungen)
    - abhängig von Befehl pandoc (Umwandlung der Dateiformate)
      - es kann eine Vorlagedatei im eigenen Nutzerverzeichnis erstellt werden, als ~/.pandoc/reference.odt

Eine einfache Abfrage durchführen, alle Wörter die in-zwischen „…wohl…“ enthalten, und nur die gefundenen Wörter abspeichern als Textdateien
```bash
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh --Lemmaabfrage "*wohl*"
# Weiterverarbeitung → JSON 1059 Ergebnisse …
# Entferne unwichtige Dateien …
# Folgende Dateien sind erstellt worden:
# -rw-r--r-- 1 andreas users 23965 19. Sep 11:51 …wohl…_Lemmata-Abfrage-DWB1_20230919-utf8_nur-Wörter+gram.txt
# -rw-r--r-- 1 andreas users 16877 19. Sep 11:51 …wohl…_Lemmata-Abfrage-DWB1_20230919-utf8_nur-Wörter.txt
```
Es ergeben sich bei `--Lemmaabfrage "*wohl*"` also Wortlisten in denen _wohl_ inmitten steht, Beispiele:

- hoch*wohl*ehrwürdig; … Grade*wohl*, das; … Volks*wohl*leben, das; *wohl*beschaffen; … *wohl*lauten;

Will man nur Wortanfänge abfragen, dann `--Lemmaabfrage "wohl*"` verwenden.

Technisch gesehen wurde im Beispiel „…wohl…“ über `https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*wohl*/0/json` abgefragt und ausgewertet.

___

Nun erstellen wir eine umfangreiche Abfrage: Wir wollen die Endung „…icht“ erfragen, z. B. in flaschicht; steinicht (d.h. man bedenke steinicht = steinähnlich, hingegen steinig = steinartig usw.), wir können:
- mit `--ODT` ein Tabellendokument, und mit `--Fundstellen` noch Textauszüge zusätzlich abfragen und einbetten lassen
- mit `--Liste_Einzelabschnitte` eine Textliste der Wörter in Einzelabschnitte (nach Sprachkunst sortierte Abschnitte) erstellen, und
- mit `--ohne "…"` können wir Wörter wegnehmen lassen, die wir vorher schon überprüft haben, weil sie als unzutreffend erachtet worden, die wir also nicht brauchen

```bash
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh \
  --Liste_Einzelabschnitte \
  --Fundstellen --ODT \
  --Lemmaabfrage  '*icht' \
  --ohne "nicht, *bericht, *pflicht, *gedicht, *gesicht, *gewicht, *bleicht"
# 2632 Fundstellen
```

## Volltextsuche innerhalb von Stichwörterbeiträgen

`DWB-PSS_volltext_abfragen-und-ausgeben.sh` – Dieses Programm befragt die Volltextsuche ab (inmitten des Wörterbuches) über eine Programm-Schnitt-Stelle (PSS, enl. API), und es werden verschiedene Dateien erzeugt, in denen reinweg die nur gefundenen Wörter stehen, oder eine ausführliche Wortlisten-Tabelle:

- Textdatei nur aus Wörtern
- Textdatei aus Wörtern mit Grammatik-Angabe
- hinzufügbar (ODT): Offenes Dokument Textvormat als Wortlisten-Tabelle 
- hinzufügbar (HTML): Netzseite als Wortlisten-Tabelle

Das Ergebnis kann sehr umfangreich sein.

Eingabebeispiel
```bash
./DWB-PSS_volltext_abfragen-und-ausgeben.sh  --Hilfe

# das lateinische stupere (für staunen) abfragen lassen:
./DWB-PSS_volltext_abfragen-und-ausgeben.sh  --HTML --ODT --Volltextabfrage "stupere" 

# Volltextsuche „…lösen…“, aber nur Stichwörter auf Endung „…ung“
./DWB-PSS_volltext_abfragen-und-ausgeben.sh  --HTML --ODT --Volltextabfrage "*lösen*" --Stichwortabfrage "*ung"
```
ZUTUN: Programm verbessern:
- derzeit nur Einzelwörter suchbar, keine Wörter mit Leerzeichen, z.B. Phrasensuche "alte Endung"

## Abfrage-Funktionen (PSS/API)

☞ https://api.woerterbuchnetz.de/open-api/dictionaries/DWB
```json
{
  "result_type": "method_list",
  "query": "/open-api/dictionaries/DWB",
  "result_set": [
    {
      "methodid": "fulltext",
      "comment": "Gesamter Text",
      "path": "/open-api/dictionaries/DWB/fulltext/:searchpattern"
    },
    {
      "methodid": "lemmata",
      "comment": "Stichwort",
      "path": "/open-api/dictionaries/DWB/lemmata/:searchpattern"
    }
  ],
  "result_count": 2
}
```

☞ https://api.woerterbuchnetz.de/open-api/dictionaries/Lexer hat vergleichsweise mehr Funktionen
```json
{
  "result_type": "method_list",
  "query": "/open-api/dictionaries/Lexer",
  "result_set": [
    {
      "methodid": "fulltext",
      "comment": "Gesamter Text",
      "path": "/open-api/dictionaries/Lexer/fulltext/:searchpattern"
    },
    {
      "methodid": "lemmata",
      "comment": "Stichwort",
      "path": "/open-api/dictionaries/Lexer/lemmata/:searchpattern"
    },
    {
      "methodid": "definition",
      "comment": "Definitionen",
      "path": "/open-api/dictionaries/Lexer/definition/:searchpattern"
    },
    {
      "methodid": "citation",
      "comment": "Beleg",
      "path": "/open-api/dictionaries/Lexer/citation/:searchpattern"
    }
  ],
  "result_count": 4
}
```

