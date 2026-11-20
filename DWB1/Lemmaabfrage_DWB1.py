#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Lemmaabfrage_DWB1.py

Fragt Lemmata aus der Programmierschnittstelle (API) des Deutschen Wörterbuchs von Jacob und Wilhelm Grimm (DWB1)
auf woerterbuchnetz.de ab und erstellt strukturierte Text-, HTML-, ODT- und Markdown-Listen.
Portierung und Weiterentwicklung von DWB-PSS-lemmata-select_abfragen-und-ausgeben.sh in Python 3.
"""

import sys
import os
import re
import json
import argparse
import datetime
import html
import shutil
import subprocess
import urllib.request
import urllib.error
from pathlib import Path


class Farben:
    def __init__(self, aktiv=True):
        if aktiv and sys.stderr.isatty():
            self.RESET = '\033[0m'
            self.ROT = '\033[0;31m'
            self.GRUEN = '\033[0;32m'
            self.ORANGE = '\033[0;33m'
            self.BLAU = '\033[0;34m'
            self.VEILCHENROT = '\033[0;35m'
            self.HIMMELBLAU = '\033[0;36m'
            self.GELB = '\033[1;33m'
        else:
            self.RESET = ''
            self.ROT = ''
            self.GRUEN = ''
            self.ORANGE = ''
            self.BLAU = ''
            self.VEILCHENROT = ''
            self.HIMMELBLAU = ''
            self.GELB = ''


def ermittle_altes_monatsdatum(jetzt=None):
    """Erzeugt das traditionelle Datumsformat mit Monatsbezeichnungen nach historischem Vorbild."""
    if jetzt is None:
        jetzt = datetime.datetime.now()
    tag = jetzt.day
    monat = jetzt.month
    jahr = jetzt.year

    monatsdaten = {
        1: f"{tag}. im Wintermonat (Januar ~ röm. Gott Janus) {jahr}",
        2: f"{tag}. im Hornung (Februar ~ lat.: februare „reinigen“) {jahr}",
        3: f"{tag}. im Lenzmonat (März ~ röm. Gott Mars) {jahr}",
        4: f"{tag}. im Ostermonat (April ~ lat.: Aprilis) {jahr}",
        5: f"{tag}. im Wonnemonat (Mai (röm. Maius o. Göttin Maia)) {jahr}",
        6: f"{tag}. im Brachmonat (Juni ~ röm. Göttin Juno) {jahr}",
        7: f"{tag}. im Heumonat (Juli ~ röm. Julius (Caesar)) {jahr}",
        8: f"{tag}. im Erntemonat (August ~ röm. Kaiser Augustus) {jahr}",
        9: f"{tag}. im Herbstmonat (September ~ lat.: Septimus, 7) {jahr}",
        10: f"{tag}. im Weinmonat (Oktober ~ lat.: Octavus, 8) {jahr}",
        11: f"{tag}. im Nebelmonat (November ~ lat.: Nonus, 9) {jahr}",
        12: f"{tag}. im Weihemonat (Dezember ~ lat.: Decimus, 10) {jahr}",
    }
    return monatsdaten.get(monat, f"{tag}. {monat}. {jahr}")


def html_sonderzeichen_als_einzelzeichen(w):
    """Wandelt hexadezimale HTML-Umlaut- und Sonderzeichen-Entities in echte UTF-8-Zeichen um."""
    if not w:
        return ""
    ersetzungen = [
        (re.compile(r'&#x00e4;|&#X00E4;|&auml;|&#228;', re.IGNORECASE), 'ä'),
        (re.compile(r'&#x00c4;|&#X00C4;|&Auml;|&#196;', re.IGNORECASE), 'Ä'),
        (re.compile(r'&#x00f6;|&#X00F6;|&ouml;|&#246;', re.IGNORECASE), 'ö'),
        (re.compile(r'&#x00d6;|&#X00D6;|&Ouml;|&#214;', re.IGNORECASE), 'Ö'),
        (re.compile(r'&#x00fc;|&#X00FC;|&uuml;|&#252;', re.IGNORECASE), 'ü'),
        (re.compile(r'&#x00dc;|&#X00DC;|&Uuml;|&#220;', re.IGNORECASE), 'Ü'),
        (re.compile(r'&#x00fa;|&#X00FA;|&uacute;|&#250;', re.IGNORECASE), 'ú'),
        (re.compile(r'&#x00da;|&#X00DA;|&Uacute;|&#218;', re.IGNORECASE), 'Ú'),
    ]
    ergebnis = str(w)
    for muster, ersatz in ersetzungen:
        ergebnis = muster.sub(ersatz, ergebnis)
    return ergebnis

def html_sonderzeichen_umlaute_ausgeschrieben(w):
    """Ersetzt Umlaute und Sonderzeichen für eine einheitliche Sortierung."""
    if not w:
        return ""
    ergebnis = html_sonderzeichen_als_einzelzeichen(w)
    ersetzungen = [
        ('ä', 'ae'), ('Ä', 'Ae'),
        ('ö', 'oe'), ('Ö', 'Oe'),
        ('ü', 'ue'), ('Ü', 'Ue'),
        ('ú', 'u'),  ('Ú', 'U'),
        ('ß', 'ss')
    ]
    for urspruenglich, ersetzt in ersetzungen:
        ergebnis = ergebnis.replace(urspruenglich, ersetzt)
    return ergebnis.lower()

def begin_grosz(w):
    """Wandelt das Wort in Großschreibung des Anfangsbuchstabens um (unter Berücksichtigung von Umlauten/HTML-Entities)."""
    if not w:
        return ""
    woerterbehalten = {"DWB1", "DWB2"}
    if w in woerterbehalten:
        return w

    # Hexadezimale HTML-Entities am Wortanfang (ä/Ä, ö/Ö, ü/Ü, ú/Ú)
    entity_ersetzungen = [
        (('&#x00e4;', '&#x00c4;'), '&#x00c4;'),  # ä / Ä -> Ä (&#x00c4;)
        (('&#x00f6;', '&#x00d6;'), '&#x00d6;'),  # ö / Ö -> Ö (&#x00d6;)
        (('&#x00fc;', '&#x00dc;'), '&#x00dc;'),  # ü / Ü -> Ü (&#x00dc;)
        (('&#x00fa;', '&#x00da;'), '&#x00da;'),  # ú / Ú -> Ú (&#x00da;)
    ]
    w_anfang = w[:8].lower()
    for abwandlungen, grosz_entity in entity_ersetzungen:
        if w_anfang.startswith(abwandlungen):
            return grosz_entity + w[8:].lower()

    return w[:1].upper() + w[1:].lower()

def sz_ersetzen(w):
    """Ersetzt historische 'sz'-Schreibweisen durch standardisiertes 'ß'."""
    if not w:
        return ""
    ergebnis = w

    # Feste Anfangswörter
    feste_anfaenge = [
        (r'^auszen', 'außen'), (r'^Auszen', 'Außen'),
        (r'^auszer', 'außer'), (r'^Auszer', 'Außer'),
        (r'^barfüsz', 'barfüß'), (r'^Barfüsz', 'Barfüß'),
        (r'^barfusz', 'barfuß'), (r'^Barfusz', 'Barfuß'),
        (r'^erlasz', 'erlaß'), (r'^Erlasz', 'Erlaß'),
        (r'^füsz', 'füß'), (r'^Füesz', 'Füß'),
        (r'^gäszchen', 'gäßchen'), (r'^Gäszchen', 'Gäßchen'),
        (r'^misz', 'miß'), (r'^Misz', 'Miß'),
        (r'^wisz', 'wiß'), (r'^Wisz', 'Wiß'),
    ]

    for muster, ziel in feste_anfaenge:
        if re.search(muster, ergebnis):
            ergebnis = re.sub(muster, ziel, ergebnis)

    # Weitere feste Wortstämme
    stamm_ersetzungen = [
        (r'^grösz', 'größ'), (r'^Grösz', 'Größ'),
        (r'^grosz', 'groß'), (r'^Grosz', 'Groß'),
        (r'^schlosz', 'schloß'), (r'^Schlosz', 'Schloß'),
        (r'^schmeisz', 'schmeiß'), (r'^Schmeisz', 'Schmeiß'),
        (r'^schweisz', 'schweiß'), (r'^Schweisz', 'Schweiß'),
        (r'^urgrosz', 'urgroß'), (r'^Urgrosz', 'Urgroß'),
        (r'äuszer', 'äußer'), (r'Äuszer', 'Äußer'),
        (r'blosz', 'bloß'), (r'grosz', 'groß'),
        (r'gröszen', 'größen'), (r'Gröszen', 'Größen'),
        (r'gröszer', 'größer'), (r'Gröszer', 'Größer'),
        (r'heisz', 'heiß'), (r'mäszig', 'mäßig'),
        (r'maszen', 'maßen'), (r'müszig', 'müßig'),
        (r'Müszig', 'Müßig'), (r'nusz', 'nuß'),
        (r'Nusz', 'Nuß'), (r'scheisz', 'scheiß'),
        (r'schmeisz', 'schmeiß'), (r'schliesz', 'schließ'),
        (r'Schliesz', 'Schließ'), (r'schlusz', 'schluß'),
        (r'Schlusz', 'Schluß'), (r'schusz', 'schuß'),
        (r'Schusz', 'Schuß'), (r'strasz', 'straß'),
        (r'süsz', 'süß'), (r'Süsz', 'Süß'),
        (r'verheisz', 'verheiß'),
    ]
    for muster, ziel in stamm_ersetzungen:
        ergebnis = re.sub(muster, ziel, ergebnis)

    # Endungsmuster
    endungen = [
        (r'beiszer$', 'beißer'),
        (r'beiszker$', 'beißker'),
        (r'beisz$', 'beiß'),
        (r'eisz$', 'eiß'),
        (r'genosz$', 'genoß'),
        (r'gieszel$', 'gießel'),
        (r'prozesz$', 'prozeß'),
        (r'szchen$', 'ßchen'),
        (r'sze$', 'ße'),
        (r'szt$', 'ßt'),
        (r'szen$', 'ßen'),
        (r'szend$', 'ßend'),
        (r'szhaft', 'ßhaft'),
        (r'szig$', 'ßig'),
        (r'szlich$', 'ßlich'),
        (r'aesz$', 'äß'),
        (r'äsz$', 'äß'),
        (r'asz$', 'aß'),
        (r'osz$', 'oß'),
        (r'ösz$', 'öß'),
        (r'oesz$', 'öß'),
        (r'uesz$', 'üß'),
        (r'ueszel$', 'üßel'),
        (r'üszel$', 'üßel'),
        (r'üsz$', 'üß'),
        (r'usz$', 'uß'),
        (r'szung$', 'ßung'),
    ]
    for muster, ziel in endungen:
        ergebnis = re.sub(muster, ziel, ergebnis)

    return ergebnis


def bereite_wort_auf(label, capitalize=False):
    """Wandelt ein Lemma in die bereinigte Form (Umlaute, sz-Ersetzung, optional Großschreibung)."""
    if not label:
        return ""
    if capitalize:
        w = begin_grosz(label)
    else:
        w = label
    w = html_sonderzeichen_als_einzelzeichen(w)
    w = sz_ersetzen(w)
    return w


def grammatik_in_hauptgruppen(g, w):
    """Bestimmt die Hauptgruppe für die Sortierung (eigenschaftlich, tuwörtlich, nennwörtlich, unbekannt, leer)."""
    if g is None or g.strip() == "":
        w_low = w.lower() if w else ""
        if re.search(r'.+en$', w_low):
            return "tuwörtlich"
        elif re.search(r'.+(?:bar|ig|isch|lich|sam)$', w_low):
            return "eigenschaftlich"
        elif re.search(r'.+(?:heit|keit|ling|schaft|thum|tum|ung)$', w_low):
            return "nennwörtlich"
        else:
            return ""

    g_norm = g.strip()

    # HTML-Umlaute vorab auflösen für robuste Erkennung
    g_norm = html_sonderzeichen_als_einzelzeichen(g_norm)

    # 1. Tuwörter (Verben)
    if re.search(r'(?:^|\b)(?:v\b|vb\b|verb|verbum|inf\b|swv\b|trans\b|intrans\b|tr\b|intr\b|refl\b|starkes verb|schwaches verb|trennb|untrennbar|schallmalend)', g_norm, re.IGNORECASE):
        # Ausnahme: Verbaladjektive / Partizipien gehören zu Eigenschaftswörtern
        if not re.search(r'adj|part', g_norm, re.IGNORECASE):
            return "tuwörtlich"

    # 2. Eigenschaftswörter (Adjektive, Adverbien, Partizipien)
    if re.search(r'(?:^|\b)(?:adj|adject|adv|adverb|part|particip|partiz|verbaladj|fragew\. u\. adv|raumadv)', g_norm, re.IGNORECASE):
        # Ausnahme: Substantivierte Formen wie 'subst. inf.' oder 'f. adj.'
        if not re.search(r'^(?:f|m|n)\b.*adj', g_norm, re.IGNORECASE):
            return "eigenschaftlich"

    # 3. Nennwörter (Substantive)
    if re.search(r'(?:^|\b)(?:f\b|m\b|n\b|fem\b|masc|neutr|subst|nomen|dimin|dim\b|pl\b|plur\b|verbalsubstantiv)', g_norm, re.IGNORECASE):
        return "nennwörtlich"

    # 4. Andere Wortarten (Präpositionen, Konjunktionen, Interjektionen, Pronomen, Zahlwörter, Präfixe)
    return "unbekannt"

# ---------------------------------------------------------------------------
# Zusammengestellte Regeltabelle (aller) Sprachkunde-Begriffe gedeutscht
# Format: (regelreiche-Mustersuche; Wort, Geschlechtswort; Geschlechtswort Wort; Sprachkundliche Begriffsdeutung)
# Platzhalter:
#   {W} : Wort Großgeschrieben  (für Nennwörter, Nomen, Substantive)
#   {w} : wort kleingeschrieben / bereinigt (für andere Wortarten)
# ---------------------------------------------------------------------------

_FUNDREGELN_SPRACHKUNDLICH = [
    # --- Weibliche Nennwörter ---
    (r'^f[.,;]*$|^f[.,;]* *f[.,;]*$|^fem[.,;]*$|^f[.,;]* +subst[. ]*$|^subst[. ]* +f[.,;]*$|^schw\. f\.',
     "{W}, die", "die {W}", "Nennwort, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f[_.,;]*\?$',
     "{W}, die?", "die? {W}", "Nennwort, ?weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f[.,;]* +m[.,;]*$|^f\. f\. m\.|^f\. m\. m\.',
     "{W}, die (o./ u.a.: der)", "die (o./ u.a.: der) {W}", "Nennwort, weiblich vermutlich – o./ u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f[.,;]* +m[.,;]* +n[.,;]*$|^f\. m\. f\. n\.',
     "{W}, die (o./ u.a.: der, das)", "die (o./ u.a.: der, das) {W}", "Nennwort, weiblich vermutlich – o./ u.a. männlich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f[.,;]* +n[.,;]*$|^f[.,;]* *n[.,;]* *n[.,;]*$',
     "{W}, die (o./ u.a.: das)", "die (o./ u.a.: das) {W}", "Nennwort, weiblich vermutlich – o./ u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f[.,;]* +n[.,;]* +m[.,;]*$',
     "{W}, die (o./ u.a.: das, der)", "die (o./ u.a.: das, der) {W}", "Nennwort, weiblich vermutlich – o./ u.a. sächlich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f\..*nomen +actionis',
     "{W}, die", "die {W}", "Nennwort einer Handlung, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^f\..*nomen +agentis',
     "{W}, die", "die {W}", "nennwörtlich Machende, weiblich – hauptwörtlich …, namenswörtlich …"),
    (r'^f\. (?:adj|m\. f\.|f\. f\.)',
     "{W}, die", "die {W}", "Nennwort, weiblich (mit weiteren Angaben)"),

    # --- Männliche Nennwörter ---
    (r'^m[.,;]*$|^m[.,;]* *m[.,;]*$|^masculinum$|^m[.,;]* +subst[. ]*$|^subst[. ]* +m[.,;]*$',
     "{W}, der", "der {W}", "Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m[_.,;]*\?|^m\.\?\.?',
     "{W}, der?", "der? {W}", "Nennwort, ?männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m[.,;]* +f[.,;]*$|^m\. f\. m\.',
     "{W}, der (o./ u.a.: die)", "der (o./ u.a.: die) {W}", "Nennwort, männlich vermutlich – o./ u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m[.,;]* +(?:und|u\.) +f[.,;]*$|^m\. und f\. m\. und f\.|^m\. m\. und f\.',
     "{W}, der u. die", "der u. die {W}", "Nennwort, Nennwort, männlich u. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m[.,;]* +f[.,;]* +n[.,;]*$',
     "{W}, der (o./ u.a.: die, das)", "der (o./ u.a.: die, das) {W}", "Nennwort, männlich vermutlich – o./ u.a. weiblich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m[.,;]* +n[.,;]*$|^m\. m\. n\.',
     "{W}, der (o./ u.a.: das)", "der (o./ u.a.: das) {W}", "Nennwort, männlich vermutlich – o./ u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m[.,;]* +n[.,;]* +f[.,;]*$|^m\. n\. m\.',
     "{W}, der (o./ u.a. das, die)", "der (o./ u.a. das, die) {W}", "Nennwort, männlich vermutlich – o./ u.a. sächlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m\..*nomen +actionis',
     "{W}, der", "der {W}", "Nennwort einer Handlung, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^m\..*nomen +agentis',
     "{W}, der", "der {W}", "nennwörtlich Machender, männlich – hauptwörtlich …, namenswörtlich …"),
    (r'^m\.\; +pl\.\; +f\.|^m\.\; +m\.\; +n\.|^m\., +f\. +m\.;|^m\. +und +f\. +f\.',
     "{W}, der (u.a.)", "der (u.a.) {W}", "Nennwort, männlich (und weitere Wortformen)"),
    (r'^m\. (?:adj|vb\.|verb)',
     "{W}, der", "der {W}", "Nennwort, männlich (mit Zeitwort-/Eigenschaftswortbezug)"),

    # --- Sächliche Nennwörter ---
    (r'^n[.,;]*$|^n[.,;]* +n[.,;]*$|^neutr\.',
     "{W}, das", "das {W}", "Nennwort, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n[_.,;]*\?$',
     "{W}, das?", "das? {W}", "Nennwort, ?sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n[.,;]* +m[.,;]*$',
     "{W}, das (o./ u.a.: der)", "das (o./ u.a.: der) {W}", "Nennwort, sächlich vermutlich – o./ u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n[.,;]* +f[.,;]*$|^n[.,;]* +f[.,;]* +f[.,;]*$',
     "{W}, das (o./ u.a.: die)", "das (o./ u.a.: die) {W}", "Nennwort, sächlich vermutlich – o./ u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n[.,;]* +m[.,;]* +f[.,;]*$|^n\. n\. m\.',
     "{W}, das (o./ u.a.: der, die)", "das (o./ u.a.: der, die) {W}", "Nennwort, sächlich vermutlich – o./ u.a. männlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n[.,;]* +f[.,;]* +m[.,;]*$',
     "{W}, das (o./ u.a.: die, der)", "das (o./ u.a.: die, der) {W}", "Nennwort, sächlich vermutlich – o./ u.a. weiblich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n\..*nomen +actionis',
     "{W}, das", "das {W}", "Nennwort einer Handlung – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^n\..*nomen +agentis',
     "{W}, das", "das {W}", "nennwörtlich Machendes, sächlich – hauptwörtlich …, namenswörtlich …"),
    (r'^n\. adj\.',
     "{W}, das", "das {W}", "Nennwort, sächlich (mit Eigenschaftswortbezug)"),
    (r'^nomen$|^subst[_.,;\s]*$|^substantivbildung$|^substantiviertes n\.|^substant\.',
     "{W}", "{W}", "Nennwort – Dingwort, Hauptwort, Namenwort, ?Eigenwort"),
    (r'^subst\. *pl(?:ur)?\.|^pl\.\?',
     "{W}, die (Mehrzahl)", "die {W} (Mehrzahl)", "Nennwort in der Mehrzahl (Plural)"),
    (r'^verbalsubstantiv$',
     "{W}, das", "das {W}", "nennwörtliches Zeitwort, Tuwort"),

    # --- Adjektive / Adverbien / Partizipien / Sonstige (Standard {w}) ---
    (r'^adj(?:ectiv|ect)?\b.*m\..*f\.', "{w}", "{w}", "Eigenschaftswort (Beispielen für m. und f.)"),
    (r'^adj(?:ectiv|ect)?[_.,;]*$|^adj(?:ectiv|ect)?[_.,;]* adj(?:ectiv|ect)?[_.,;]*$', "{w}", "{w}", "Eigenschaftswort, Beiwort"),
    (r'^adj(?:ectiv|ect)?[_.,;]*\?[_.,;]*$', "{w}", "{w}", "?Eigenschaftswort, Beiwort"),
    (r'^adj(?:ectiv|ect)?[_.,;]* f[.,;]*$', "{w}", "{w}", "Eigenschaftswort, Beiwort (mit Beispiel-Nennwort weiblich)"),
    (r'^adj(?:ectiv|ect)?[_.,;]* m[.,;]*$', "{w}", "{w}", "Eigenschaftswort, Beiwort (mit Beispiel-Nennwort männlich)"),
    (r'^adj(?:ectiv|ect)?[_.,;]* +(?:u[nd.]* +)?adv(?:erb)?[_.,;]*$|^adjectiv und adverb', "{w}", "{w}", "Eigenschaftswort, Beiwort und Umstandswort, Zuwort"),
    (r'^adv(?:erbiell)?[_.,;]*$|^adv\.\?', "{w}", "{w}", "Umstandswort, Zuwort"),
    (r'^adv\..*adj\.', "{w}", "{w}", "Umstandswort und Eigenschaftswort"),
    (r'^[kc]onj(?:unction)?[.,;]?$', "{w}", "{w}", "Fügewort, Bindewort"),
    (r'^dim(?:inutiv|in)?[.,;]?$', "{w}", "{w}", "Verniedlichung, Verkleinerung"),
    (r'^interj[.,;]?$|^interje[ck]tion[.,;]?$', "{w}", "{w}", "Zwischenwort, Empfindungswort"),
    (r'^part(?:icz|ic)?[.;]?$', "{w}", "{w}", "Mittelwort"),
    (r'^part(?:icpalesz|icip|iz|ic|icipiales)?[\.\s-]+adj(?:ect)?\b|^adjektivisches part\.', "{w}", "{w}", "mittelwörtliches Eigenschaftswort, Beiwort"),
    (r'^part(?:icpalesz|icip|iz|ic|icipiales)?[.\s-]+adj(?:ektiv)?[.\s]+(?:oder )*adv(?:erb)?|^part\.[ -]+adv\.[ ]+adj|^partizipiales', "{w}", "{w}", "mittelwörtliches Umstandswort oder Eigenschaftswort"),
    (r'^präf\.|^pr&#x00e4;f\.', "{w}", "{w}", "Vorsilbe, Vorfügsel"),
    (r'^(?:präp|pr&#x00e4;p|praep)[os]*[_.,;]*$', "{w}", "{w}", "Vorwort, Verhältniswort"),
    (r'^(?:präp|pr&#x00e4;p|praep)[osz]*[. -]+adv(?:erb)?.*$|^raumadv\. und (?:präp|pr&#x00e4;p|praep)\.', "{w}", "{w}", "vorwörtliches Umstandswort"),
    (r'^(?:präposition|praeposition),\s*conjunction,\s*adv\.', "{w}", "{w}", "Vorwort, Bindewort und Umstandswort"),
    (r'^fragew\.\s*u\.\s*adv\.', "{w}", "{w}", "Fragewort und Umstandswort"),
    (r'^indeklin\.', "{w}", "{w}", "Unbeugsam (nicht abwandelbar / indeklinabel)"),
    (r'^praet\.[;]?$', "{w}", "{w}", "Vergangenheit"),
    (r'^pron(?:omen)?[_.,;]*$', "{w}", "{w}", "Vornennwort, Fürwort"),
    (r'^refl[.,;]*$', "{w}", "{w}", "sich-bezogenes Zeitwort, Tuwort"),

    # --- Tuwörter (Verben) ---
    (r'^subst\. *inf[.]?$|^subst\. *v(?:er)?b[.]?$|^vb\.\s*subst\.', "{w}", "{w}", "nennwörtliches Zeitwort, Tuwort (Infinitiv)"),
    (r'^v\. +u\. +subst\. +n\.$', "{w}; {W}, das", "{w}; das {W}", "Tuwort und Nennwort sächlich (Tuwort: auch Zeitwort, Tätigkeitswort; Nennwort: auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)"),
    (r'^st(?:arkes)?[.]* +v(?:erbum|erb)?[.,; ]*$', "{w}", "{w}", "starkes Zeitwort (auch Tuwort, Tätigkeitswort)"),
    (r'^schw(?:aches)?[.]* +v(?:erbum|erb)?[.,; ]*$|^sw[_.,;]* +vb[.,;]* *$|^swv[.,; ]*$|^schw\.\s*vb\.|^sw\.\s*v\.', "{w}", "{w}", "schwaches Zeitwort (auch Tuwort, Zeitwort, Tätigkeitswort)"),
    (r'^untrennbares +v(?:erbum|erb)?[_.,;]*$', "{w}", "{w}", "untrennbares Zeitwort (auch Tuwort, Tätigkeitswort)"),
    (r'^trennb(?:ares)?[.]* +v(?:erbum|erb)?[.,;]*$|^schw\.\s*trennbares\s*v\.', "{w}", "{w}", "trennbares Zeitwort (auch Tuwort, Tätigkeitswort)"),
    (r'^schallmalendes\s+vb\.', "{w}", "{w}", "schallnachahmendes Zeitwort (Lautmalerei)"),
    (r'^schw\.\s*v\.\s*adj\.', "{w}", "{w}", "schwaches Zeitwort (auch als Eigenschaftswort verwendet)"),
    (r'^inf\.', "{w}", "{w}", "Nennform des Zeitworts (Infinitiv)"),
    (r'^v[_.,;]*$|^vb[_.,;]*$|^verb[_.,;]*$|^verbum[.,;]*$|^verb\.\s*verb\.|^verb\.\s*m\.', "{w}", "{w}", "Zeitwort (auch Tuwort, Tätigkeitswort)"),
    (r'^verb(?:al)?[ .-]*adj[_.,;]*$|^substantiviertes adj\.|^substantiviertes adject\.', "{w}", "{w}", "Eigenschaftswort tuwörtlichen Ursprungs (oder Beiwort zeitwörtlichen Ursprungs)"),
    (r'^verb(?:al)?[ .-]*adj[_.,;]+[ -–—]+adv[_.,;]*$', "{w}", "{w}", "Eigenschafts- oder Umstandswort tuwörtlichen Ursprungs"),
    (r'^tr(?:ans)?[.]?$', "{w}", "{w}", "Tuwort oder Zeitwort hinbezüglich, übertragend (Frage: „wen/was? → … !“; transitiv)"),
    (r'^intr(?:ans)?[.]?$', "{w}", "{w}", "Tuwort oder Zeitwort in sich, ohn-hinbezüglich (Frage „wen/was? → ??“ ist offen; intransitiv)"),
    (r'^zahlw(?:ort)?[.;]?$', "{w}", "{w}", "Zahlwort"),
]

# Einmaliges Vormustern der Ausdrücke für geschwindes Abarbeiten
_ZUSAMMENGESETZTE_SPRACHKUNDE_REGELN = [
    (re.compile(regelmuster, re.IGNORECASE), wort_geschlwort, geschlwort_wort, deutung)
    for regelmuster, wort_geschlwort, geschlwort_wort, deutung in _FUNDREGELN_SPRACHKUNDLICH
]


def grammatik_dem_wort_anhaengen(g, w, W):
    """
    Erstellt Wort mit Artikel, vorangestelltem Artikel und die sprachkundlich gedeutete Einordnung.
    """
    if g is None or not g.strip():
        return {
            "wort_mit_geschlechtswort": w,
            "geschlechtswort_vorm_wort": w,
            "grammatik_deutung": ""
        }

    g_orig = g.strip()
    g_clean = html_sonderzeichen_als_einzelzeichen(g_orig)

    # Tabellarischer Abgleich
    for regex, nach_tpl, vor_tpl, deutung in _ZUSAMMENGESETZTE_SPRACHKUNDE_REGELN:
        if regex.search(g_clean):
            return {
                "wort_mit_geschlechtswort": nach_tpl.format(w=w, W=W),
                "geschlechtswort_vorm_wort": vor_tpl.format(w=w, W=W),
                "grammatik_deutung": f"{g_orig} ~ {deutung}"
            }

    # Fallback bei unbekannten Angaben
    return {
        "wort_mit_geschlechtswort": w,
        "geschlechtswort_vorm_wort": w,
        "grammatik_deutung": f"{g_orig} ~ ?"
    }


# def grammatik_dem_wort_anhaengen(g, w, W):
#     """
#     Erstellt Wort mit Artikel, vorangestelltem Artikel und die semantische Grammatikdeutung.
#     Rückgabe: {
#         'wort_mit_geschlechtswort': str,
#         'geschlechtswort_vorm_wort': str,
#         'grammatik_deutung': str
#     }
#     """
#     if g is None or g.strip() == "":
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": ""
#         }
#
#     g_orig = g.strip()
#     g_clean = html_sonderzeichen_als_einzelzeichen(g_orig)
#
#     # --- Weibliche Nennwörter ---
#     if re.search(r'^f[.,;]*$|^f[.,;]* *f[.,;]*$|^fem[.,;]*$|^f[.,;]* +subst[. ]*$|^subst[. ]* +f[.,;]*$|^schw\. f\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die",
#             "geschlechtswort_vorm_wort": f"die {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f[_.,;]*\?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die?",
#             "geschlechtswort_vorm_wort": f"die? {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, ?weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f[.,;]* +m[.,;]*$|^f\. f\. m\.|^f\. m\. m\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die (o./ u.a.: der)",
#             "geschlechtswort_vorm_wort": f"die (o./ u.a.: der) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, weiblich vermutlich – o./ u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f[.,;]* +m[.,;]* +n[.,;]*$|^f\. m\. f\. n\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die (o./ u.a.: der, das)",
#             "geschlechtswort_vorm_wort": f"die (o./ u.a.: der, das) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, weiblich vermutlich – o./ u.a. männlich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f[.,;]* +n[.,;]*$|^f[.,;]* *n[.,;]* *n[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die (o./ u.a.: das)",
#             "geschlechtswort_vorm_wort": f"die (o./ u.a.: das) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, weiblich vermutlich – o./ u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f[.,;]* +n[.,;]* +m[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die (o./ u.a.: das, der)",
#             "geschlechtswort_vorm_wort": f"die (o./ u.a.: das, der) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, weiblich vermutlich – o./ u.a. sächlich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f\..*nomen +actionis', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die",
#             "geschlechtswort_vorm_wort": f"die {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort einer Handlung, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^f\..*nomen +agentis', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die",
#             "geschlechtswort_vorm_wort": f"die {W}",
#             "grammatik_deutung": f"{g_orig} ~ nennwörtlich Machende, weiblich – hauptwörtlich …, namenswörtlich …"
#         }
#     if re.search(r'^f\. (?:adj|m\. f\.|f\. f\.)', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die",
#             "geschlechtswort_vorm_wort": f"die {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, weiblich (mit weiteren Angaben)"
#         }
#
#     # --- Männliche Nennwörter ---
#     if re.search(r'^m[.,;]*$|^m[.,;]* *m[.,;]*$|^masculinum$|^m[.,;]* +subst[. ]*$|^subst[. ]* +m[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der",
#             "geschlechtswort_vorm_wort": f"der {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m[_.,;]*\?|^m\.\?\.?', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der?",
#             "geschlechtswort_vorm_wort": f"der? {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, ?männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m[.,;]* +f[.,;]*$|^m\. f\. m\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der (o./ u.a.: die)",
#             "geschlechtswort_vorm_wort": f"der (o./ u.a.: die) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich vermutlich – o./ u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m[.,;]* +(?:und|u\.) +f[.,;]*$|^m\. und f\. m\. und f\.|^m\. m\. und f\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der u. die",
#             "geschlechtswort_vorm_wort": f"der u. die {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, Nennwort, männlich u. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m[.,;]* +f[.,;]* +n[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der (o./ u.a.: die, das)",
#             "geschlechtswort_vorm_wort": f"der (o./ u.a.: die, das) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich vermutlich – o./ u.a. weiblich, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m[.,;]* +n[.,;]*$|^m\. m\. n\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der (o./ u.a.: das)",
#             "geschlechtswort_vorm_wort": f"der (o./ u.a.: das) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich vermutlich – o./ u.a. sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m[.,;]* +n[.,;]* +f[.,;]*$|^m\. n\. m\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der (o./ u.a. das, die)",
#             "geschlechtswort_vorm_wort": f"der (o./ u.a. das, die) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich vermutlich – o./ u.a. sächlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m\..*nomen +actionis', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der",
#             "geschlechtswort_vorm_wort": f"der {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort einer Handlung, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^m\..*nomen +agentis', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der",
#             "geschlechtswort_vorm_wort": f"der {W}",
#             "grammatik_deutung": f"{g_orig} ~ nennwörtlich Machender, männlich – hauptwörtlich …, namenswörtlich …"
#         }
#     if re.search(r'^m\.\; +pl\.\; +f\.|^m\.\; +m\.\; +n\.|^m\., +f\. +m\.;|^m\. +und +f\. +f\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der (u.a.)",
#             "geschlechtswort_vorm_wort": f"der (u.a.) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich (und weitere Wortformen)"
#         }
#     if re.search(r'^m\. (?:adj|vb\.|verb)', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, der",
#             "geschlechtswort_vorm_wort": f"der {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, männlich (mit Zeitwort-/Eigenschaftswortbezug)"
#         }
#
#     # --- Sächliche Nennwörter ---
#     if re.search(r'^n[.,;]*$|^n[.,;]* +n[.,;]*$|^neutr\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das",
#             "geschlechtswort_vorm_wort": f"das {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n[_.,;]*\?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das?",
#             "geschlechtswort_vorm_wort": f"das? {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, ?sächlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n[.,;]* +m[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das (o./ u.a.: der)",
#             "geschlechtswort_vorm_wort": f"das (o./ u.a.: der) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, sächlich vermutlich – o./ u.a. männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n[.,;]* +f[.,;]*$|^n[.,;]* +f[.,;]* +f[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das (o./ u.a.: die)",
#             "geschlechtswort_vorm_wort": f"das (o./ u.a.: die) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, sächlich vermutlich – o./ u.a. weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n[.,;]* +m[.,;]* +f[.,;]*$|^n\. n\. m\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das (o./ u.a.: der, die)",
#             "geschlechtswort_vorm_wort": f"das (o./ u.a.: der, die) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, sächlich vermutlich – o./ u.a. männlich, weiblich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n[.,;]* +f[.,;]* +m[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das (o./ u.a.: die, der)",
#             "geschlechtswort_vorm_wort": f"das (o./ u.a.: die, der) {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, sächlich vermutlich – o./ u.a. weiblich, männlich – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n\..*nomen +actionis', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das",
#             "geschlechtswort_vorm_wort": f"das {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort einer Handlung – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^n\..*nomen +agentis', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das",
#             "geschlechtswort_vorm_wort": f"das {W}",
#             "grammatik_deutung": f"{g_orig} ~ nennwörtlich Machendes, sächlich – hauptwörtlich …, namenswörtlich …"
#         }
#     if re.search(r'^n\. adj\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das",
#             "geschlechtswort_vorm_wort": f"das {W}",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort, sächlich (mit Eigenschaftswortbezug)"
#         }
#     if re.search(r'^nomen$|^subst[_.,;\s]*$|^substantivbildung$|^substantiviertes n\.|^substant\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": W,
#             "geschlechtswort_vorm_wort": W,
#             "grammatik_deutung": f"{g_orig} ~ Nennwort – Dingwort, Hauptwort, Namenwort, ?Eigenwort"
#         }
#     if re.search(r'^subst\. *pl(?:ur)?\.|^pl\.\?', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, die (Mehrzahl)",
#             "geschlechtswort_vorm_wort": f"die {W} (Mehrzahl)",
#             "grammatik_deutung": f"{g_orig} ~ Nennwort in der Mehrzahl (Plural)"
#         }
#     if re.search(r'^verbalsubstantiv$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{W}, das",
#             "geschlechtswort_vorm_wort": f"das {W}",
#             "grammatik_deutung": f"{g_orig} ~ nennwörtliches Zeitwort, Tuwort"
#         }
#
#     # --- Adjektive / Adverbien / Partizipien ---
#     if re.search(r'^adj(?:ectiv|ect)?\b.*m\..*f\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschaftswort (Beispielen für m. und f.)"
#         }
#     if re.search(r'^adj(?:ectiv|ect)?[_.,;]*$|^adj(?:ectiv|ect)?[_.,;]* adj(?:ectiv|ect)?[_.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschaftswort, Beiwort"
#         }
#     if re.search(r'^adj(?:ectiv|ect)?[_.,;]*\?[_.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ ?Eigenschaftswort, Beiwort"
#         }
#     if re.search(r'^adj(?:ectiv|ect)?[_.,;]* f[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort weiblich)"
#         }
#     if re.search(r'^adj(?:ectiv|ect)?[_.,;]* m[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschaftswort, Beiwort (mit Beispiel-Nennwort männlich)"
#         }
#     if re.search(r'^adj(?:ectiv|ect)?[_.,;]* +(?:u[nd.]* +)?adv(?:erb)?[_.,;]*$|^adjectiv und adverb', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschaftswort, Beiwort und Umstandswort, Zuwort"
#         }
#     if re.search(r'^adv(?:erbiell)?[_.,;]*$|^adv\.\?', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Umstandswort, Zuwort"
#         }
#     if re.search(r'^adv\..*adj\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Umstandswort und Eigenschaftswort"
#         }
#     if re.search(r'^[kc]onj(?:unction)?[.,;]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Fügewort, Bindewort"
#         }
#     if re.search(r'^dim(?:inutiv|in)?[.,;]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Verniedlichung, Verkleinerung"
#         }
#     if re.search(r'^interj[.,;]?$|^interje[ck]tion[.,;]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Zwischenwort, Empfindungswort"
#         }
#     if re.search(r'^part(?:icz|ic)?[.;]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Mittelwort"
#         }
#     if re.search(r'^part(?:icpalesz|icip|iz|ic|icipiales)?[\.\s-]+adj(?:ect)?\b|^adjektivisches part\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ mittelwörtliches Eigenschaftswort, Beiwort"
#         }
#     if re.search(r'^part(?:icpalesz|icip|iz|ic|icipiales)?[.\s-]+adj(?:ektiv)?[.\s]+(?:oder )*adv(?:erb)?|^part\.[ -]+adv\.[ ]+adj|^partizipiales', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ mittelwörtliches Umstandswort oder Eigenschaftswort"
#         }
#     if re.search(r'^präf\.|^pr&#x00e4;f\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Vorsilbe, Vorfügsel"
#         }
#     if re.search(r'^(?:präp|pr&#x00e4;p|praep)[os]*[_.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Vorwort, Verhältniswort"
#         }
#     if re.search(r'^(?:präp|pr&#x00e4;p|praep)[osz]*[. -]+adv(?:erb)?.*$|^raumadv\. und (?:präp|pr&#x00e4;p|praep)\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ vorwörtliches Umstandswort"
#         }
#     if re.search(r'^(?:präposition|praeposition),\s*conjunction,\s*adv\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Vorwort, Bindewort und Umstandswort"
#         }
#     if re.search(r'^fragew\.\s*u\.\s*adv\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Fragewort und Umstandswort"
#         }
#     if re.search(r'^indeklin\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Unbeugsam (nicht abwandelbar / indeklinabel)"
#         }
#     if re.search(r'^praet\.[;]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Vergangenheit"
#         }
#     if re.search(r'^pron(?:omen)?[_.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Vornennwort, Fürwort"
#         }
#     if re.search(r'^refl[.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ sich-bezogenes Zeitwort, Tuwort"
#         }
#
#     # --- Tuwörter (Verben) ---
#     if re.search(r'^subst\. *inf[.]?$|^subst\. *v(?:er)?b[.]?$|^vb\.\s*subst\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ nennwörtliches Zeitwort, Tuwort (Infinitiv)"
#         }
#     if re.search(r'^v\. +u\. +subst\. +n\.$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": f"{w}; {W}, das",
#             "geschlechtswort_vorm_wort": f"{w}; das {W}",
#             "grammatik_deutung": f"{g_orig} ~ Tuwort und Nennwort sächlich (Tuwort: auch Zeitwort, Tätigkeitswort; Nennwort: auch Dingwort, Hauptwort, Namenwort, ?Eigenwort)"
#         }
#     if re.search(r'^st(?:arkes)?[.]* +v(?:erbum|erb)?[.,; ]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ starkes Zeitwort (auch Tuwort, Tätigkeitswort)"
#         }
#     if re.search(r'^schw(?:aches)?[.]* +v(?:erbum|erb)?[.,; ]*$|^sw[_.,;]* +vb[.,;]* *$|^swv[.,; ]*$|^schw\.\s*vb\.|^sw\.\s*v\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ schwaches Zeitwort (auch Tuwort, Zeitwort, Tätigkeitswort)"
#         }
#     if re.search(r'^untrennbares +v(?:erbum|erb)?[_.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ untrennbares Zeitwort (auch Tuwort, Tätigkeitswort)"
#         }
#     if re.search(r'^trennb(?:ares)?[.]* +v(?:erbum|erb)?[.,;]*$|^schw\.\s*trennbares\s*v\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ trennbares Zeitwort (auch Tuwort, Tätigkeitswort)"
#         }
#     if re.search(r'^schallmalendes\s+vb\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ schallnachahmendes Zeitwort (Lautmalerei)"
#         }
#     if re.search(r'^schw\.\s*v\.\s*adj\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ schwaches Zeitwort (auch als Eigenschaftswort verwendet)"
#         }
#     if re.search(r'^inf\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Nennform des Zeitworts (Infinitiv)"
#         }
#     if re.search(r'^v[_.,;]*$|^vb[_.,;]*$|^verb[_.,;]*$|^verbum[.,;]*$|^verb\.\s*verb\.|^verb\.\s*m\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Zeitwort (auch Tuwort, Tätigkeitswort)"
#         }
#     if re.search(r'^verb(?:al)?[ .-]*adj[_.,;]*$|^substantiviertes adj\.|^substantiviertes adject\.', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschaftswort tuwörtlichen Ursprungs (oder Beiwort zeitwörtlichen Ursprungs)"
#         }
#     if re.search(r'^verb(?:al)?[ .-]*adj[_.,;]+[ -–—]+adv[_.,;]*$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Eigenschafts- oder Umstandswort tuwörtlichen Ursprungs"
#         }
#     if re.search(r'^tr(?:ans)?[.]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Tuwort oder Zeitwort hinbezüglich, übertragend (Frage: „wen/was? → … !“; transitiv)"
#         }
#     if re.search(r'^intr(?:ans)?[.]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Tuwort oder Zeitwort in sich, ohn-hinbezüglich (Frage „wen/was? → ??“ ist offen; intransitiv)"
#         }
#     if re.search(r'^zahlw(?:ort)?[.;]?$', g_clean, re.IGNORECASE):
#         return {
#             "wort_mit_geschlechtswort": w,
#             "geschlechtswort_vorm_wort": w,
#             "grammatik_deutung": f"{g_orig} ~ Zahlwort"
#         }
#
#     # Übrige / Unbekannte Angaben
#     return {
#         "wort_mit_geschlechtswort": w,
#         "geschlechtswort_vorm_wort": w,
#         "grammatik_deutung": f"{g_orig} ~ ?"
#     }


