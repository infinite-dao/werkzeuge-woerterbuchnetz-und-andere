## Leipzig Corpora Collection - Wortschatz Deutsch

Das Netzangebot von [corpora.uni-leipzig.de](https://corpora.uni-leipzig.de) ist eines, welches Wörter eher forschend aufgliedert, Wortverwendungen aus dem Netz aufbereitet, gruppiert usw.; dort gibt es auch die Dornseiff-Bedeutungsgruppen. Die Dornseiff-Bedeutungsgruppen sind sehr aufschlußreich (=Dornseif 1934f. „Der deutsche Wortschatz nach Sachgruppen“). Allgemein sind diese Gruppen von Dornseiff (1934) eingeteilt worden in: 

1. Natur und Umwelt
2. Leben
3. Raum, Lage, Form
4. Größe, Menge, Zahl
5. Wesen, Beziehung, Geschehnis
6. Zeit
7. Sichtbarkeit, Licht, Farbe, Schall, Temperatur, Gewicht, Aggregatzustände
8. Ort und Ortsveränderung
9. Wollen und Handeln
10. Fühlen, Affekte, Charaktereigenschaften
11. Das Denken
12. Zeichen, Mitteilung, Sprache
13. Wissenschaft
14. Kunst und Kultur
15. Menschliches Zusammenleben
16. Essen und Trinken
17. Sport und Freizeit
18. Gesellschaft
19. Geräte, Technik
20. Wirtschaft, Finanzen
21. Recht, Ethik
22. Religion, Übersinnliches

## Beispielabfrage

```bash
./schreibe_Dornseiff-Liste.sh --Hilfe # Benutzung lesen
./schreibe_Dornseiff-Liste.sh --Wortliste "wohl Hilfe Not" # befrage 3 Wörter nach Dorn
```
… und folglich wird eine Liste erstellt, mit gefundenen Dornseiff-Bedeutungen, je als Datei für Textverarbeitungen (Word: \*.docx, LibreOffice: \*.odt):
```
Folgende Dateien sind übrig oder erstellt:
-rw-r--r-- 1 andreas users   649 21. Feb 18:00 ./dornseiff.gesamt_20230221.md
-rw-r--r-- 1 andreas users 10227 21. Feb 18:00 ./dornseiff.gesamt_20230221.md.docx
-rw-r--r-- 1 andreas users 12123 21. Feb 18:00 ./dornseiff.gesamt_20230221.md.odt
```
