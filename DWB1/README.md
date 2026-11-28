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

[Volltextabfrage_DWB1.py](Volltextabfrage_DWB1.py) – Diese Befehlsvorschrift fragt die Volltextsuche ab und gibt die Möglichkeit auch Ausschluß-Wörter anzugeben. Mittels Volltextsuche sind auch lateinische Umschreibungen der GRIMM auffindbar, so daß man sinnverwandte Wörter leichter findet (jedoch fehlen bei vielen Belegen auch lateinische Umschreibungen). Wir können daher versuchen Textstelllen nachzusuchen, in denen „sensib…“ vorkommt:
```bash
Volltextabfrage_DWB1.py  --Volltextabfrage "sensib*" 
```
… und bekommen als Ergebnisbelege recht viele Fühl- und Empfindungswörter:

    empfindeln;
    fühlend;
    sturm;
    elementarisch;
    empfindbar;
    empfindlich;
    empfindlich (adv.);
    fühlbar (adj.);
    fühlbar (adv.);
    fühlig (adj.);
    fühlig (adv.);
    fühlsam (adj.);
    gefühlig (adj.);
    gewiss (adj. und adv.);
    seelentzückend (adj.);
    sensibel (adj.);
    sichtbar (adj.);
    sichtlich (adj.);
    sinnig (adj.);
    sinnisch (adj.);
    sinnlich (adj.);
    spürhaft (adj. und adv.);
    spürig (adj.);
    spürlich (adj. und adv.);
    …
    usw.


In schlichter Anweisung werden nur Textdateien erzeugt mit den Stichworten/Lemmata in denen die Volltextsuche etwas gefunden hat. Vermittels zusätzlicher Befehls-Anweisungen kann man gesonderte Ausgabeformate oder eine nachlesende Zusammenfassung (tatsächlich im Text gefundene Wortformen) erstellen lassen:

- Textdatei nur aus Wörtern
- Textdatei aus Wörtern mit Sprachkunde-Angabe
- hinzufügbar: Wortfunde zusammenfassen (`--wortfunde-auslesen`)
- hinzufügbar (ODT): Offenes Dokument Textvormat als Wortlisten-Tabelle  (`--ODT`)
- hinzufügbar (HTML): Netzseite als Wortlisten-Tabelle (`--HTML`)
- usw. siehe Datei-Hilfe

Die umfangreiche Hilfe kann mit `--Hilfe` angezeigt werden:

    Nutzung:
      ./Volltextabfrage_DWB1.py [-h] [-s] [-H] [-O] [-S "…"] -V "stupere"
    
    Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
    DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
    - Textdatei reine Wortliste (ohne Zusätzliches)
    - Textdatei mit Sprachkunde-Einträgen
    Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programme pandoc / tidy).
    
    Verwendbare Wahlmöglichkeiten:
    -h,    --Hilfe             Hilfetext dieses Programms ausgeben.
    -v,-V  --Volltextabfrage   Pflichtfeld für die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.
    -S     --Stichwortabfrage  Zusätzliche Einschränkung der Stichworte/Lemmata (z.B. „*lösen*“, „*heili*, *heils*“).
    -o,    --ohne              Ohne diese Stichwörter/Lemmata – Liste einfacher regulärer Ausdrücke anwendbar
                               (z.B. --ohne "*pflicht, das *licht").
    -e,    --eineinzig         Ergebnisliste vereinzigen, so daß nur jedes Stichwort einmal vorkommt.
    -H,    --HTML              HTML-Datei erzeugen.
    -O,    --ODT               ODT-Datei (für LibreOffice) erzeugen.
    -T,    --Telegrammarkdown  MD-Datei (für Text in Markdown bei Telegram) erzeugen.
    -z,    --wortfunde-auslesen
                               Zusammenfassend alle Wortfunde nachlesen, der im Volltext gefundenen Wortformen 
                               und in ein gesondertes Markdown-Dokument schreiben 
                               (<gesuchte-wort-abfrage>-utf8 Volltext nur Wortfunde zusammengefaßt.md) erstellen.
           --Einzeltabelle     Die Wörtertabelle allein in eine gesonderte Datei speichern.
    -b,    --behalte_Dateien   Behalte auch die vorläufigen Zwischendateien, die regulär gelöscht werden.
    -s,    --stillschweigend   Kaum Meldungen ausgeben.
           --debug             Befehlsmeldungen und Debug-Informationen ausgeben.
           --farb-frei         Meldungen ohne Farben ausgeben.
    
    Wahlmöglichkeiten für Suchpuffer & Zeitgleichsuche:
           --ohne-suchpuffer   Den persistenten SQLite-Suchpuffer für diesen Lauf außer acht lassen.
           --suchpuffer-leeren Den gesamten SQLite-Suchpuffer leeren und Speicherplatz freigeben.
           --suchpuffer-info   Verdichtete Übersicht zur Nutzung, Speichergröße und Wiederfunden ausgeben.
           --suchpuffer-pfad   Benutzerdefinierten Pfad für die SQLite-Pufferdatei angeben.
           --ohne-zeitgleich-suche
                               Zeitgleiches Nachladen von Fundstellen (4-fach suchend) abschalten und rein nacheinander abfragen.