def erstelle_ohne_filter(ohne_str):
    """
    Erstellt reguläre Ausdrücke und formatierte Texte zur Ausschlußfilterung aus der '--ohne' Angabe.
    """
    if not ohne_str or not ohne_str.strip():
        return "", "", ""

    # Wandlung von Wildcards (*, ?) und Trennzeichen in Regex
    raw_ohne = ohne_str.strip()
    begriffe = [begriff_hier.strip() for begriff_hier in re.split(r'[,; ]+', raw_ohne) if begriff_hier.strip()]

    # Anzeige-Text
    ohne_text = ", ".join(begriffe)

    # Regex-Muster zusammenbauen
    muster_teile = []
    muster_teile_xml = []
    entity_ersetzungen = [
        ('ä', '&#x00e4;'), ('Ä', '&#x00c4;'),
        ('ö', '&#x00f6;'), ('Ö', '&#x00d6;'),
        ('ü', '&#x00fc;'), ('Ü', '&#x00dc;'),
        ('ú', '&#x00fa;'), ('Ú', '&#x00da;'),
    ]
    for begriff_hier in begriffe:
        reg_muster = re.escape(begriff_hier)
        reg_muster = reg_muster.replace(r'\*', '.*').replace(r'\?', '.')
        muster_teile.append(reg_muster)

        # XML-Variante mit Entity-Umlauten
        b_xml = begriff_hier
        for sonderzeichen, xml_entity in entity_ersetzungen:
            b_xml = b_xml.replace(sonderzeichen, xml_entity)
        pat_xml = re.escape(b_xml).replace(r'\*', '.*').replace(r'\?', '.')
        muster_teile_xml.append(pat_xml)

    ohne_regex = r'^(?:' + '|'.join(muster_teile) + r')$'
    ohne_regex_xml = r'^(?:' + '|'.join(muster_teile_xml) + r')$'

    return ohne_text, ohne_regex, ohne_regex_xml


