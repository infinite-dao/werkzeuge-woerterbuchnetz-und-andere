# Grimm Wörterbuch DWB1

https://woerterbuchnetz.de/DWB/

## `DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh`

Im folgenden Programm wird „…wohl…“ über `https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*wohl*/0/json` abgefragt, und verschiedene Dateien erzeugt, in denen reinweg die gefundenen Wörter stehen, oder eine ausführliche Wortlisten-Tabelle:
- Textdatei nur aus Wörtern
- Textdatei aus Wörtern mit Grammatik-Angabe
- hinzufügbar (ODT): Offenes Dokument Textvormat als Wortlisten-Tabelle 
- hinzufügbar (HTML): Netzseite als Wortlisten-Tabelle

```bash
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh --Hilfe  # Hilfe anzeigen lassen mit allen Wahlmöglichkeiten (Optionen)
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --ODT  --lemmaabfrage "*wohl*"
  # Folgende Dateien sind erstellt worden:
  # -rw-r--r-- 1 andreas users  5444 10. Nov 00:54 …wohl…lemmata-select-DWB-20221110-utf8_nur-Wörter+gram.txt
  # -rw-r--r-- 1 andreas users  4099 10. Nov 00:54 …wohl…lemmata-select-DWB-20221110-utf8_nur-Wörter.txt
  # -rw-r--r-- 1 andreas users 15742 10. Nov 00:54 …wohl…lemmata-select-DWB-20221110-utf8_Wortliste+gram.odt

./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --HTML       --Lemmaabfrage "*wohl*"
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --HTML --ODT --Lemmaabfrage "*wohl*"
```
Es ergeben sich bei `--Lemmaabfrage "*wohl"` also Wortlisten in denen _vera_ mittendrinn steht, Beispiele:

- hoch*wohl*ehrwürdig; … Grade*wohl*, das; … Volks*wohl*leben, das; *wohl*beschaffen; … *wohl*lauten;

Will man nur Wortanfänge abfragen, dann `--Lemmaabfrage "wohl*"` verwenden.