Das Suchergebnis kann also sehr umfangreich werden, und es wird empfohlen, achtsam mit den Abfragen umzugehen, da bei Erzeugung der umfänglichen Textdokumente erneute Netzanfragen getätigt werden müssen. Hierfür versucht ein Suchpuffer einen vernünftigen Mittelweg zu schaffen, wobei mehrmalige Anfragen derselben (kürzlich verwendeten) Volltextsuchen, den hiesigen Suchpuffer nutzen, anstatt die Serveranfragen unnötig zu belasten:

```bash
./Volltextabfrage_DWB1.py --suchpuffer-info
# === Übersicht & Auskunft zum DWB1-Suchpuffer ===
#   Bestand der Datenbank:  Vorhanden
#   Speicherort (SQLite):   /home/andreas/.cache/woerterbuchnetz/dwb1_suchpuffer.sqlite
#   Belegter Speicherplatz: 0.04 MB (40.960 Bytes) / größtens 100 MB
#   Gespeicherte Einträge:  18 / höchstens 10.000 Einträge
#   Längste Vorratsdauer:   180 Tage (Selbstleerung kürzlich kaum genutzter Einträge)
#   Abfrage-Zählungen:
#     - Puffer-Treffer:     36
#     - Neuabrufe (Fehl.):  18
#     - Gesamtanfragen:     54
#     - Wiederfunde:        66.7 %
#   Ältester Eintrag:       2026-11-24T00:48:28.539460
#   Letzter Zugriff:        2026-11-24T00:48:59.029779
```

### Suchbeispiele
```bash
# Hilfe anzeigen lassen
./Volltextabfrage_DWB1.py  --Hilfe

# das lateinische stupere (für staunen, verdutzt sein usw.) abfragen lassen:
./Volltextabfrage_DWB1.py  --Volltextabfrage "stupere" 

./Volltextabfrage_DWB1.py  --HTML --ODT --Volltextabfrage "stupere" # mit 2 Textausgabe-Tabellen-Formaten 

./Volltextabfrage_DWB1.py  --Volltextabfrage "stupere" # mit 2 Textausgabe-Tabellen-Formaten 

# Volltextsuche „…lösen…“, aber nur Stichwörter auf Endung „…ung“, Wortfunde zusammenfassen
./Volltextabfrage_DWB1.py  --Volltextabfrage "*lösen*" --Stichwortabfrage "*ung" --wortfunde-auslesen

# mit Textverarbeitungs-Datei als Tabelle erzeugen
./Volltextabfrage_DWB1.py  --ODT --Volltextabfrage "*lösen*" --Stichwortabfrage "*ung"
```

### Nachlese der tatsächlich im Text vorkommenden Wortformen (Beispielausgabe `--wortfunde-auslesen`)

```bash
./Volltextabfrage_DWB1.py  --Volltextabfrage "*lösen*" --Stichwortabfrage "*ung" --wortfunde-auslesen
```
ergibt beispielsweise:

#### Wortfunde in Stichwörtern/Lemmata

*ablösen* in [*zinsreichung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=Z06937&textid=63531252)

