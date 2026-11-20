Einige Beispiel-Ergebnisse von Abfragen

```bash
Lemmaabfrage_DWB1.py --Lemmaabfrage '*wohl*' --Fundstellen --ODT
# Abfrage an api.woerterbuchnetz.de … (https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/*wohl*/0/json)
# Weiterverarbeitung → JSON 1059 Ergebnisse …
# Weiterverarbeitung → JSON (…wohl…_Lemmata-Abfrage-DWB1_20261120-utf8_nur-Wörter.txt)
# Weiterverarbeitung → JSON (…wohl…_Lemmata-Abfrage-DWB1_20261120-utf8_nur-Wörter mit Sprachkunde.txt)
# Weiterverarbeitung → JSON 1055 eineinzige Wörter aus 1059 Ergebnissen
# Weiterverarbeitung → JSON (…wohl…_Lemmata-Abfrage-DWB1_20261120-utf8_Zwischenablage_Wortliste mit Sprachkunde.html)
# Weiterverarbeitung → JSON → HTML (1059 Fundstellen)
# .................................................................................................... 0100
# .......................................
# Folgende Dateien sind erstellt worden:
#   …wohl…_Lemmata-Abfrage-DWB1_20261120-utf8_nur-Wörter mit Sprachkunde.txt
#   …wohl…_Lemmata-Abfrage-DWB1_20261120-utf8_nur-Wörter.txt
#   …wohl…_Lemmata-Abfrage-DWB1_20261120_Wortliste mit Sprachkunde.odt
#
# Aufruf früher
# DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh  --Einzeltabelle --Fundstellen --ODT --Lemmaabfrage '*wohl*'
# 1059 Fundstellen und Beiträge mit „…wohl…“-Wörtern
```
