# Grimm Wörterbuch DWB1

https://woerterbuchnetz.de/DWB/

Im folgenden Programm wird `https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*vera*/0/json` abgefragt und verschiedene Dateien erzeugt in denen reinweg die gefundenen Wörter stehen oder eine ausführliche Wortlisten-Tabelle:
- Textdatei nur aus Wörtern
- Textdatei aus Wörtern mit Grammatik-Angabe
- hinzufügbar: Wortlisten-Tabelle (ODT – Offenes Dokument Textvormat)
- hinzufügbar: Wortlisten-Tabelle (HTML – als Netzseite)

```bash
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh --hilfe  # Hilfe anzeigen lassen mit allen Wahlmöglichkeiten (Optionen)
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --ODT  --lemmaabfrage "*vera*"
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --HTML  --lemmaabfrage "*vera*"
./DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --HTML --ODT --lemmaabfrage "*vera*"
```
