#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Volltextabfrage_DWB1.py

Fragt Volltexte aus der Programmierschnittstelle (API) des Deutschen Wörterbuchs
von Jacob und Wilhelm Grimm (DWB1) auf woerterbuchnetz.de ab, filtert die Treffer
nach Stichwort- und Ausschlusskriterien und erstellt strukturierte Text-, HTML-,
ODT- und Markdown-Listen mit nachgeladenen KWIC-Fundstellen.

Portierung und Weiterentwicklung von DWB-PSS_volltext_abfragen-und-ausgeben.sh in Python 3.
"""

import sys
import os
import re
import json
import sqlite3
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse
import datetime
import html
import shutil
import subprocess
import time
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path


class Farben:
    """Verwaltung von Terminalfarben für formatierte Bildschirmausgaben."""
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


# Zuordnungstabelle: Private Unicode-Zeichen (PUA / MUFI aus woerterbuchnetz)
# zu standardkonformen kombinierenden Unicode-Zeichen (Weg 2: Mittelweg)
PUA_KOMBINIEREND_ERSATZ = {
    '\ue433': 'a\u0364',  # a mit übergestelltem e (aͤ)
    '\ue438': 'o\u0364',  # o mit übergestelltem e (oͤ)
    '\ue440': 'u\u0364',  # u mit übergestelltem e (uͤ)
    '\ue0c4': 'A\u0364',  # A mit übergestelltem e (Aͤ)
    '\ue0d6': 'O\u0364',  # O mit übergestelltem e (Oͤ)
    '\ue0dc': 'U\u0364',  # U mit übergestelltem e (Uͤ)
    '\ue560': 'u\u0366',  # u mit übergestelltem o (uͦ)
    '\ue0ad': 'U\u0366',  # U mit übergestelltem o (Uͦ)
    '\ue998': 's\u0305',  # s mit Kürzungsstrich / Makron (s̅)
}


def html_sonderzeichen_als_einzelzeichen(w):
    """Wandelt hexadezimale HTML-Umlaut- und Sonderzeichen-Entities in echte UTF-8-Zeichen um und ersetzt PUA-Zeichen durch kombinierende Unicode-Zeichen."""
    if not w:
        return ""
    import html as _html
    text = _html.unescape(str(w))
    for pua_char, kombi_char in PUA_KOMBINIEREND_ERSATZ.items():
        text = text.replace(pua_char, kombi_char)
    return text


def html_sonderzeichen_umlaute_ausgeschrieben(w):
    """Ersetzt Umlaute und Sonderzeichen für eine einheitliche Sortierung."""
    if not w:
        return ""
    ergebnis = html_sonderzeichen_als_einzelzeichen(w)
    ersetzungen = [
        ('a\u0364', 'ae'), ('A\u0364', 'Ae'),
        ('o\u0364', 'oe'), ('O\u0364', 'Oe'),
        ('u\u0364', 'ue'), ('U\u0364', 'Ue'),
        ('u\u0366', 'uo'), ('U\u0366', 'Uo'),
        ('s\u0305', 's'),
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

    feste_anfaenge = [
        (r'^auszen', 'außen'), (r'^Auszen', 'Außen'),
        (r'^auszer', 'außer'), (r'^Auszer', 'Außer'),
        (r'^barfüsz', 'barfüß'), (r'^Barfüsz', 'Barfüß'),
        (r'^barfusz', 'barfuß'), (r'^Barfusz', 'Barfuß'),
        (r'^droszlicht', 'droßlicht'), (r'^Droszlicht', 'Droßlicht'),
        (r'^erlasz', 'erlaß'), (r'^Erlasz', 'Erlaß'),
        (r'^fusz', 'fuß'), (r'^Fusz', 'Fuß'),
        (r'^füsz', 'füß'), (r'^Fuesz', 'Füß'),
        (r'^gäszchen', 'gäßchen'), (r'^Gäszchen', 'Gäßchen'),
        (r'^gesträusz', 'gesträuß'), (r'^Gesträusz', 'Gesträuß'),
        (r'^grösz', 'größ'), (r'^Grösz', 'Größ'),
        (r'^grosz', 'groß'), (r'^Grosz', 'Groß'),
        (r'^misz', 'miß'), (r'^Misz', 'Miß'),
        (r'^räszlicht', 'räßlicht'), (r'^reszlicht', 'reßlicht'),
        (r'^rusz', 'ruß'), (r'^Rusz', 'Ruß'),
        (r'^schiesz', 'schieß'), (r'^Schiesz', 'Schieß'),
        (r'^schleisz', 'schleiß'), (r'^Schleisz', 'Schleiß'),
        (r'^schlosz', 'schloß'), (r'^Schlosz', 'Schloß'),
        (r'^schmeisz', 'schmeiß'), (r'^Schmeisz', 'Schmeiß'),
        (r'^schösz', 'schöß'), (r'^Schösz', 'Schöß'),
        (r'^schoosz', 'schooß'), (r'^Schoosz', 'Schooß'),
        (r'^schosz', 'schoß'), (r'^Schosz', 'Schoß'),
        (r'^schweisz', 'schweiß'), (r'^Schweisz', 'Schweiß'),
        (r'^spasz', 'spaß'), (r'^Spasz', 'Spaß'),
        (r'^spleisz', 'spleiß'), (r'^Spleisz', 'Spleiß'),
        (r'^spreisz', 'spreiß'), (r'^Spreisz', 'Spreiß'),
        (r'^sprosz', 'sproß'), (r'^Sprosz', 'Sproß'),
        (r'^sprösz', 'spröß'), (r'^Sprösz', 'Spröß'),
        (r'^stosz', 'stoß'), (r'^Stosz', 'Stoß'),
        (r'^strasz', 'straß'), (r'^Strasz', 'Straß'),
        (r'^trasz', 'traß'), (r'^Trasz', 'Traß'),
        (r'^tüszlicht', 'tüßlicht'),
        (r'^urgrosz', 'urgroß'), (r'^Urgrosz', 'Urgroß'),
        (r'^vergiszmein', 'vergißmein'), (r'^Vergiszmein', 'Vergißmein'),
        (r'^wisz', 'wiß'), (r'^Wisz', 'Wiß'),
        (r'^weisz', 'weiß'), (r'^Weisz', 'Weiß'),
        (r'^zwiszlich', 'zwißlich'),
    ]

    for muster, ziel in feste_anfaenge:
        if re.search(muster, ergebnis):
            ergebnis = re.sub(muster, ziel, ergebnis)

    endungen = [
        (r'beiszer$', 'beißer'),
        (r'beiszker$', 'beißker'),
        (r'beisz$', 'beiß'),
        (r'eisz$', 'eiß'),
        (r'füszicht$', 'füßicht'),
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

    stamm_ersetzungen = [
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
        (r'vergiszmein', 'vergißmein'),
        (r'verheisz', 'verheiß'),
        (r'verlaszmich', 'verlaßmich'),
    ]
    for muster, ziel in stamm_ersetzungen:
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
        elif re.search(r'.+(?:heit|keit|ling|schaft|thum|tum|ung|zuversicht)$', w_low):
            return "nennwörtlich"
        else:
            return ""

    g_norm = g.strip()
    g_norm = html_sonderzeichen_als_einzelzeichen(g_norm)

    # 1. Tuwörter (Verben)
    if re.search(r'(?:^|\b)(?:v\b|vb\b|verb|verbum|inf\b|swv\b|trans\b|intrans\b|tr\b|intr\b|refl\b|starkes verb|schwaches verb|trennb|untrennbar|schallmalend)', g_norm, re.IGNORECASE):
        if not re.search(r'adj|part', g_norm, re.IGNORECASE):
            return "tuwörtlich"

    # 2. Eigenschaftswörter (Adjektive, Adverbien, Partizipien)
    if re.search(r'(?:^|\b)(?:adj|adject|adv|adverb|part|particip|partiz|verbaladj|fragew\. u\. adv|raumadv)', g_norm, re.IGNORECASE):
        if not re.search(r'^(?:f|m|n)\b.*adj', g_norm, re.IGNORECASE):
            return "eigenschaftlich"

    # 3. Nennwörter (Substantive)
    if re.search(r'(?:^|\b)(?:f\b|m\b|n\b|fem\b|masc|neutr|subst|nomen|dimin|dim\b|pl\b|plur\b|verbalsubstantiv)', g_norm, re.IGNORECASE):
        return "nennwörtlich"

    # 4. Andere Wortarten
    return "unbekannt"


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

    # --- Adjektive / Adverbien / Partizipien / Sonstige ---
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

    for regex, nach_tpl, vor_tpl, deutung in _ZUSAMMENGESETZTE_SPRACHKUNDE_REGELN:
        if regex.search(g_clean):
            return {
                "wort_mit_geschlechtswort": nach_tpl.format(w=w, W=W),
                "geschlechtswort_vorm_wort": vor_tpl.format(w=w, W=W),
                "grammatik_deutung": f"{g_orig} ~ {deutung}"
            }

    return {
        "wort_mit_geschlechtswort": w,
        "geschlechtswort_vorm_wort": w,
        "grammatik_deutung": f"{g_orig} ~ ?"
    }


def erstelle_ohne_filter(ohne_str):
    """
    Erstellt reguläre Ausdrücke zur Ausschlußfilterung aus der '--ohne' Angabe.
    Unterstützt sowohl 'wort' als auch Formen mit Geschlechtswort wie 'das *licht'.
    """
    if not ohne_str or not ohne_str.strip():
        return "", "", ""

    raw_ohne = ohne_str.strip()
    begriffe = [b.strip() for b in re.split(r'[,;]+', raw_ohne) if b.strip()]
    ohne_text = ", ".join(begriffe)

    muster_teile = []
    muster_teile_xml = []
    entity_ersetzungen = [
        ('ä', '&#x00e4;'), ('Ä', '&#x00c4;'),
        ('ö', '&#x00f6;'), ('Ö', '&#x00d6;'),
        ('ü', '&#x00fc;'), ('Ü', '&#x00dc;'),
        ('ú', '&#x00fa;'), ('Ú', '&#x00da;'),
    ]

    for begriff_hier in begriffe:
        reg_muster = re.escape(begriff_hier).replace(r'\*', '.*').replace(r'\?', '.')
        muster_teile.append(reg_muster)

        b_xml = begriff_hier
        for sonderzeichen, xml_entity in entity_ersetzungen:
            b_xml = b_xml.replace(sonderzeichen, xml_entity)
        pat_xml = re.escape(b_xml).replace(r'\*', '.*').replace(r'\?', '.')
        muster_teile_xml.append(pat_xml)

    ohne_regex = r'^(?:' + '|'.join(muster_teile) + r')$'
    ohne_regex_xml = r'^(?:' + '|'.join(muster_teile_xml) + r')$'

    return ohne_text, ohne_regex, ohne_regex_xml


def erstelle_stichwort_filter(stichwort_str):
    """
    Erstellt reguläre Ausdrücke zur Stichwortfilterung aus der '--Stichwortabfrage' Angabe.
    Unterstützt Globs (*, ?), reguläre Ausdrücke und kommagetrennte Listen.
    """
    if not stichwort_str or not stichwort_str.strip():
        return "", "", ""

    raw = stichwort_str.strip()
    begriffe = [b.strip() for b in re.split(r'[,;]+', raw) if b.strip()]
    stichwort_text = ", ".join(begriffe)

    muster_teile = []
    muster_teile_xml = []
    entity_ersetzungen = [
        ('ä', '&#x00e4;'), ('Ä', '&#x00c4;'),
        ('ö', '&#x00f6;'), ('Ö', '&#x00d6;'),
        ('ü', '&#x00fc;'), ('Ü', '&#x00dc;'),
        ('ú', '&#x00fa;'), ('Ú', '&#x00da;'),
    ]

    for begriff_hier in begriffe:
        reg_muster = re.escape(begriff_hier).replace(r'\*', '.*').replace(r'\?', '.')
        muster_teile.append(reg_muster)

        b_xml = begriff_hier
        for sonderzeichen, xml_entity in entity_ersetzungen:
            b_xml = b_xml.replace(sonderzeichen, xml_entity)
        pat_xml = re.escape(b_xml).replace(r'\*', '.*').replace(r'\?', '.')
        muster_teile_xml.append(pat_xml)

    stichwort_regex = r'^(?:' + '|'.join(muster_teile) + r')$'
    stichwort_regex_xml = r'^(?:' + '|'.join(muster_teile_xml) + r')$'

    return stichwort_text, stichwort_regex, stichwort_regex_xml


def ermittle_standard_suchpuffer_pfad():
    """Ermittelt den Standardpfad für den SQLite-Suchpuffer nach XDG-Spezifikation."""
    xdg_cache = os.environ.get("XDG_CACHE_HOME")
    if xdg_cache:
        basis = Path(xdg_cache)
    else:
        basis = Path.home() / ".cache"
    return basis / "woerterbuchnetz" / "dwb1_suchpuffer.sqlite"


class SuchpufferDWB1:
    """
    Zentraler SQLite-Suchpuffer zur persistenten Zwischenspeicherung von
    Wörterbuch- und KWIC-Fundstellenabfragen.
    """
    def __init__(self, db_pfad=None, aktiv=True, max_eintraege=10000, max_groesse_mb=100, max_alter_tage=180):
        self.aktiv = aktiv
        self.max_eintraege = max_eintraege
        self.max_groesse_mb = max_groesse_mb
        self.max_alter_tage = max_alter_tage
        self.session_treffer = 0
        self.session_fehlschlaege = 0
        self._sperre = threading.Lock()

        if db_pfad:
            self.db_pfad = Path(db_pfad).expanduser()
        else:
            self.db_pfad = ermittle_standard_suchpuffer_pfad()

        self.verbindung = None
        if self.aktiv:
            self._initialisiere_datenbank()

    def _initialisiere_datenbank(self):
        with self._sperre:
            try:
                self.db_pfad.parent.mkdir(parents=True, exist_ok=True)
                self.verbindung = sqlite3.connect(str(self.db_pfad), timeout=15.0, check_same_thread=False)
                cur = self.verbindung.cursor()
                cur.execute("PRAGMA journal_mode = WAL;")
                cur.execute("PRAGMA synchronous = NORMAL;")
                cur.execute("PRAGMA auto_vacuum = INCREMENTAL;")
                cur.execute("PRAGMA temp_store = MEMORY;")

                cur.execute("""
                    CREATE TABLE IF NOT EXISTS kwic_puffer (
                        formid TEXT NOT NULL,
                        textid TEXT NOT NULL,
                        wordid TEXT NOT NULL,
                        kwic_url TEXT,
                        rohtext_html TEXT NOT NULL,
                        hit_count INTEGER DEFAULT 1,
                        last_accessed TIMESTAMP,
                        created_at TIMESTAMP,
                        PRIMARY KEY (formid, textid, wordid)
                    );
                """)
                cur.execute("CREATE INDEX IF NOT EXISTS idx_kwic_last_accessed ON kwic_puffer (last_accessed);")

                cur.execute("""
                    CREATE TABLE IF NOT EXISTS puffer_statistik (
                        schluessel TEXT PRIMARY KEY,
                        wert INTEGER DEFAULT 0
                    );
                """)
                self.verbindung.commit()
                self._bereinige_puffer_gesperrt()
            except Exception:
                self.aktiv = False
                self.verbindung = None

    def _inkrementiere_statistik_gesperrt(self, schluessel, anzahl=1):
        if not self.verbindung or not self.aktiv:
            return
        try:
            cur = self.verbindung.cursor()
            cur.execute("""
                INSERT INTO puffer_statistik (schluessel, wert)
                VALUES (?, ?)
                ON CONFLICT(schluessel) DO UPDATE SET wert = wert + excluded.wert;
            """, (schluessel, anzahl))
            self.verbindung.commit()
        except Exception:
            pass

    def hole_kwic(self, formid, textid, wordid):
        if not self.aktiv:
            return None
        with self._sperre:
            if not self.verbindung:
                return None
            try:
                cur = self.verbindung.cursor()
                cur.execute("""
                    SELECT rohtext_html, hit_count FROM kwic_puffer
                    WHERE formid = ? AND textid = ? AND wordid = ?;
                """, (str(formid), str(textid), str(wordid)))
                row = cur.fetchone()
                if row:
                    rohtext_html, hit_count = row
                    jetzt_iso = datetime.datetime.now().isoformat()
                    cur.execute("""
                        UPDATE kwic_puffer
                        SET last_accessed = ?, hit_count = hit_count + 1
                        WHERE formid = ? AND textid = ? AND wordid = ?;
                    """, (jetzt_iso, str(formid), str(textid), str(wordid)))
                    self.verbindung.commit()
                    self.session_treffer += 1
                    self._inkrementiere_statistik_gesperrt('treffer_gesamt', 1)
                    return rohtext_html
                else:
                    self.session_fehlschlaege += 1
                    self._inkrementiere_statistik_gesperrt('fehlschlaege_gesamt', 1)
                    return None
            except Exception:
                return None

    def speichere_kwic(self, formid, textid, wordid, kwic_url, rohtext_html):
        if not self.aktiv:
            return
        with self._sperre:
            if not self.verbindung:
                return
            try:
                jetzt_iso = datetime.datetime.now().isoformat()
                cur = self.verbindung.cursor()
                cur.execute("""
                    INSERT INTO kwic_puffer (formid, textid, wordid, kwic_url, rohtext_html, hit_count, last_accessed, created_at)
                    VALUES (?, ?, ?, ?, ?, 1, ?, ?)
                    ON CONFLICT(formid, textid, wordid) DO UPDATE SET
                        rohtext_html = excluded.rohtext_html,
                        kwic_url = excluded.kwic_url,
                        last_accessed = excluded.last_accessed;
                """, (str(formid), str(textid), str(wordid), str(kwic_url), str(rohtext_html), jetzt_iso, jetzt_iso))
                self.verbindung.commit()
            except Exception:
                pass

    def _bereinige_puffer_gesperrt(self):
        if not self.verbindung or not self.aktiv:
            return
        try:
            cur = self.verbindung.cursor()
            grenz_datum = (datetime.datetime.now() - datetime.timedelta(days=self.max_alter_tage)).isoformat()
            cur.execute("DELETE FROM kwic_puffer WHERE last_accessed < ?;", (grenz_datum,))

            cur.execute("SELECT COUNT(*) FROM kwic_puffer;")
            anzahl = cur.fetchone()[0]

            dateigroesse_mb = 0.0
            if self.db_pfad.exists():
                dateigroesse_mb = self.db_pfad.stat().st_size / (1024 * 1024)

            muss_bereinigen = (anzahl > self.max_eintraege) or (dateigroesse_mb > self.max_groesse_mb)
            if muss_bereinigen and anzahl > 0:
                anzahl_zu_loeschen = max(int(anzahl * 0.20), anzahl - int(self.max_eintraege * 0.80))
                if anzahl_zu_loeschen > 0:
                    cur.execute("""
                        DELETE FROM kwic_puffer
                        WHERE rowid IN (
                            SELECT rowid FROM kwic_puffer
                            ORDER BY last_accessed ASC
                            LIMIT ?
                        );
                    """, (anzahl_zu_loeschen,))

            self.verbindung.commit()
            if muss_bereinigen:
                cur.execute("PRAGMA incremental_vacuum;")
                self.verbindung.commit()
        except Exception:
            pass

    def bereinige_puffer(self):
        """Entfernt alte Einträge (TTL > 180 Tage) oder führt LRU-Bereinigung durch."""
        with self._sperre:
            self._bereinige_puffer_gesperrt()

    def leere_puffer(self):
        """Löscht alle Einträge aus dem Puffer und setzt die Statistiken zurück."""
        with self._sperre:
            if not self.verbindung:
                if self.db_pfad.exists():
                    self.verbindung = sqlite3.connect(str(self.db_pfad), check_same_thread=False)
                else:
                    return True
            try:
                cur = self.verbindung.cursor()
                cur.execute("DELETE FROM kwic_puffer;")
                cur.execute("DELETE FROM puffer_statistik;")
                self.verbindung.commit()
                cur.execute("VACUUM;")
                self.verbindung.commit()
                return True
            except Exception:
                return False

    def ermittle_info(self):
        """Ermittelt verdichtete Informationen und Nutzungsstatistiken des Suchpuffers."""
        with self._sperre:
            if not self.db_pfad.exists():
                return {
                    'existiert': False,
                    'db_pfad': str(self.db_pfad),
                    'anzahl_eintraege': 0,
                    'dateigroesse_mb': 0.0,
                    'dateigroesse_bytes': 0,
                    'treffer_gesamt': 0,
                    'fehlschlaege_gesamt': 0,
                    'anfragen_gesamt': 0,
                    'trefferquote': 0.0,
                    'max_eintraege': self.max_eintraege,
                    'max_groesse_mb': self.max_groesse_mb,
                    'max_alter_tage': self.max_alter_tage
                }

            conn = self.verbindung
            soll_schliessen = False
            if not conn:
                conn = sqlite3.connect(str(self.db_pfad), check_same_thread=False)
                soll_schliessen = True

            try:
                cur = conn.cursor()
                cur.execute("SELECT COUNT(*) FROM kwic_puffer;")
                anzahl = cur.fetchone()[0]

                cur.execute("SELECT MIN(created_at), MAX(last_accessed) FROM kwic_puffer;")
                row_zeit = cur.fetchone()
                aeltester = row_zeit[0] if row_zeit else None
                neuester = row_zeit[1] if row_zeit else None

                stats = {}
                try:
                    cur.execute("SELECT schluessel, wert FROM puffer_statistik;")
                    for k, v in cur.fetchall():
                        stats[k] = v
                except Exception:
                    pass

                treffer = stats.get('treffer_gesamt', 0)
                fehlschlaege = stats.get('fehlschlaege_gesamt', 0)
                anfragen = treffer + fehlschlaege
                quote = (treffer / anfragen * 100.0) if anfragen > 0 else 0.0

                groesse_bytes = self.db_pfad.stat().st_size
                groesse_mb = groesse_bytes / (1024 * 1024)

                return {
                    'existiert': True,
                    'db_pfad': str(self.db_pfad),
                    'anzahl_eintraege': anzahl,
                    'dateigroesse_mb': groesse_mb,
                    'dateigroesse_bytes': groesse_bytes,
                    'treffer_gesamt': treffer,
                    'fehlschlaege_gesamt': fehlschlaege,
                    'anfragen_gesamt': anfragen,
                    'trefferquote': quote,
                    'aeltester_eintrag': aeltester,
                    'neuester_eintrag': neuester,
                    'max_eintraege': self.max_eintraege,
                    'max_groesse_mb': self.max_groesse_mb,
                    'max_alter_tage': self.max_alter_tage
                }
            finally:
                if soll_schliessen:
                    conn.close()

    def schliessen(self):
        with self._sperre:
            if self.verbindung:
                try:
                    self._bereinige_puffer_gesperrt()
                    self.verbindung.close()
                except Exception:
                    pass
                self.verbindung = None


def hole_datenschnittstelle_json(url, max_versuche=3, timeout=30):
    """Ruft die JSON-Datenquelle als Handlungsnutzer (user-agent) ab und gibt das erteilte JSON-Ergebnis zurück."""
    headers = {'User-Agent': 'Mozilla/5.0 (Volltextabfrage_DWB1)'}
    for versuch in range(1, max_versuche + 1):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                daten_text = resp.read().decode('utf-8')
                return json.loads(daten_text)
        except Exception as e:
            if versuch == max_versuche:
                raise e
            time.sleep(0.5 * versuch)


def lade_kwic_fundstelle(wbnetzkwiclink, textid, suchpuffer=None, max_versuche=3):
    """Lädt den KWIC-Fundstellentext aus dem Suchpuffer oder der PSS (API) und formatiert ihn mit HTML-TextAusGestaltern."""
    formid = '0'
    wordid = '1'
    m = re.search(r'/kwic/([^/]+)/textid/([^/]+)/wordid/([^/]+)', wbnetzkwiclink)
    if m:
        formid, textid, wordid = m.group(1), m.group(2), m.group(3)
    else:
        m_open = re.search(r'/kwic/([^/]+)', wbnetzkwiclink)
        if m_open:
            textid = m_open.group(1)

    if suchpuffer and suchpuffer.aktiv:
        gepuffert = suchpuffer.hole_kwic(formid, textid, wordid)
        if gepuffert:
            return gepuffert, True

    try:
        data = hole_datenschnittstelle_json(wbnetzkwiclink, max_versuche=max_versuche, timeout=20)
    except Exception as e:
        return f"[Fehler beim Laden der Fundstelle: {e}]", False

    token_liste = []
    if isinstance(data, list):
        token_liste = data
    elif isinstance(data, dict):
        token_liste = data.get('result_set', [])

    ergebnis_teile = []
    hervorgehoben = False
    for eintrag in token_liste:
        w_textid = str(eintrag.get('textid', ''))
        raw_word = eintrag.get('word', '')
        word = html_sonderzeichen_als_einzelzeichen(raw_word)
        typeset = eintrag.get('typeset', '')
        charposition = eintrag.get('charposition', '')
        elementtype = str(eintrag.get('elementtype', ''))

        if w_textid == str(textid):
            wort_formatiert = f'<b class="gefunden-hervorheben" id="textid-{textid}">{word}</b>'
            hervorgehoben = True
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
        else:
            if charposition == 'super':
                wort_formatiert = f'<sup>{word}</sup>'
            elif re.search(r'sensemark\d+', elementtype):
                wort_formatiert = f'<b>{word}</b>'
            else:
                wort_formatiert = word

        ergebnis_teile.append(wort_formatiert)

    # Fallback falls über /dictionaries/.../wordid/1 die textid nicht zentriert war
    if not hervorgehoben and isinstance(data, list) and textid:
        url_openapi = f"https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/kwic/{textid}"
        try:
            data_open = hole_datenschnittstelle_json(url_openapi, max_versuche=2, timeout=15)
            if isinstance(data_open, dict) and data_open.get('result_set'):
                ergebnis_teile = []
                for eintrag in data_open.get('result_set', []):
                    w_textid = str(eintrag.get('textid', ''))
                    raw_word = eintrag.get('word', '')
                    word = html_sonderzeichen_als_einzelzeichen(raw_word)
                    if w_textid == str(textid):
                        ergebnis_teile.append(f'<b class="gefunden-hervorheben" id="textid-{textid}">{word}</b>')
                    else:
                        ergebnis_teile.append(word)
        except Exception:
            pass

    rohtext = "".join(ergebnis_teile)
    rohtext = rohtext.replace("</i><i>", "")
    rohtext = re.sub(r'»([ ;.:]+)', r'»…\1', f"»{rohtext}«")
    rohtext = rohtext.replace("«", "…«")

    if suchpuffer and suchpuffer.aktiv:
        suchpuffer.speichere_kwic(formid, textid, wordid, wbnetzkwiclink, rohtext)

    return rohtext, False


def urspruengliches_echtes_fundwort_auslesen(kwic_rohtext, notfall_ersatz=""):
    """
    Liest den ursprünglichen echten Wortfund aus dem formatierten KWIC-Text
    (einschließlich ursprünglicher Umlaute, Groß-/Kleinschreibung) und bereinigt Rand-Satzzeichen.
    Falls kein KWIC vorhanden ist, wird auf fallback_match zurückgegriffen.
    """
    if kwic_rohtext:
        m = re.search(r'<b class="gefunden-hervorheben"[^>]*>(.*?)</b>', kwic_rohtext, re.DOTALL)
        if m:
            rohes_wort = m.group(1)
            rohes_wort = re.sub(r'<[^>]+>', '', rohes_wort)
            wort = html_sonderzeichen_als_einzelzeichen(rohes_wort)
            wort = wort.strip()
            wort = re.sub(r'^[^\w]+|[^\w]+$', '', wort)
            wort = wort.strip()
            if wort:
                return wort
    if notfall_ersatz:
        fb = html_sonderzeichen_als_einzelzeichen(notfall_ersatz).strip()
        fb = re.sub(r'^[^\w]+|[^\w]+$', '', fb)
        return fb.strip()
    return ""


def baue_kwic_felder_zuordnung(allquery_daten):
    """Baut eine Zuordnungs-Tabelle auf: (formid, textid) -> kwic_url und textid -> kwic_url."""
    kwic_map = {}
    if not isinstance(allquery_daten, list):
        return kwic_map

    for eintrag in allquery_daten:
        fid = eintrag.get('formid', '')
        t_list = eintrag.get('textidlist', [])
        w_list = eintrag.get('wordidlist', [])

        def flach(l):
            res = []
            if isinstance(l, list):
                for item in l:
                    if isinstance(item, list):
                        res.extend(flach(item))
                    else:
                        res.append(item)
            else:
                res.append(l)
            return res

        t_flat = flach(t_list)
        w_flat = flach(w_list)

        for i, tid in enumerate(t_flat):
            wid = w_flat[i] if i < len(w_flat) else 1
            kwic_url = f"https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/{fid}/textid/{tid}/wordid/{wid}"
            kwic_map[(str(fid), str(tid))] = kwic_url
            kwic_map[str(tid)] = kwic_url
    return kwic_map


def erteile_befehlszeilen_anweisungen():
    """Legt anwendbare Befehlsanweisungen fest und erteilt sie zur Weiterverarbeitung."""
    parser = argparse.ArgumentParser(
        description="Volltext aus der Programm-Schnitt-Stelle (PSS/API) des Grimm-Wörterbuchs DWB abfragen und daraus strukturierte Listen-Textdokumente erstellen.",
        add_help=False
    )
    parser.add_argument('-h', '--Hilfe', '--hilfe', action='store_true',
                        help='Hilfetext dieses Programms ausgeben.')
    parser.add_argument('-v', '-V', '--Volltextabfrage', '--volltextabfrage', dest='volltextabfrage', type=str, default=None,
                        help='Pflichtfeld für die Volltextabfrage, die getätigt werden soll, z.B. „stupere“, „Haustür“ oder „*stall*“ u.ä. Mehrere Volltext-Suchwörter zugleich sind möglich: „sensibus, sensibilis, sensificus“')
    parser.add_argument('-S', '--Stichwortabfrage', '--stichwortabfrage', dest='stichwortabfrage', type=str, default=None,
                        help='Zusätzliche Einschränkung der Lemmata/Stichworte (z.B. „*pferd*“, „*heili*, *heils*“).')
    parser.add_argument('-o', '--ohne', dest='ohne', type=str, default=None,
                        help='Ausschlußfilter – ohne diese Stichwörter oder sprachkundlichen Worteinträge (z.B. Nennwörter mittels --ohne "das *licht").')
    parser.add_argument('-e', '--eineinzig', action='store_true',
                        help='Ergebnisliste vereinzigen, so daß jedes Stichwort nur einmal vorkommt.')
    parser.add_argument('-H', '--HTML', '--html', action='store_true',
                        help='HTML-Datei erzeugen.')
    parser.add_argument('-O', '--ODT', '--odt', action='store_true',
                        help='ODT-Datei (für LibreOffice) erzeugen (benötigt pandoc).')
    parser.add_argument('-T', '--Telegrammarkdown', '--telegrammarkdown', action='store_true',
                        help='MD-Datei (für Text in Markdown bei Telegram) erzeugen.')
    parser.add_argument('-z', '--wortfunde-auslesen', '--wortfunde-zusammenfassen', '--nachlese-erstellen', '--nachlese',
                        dest='wortfunde_auslesen', action='store_true',
                        help='Zusammenfassend alle Wortfunde nachlesen, der im Volltext gefundenen Wortformen und in ein gesondertes Markdown-Dokument schreiben (<gesuchte-wort-abfrage>-utf8 Volltext nur Wortfunde zusammengefaßt.md) erstellen.')
    parser.add_argument('--Einzeltabelle', '--Liste_Einzelabschnitte', dest='einzeltabelle', action='store_true',
                        help='Die Wörtertabelle allein in eine gesonderte Datei speichern.')
    parser.add_argument('-b', '--behalte_Dateien', '--behalte_dateien', action='store_true',
                        help='Behalte auch temporäre Zwischendateien, die normalerweise gelöscht werden.')
    parser.add_argument('-s', '--stillschweigend', action='store_true',
                        help='Kaum Meldungen ausgeben.')
    parser.add_argument('--entwickeln', '--debug', action='store_true',
                        help='Befehlsmeldungen und Debug-Informationen ausgeben.')
    parser.add_argument('--farb-frei', '--farbfrei', action='store_true',
                        help='Meldungen ohne Farben ausgeben.')

    # Suchpuffer-Wahlmöglichkeiten (SQLite-Caching)
    parser.add_argument('--ohne-suchpuffer', '--kein-suchpuffer', '--ohne-puffer', dest='ohne_suchpuffer', action='store_true',
                        help='Beständige SQLite-Zwischenspeicherung für diesen Suchlauf außer acht lassen.')
    parser.add_argument('--suchpuffer-leeren', '--puffer-leeren', dest='suchpuffer_leeren', action='store_true',
                        help='Gesamten SQLite-Suchpuffer leeren und Speicherplatz freigeben.')
    parser.add_argument('--suchpuffer-info', '--suchpuffer-erlaeutern', '--suchpuffer-erläutern', '--puffer-info', dest='suchpuffer_info', action='store_true',
                        help='Verdichtete Übersicht zur Nutzung, Speichergröße und Trefferhäufigkeiten des Suchpuffers ausgeben.')
    parser.add_argument('--suchpuffer-pfad', dest='suchpuffer_pfad', type=str, default=None,
                        help='Benutzerdefinierten Pfad für die SQLite-Pufferdatei angeben.')

    # Zeitgleichsuche-Wahlmöglichkeiten (Parallelisierung)
    parser.add_argument('--ohne-zeitgleich-suche', '--ohne-zeitgleichsuche', '--keine-zeitgleichsuche', '--einzelabruf', '--nacheinander',
                        dest='ohne_zeitgleich_suche', action='store_true',
                        help='Zeitgleiches Nachladen von Fundstellen (4-fach suchend) abschalten und rein nacheinander abfragen.')

    return parser, parser.parse_args()


def main():
    parser, args = erteile_befehlszeilen_anweisungen()
    farben = Farben(aktiv=not args.farb_frei)

    # Vorzeitige Suchpuffer-Aktionen abhandeln (ohne Pflicht-Suchbegriff)
    if args.suchpuffer_leeren:
        suchpuffer = SuchpufferDWB1(db_pfad=args.suchpuffer_pfad, aktiv=True)
        erfolg = suchpuffer.leere_puffer()
        if erfolg:
            print(f"{farben.GRUEN}Der Suchpuffer ({suchpuffer.db_pfad}) wurde erfolgreich geleert.{farben.RESET}")
        else:
            print(f"{farben.ROT}Fehler beim Leeren des Suchpuffers ({suchpuffer.db_pfad}).{farben.RESET}", file=sys.stderr)
        suchpuffer.schliessen()
        sys.exit(0)

    if args.suchpuffer_info:
        suchpuffer = SuchpufferDWB1(db_pfad=args.suchpuffer_pfad, aktiv=True)
        info = suchpuffer.ermittle_info()
        print(f"\n{farben.GELB}=== Übersicht & Auskunft zum DWB1-Suchpuffer ==={farben.RESET}")
        print(f"  Bestand der Datenbank:  {'Vorhanden' if info['existiert'] else 'Noch nicht angelegt'}")
        print(f"  Speicherort (SQLite):   {info['db_pfad']}")
        print(f"  Belegter Speicherplatz: {info['dateigroesse_mb']:.2f} MB ({info['dateigroesse_bytes']:,} Bytes) / größtens {info.get('max_groesse_mb', 100)} MB".replace(',', '.'))
        print(f"  Gespeicherte Einträge:  {info['anzahl_eintraege']:,} / höchstens {info.get('max_eintraege', 10000):,} Einträge".replace(',', '.'))
        print(f"  Längste Vorratsdauer:   {info.get('max_alter_tage', 180)} Tage (Selbstleerung kürzlich kaum genutzter Einträge)")
        # LRU-Prinzip (Least Recently Used)
        print(f"  Abfrage-Zählungen:")
        print(f"    - Puffer-Treffer:     {info['treffer_gesamt']:,}".replace(',', '.'))
        print(f"    - Neuabrufe (Fehl.):  {info['fehlschlaege_gesamt']:,}".replace(',', '.'))
        print(f"    - Gesamtanfragen:     {info['anfragen_gesamt']:,}".replace(',', '.'))
        print(f"    - Wiederfunde:        {farben.GRUEN}{info['trefferquote']:.1f} %{farben.RESET}")
        if info.get('aeltester_eintrag'):
            print(f"  Ältester Eintrag:       {info['aeltester_eintrag']}")
        if info.get('neuester_eintrag'):
            print(f"  Letzter Zugriff:        {info['neuester_eintrag']}")
        print()
        suchpuffer.schliessen()
        sys.exit(0)

    if args.Hilfe or not args.volltextabfrage:
        hilfe_text = f"""Nutzung:
  ./Volltextabfrage_DWB1.py [-h] [-s] [-H] [-O] [-S "…"] -V "stupere"