def lade_kwic_fundstelle(wbnetzkwiclink, textid):
    """Lädt den KWIC-Fundstellentext aus der API und formatiert ihn mit HTML-Tags."""
    try:
        req = urllib.request.Request(wbnetzkwiclink, headers={'User-Agent': 'Mozilla/5.0 (Lemmaabfrage_DWB1)'})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        return f"[Fehler beim Laden der Fundstelle: {e}]"

    ergebnis_teile = []
    for eintrag in data:
        w_textid = eintrag.get('textid')
        word = eintrag.get('word', '')
        typeset = eintrag.get('typeset', '')
        charposition = eintrag.get('charposition', '')
        elementtype = str(eintrag.get('elementtype', ''))

        ist_suchwort = False
        try:
            if int(w_textid) == int(textid):
                ist_suchwort = True
        except (ValueError, TypeError):
            pass

        if ist_suchwort:
            wort_formatiert = f'<b class="gefunden-hervorheben" id="textid-{textid}">{word}</b>'
        elif typeset == 'italics':
            if charposition == 'super':
                wort_formatiert = f'<i><sup>{word}</sup></i>'
            else:
                wort_formatiert = f'<i>{word}</i>'
        elif typeset == 'caps':
            if charposition == 'super':
                wort_formatiert = f'<span style="font-variant:small-caps"><sup>{word}</sup></span>'
            else:
                wort_formatiert = f'<span style="font-variant:small-caps">{word}</span>'
        elif typeset == 'recte' or True:
            if charposition == 'super':
                wort_formatiert = f'<sup>{word}</sup>'
            elif re.search(r'sensemark\d+', elementtype):
                wort_formatiert = f'<b>{word}</b>'
            else:
                wort_formatiert = word

        ergebnis_teile.append(wort_formatiert)

    rohtext = "".join(ergebnis_teile)
    rohtext = rohtext.replace("</i><i>", "")
    # Formatierung mit Guillemets und Auslassungspunkten
    rohtext = re.sub(r'»([ ;.:]+)', r'»…\1', f"»{rohtext}«")
    rohtext = rohtext.replace("«", "…«")
    return rohtext


