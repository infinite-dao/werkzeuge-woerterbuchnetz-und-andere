# Grimm Wörterbuch DWB1

https://woerterbuchnetz.de/DWB/

## Stichwörter abfragen

`Lemmaabfrage_DWB1.py` (sowie das ursprüngliche Shell-Skript `DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh`) – Dieses Programm fragt Lemmata (Hauptwörter-Einträge) ab über eine Programm-Schnitt-Stelle (PSS, engl. API), und es werden verschiedene Dateien erzeugt, in denen reinweg die nur gefundenen Wörter stehen, oder eine ausführliche Wortlisten-Tabelle:
- Textdatei nur aus Wörtern und mit Sprachkunst-Angabe (Grammatik) – diese werden immer erstellt
- hinzufügbar (<abbr title="Offenkundiges Dokument Textformat">ODT</abbr>): Offenkundiges Dokument Textformat als Wortlisten-Tabelle 
- hinzufügbar (HTML): Netzseite als Wortlisten-Tabelle
- uvam.

```bash
# Hilfe anzeigen lassen mit allen Wahlmöglichkeiten (Optionen)
./Lemmaabfrage_DWB1.py --Hilfe
```

    Nutzung:
      ./Lemmaabfrage_DWB1.py [-h] [-s] [-H] [-O] -l "*wohl*"
    
    Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
    DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
    - Textdatei reine Wortliste (ohne Zusätzliches)
    - Textdatei mit Grammatik-Einträgen
    Zusätzlich kann man eine HTML- oder ODT-Datei erstellen lassen (benötigt ggf. pandoc / tidy).
    
    Verwendbare Wahlmöglichkeiten:
    -h,  --Hilfe          Hilfetext dieses Programms ausgeben.
    -l,-L, --Lemmaabfrage Die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.
                          mehrere Suchwörter zugleich sind möglich: „*wohn*, *wöhn*“
    -F,  --Fundstellen    Fundstellen mit abfragen, jedes Stichworts
    -H,  --HTML           HTML-Datei erzeugen
    -O,  --ODT            ODT-Datei (für LibreOffice) erzeugen. 
                          Hierbei dient pandoc_Vorlage_DWB1_Wörterliste.odt als Vorlagendatei, 
                          die gerne umgestaltet werden kann.
         --Liste_Einzelabschnitte
                          Wörtertabelle als Wörterliste in Einzelabschnitte umschreiben (als Markdown-Text)
    -T,  --Telegrammarkdown
                          MD-Datei (für Text in Markdown bei Telegram) erzeugen
    -b,  --behalte_Dateien
                          Behalte auch die Zwischendateien, die normalerweise gelöscht werden
    -s,  --stillschweigend
                          Kaum Meldungen ausgeben
    -o,  --ohne           ohne Wörter (Wortliste z.B. --ohne 'aufstand, verstand' bei --Lemmaabfrage '*stand*')
         --entwickeln, --debug
                          Befehlsmeldungen ausgeben, die ausgeführt werden (für Programmier-Entwicklung)
         --farb-frei      Meldungen ohne Farben ausgeben
    
    
Eine einfache Abfrage durchführen, alle Wörter die in-zwischen „…wohl…“ enthalten, und nur die gefundenen Wörter abspeichern als Textdateien
```bash
./Lemmaabfrage_DWB1.py --Lemmaabfrage "*wohl*"
# Abfrage an api.woerterbuchnetz.de … (https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*wohl*/0/json)
# Weiterverarbeitung → JSON 1059 Ergebnisse …
# …
# Weiterverarbeitung → JSON 1055 eineinzige Wörter aus 1059 Ergebnissen
# Folgende Dateien sind erstellt worden:
#   …wohl…_Lemmata-Abfrage-DWB1_20261120-utf8 nur Wörter mit Sprachkunde.txt
#   …wohl…_Lemmata-Abfrage-DWB1_20261120-utf8 nur Wörter.txt
```
Es ergeben sich bei `--Lemmaabfrage "*wohl*"` also Wortlisten in denen _wohl_ inmitten steht, Beispiele:

- hoch*wohl*ehrwürdig; … Grade*wohl*, das; … Volks*wohl*leben, das; *wohl*beschaffen; … *wohl*lauten;

Will man nur Wortanfänge abfragen, dann `--Lemmaabfrage "wohl*"` verwenden.

Technisch gesehen wurde im Beispiel „…wohl…“ über `https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*wohl*/0/json` abgefragt und ausgewertet.

___

Nun erstellen wir eine umfangreiche Abfrage: Wir wollen die Endung „…icht“ erfragen, z. B. in flaschicht; steinicht (d.h. man bedenke steinicht = steinähnlich, hingegen steinig = steinartig usw.), wir können:
- mit `--ODT` ein Tabellendokument, und mit `--Fundstellen` noch Textauszüge zusätzlich abfragen und einbetten lassen
- mit `--Liste_Einzelabschnitte` eine Textliste der Wörter in Einzelabschnitte (nach Sprachkunst sortierte Abschnitte) erstellen, und
- mit `--ohne "…"` können wir Wörter wegnehmen lassen, die wir vorher schon überprüft haben, weil sie als unzutreffend erachtet haben, die wir also nicht brauchen. Dabei können auch Nennwörter gezielt herausgenommen werden, da z.B. neben der Eigenschaft _anprallicht_ viele Licht-Nennwörter mit enthalten sind, diese kann man auslesen lassen mittels: `--ohne "das *licht"`, was nur sächliche Nennwörter mit `*licht` zu entfernen versucht. Eine halbwegs gute und noch sehr umfangreiche Ausgangsliste für _…icht_-Eigenschaftswörter ergibt sich mit: 

```bash
./Lemmaabfrage_DWB1.py --Lemmaabfrage "*icht"  \
  --ohne "*bericht, *bleicht, *bösewicht, fackellicht, *gedicht, *gesicht, *gewicht, gewicht*, gaulicht, golicht"\
  ", nicht, der *nicht, zunicht,  *verzicht*, *zuversicht, das Berührmeinnicht, das *dickicht, das Waldesdicht"\
  ", die *gicht, das Gegicht, das Kaltvergicht, das Vergicht, das *gericht, der Ketzergericht, der *habicht"\
  ", das *licht, die *pflicht, die *licht, die *nachricht, das *röhricht, der Schlicht, die *schicht"\
  ", die *sicht, das Herrenschicht, das Schmeckenicht, der *unterricht, die *unterricht"\
  ", der *wicht, das *vergißmeinnicht" # --ODT --Fundstellen
# Abfrage an api.woerterbuchnetz.de … (https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*icht/0/json)
# Weiterverarbeitung → JSON 3285 Ergebnisse …
# …
# Weiterverarbeitung → JSON 1762 eineinzige Wörter aus 3285 Ergebnissen
# Weiterverarbeitung → JSON → HTML (1800 Fundstellen)
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