*ablösend* (2 Fundstellen)
- in [*trauung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=T09322&textid=43272532)
- in [*winkung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=W22633&textid=59995260)

*ablösens* in [*ablösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=A00897&textid=65453)

*auflösen* (8 Fundstellen)
- in [*gleichung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=G18787&textid=13147711)
- in [*stockung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=S48286&textid=38988164)
- in [*strahlung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=S50574&textid=39640888)
- in [*verabredung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V00284&textid=49207129)
- in [*verknüpfung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V02220&textid=49787095)
- in [*verwässerung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V06161&textid=51135317)
- in [*wegdrängung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=W10937&textid=56300869)
- in [*werdung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=W17471&textid=58444407)

*aufloͤsen* in [*zeitabtheilung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=Z03440&textid=62533611)

*auflösende* in [*stockung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=S48286&textid=38985790)

*auflösens* in [*auflösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=A06631&textid=637358)

*aufzulösen* (3 Fundstellen)
- in [*bezauberung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=B06602&textid=1686754)
- in [*stockverblasung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=S48294&textid=38988714)
- in [*verkleisterung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V02161&textid=49777820)

*auseinanderlösen* in [*trennung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=T09785&textid=43523543)

*auslösen* in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220296)

*auslösens* in [*auslösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=A08507&textid=845332)

*einlösen* (2 Fundstellen)
- in [*wi(e)derlösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=W19525&textid=59167974)
- in [*zinslosung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=Z06921&textid=63527506)

*erlösen* (2 Fundstellen)
- in [*gottesoffenbarung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=G23809&textid=14398012)
- in [*heilung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=H05395&textid=17467813)

*lösen* (26 Fundstellen)
- in [*brandschatzung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=B10550&textid=2005160)
- in [*erlassung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=E07965&textid=4291918)
- in [*göttererscheinung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=G23472&textid=14286924)
- in [*grasböschung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=G26080&textid=14970744)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23219867)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23219884)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220094)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220261)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220292)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220410)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220481)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220529)
- in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220598)
- in [*loslösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06869&textid=23215860)
- in [*losung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23218722)
- in [*losung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23218811)
- in [*losung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23219048)
- in [*losung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23219468)
- in [*rechnung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=R02004&textid=27717301)
- in [*schatzung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=S05324&textid=29648229)
- in [*spannung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=S32700&textid=34930286)
- in [*verkettung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V02083&textid=49756113)
- in [*verschränkung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V03724&textid=50233611)
- in [*verwirrung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V06474&textid=51290034)
- in [*vorlosung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V13878&textid=52839949)
- in [*vorzugsstellung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=V16677&textid=53496782)

*lösent* in [*losung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23219588)

*wasserlösen* (2 Fundstellen)
- in [*kammelung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=K00916&textid=19096501)
- in [*wetterung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=W18814&textid=58869958)

*wiederlösen* in [*lösung*](https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220331)

#### Wortfunde als Tabelle