Ein Wort aus der Programm-Schnitt-Stelle (PSS, engl. API) des Grimm-Wörterbuchs
DWB abfragen und daraus Listen-Textdokumente erstellen. Im Normalfall werden erzeugt:
- Textdatei reine Wortliste (ohne Zusätzliches)
- Textdatei mit Sprachkunde-Einträgen
Zusätzlich kann man eine HTML oder ODT Datei erstellen lassen (benötigt Programme pandoc / tidy).

Verwendbare Wahlmöglichkeiten:
-h,    --Hilfe             Hilfetext dieses Programms ausgeben.
-v,-V  --Volltextabfrage   Pflichtfeld für die Abfrage, die getätigt werden soll, z.B. „hinun*“ oder „*glaub*“ u.ä.
                           Mehrere Suchwörter zugleich sind möglich: „sensibus, sensibilis, sensificus“
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
"""
        print(hilfe_text)
        if not args.volltextabfrage and not args.Hilfe:
            print(f"{farben.ROT}Fehlender Volltext, der abgefragt werden soll (Abbruch).{farben.RESET}", file=sys.stderr)
            sys.exit(1)
        sys.exit(0)

    suchpuffer = SuchpufferDWB1(db_pfad=args.suchpuffer_pfad, aktiv=not args.ohne_suchpuffer)

    volltext_roh = args.volltextabfrage.strip()
    volltext_begriffe = [b.strip() for b in re.split(r'[,;]+', volltext_roh) if b.strip()]
    if not volltext_begriffe:
        print(f"{farben.ROT}Fehlender Volltext, der abgefragt werden soll (Abbruch).{farben.RESET}", file=sys.stderr)
        sys.exit(1)

    if all(re.match(r'^[*?]+$', b) for b in volltext_begriffe):
        print(f"{farben.ORANGE}Alle Volltexte abzufragen (--Volltextabfrage '{volltext_roh}') wird nicht unterstützt (Abbruch){farben.RESET}", file=sys.stderr)
        sys.exit(1)

    volltext_begriffe = [b for b in volltext_begriffe if not re.match(r'^[*?]+$', b)]

    # Dateivorsilben-Text
    def saeubere_dateiname_begriff(b):
        t = re.sub(r'[^\w\s]', '…', b)
        t = re.sub(r'^…{2,}', '', t)
        t = re.sub(r'…{2,}$', '…', t)
        return t or "Volltext"

    if len(volltext_begriffe) == 1:
        volltext_text = saeubere_dateiname_begriff(volltext_begriffe[0])
    elif len(volltext_begriffe) == 2:
        volltext_text = f"{saeubere_dateiname_begriff(volltext_begriffe[0])}, {saeubere_dateiname_begriff(volltext_begriffe[1])}"
    else:
        erster_begriff = saeubere_dateiname_begriff(volltext_begriffe[0])
        volltext_text = f"{erster_begriff} u.a. ({len(volltext_begriffe)} Begriffe)"

    stichwort_text, stichwort_regex, stichwort_regex_xml = erstelle_stichwort_filter(args.stichwortabfrage)
    stichwort_filter_re = re.compile(stichwort_regex, re.IGNORECASE) if stichwort_regex else None

    ohne_text, ohne_regex, ohne_regex_xml = erstelle_ohne_filter(args.ohne)
    ohne_filter_re = re.compile(ohne_regex, re.IGNORECASE) if ohne_regex else None

    datum_heute_lang = ermittle_altes_monatsdatum()
    if len(volltext_begriffe) == 1:
        titel_text = f"Volltextsuche „{volltext_begriffe[0]}“ aus Grimm-Wörterbuch"
    else:
        begriffe_titel = ", ".join(f"„{b}“" for b in volltext_begriffe)
        titel_text = f"Volltextsuche {begriffe_titel} aus Grimm-Wörterbuch"
    untertitel_text = datum_heute_lang

    heute_str = datetime.datetime.now().strftime('%Y%m%d')

    # Dateinamen definieren
    if stichwort_text:
        stichwort_datei_name = re.sub(r'[^\w\s,]', '…', stichwort_text)
        stichwort_datei_name = re.sub(r'^…{2,}', '', stichwort_datei_name)
        stichwort_datei_name = re.sub(r'…+$', '…', stichwort_datei_name)
        if ohne_text:
            datei_vorfuegung = f"{volltext_text} und ohne Wörter im Volltext, mit Stichwort „{stichwort_datei_name}“, DWB1 {heute_str}"
        else:
            datei_vorfuegung = f"{volltext_text} im Volltext, mit Stichwort „{stichwort_datei_name}“, DWB1 {heute_str}"
    else:
        if ohne_text:
            datei_vorfuegung = f"{volltext_text} und ohne Wörter Volltext-Abfrage, DWB1 {heute_str}"
        else:
            datei_vorfuegung = f"{volltext_text} Volltext-Abfrage, DWB1 {heute_str}"

    json_speicher_datei = f"{datei_vorfuegung}.json"
    json_speicher_all_query_datei = f"{datei_vorfuegung}.allquery.json"
    json_speicher_datei_ueberarbeitet = f"{datei_vorfuegung}-ordentlich überarbeitet.json"

    datei_utf8_reiner_text = f"{datei_vorfuegung}-utf8 nur Wörter.txt"
    datei_utf8_reiner_text_gram = f"{datei_vorfuegung}-utf8 nur Wörter mit Sprachkunde.txt"
    datei_utf8_wortfunde_zusammengefaszt = f"{datei_vorfuegung}-utf8 Volltext nur Wortfunde zusammengefaßt.md"

    datei_utf8_html_zwischenablage_gram = f"{datei_vorfuegung}-utf8 Zwischenablage Wortliste mit Sprachkunde.html"
    datei_utf8_html_gram_tidy = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde_tidy.html"
    datei_utf8_html_gram_tidy_log = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde_tidy.html.log"
    datei_utf8_html_gram_tidy_markdown_telegram = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde_tidy (Telegram).md"
    datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte = f"{datei_vorfuegung}-utf8 Wortliste mit Sprachkunde_tidy Einzelabschnitte.md"
    datei_utf8_odt_gram = f"{datei_vorfuegung} Wortliste mit Sprachkunde.odt"
    datei_diese_wbnetzkwiclink = f"{datei_utf8_html_zwischenablage_gram}.wbnetzkwiclink.txt"

    if not args.stillschweigend and args.entwickeln:
        print(f"{farben.ORANGE}ENTWICKLUNG - volltextabfrage:             {volltext_roh}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - volltext_begriffe:           {volltext_begriffe}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - stichwortabfrage:            {args.stichwortabfrage}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - stichwort_regex:             {stichwort_regex}{farben.RESET}", file=sys.stderr)
        print(f"{farben.ORANGE}ENTWICKLUNG - ohne_regex:                  {ohne_regex}{farben.RESET}", file=sys.stderr)

    # 1. API-Abfragen: Volltext & All-Query (für alle Volltext-Begriffe)
    kombinierte_rohe_treffer = []
    gesehene_treffer_keys = set()
    kombinierte_allquery_daten = []
    gesamte_fulltext_daten = {'result_set': [], 'begriffe': volltext_begriffe}

    for begriff in volltext_begriffe:
        volltext_quoted = urllib.parse.quote(begriff)
        url_fulltext = f"https://api.woerterbuchnetz.de/open-api/dictionaries/DWB/fulltext/{volltext_quoted}"
        all_query_param = urllib.parse.quote(begriff.replace(' ', ';all='))
        url_allquery = f"https://api.woerterbuchnetz.de/dictionaries/DWB/query/all={all_query_param}"

        if not args.stillschweigend:
            print(f"{farben.GRUEN}Abfrage an api.woerterbuchnetz.de …{farben.RESET} ({url_fulltext})", file=sys.stderr)
            print(f"{farben.GRUEN}Abfrage an api.woerterbuchnetz.de …{farben.RESET} ({url_allquery})", file=sys.stderr)

        try:
            fulltext_daten = hole_datenschnittstelle_json(url_fulltext)
        except Exception as e:
            print(f"{farben.ROT}Fehler Datenfehler mit der Schnittstellen-Abfrage ({url_fulltext}): {e}{farben.RESET}", file=sys.stderr)
            if len(volltext_begriffe) == 1:
                sys.exit(1)
            else:
                fulltext_daten = {'result_set': []}

        try:
            allquery_daten = hole_datenschnittstelle_json(url_allquery)
        except Exception as e:
            if args.entwickeln:
                print(f"{farben.ORANGE}Hinweis: Gesamt-Abfrage ({url_allquery}) lieferte Fehler ({e}), Weiterverarbeitung unter Notfall-Umständen.{farben.RESET}", file=sys.stderr)
            allquery_daten = []

        if isinstance(allquery_daten, list):
            kombinierte_allquery_daten.extend(allquery_daten)

        for item in fulltext_daten.get('result_set', []):
            wbnetzid = item.get('wbnetzid', '')
            textid = str(item.get('textid', ''))
            treffer_key = (wbnetzid, textid)
            if treffer_key not in gesehene_treffer_keys:
                gesehene_treffer_keys.add(treffer_key)
                kombinierte_rohe_treffer.append(item)

    gesamte_fulltext_daten['result_set'] = kombinierte_rohe_treffer

    with open(json_speicher_datei, 'w', encoding='utf-8') as f:
        json.dump(gesamte_fulltext_daten, f, ensure_ascii=False, indent=2)

    with open(json_speicher_all_query_datei, 'w', encoding='utf-8') as f:
        json.dump(kombinierte_allquery_daten, f, ensure_ascii=False, indent=2)

    rohe_treffer = kombinierte_rohe_treffer
    n_suchergebnisse_volltext = len(rohe_treffer)

    if not args.stillschweigend:
        print(f"{farben.GRUEN}Weiterverarbeitung → JSON{farben.RESET} ({n_suchergebnisse_volltext} Volltext-Treffer)", file=sys.stderr)

    kwic_map = baue_kwic_felder_zuordnung(kombinierte_allquery_daten)

    # 2. Filterpipeline & Strukturierung
    verarbeitete_liste = []
    gesehene_eineinzig = set()

    for item in rohe_treffer:
        lemma = item.get('lemma', '')
        gram = item.get('gram', '')
        wbnetzid = item.get('wbnetzid', '')
        textid = str(item.get('textid', ''))
        match = item.get('match', '')
        wbnetzlink = item.get('wbnetzlink', '')
        wbnetzkwiclink = item.get('wbnetzkwiclink', '')

        # Fallback / Verknüpfung KWIC-Link
        kwic_link_konstruiert = kwic_map.get((wbnetzid, textid)) or kwic_map.get(textid)
        if not kwic_link_konstruiert:
            kwic_link_konstruiert = f"https://api.woerterbuchnetz.de/dictionaries/DWB/kwic/{wbnetzid}/textid/{textid}/wordid/1" if wbnetzid and textid else wbnetzkwiclink

        label_grosz = begin_grosz(lemma)
        gram_hauptgruppe = grammatik_in_hauptgruppen(gram, label_grosz)

        wort_grosz = bereite_wort_auf(lemma, capitalize=True)
        wort_klein = bereite_wort_auf(lemma, capitalize=False)

        wort_deutung = grammatik_dem_wort_anhaengen(gram, wort_klein, wort_grosz)
        geschlwort_vorm_wort = wort_deutung['geschlechtswort_vorm_wort']
        lemma_dekodiert = html_sonderzeichen_als_einzelzeichen(lemma)

        # 2a. Filter: Stichwortabfrage (Inklusion)
        if stichwort_filter_re:
            treffer_stichwort = (
                stichwort_filter_re.search(lemma) or
                stichwort_filter_re.search(lemma_dekodiert) or
                stichwort_filter_re.search(wort_klein) or
                stichwort_filter_re.search(wort_grosz) or
                stichwort_filter_re.search(geschlwort_vorm_wort)
            )
            if not treffer_stichwort:
                continue

        # 2b. Filter: Ohne-Filter (Exklusion)
        if ohne_filter_re:
            treffer_ohne = (
                ohne_filter_re.search(lemma) or
                ohne_filter_re.search(lemma_dekodiert) or
                ohne_filter_re.search(geschlwort_vorm_wort) or
                ohne_filter_re.search(wort_klein) or
                ohne_filter_re.search(wort_grosz)
            )
            if treffer_ohne:
                continue

        # 2c. Filter: Eineinzig (Deduplizierung)
        if args.eineinzig:
            schluessel_eineinzig = (wort_klein, gram)
            if schluessel_eineinzig in gesehene_eineinzig:
                continue
            gesehene_eineinzig.add(schluessel_eineinzig)

        wort_sortier_umlaut = html_sonderzeichen_umlaute_ausgeschrieben(lemma)

        verarbeitete_liste.append({
            'lemma': lemma,
            'gram': gram,
            'wbnetzid': wbnetzid,
            'textid': textid,
            'match': match,
            'wbnetzlink': wbnetzlink,
            'wbnetzkwiclink': kwic_link_konstruiert,
            'gramHautgruppen': gram_hauptgruppe,
            'Wort': wort_grosz,
            'wort': wort_klein,
            'Wortdeutung_mit_Grammatik': wort_deutung,
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

    n_gefilterte_treffer = len(verarbeitete_liste)

    if not args.stillschweigend:
        if stichwort_text or ohne_text or args.eineinzig:
            print(f"{farben.GRUEN}Gefilterte Treffermenge:{farben.RESET} {n_gefilterte_treffer} aus {n_suchergebnisse_volltext} Volltext-Treffern", file=sys.stderr)

    # 3. KWIC-Fundstellen nachladen (NUR für gefilterte Treffer!)
    kwic_fundstellen = {}
    muss_kwic_laden = args.HTML or args.ODT or args.Telegrammarkdown or args.einzeltabelle or args.wortfunde_auslesen

    if muss_kwic_laden and n_gefilterte_treffer > 0:
        zeitgleich_aktiv = not args.ohne_zeitgleich_suche
        max_arbeiter = 4 if zeitgleich_aktiv else 1

        if not args.stillschweigend:
            puffer_status_str = f" [Suchpuffer: {farben.GRUEN}aktiv{farben.RESET}]" if suchpuffer.aktiv else f" [Suchpuffer: {farben.ORANGE}deaktiviert{farben.RESET}]"
            modus_str = f" [Zeitgleichsuche: {farben.GRUEN}4 läufig{farben.RESET}]" if zeitgleich_aktiv else f" [Zeitgleichsuche: {farben.ORANGE}nacheinander (1 Tätigkeit){farben.RESET}]"
            print(f"{farben.GRUEN}Weiterverarbeitung → Fundstellen nachladen (wbnetzkwiclink: {farben.ORANGE}{n_gefilterte_treffer} Fundstellen{farben.GRUEN} abfragen){farben.RESET}{puffer_status_str}{modus_str}", file=sys.stderr)

        puffer_treffer_zaehler = 0
        api_abruf_zaehler = 0

        # Eindeutige Fundstellen-Aufgaben ermitteln
        eindeutige_aufgaben = []
        gesehene_paare = set()
        for item in verarbeitete_liste:
            paar = (item['wbnetzkwiclink'], item['textid'])
            if paar not in gesehene_paare:
                gesehene_paare.add(paar)
                eindeutige_aufgaben.append(paar)

        with open(datei_diese_wbnetzkwiclink, 'w', encoding='utf-8') as f_kwic_links:
            for item in verarbeitete_liste:
                f_kwic_links.write(f"{item['wbnetzkwiclink']}\n")

        def lade_einzelstelle(paar):
            kwic_url, textid = paar
            text, aus_puffer = lade_kwic_fundstelle(kwic_url, textid=textid, suchpuffer=suchpuffer)
            return kwic_url, textid, text, aus_puffer

        anzahl_aufgaben = len(eindeutige_aufgaben)
        if max_arbeiter > 1 and anzahl_aufgaben > 1:
            with ThreadPoolExecutor(max_workers=max_arbeiter) as executor:
                zukunfts_objekte = [executor.submit(lade_einzelstelle, paar) for paar in eindeutige_aufgaben]
                for idx, zukunft in enumerate(as_completed(zukunfts_objekte), 1):
                    kwic_url, textid, text, aus_puffer = zukunft.result()
                    kwic_fundstellen[(kwic_url, textid)] = text
                    if aus_puffer:
                        puffer_treffer_zaehler += 1
                    else:
                        api_abruf_zaehler += 1

                    if not args.stillschweigend:
                        if idx % 100 == 0:
                            sys.stderr.write(f". {idx:04d}\n")
                            sys.stderr.flush()
                        else:
                            sys.stderr.write("." if idx < anzahl_aufgaben else ".\n")
                            sys.stderr.flush()
        else:
            for idx, paar in enumerate(eindeutige_aufgaben, 1):
                kwic_url, textid, text, aus_puffer = lade_einzelstelle(paar)
                kwic_fundstellen[(kwic_url, textid)] = text
                if aus_puffer:
                    puffer_treffer_zaehler += 1
                else:
                    api_abruf_zaehler += 1

                if not args.stillschweigend:
                    if idx % 100 == 0:
                        sys.stderr.write(f". {idx:04d}\n")
                        sys.stderr.flush()
                    else:
                        sys.stderr.write("." if idx < anzahl_aufgaben else ".\n")
                        sys.stderr.flush()

        if not args.stillschweigend:
            modus_text = f"zeitgleich mit bis zu {max_arbeiter} Arbeitsläufen" if zeitgleich_aktiv else "nacheinander"
            if suchpuffer.aktiv:
                print(f"{farben.GRUEN}Fundstellen-Verarbeitung ({modus_text}):{farben.RESET} {puffer_treffer_zaehler} aus Suchpuffer bezogen, {api_abruf_zaehler} neu von API nachgeladen.", file=sys.stderr)
            else:
                print(f"{farben.GRUEN}Fundstellen-Verarbeitung ({modus_text}):{farben.RESET} {api_abruf_zaehler} erneut von Datenschnittstelle (API) nachgeladen.", file=sys.stderr)

    # 4. Text Hinweise
    einschraenkung_stichwort = ""
    if stichwort_text:
        stichwort_begriffe = [b.strip() for b in re.split(r'[,;]+', stichwort_text) if b.strip()]
        if len(stichwort_begriffe) > 1:
            einschraenkung_stichwort = f", beschränkt auf die Stichwörtersuche „{stichwort_text}“"
        else:
            einschraenkung_stichwort = f", beschränkt auf Stichwortsuche „{stichwort_text}“"

    if len(volltext_begriffe) == 1:
        volltext_hinweis_text = f"für die Volltextabfrage „{volltext_begriffe[0]}“"
        html_abfrage_bezeichnung = "Volltextabfrage nach"
        html_volltext_suchausdruck = f"<i>{volltext_begriffe[0]}</i>"
    else:
        begriffe_aufzaehlung = ", ".join(f"„{b}“" for b in volltext_begriffe)
        volltext_hinweis_text = f"für die Volltextabfragen {begriffe_aufzaehlung}"
        html_abfrage_bezeichnung = "Volltextabfragen nach"
        html_volltext_suchausdruck = ", ".join(f"<i>{b}</i>" for b in volltext_begriffe)

    if n_gefilterte_treffer == 1:
        funde_satz_text = f"Im Grimm-Wb. fand sich 1 Beitrag oder Beleg {volltext_hinweis_text}{einschraenkung_stichwort}."
        funde_satz_html = "Im Grimm-Wb. fand sich 1 Beitrag oder Beleg."
    else:
        funde_satz_text = f"Im Grimm-Wb. fanden sich {n_gefilterte_treffer} Beiträge oder Belege {volltext_hinweis_text}{einschraenkung_stichwort}."
        funde_satz_html = f"Im Grimm-Wb. fanden sich {n_gefilterte_treffer} Beiträge oder Belege."

    zusatzbemerkungen_text = (
        f"{funde_satz_text} "
        f"Die nachfolgende Liste ist dabei vorgeordnet nach den sprachkundlichen Angaben von Grimm, "
        f"d.h. nach Wortarten gruppiert: ohne sprachkundliche (Grammatik-)Angabe, "
        f"Eigenschaften (Adjektive) und dergleichen, Nennwörter (Substantive), Zeit- oder Tuwörter usw.."
    )
    if ohne_text:
        zusatzbemerkungen_text += f"\n\nIn der Liste wurden folgende Wortverbindungen bewußt entfernt, also ohne\n„{ohne_text}“."

    # 4a. Reine Wörter
    reine_woerter_zeilen = []
    gesehene_reine_woerter = set()
    for item in verarbeitete_liste:
        geschl = item['Wortdeutung_mit_Grammatik']['geschlechtswort_vorm_wort']
        if geschl not in gesehene_reine_woerter:
            gesehene_reine_woerter.add(geschl)
            if not item['gram']:
                reine_woerter_zeilen.append(f"{item['wort']};")
            else:
                reine_woerter_zeilen.append(f"{geschl};")

    with open(datei_utf8_reiner_text, 'w', encoding='utf-8') as f:
        f.write(f"{titel_text} ({untertitel_text})\n\n{zusatzbemerkungen_text}\n\n")
        f.write("\n".join(reine_woerter_zeilen) + "\n")

    # 4b. Wörter mit Grammatik
    if not args.stillschweigend:
        print(f"{farben.GRUEN}Weiterverarbeitung → Text{farben.RESET} ({datei_utf8_reiner_text_gram})", file=sys.stderr)

    gram_woerter_zeilen = []
    gesehene_gram_zeilen = set()
    for item in verarbeitete_liste:
        geschl = item['Wortdeutung_mit_Grammatik']['geschlechtswort_vorm_wort']
        gram = item['gram']
        zeile = f"{geschl} ({gram});" if gram else f"{geschl};"
        if zeile not in gesehene_gram_zeilen:
            gesehene_gram_zeilen.add(zeile)
            gram_woerter_zeilen.append(zeile)

    with open(datei_utf8_reiner_text_gram, 'w', encoding='utf-8') as f:
        f.write(f"{titel_text} ({untertitel_text})\n\n{zusatzbemerkungen_text}\n\n")
        f.write("\n".join(gram_woerter_zeilen) + "\n")

    # 4c. Nachlesende Wortfunde-Zusammenfassung (Markdown)
    if args.wortfunde_auslesen:
        if not args.stillschweigend:
            print(f"{farben.GRUEN}Weiterverarbeitung → Wortfunde-Zusammenfassung{farben.RESET} ({datei_utf8_wortfunde_zusammengefaszt})", file=sys.stderr)

        wortfunde_gruppen = {}
        for item in verarbeitete_liste:
            wert_textid = str(item.get('textid', ''))
            kwic_url = item.get('wbnetzkwiclink', '')
            kwic_text = kwic_fundstellen.get((kwic_url, wert_textid), "")
            match_str = urspruengliches_echtes_fundwort_auslesen(kwic_text, notfall_ersatz=item.get('match', '').strip() or volltext_roh)
            lemma_roh = item.get('lemma', '')
            lemma_str = html_sonderzeichen_als_einzelzeichen(lemma_roh)
            wert_lemid = item.get('wbnetzid', '')
            wb_verknuepfung = item.get('wbnetzlink') or (
                f"https://woerterbuchnetz.de/?sigle=DWB&lemid={wert_lemid}&textid={wert_textid}" if wert_lemid and wert_textid else
                f"https://woerterbuchnetz.de/?sigle=DWB&lemma={urllib.parse.quote(lemma_roh)}#{wert_textid}" if lemma_roh and wert_textid else
                f"https://woerterbuchnetz.de/?sigle=DWB&lemma={urllib.parse.quote(lemma_roh)}"
            )

            if match_str not in wortfunde_gruppen:
                wortfunde_gruppen[match_str] = []
            wortfunde_gruppen[match_str].append({
                'lemma': lemma_str,
                'wb_verknuepfung': wb_verknuepfung,
                'wert_lemid': wert_lemid,
                'wert_textid': wert_textid
            })

        sortierte_matches = sorted(
            wortfunde_gruppen.keys(),
            key=lambda m: html_sonderzeichen_umlaute_ausgeschrieben(m).lower()
        )

        zeilen_b = []
        zeilen_c = []

        for match_str in sortierte_matches:
            eintraege = wortfunde_gruppen[match_str]
            eintraege_sortiert = sorted(
                eintraege,
                key=lambda e: html_sonderzeichen_umlaute_ausgeschrieben(e['lemma']).lower()
            )

            # Gestaltung B: Gruppierte Stichpunktliste nach Volltextfunden
            if len(eintraege_sortiert) == 1:
                e = eintraege_sortiert[0]
                zeilen_b.append(f"\n*{match_str}* in [*{e['lemma']}*]({e['wb_verknuepfung']})")
            else:
                zeilen_b.append(f"\n*{match_str}* ({len(eintraege_sortiert)} Fundstellen)")
                for e in eintraege_sortiert:
                    zeilen_b.append(f"- in [*{e['lemma']}*]({e['wb_verknuepfung']})")

            # Gestaltung C: Schlichte Markdown-Tabelle
            for e in eintraege_sortiert:
                zeilen_c.append(f"| {match_str} | {e['lemma']} | <{e['wb_verknuepfung']}> |")

        inhalt_b = "\n".join(zeilen_b) if zeilen_b else "*(Keine Wortfunde ermittelt)*"
        inhalt_c = "\n".join(zeilen_c) if zeilen_c else "| *(keine)* | *(keine)* | *(keine)* |"

        with open(datei_utf8_wortfunde_zusammengefaszt, 'w', encoding='utf-8') as f:
            f.write(
                f"# {titel_text} ({untertitel_text})\n\n"
                f"## Wortfunde in Stichwörtern/Lemmata\n"
                f"{inhalt_b}\n\n"
                f"## Wortfunde als Tabelle\n\n"
                f"| Volltextfund       | im Stichwort (Lemma) | Fundstelle im Wörterbuchnetz                            |\n"
                f"|:-------------------| :--- |:--------------------------------------------------------|\n"
                f"{inhalt_c}\n"
            )

    # 5. HTML-, ODT-, Markdown-Exporte
    if args.HTML or args.ODT or args.Telegrammarkdown or args.einzeltabelle:
        if not args.stillschweigend:
            print(f"{farben.GRUEN}Weiterverarbeitung → HTML{farben.RESET} ({datei_utf8_html_zwischenablage_gram})", file=sys.stderr)

        zusatz_html_teile = []
        if stichwort_text:
            stichwort_begriffe = [b.strip() for b in re.split(r'[,;]+', stichwort_text) if b.strip()]
            if len(stichwort_begriffe) > 1:
                zusatz_html_teile.append(f"beschränkt auf die Stichwörtersuche „{stichwort_text}“")
            else:
                zusatz_html_teile.append(f"beschränkt auf Stichwortsuche „{stichwort_text}“")
        if ohne_text:
            zusatz_html_teile.append(f"ohne „{ohne_text}“")
        zusatz_hinweis_html = f" ({', '.join(zusatz_html_teile)})" if zusatz_html_teile else ""

        bearbeitungstext_html = f"{html_abfrage_bezeichnung} {html_volltext_suchausdruck} im Deutschen Wörterbuch von Jacob und Wilhelm Grimm{zusatz_hinweis_html}."

        html_zeilen = []
        for item in verarbeitete_liste:
            wort_geschlecht = item['Wortdeutung_mit_Grammatik']['wort_mit_geschlechtswort']
            gram_deutung = item['Wortdeutung_mit_Grammatik']['grammatik_deutung']
            wert_lemid = item['wbnetzid']
            lab = item['lemma']
            wert_textid = item['textid']
            kwic_url = item['wbnetzkwiclink']
            wb_verknuepfung = item['wbnetzlink'] or f"https://woerterbuchnetz.de/?sigle=DWB&lemid={wert_lemid}&textid={wert_textid}"

            fundstelle_html = kwic_fundstellen.get((kwic_url, wert_textid), "")
            spalte_fundstelle = f"<td>{fundstelle_html}</td>"

            verknuepfung_lemma = f'<a href="https://woerterbuchnetz.de/DWB?lemid={wert_lemid}">{html_sonderzeichen_als_einzelzeichen(lab)}</a>'
            verknuepfung_textbeleg = f'<a href="{wb_verknuepfung}">{wert_lemid}/{wert_textid}</a>'
            html_verknuepfung = f"<small>{verknuepfung_lemma} (im Text: {verknuepfung_textbeleg})</small>"

            zeile_html = f"<tr><td>{wort_geschlecht}</td>{spalte_fundstelle}<td>{gram_deutung}</td><td>{html_verknuepfung}</td></tr>"
            html_zeilen.append(zeile_html)

        abkuerzungs_hinweis = ""
        abkuerzungen_anhang = ""

        abk_pfade = [
            Path("Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html"),
            Path("DWB1/Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html"),
            Path(__file__).resolve().parent / "Abkürzungen-GRIMM-Tabelle-DWB1-und-DWB2.html",
        ]
        abk_datei = next((p for p in abk_pfade if p.is_file()), None)
        if abk_datei:
            abkuerzungs_hinweis = '<p>Siehe auch das <a class="local" href="#sec-GRIMM_Abkuerzungen">Abkürzungsverzeichnis</a>.</p>\n'
            try:
                abkuerzungen_anhang = abk_datei.read_text(encoding='utf-8')
            except Exception:
                abkuerzungen_anhang = ""

        html_technischer_hinweis = '<p>Für die Techniker: Die Abfrage wurde mit <a href="https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/tree/main/DWB1#volltext-abfragen"><code>Volltextabfrage_DWB1.py</code> (siehe GitHub)</a> durchgeführt.</p>\n'

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

b.gefunden-hervorheben {{ background-color: #ffffaa; font-weight: bold; }}
a.local {{ text-decoration:none; }}
</style>
<body style="font-family: Antykwa Torunska, serif; background: white;"><p>{bearbeitungstext_html}</p>
<p>{funde_satz_html} Diese Tabelle ist nach sprachkundlichen Begriffen <i>Grammatik (Grimm)</i> geordnet, also finden sich Tätigkeitswörter (Verben) beisammen, Eigenschaftswörter (Adjektive) beisammen, Nennwörter (Substantive), als auch Wörter ohne Angabe der Grammatik/Sprachkunst-Begriffe usw..</p>{abkuerzungs_hinweis}<p>Zur Sprachkunst oder Grammatik siehe vor allem <i style="font-variant:small-caps;">Schottel (1663)</i> das ist Justus Georg Schottels Riesenwerk über „<i>Ausführliche Arbeit Von der Teutschen HaubtSprache …</i>“; Bücher 1-2: <a href="https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346534-1</a>; Bücher 3-5: <a href="https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6">https://mdz-nbn-resolving.de/urn:nbn:de:bvb:12-bsb11346535-6</a></p><table id="Wortliste-Tabelle"><thead><tr><th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Wortbeitrag</th><th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Textauszug (gekürzt)</th><th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Grammatik (<i>Grimm</i>) ~ Sprachkunst, Sprachlehre (s. a. <i style="font-variant:small-caps;">Schottel&nbsp;1663</i>)</th><th style="vertical-align:bottom;border-top:2px solid gray;border-bottom:2px solid gray;">Verknüpfungen</th></tr></thead><tbody>
{chr(10).join(html_zeilen)}
</tbody><tfoot><tr><td colspan="4" style="border-top:2px solid gray;border-bottom:0 none;"></td>
</tr></tfoot></table>{html_technischer_hinweis}
{abkuerzungen_anhang}
</body>
</html>
"""

        with open(datei_utf8_html_zwischenablage_gram, 'w', encoding='utf-8') as f:
            f.write(html_dokument)

        # tidy Bereinigung
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

        # 5a. ODT Export
        if args.ODT:
            pandoc_cmd = shutil.which("pandoc")
            if not pandoc_cmd:
                print(f"{farben.ORANGE}pandoc nicht gefunden; ODT-Erstellung übersprungen.{farben.RESET}", file=sys.stderr)
            else:
                if not args.stillschweigend:
                    print(f"{farben.GRUEN}Weiterverarbeitung: HTML → ODT{farben.RESET} ({datei_utf8_odt_gram})", file=sys.stderr)

                odt_vorlage_pfade = [
                    Path("pandoc_Vorlage_DWB1_Wörterliste.odt"),
                    Path("DWB1/pandoc_Vorlage_DWB1_Wörterliste.odt"),
                    Path(__file__).resolve().parent / "pandoc_Vorlage_DWB1_Wörterliste.odt",
                    Path.home() / ".pandoc" / "reference.odt",
                ]
                odt_vorlage = next((p for p in odt_vorlage_pfade if p.is_file()), None)

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

        # 5b. Einzelabschnitte (Markdown)
        if args.einzeltabelle:
            if not args.stillschweigend:
                print(f"{farben.GRUEN}Weiterverarbeitung: Einzelabschnitte{farben.RESET} ({datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte})", file=sys.stderr)

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

        # 5c. Telegram Markdown
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

    # 6. Aufräumen temporärer Zwischendateien
    if not args.behalte_Dateien:
        kurzweilige_dateien = [
            json_speicher_datei,
            json_speicher_all_query_datei,
            json_speicher_datei_ueberarbeitet,
            datei_utf8_html_zwischenablage_gram,
            datei_utf8_html_gram_tidy if not args.HTML else None,
            datei_utf8_html_gram_tidy_log,
            datei_diese_wbnetzkwiclink,
        ]

        for f_pfad in kurzweilige_dateien:
            if f_pfad and os.path.exists(f_pfad):
                try:
                    os.remove(f_pfad)
                except OSError:
                    pass

    if not args.stillschweigend:
        print(f"{farben.ORANGE}Abschluß: Folgende Dateien sind erstellt worden:{farben.RESET}", file=sys.stderr)
        erzeugte_dateien = [
            datei_utf8_reiner_text,
            datei_utf8_reiner_text_gram,
            datei_utf8_wortfunde_zusammengefaszt if args.wortfunde_auslesen else None,
            datei_utf8_html_gram_tidy if (args.HTML or args.ODT or args.Telegrammarkdown or args.einzeltabelle) else None,
            datei_utf8_odt_gram if args.ODT else None,
            datei_utf8_html_gram_tidy_markdown_telegram if args.Telegrammarkdown else None,
            datei_utf8_html_gram_tidy_worttabelle_odt_einzelabschnitte if args.einzeltabelle else None,
        ]
        for f_name in erzeugte_dateien:
            if f_name and os.path.exists(f_name):
                print(f"  - {f_name}", file=sys.stderr)

    suchpuffer.schliessen()


if __name__ == '__main__':
    main()