def main():
    parser = argparse.ArgumentParser(
        description="Ein Wort aus der Programm-Schnitt-Stelle (PSS/API) des Grimm-Wörterbuchs DWB abfragen und daraus strukturierte Listen-Textdokumente erstellen.",
        add_help=False
    )
    parser.add_argument('-h', '--Hilfe', '--hilfe', action='store_true', help='Hilfetext dieses Programms ausgeben.')
    parser.add_argument('-l', '-L', '--Lemmaabfrage', '--lemmaabfrage', dest='lemmaabfrage', type=str, default=None,
                        help='Die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“. Mehrere Suchwörter zugleich sind möglich: „*wohn*, *wöhn*“')
    parser.add_argument('-F', '--Fundstellen', '--fundstellen', action='store_true', help='Fundstellen jedes Stichworts mit abfragen.')
    parser.add_argument('-H', '--HTML', '--html', action='store_true', help='HTML-Datei erzeugen')
    parser.add_argument('-O', '--ODT', '--odt', action='store_true', help='ODT-Datei (für LibreOffice) erzeugen (benötigt pandoc)')
    parser.add_argument('--Liste_Einzelabschnitte', '--Einzeltabelle', dest='liste_einzelabschnitte', action='store_true',
                        help='Wörtertabelle als Wörterliste in Einzelabschnitte umschreiben (als Markdown-Text)')
    parser.add_argument('-T', '--Telegrammarkdown', '--telegrammarkdown', action='store_true', help='MD-Datei (für Text in Markdown bei Telegram) erzeugen')
    parser.add_argument('-b', '--behalte_Dateien', '--behalte_dateien', action='store_true', help='Behalte auch temporäre Zwischendateien')
    parser.add_argument('-s', '--stillschweigend', action='store_true', help='Kaum Meldungen ausgeben')
    parser.add_argument('-o', '--ohne', dest='ohne', type=str, default='',
                        help='ohne Wörter (Wortliste z.B. --ohne "aufstand, verstand" bei --Lemmaabfrage "*stand*")')
    parser.add_argument('--entwickeln', '--debug', action='store_true', help='Entwicklungs- und Debugmeldungen ausgeben')
    parser.add_argument('--farb-frei', action='store_true', help='Meldungen ohne Farben ausgeben')

    args = parser.parse_args()

    farben = Farben(aktiv=not args.farb_frei)

    if args.Hilfe or not args.lemmaabfrage:
        hilfe_text = f"""Nutzung:
  {sys.argv[0]} [-h] [-s] [-H] [-O] -l "*wohl*"

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
"""
        print(hilfe_text)
        if not args.lemmaabfrage and not args.Hilfe:
            print(f"{farben.ROT}Fehlendes Lemma, das abgefragt werden soll (Abbruch).{farben.RESET}", file=sys.stderr)
            sys.exit(1)
        sys.exit(0)

    lemmaabfrage_raw = args.lemmaabfrage.strip()
    if re.match(r'^[*?]+$', lemmaabfrage_raw):
        print(f"{farben.ORANGE}Alle Lemmata abzufragen (--Lemmaabfrage '{lemmaabfrage_raw}') wird nicht unterstützt (Abbruch){farben.RESET}", file=sys.stderr)
        sys.exit(1)

    # API Abfragebegriff formatieren
    lemmaabfrage_api = re.sub(r' +(?:ODER|OR) +', '@OR@', lemmaabfrage_raw, flags=re.IGNORECASE)
    lemmaabfrage_api = re.sub(r' +(?:UND|AND) +', '@AND@', lemmaabfrage_api, flags=re.IGNORECASE)
    lemmaabfrage_api = re.sub(r'\s+', '', lemmaabfrage_api)

    # Dateivorsilben-Text
    lemma_text = lemmaabfrage_raw.replace(',', 'κομμα')
    lemma_text = re.sub(r'[^\w\s]', '…', lemma_text)
    lemma_text = re.sub(r'^…{2,}', '…', lemma_text)
    lemma_text = re.sub(r'…{2,}$', '…', lemma_text)
    lemma_text = lemma_text.replace('κομμα', ',')

    datum_heute_lang = ermittle_altes_monatsdatum()
    titel_text = f"Wörter-Abfrage „{lemma_text}“ aus Grimm-Wörterbuch"
    untertitel_text = datum_heute_lang

    ohne_text, ohne_regex, ohne_regex_xml = erstelle_ohne_filter(args.ohne)

    # Dateinamen definieren
    heute_str = datetime.datetime.now().strftime('%Y%m%d')
    if len(ohne_text) > 0:
        datei_vorfuegung = f"{lemma_text} und ohne Wörter_Lemmata-Abfrage-DWB1_{heute_str}"
    else:
        datei_vorfuegung = f"{lemma_text}_Lemmata-Abfrage-DWB1_{heute_str}"

    json_speicher_datei = f"{datei_vorfuegung}.json"
    json_speicher_datei_ueberarbeitet = f"{datei_vorfuegung}-ordentlich überarbeitet.json"
    datei_utf8_text_zwischenablage = f"{datei_vorfuegung}-utf8_Zwischenablage.txt"
    datei_utf8_text_zwischenablage_gram = f"{datei_vorfuegung}-utf8_Zwischenablage mit Sprachkunde.txt"
    datei_utf8_reiner_text = f"{datei_vorfuegung}-utf8 nur Wörter.txt"
    datei_utf8_reiner_text_gram = f"{datei_vorfuegung}-utf8 nur Wörter mit Sprachkunde.txt"
    datei_utf8_html_zwischenablage_gram = f"{datei_vorfuegung}-utf8 Zwischenablage Wortliste mit Sprachkunde.html"
    datei_utf8_html_gram_tidy = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde-tidy.html"
    datei_utf8_html_gram_tidy_log = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde-tidy.html.log"
    datei_utf8_html_gram_tidy_worttabelle_odt = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde-tidy Einzeltabelle.odt"
    datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde-tidy Einzelabschnitte.md"
    datei_utf8_odt_gram = f"{datei_vorfuegung} Wortliste mit Sprachkunde.odt"
    datei_diese_wbnetzkwiclink = f"{datei_utf8_html_zwischenablage_gram}.wbnetzkwiclink.txt"
    datei_utf8_html_gram_tidy_markdown_telegram = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde-tidy (Telegram).md"

    if not args.stillschweigend and args.entwickeln:
        print(f"{farben.ORANGE}ENTWICKLUNG - lemmaabfrage:                {lemmaabfrage_raw}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - lemmaabfrage_api:            {lemmaabfrage_api}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - lemma_text:                  {lemma_text}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - ohne_regex:                  {ohne_regex}{farben.RESET}", file=sys.stderr)

    api_url = f"https://api.woerterbuchnetz.de/dictionaries/DWB/lemmata/select/{lemmaabfrage_api}/0/json"
    if not args.stillschweigend:
        print(f"{farben.GRUEN}Abfrage an api.woerterbuchnetz.de …{farben.RESET} ({api_url})", file=sys.stderr)

    try:
        req = urllib.request.Request(api_url, headers={'User-Agent': 'Mozilla/5.0 (Lemmaabfrage_DWB1)'})
        with urllib.request.urlopen(req, timeout=30) as resp:
            rohe_json_daten = resp.read().decode('utf-8')
            eintraege = json.loads(rohe_json_daten)
    except Exception as e:
        print(f"{farben.ROT}Fehler bei der API-Abfrage ({api_url}): {e}{farben.RESET}", file=sys.stderr)
        sys.exit(1)

    with open(json_speicher_datei, 'w', encoding='utf-8') as f:
        json.dump(eintraege, f, ensure_ascii=False, indent=2)

    anzahl_alle_eintraege = len(eintraege)
    if not args.stillschweigend:
        print(f"{farben.GRUEN}Weiterverarbeitung → JSON{farben.RESET} {anzahl_alle_eintraege} Ergebnisse …", file=sys.stderr)
        print(f"{farben.GRUEN}Weiterverarbeitung → JSON{farben.RESET} ({datei_utf8_reiner_text})", file=sys.stderr)

    # Weiterverarbeitung & Strukturierung
    verarbeitete_liste = []
    ohne_filter_re = re.compile(ohne_regex, re.IGNORECASE) if ohne_regex else None

    for item in eintraege:
        label = item.get('label', '')
        value = item.get('value', '')
        gram = item.get('gram', '')

        # Filterprüfung
        label_dekodiert = html_sonderzeichen_als_einzelzeichen(label)
        if ohne_filter_re and (ohne_filter_re.search(label) or ohne_filter_re.search(label_dekodiert)):
            continue

        label_gross = begin_grosz(label)
        gram_hauptgruppe = grammatik_in_hauptgruppen(gram, label_gross)

        wort_gross = bereite_wort_auf(label, capitalize=True)
        wort_klein = bereite_wort_auf(label, capitalize=False)

        deutung = grammatik_dem_wort_anhaengen(gram, wort_klein, wort_gross)
        wort_sortier_umlaut = html_sonderzeichen_umlaute_ausgeschrieben(label)

        verarbeitete_liste.append({
            'label': label,
            'value': value,
            'gram': gram,
            'gramHautgruppen': gram_hauptgruppe,
            'Wort': wort_gross,
            'wort': wort_klein,
            'Wortdeutung_mit_Grammatik': deutung,
            'wort_umlaut_geschrieben': wort_sortier_umlaut
        })

    # Sortierung: nach Hauptgruppe, dann alphabetisch nach Umlaut-Ausschreibung, dann Artikelform
    verarbeitete_liste.sort(key=lambda x: (
        x['gramHautgruppen'],
        x['wort_umlaut_geschrieben'],
        x['Wortdeutung_mit_Grammatik']['geschlechtswort_vorm_wort']
    ))

    with open(json_speicher_datei_ueberarbeitet, 'w', encoding='utf-8') as f:
        json.dump(verarbeitete_liste, f, ensure_ascii=False, indent=2)

    # Zusatzbemerkungen für Textausgabe
    zusatzbemerkungen_text = "Die Liste ist vorgruppiert geordnet nach den Grammatik-Angaben von Grimm, d.h. die Wörter sind nach Wortarten gruppiert: ohne Grammatik-Angabe, Eigenschaftswörter (Adjektive), Nennwörter (Substantive), Zeit- oder Tuwörter usw.."
    if ohne_text:
        zusatzbemerkungen_text += f"\n\nIn der Liste wurden folgende Wortverbindungen bewußt entfernt, allso ohne\n„{ohne_text}“."

    # 1. Textdatei: reine Wörter (ohne Grammatikangaben)
    gesehene_woerter = set()
    reine_woerter_zeilen = []
    for item in verarbeitete_liste:
        art_form = item['Wortdeutung_mit_Grammatik']['geschlechtswort_vorm_wort']
        if art_form not in gesehene_woerter:
            gesehene_woerter.add(art_form)
            if not item['gram']:
                reine_woerter_zeilen.append(f"{item['wort']};")
            else:
                reine_woerter_zeilen.append(f"{art_form};")

    with open(datei_utf8_reiner_text, 'w', encoding='utf-8') as f:
        f.write(f"{titel_text} ({untertitel_text})\n\n{zusatzbemerkungen_text}\n\n")
        f.write("\n".join(reine_woerter_zeilen) + "\n")

    # 2. Textdatei: mit Grammatikangaben
    if not args.stillschweigend:
        print(f"{farben.GRUEN}Weiterverarbeitung → JSON{farben.RESET} ({datei_utf8_reiner_text_gram})", file=sys.stderr)

    gram_woerter_zeilen = []
    gesehene_gram_zeilen = set()
    for item in verarbeitete_liste:
        art_form = item['Wortdeutung_mit_Grammatik']['geschlechtswort_vorm_wort']
        gram = item['gram']
        if not gram:
            zeile = f"{art_form};"
        else:
            zeile = f"{art_form} ({gram});"

        if zeile not in gesehene_gram_zeilen:
            gesehene_gram_zeilen.add(zeile)
            gram_woerter_zeilen.append(zeile)

    with open(datei_utf8_reiner_text_gram, 'w', encoding='utf-8') as f:
        f.write(f"{titel_text} ({untertitel_text})\n\n{zusatzbemerkungen_text}\n\n")
        f.write("\n".join(gram_woerter_zeilen) + "\n")

    anzahl_verarbeitete_eintraege = len(gram_woerter_zeilen)
    if not args.stillschweigend:
        print(f"{farben.GRUEN}Weiterverarbeitung → JSON{farben.RESET} {anzahl_verarbeitete_eintraege} eineinzige Wörter aus {anzahl_alle_eintraege} Ergebnissen", file=sys.stderr)

    # 3. HTML-Ausgabe vorbereiten (sofern -H, -O, -T oder Einzelabschnitte gefordert)
    if args.HTML or args.ODT or args.Telegrammarkdown or args.liste_einzelabschnitte:
        if not args.stillschweigend:
            print(f"{farben.GRUEN}Weiterverarbeitung → JSON{farben.RESET} ({datei_utf8_html_zwischenablage_gram})", file=sys.stderr)

        # Einleitungstext für HTML
        zusatz_html = f"; in der Liste wurden folgende Wortverbindungen bewußt entfernt, d.h. ohne „{args.ohne}“." if args.ohne else "."
        if lemma_text.startswith('…') and lemma_text.endswith('…'):
            bearbeitungstext_html = f"Liste {'leicht' if args.ohne else 'noch nicht'} überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>{lemma_text}</i> zu tun haben){zusatz_html}"
        elif lemma_text.startswith('…'):
            bearbeitungstext_html = f"Liste {'leicht' if args.ohne else 'noch nicht'} übearbeitet (es können auch Wörter enthalten sein, die nichts mit der Endung <i>{lemma_text}</i> gemein haben){zusatz_html}"
        elif lemma_text.endswith('…'):
            bearbeitungstext_html = f"Liste {'leicht' if args.ohne else 'noch nicht'} überarbeitet (es können auch Wörter enthalten sein, die nichts mit dem Wortanfang <i>{lemma_text}</i> gemein haben){zusatz_html}"
        else:
            bearbeitungstext_html = f"Liste {'leicht' if args.ohne else 'noch nicht'} überarbeitet (es können auch Wörter enthalten sein, die nichts mit der Abfrage <i>{lemma_text}</i> zu tun haben){zusatz_html}"

        # Fundstellen laden, falls -F aktiv
        kwic_fundstellen = {}
        if args.Fundstellen:
            if not args.stillschweigend:
                print(f"{farben.GRUEN}Weiterverarbeitung → JSON → HTML{farben.RESET} ({len(verarbeitete_liste)} Fundstellen)", file=sys.stderr)

            for idx, item in enumerate(verarbeitete_liste, 1):
                val = item['value']
                kwic_url = f"https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/{val}/textid/1/wordid/1"
                kwic_text = lade_kwic_fundstelle(kwic_url, textid=1)
                kwic_fundstellen[val] = kwic_text

                if not args.stillschweigend:
                    if idx % 100 == 0:
                        sys.stderr.write(f". {idx:04d}\n")
                        sys.stderr.flush()
                    else:
                        sys.stderr.write("." if idx < len(verarbeitete_liste) else ".\n")
                        sys.stderr.flush()

        # HTML-Tabellenzeilen
        html_zeilen = []
        for item in verarbeitete_liste:
            wort_geschlecht = item['Wortdeutung_mit_Grammatik']['wort_mit_geschlechtswort']
            gram_deutung = item['Wortdeutung_mit_Grammatik']['grammatik_deutung']
            val = item['value']
            lab = item['label']

            fundstelle_spalte = ""
            if args.Fundstellen:
                fundstelle_spalte = f"<td>{kwic_fundstellen.get(val, '')}</td>"

            link_html = f'<small><a href="https://www.woerterbuchnetz.de/DWB?lemid={val}">woerterbuchnetz.de/DWB/{lab}</a>, <a href="https://www.woerterbuchnetz.de/DWB?lemid={val}">woerterbuchnetz.de/DWB?lemid={val}</a></small>'
            zeile_html = f"<tr><td>{wort_geschlecht}</td>{fundstelle_spalte}<td>{gram_deutung}</td><td>{link_html}</td></tr>"
            html_zeilen.append(zeile_html)

        tabellenkopf_fundstelle = "<th>Textauszug (gekürzt)</th>" if args.Fundstellen else ""
        abkuerzungs_hinweis = ""
        abkuerzungen_anhang = ""

        # Prüfe auf Abkürzungstabelle
        abk_pfade = [
            Path("Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html"),
            Path("DWB1/Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html"),
            Path(__file__).resolve().parent / "Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html",
        ]
        abk_datei = next((pfad_hier for pfad_hier in abk_pfade if pfad_hier.is_file()), None)
        if args.Fundstellen and abk_datei:
            abkuerzungs_hinweis = '<p>Siehe auch das <a class="local" href="#abschnitt-GRIMM_Abkuerzungen">Abkürzungsverzeichnis</a>.</p>\n'
            try:
                abkuerzungen_anhang = abk_datei.read_text(encoding='utf-8')
            except Exception:
                abkuerzungen_anhang = ""

        html_technischer_hinweis = '<p>Für die Techniker: Die Abfrage wurde mit <a href="https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/tree/main/DWB1#stichwörter-abfragen"><code>Lemmaabfrage_DWB1.py</code> (siehe GitHub)</a> durchgeführt.</p>\n'

        html_dokument = f"""<!DOCTYPE html>
<html lang="de-DE" xml:lang="de-DE" xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>{titel_text}</title>
</head>
<style type="text/css" >
#Wortliste-Tabelle td {{ vertical-align:top; }}

#Wortliste-Tabelle td:nth-child(2),
#Wortliste-Tabelle td:nth-child(4),
#Wortliste-Tabelle td:nth-child(5) {{ font-size:smaller; }}

a.local {{ text-decoration:none; }}
</style>
<body style="font-family: Antykwa Torunska, serif; background: white;"><p>{bearbeitungstext_html}</p><p>Diese Tabelle ist nach <i>Grammatik (Grimm)</i> buchstäblich vorsortiert gruppiert, also finden sich Tätigkeitswörter (Verben) beisammen, Eigenschaftswörter (Adjektive) beisammen, Nennwörter (Substantive), als auch Wörter ohne Angabe der Grammatik/Sprachkunst-Begriffe usw..</p>{abkuerzungs_hinweis}<p>Zur Sprachkunst oder Grammatik siehe vor allem <i style="font-variant:small-caps;">Schottel (1663)</i> das ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href="https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href="https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table id="Wortliste-Tabelle"><thead><tr><th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Wort</th>{f'<th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Textauszug (gekürzt)</th>' if args.Fundstellen else ''}<th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Grammatik (<i>Grimm</i>) ~ Sprachkunst, Sprachlehre (s. a. <i style="font-variant:small-caps;">Schottel&nbsp;1663</i>)</th><th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Verknüpfungen</th></tr></thead><tbody>
{chr(10).join(html_zeilen)}
</tbody><tfoot><tr><td colspan="{4 if args.Fundstellen else 3}" style="border-top:2px solid gray;border-bottom:0 none;"></td>
</tr></tfoot></table>{html_technischer_hinweis}
{abkuerzungen_anhang}
</body>
</html>
"""

        with open(datei_utf8_html_zwischenablage_gram, 'w', encoding='utf-8') as f:
            f.write(html_dokument)

        # Bereinigung mit tidy (falls installiert)
        tidy_cmd = shutil.which("tidy")
        if tidy_cmd:
            if not args.stillschweigend:
                print(f"{farben.GRUEN}Weiterverarbeitung → JSON → HTML{farben.RESET} (tidy: {datei_utf8_html_gram_tidy})", file=sys.stderr)
            tidy_aufruf = [
                tidy_cmd,
                "-quiet",
                "--wrap", "0",
                "--indent", "2",
                "--tidy-mark", "no",
                "-output", datei_utf8_html_gram_tidy,
                datei_utf8_html_zwischenablage_gram
            ]

            with open(datei_utf8_html_gram_tidy_log, 'w', encoding='utf-8') as log_file:
                subprocess.run(tidy_aufruf, stderr=log_file, check=False)

        else:
            shutil.copyfile(datei_utf8_html_zwischenablage_gram, datei_utf8_html_gram_tidy)

        # 4. ODT erzeugen
        if args.ODT:
            pandoc_cmd = shutil.which("pandoc")
            if not pandoc_cmd:
                print(f"{farben.ORANGE}pandoc nicht gefunden; ODT-Erstellung übersprungen.{farben.RESET}", file=sys.stderr)
            else:
                if not args.stillschweigend:
                    print(f"{farben.GRUEN}Weiterverarbeitung: HTML → ODT{farben.RESET} ({datei_utf8_odt_gram})", file=sys.stderr)

                # Prüfe auf ODT-Formatvorlage
                odt_vorlage_pfade = [
                    Path("pandoc_Vorlage_DWB1_Wörterliste.odt"),
                    Path("DWB1/pandoc_Vorlage_DWB1_Wörterliste.odt"),
                    Path(__file__).resolve().parent / "pandoc_Vorlage_DWB1_Wörterliste.odt",
                ]
                odt_vorlage = next((pfad for pfad in odt_vorlage_pfade if pfad.is_file()), None)

                cmd_odt = [
                    pandoc_cmd,
                    f"--variable=subtitle:{untertitel_text}",
                    "--variable=lang:de-DE",
                    "--from", "html",
                    "--to", "odt",
                ]

                if odt_vorlage:
                    if not args.stillschweigend:
                        print(f"{farben.GRUEN}Verwende ODT-Vorlage:{farben.RESET} {odt_vorlage}", file=sys.stderr)
                    cmd_odt.append(f"--reference-doc={odt_vorlage}")

                cmd_odt.extend([
                    datei_utf8_html_gram_tidy,
                    "--output", datei_utf8_odt_gram
                ])

                subprocess.run(cmd_odt, check=False)

        # 5. Einzelabschnitte (Markdown)
        if args.liste_einzelabschnitte:
            if not args.stillschweigend:
                print(f"{farben.GRUEN}Weiterverarbeitung: Einzelabschnitte{farben.RESET} ({datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte})", file=sys.stderr)

            # Gruppierung direkt in Python
            kategorien = {}
            for item in verarbeitete_liste:
                kat = item['Wortdeutung_mit_Grammatik']['grammatik_deutung'] or "ohne Begriffsangabe der Sprachkunde"
                wort = item['Wortdeutung_mit_Grammatik']['wort_mit_geschlechtswort']
                kategorien.setdefault(kat, []).append(wort)

            abschnitt_zeilen = []
            for kat, woerter in kategorien.items():
                abschnitt_zeilen.append(f"\n## {kat}\n")
                for w in woerter:
                    abschnitt_zeilen.append(w)

            with open(datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte, 'w', encoding='utf-8') as f:
                f.write("\n".join(abschnitt_zeilen).strip() + "\n")

        # 6. Telegram Markdown
        if args.Telegrammarkdown:
            if not args.stillschweigend:
                print(f"{farben.GRUEN}Weiterverarbeitung: HTML → Telegram.MD{farben.RESET} ({datei_utf8_html_gram_tidy_markdown_telegram})", file=sys.stderr)

            pandoc_cmd = shutil.which("pandoc")
            if pandoc_cmd and os.path.exists(datei_utf8_html_gram_tidy):
                res = subprocess.run(
                    [pandoc_cmd, "--wrap=none", "-f", "html", "-t", "markdown", datei_utf8_html_gram_tidy],
                    capture_output=True, text=True, check=False
                )
                md_text = res.stdout
                md_text = md_text.replace("**", "FETTSCHRIFT").replace("*", "__").replace("FETTSCHRIFT", "**")
                md_text = re.sub(r'\[([^\]]+)\]\{.smallcaps\}', lambda m: m.group(1).upper(), md_text)
                md_text = re.sub(r'\{[.]small\}', '', md_text)
                md_text = re.sub(r'([^…]|[^.]{3})«', r'\1…«', md_text)
                md_text = re.sub(r'__( +)__', r'\1', md_text)
                md_text = md_text.replace('^', '')
                md_text = re.sub(r'\\([~\'.])', r'\1', md_text)
                md_text = md_text.replace(r'\[', '[').replace(r'\]', ']')

                with open(datei_utf8_html_gram_tidy_markdown_telegram, 'w', encoding='utf-8') as f:
                    f.write(md_text)

    # Aufräumen nicht benötigter Dateien, falls nicht -b
    if not args.behalte_Dateien:
        kurzweilige_dateien = [
            json_speicher_datei,
            json_speicher_datei_ueberarbeitet,
            datei_utf8_text_zwischenablage,
            datei_utf8_text_zwischenablage_gram,
            datei_utf8_html_zwischenablage_gram,
            datei_utf8_html_gram_tidy,
            datei_utf8_html_gram_tidy_log,
            datei_diese_wbnetzkwiclink,
            datei_utf8_html_gram_tidy_worttabelle_odt
        ]
        if not (args.HTML or args.ODT or args.Telegrammarkdown or args.liste_einzelabschnitte):
            kurzweilige_dateien.append(datei_utf8_html_gram_tidy)

        for kurzweilige_datei in kurzweilige_dateien:
            if os.path.exists(kurzweilige_datei):
                try:
                    os.remove(kurzweilige_datei)
                except OSError:
                    pass

    if not args.stillschweigend:
        print(f"{farben.ORANGE}Folgende Dateien sind erstellt worden:{farben.RESET}", file=sys.stderr)
        for dateipfad in sorted(Path('.').glob(f"{datei_vorfuegung}*")):
            if dateipfad.is_file():
                print(f"  {dateipfad.name}", file=sys.stderr)


if __name__ == '__main__':
    main()