| Volltextfund     | im Stichwort (Lemma) | Fundstelle im Wörterbuchnetz                                         |
|:-----------------|:---------------------|:---------------------------------------------------------------------|
| ablösen          | zinsreichung         | <https://woerterbuchnetz.de/?sigle=DWB&lemid=Z06937&textid=63531252> |
| ablösend         | trauung              | <https://woerterbuchnetz.de/?sigle=DWB&lemid=T09322&textid=43272532> |
| ablösend         | winkung              | <https://woerterbuchnetz.de/?sigle=DWB&lemid=W22633&textid=59995260> |
| ablösens         | ablösung             | <https://woerterbuchnetz.de/?sigle=DWB&lemid=A00897&textid=65453>    |
| auflösen         | gleichung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=G18787&textid=13147711> |
| auflösen         | stockung             | <https://woerterbuchnetz.de/?sigle=DWB&lemid=S48286&textid=38988164> |
| auflösen         | strahlung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=S50574&textid=39640888> |
| auflösen         | verabredung          | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V00284&textid=49207129> |
| auflösen         | verknüpfung          | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V02220&textid=49787095> |
| auflösen         | verwässerung         | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V06161&textid=51135317> |
| auflösen         | wegdrängung          | <https://woerterbuchnetz.de/?sigle=DWB&lemid=W10937&textid=56300869> |
| auflösen         | werdung              | <https://woerterbuchnetz.de/?sigle=DWB&lemid=W17471&textid=58444407> |
| aufloͤsen         | zeitabtheilung       | <https://woerterbuchnetz.de/?sigle=DWB&lemid=Z03440&textid=62533611> |
| auflösende       | stockung             | <https://woerterbuchnetz.de/?sigle=DWB&lemid=S48286&textid=38985790> |
| auflösens        | auflösung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=A06631&textid=637358>   |
| aufzulösen       | bezauberung          | <https://woerterbuchnetz.de/?sigle=DWB&lemid=B06602&textid=1686754>  |
| aufzulösen       | stockverblasung      | <https://woerterbuchnetz.de/?sigle=DWB&lemid=S48294&textid=38988714> |
| aufzulösen       | verkleisterung       | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V02161&textid=49777820> |
| auseinanderlösen | trennung             | <https://woerterbuchnetz.de/?sigle=DWB&lemid=T09785&textid=43523543> |
| auslösen         | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220296> |
| auslösens        | auslösung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=A08507&textid=845332>   |
| einlösen         | wi(e)derlösung       | <https://woerterbuchnetz.de/?sigle=DWB&lemid=W19525&textid=59167974> |
| einlösen         | zinslosung           | <https://woerterbuchnetz.de/?sigle=DWB&lemid=Z06921&textid=63527506> |
| erlösen          | gottesoffenbarung    | <https://woerterbuchnetz.de/?sigle=DWB&lemid=G23809&textid=14398012> |
| erlösen          | heilung              | <https://woerterbuchnetz.de/?sigle=DWB&lemid=H05395&textid=17467813> |
| lösen            | brandschatzung       | <https://woerterbuchnetz.de/?sigle=DWB&lemid=B10550&textid=2005160>  |
| lösen            | erlassung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=E07965&textid=4291918>  |
| lösen            | göttererscheinung    | <https://woerterbuchnetz.de/?sigle=DWB&lemid=G23472&textid=14286924> |
| lösen            | grasböschung         | <https://woerterbuchnetz.de/?sigle=DWB&lemid=G26080&textid=14970744> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23219867> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23219884> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220094> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220261> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220292> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220410> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220481> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220529> |
| lösen            | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220598> |
| lösen            | loslösung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06869&textid=23215860> |
| lösen            | losung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23218722> |
| lösen            | losung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23218811> |
| lösen            | losung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23219048> |
| lösen            | losung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23219468> |
| lösen            | rechnung             | <https://woerterbuchnetz.de/?sigle=DWB&lemid=R02004&textid=27717301> |
| lösen            | schatzung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=S05324&textid=29648229> |
| lösen            | spannung             | <https://woerterbuchnetz.de/?sigle=DWB&lemid=S32700&textid=34930286> |
| lösen            | verkettung           | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V02083&textid=49756113> |
| lösen            | verschränkung        | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V03724&textid=50233611> |
| lösen            | verwirrung           | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V06474&textid=51290034> |
| lösen            | vorlosung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V13878&textid=52839949> |
| lösen            | vorzugsstellung      | <https://woerterbuchnetz.de/?sigle=DWB&lemid=V16677&textid=53496782> |
| lösent           | losung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06885&textid=23219588> |
| wasserlösen      | kammelung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=K00916&textid=19096501> |
| wasserlösen      | wetterung            | <https://woerterbuchnetz.de/?sigle=DWB&lemid=W18814&textid=58869958> |
| wiederlösen      | lösung               | <https://woerterbuchnetz.de/?sigle=DWB&lemid=L06886&textid=23220331> |

## Abfrage-Funktionen der Datenschnittstelle (API)

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

Die folgenden BASH-Dateien sind veraltet, und werden nicht weiter gepflegt
- [DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh](DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh)
- [DWB-PSS_volltext_abfragen-und-ausgeben.sh](DWB-PSS_volltext_abfragen-und-ausgeben.sh)

Sie werden irgendwann gelöscht, bitte stattdessen die Python-Vorschriften verwenden.