import urllib.request
from bs4 import BeautifulSoup


def extrahiere_paare_aus_container(container):
    """Extrahiert alle Begriff-Erklärungs-Paare aus allen <tr>/<td>-Elementen eines Bereichs."""
    eintraege = []
    if not container:
        return eintraege

    for zeile in container.find_all('tr'):
        zellen = zeile.find_all('td')
        if len(zellen) == 2:
            abk = zellen[0].get_text(strip=True)
            erlaeuterung = zellen[1].get_text(strip=True)
            # Nur Zeilen mit tatsächlichem Inhalt aufnehmen
            if abk or erlaeuterung:
                eintraege.append((abk, erlaeuterung))
    return eintraege


def generiere_mediawiki_dl(titel, eintraege, spalten=4):
    """Erzeugt saubere MediaWiki-Definitionslisten-Syntax im Mehrspaltenlayout."""
    mw_zeilen = [f"; {abk} : {erl}" for abk, erl in eintraege]
    inhalt = "\n".join(mw_zeilen)
    return (
        f"== {titel} ==\n"
        f'<div style="column-count: {spalten}; column-gap: 30px;">\n'
        f"{inhalt}\n"
        f"</div>\n"
    )


def generiere_html_dl_abschnitt(titel, eintraege):
    """Erzeugt semantisch valides HTML5 mit <dl>, <dt> und <dd>."""
    dt_dd_zeilen = [
        f"          <p><i>{abk}</i> ~ {erl}</p>"
        for abk, erl in eintraege
    ]
    inhalt = "\n".join(dt_dd_zeilen)
    return (
        f"    <section>\n"
        f"        <h2>{titel}</h2>\n"
        f'        <div style="column-count: 5; column-gap: 30px; font-size: 14px;">\n'
        f"{inhalt}\n"
        f"        </div>\n"
        f"    </section>\n"
    )


def wandle_dwb_tabellen():
    url = "https://github.com/infinite-dao/werkzeuge-woerterbuchnetz-und-andere/raw/refs/heads/main/DWB1/Abk%C3%BCrzungen-GRIMM-Tabelle-DWB1-und-DWB2.html"
    print(f"Lade Daten herunter von: {url}...")

    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            html_inhalte = response.read().decode('utf-8')
    except Exception as e:
        print(f"Fehler beim Herunterladen: {e}")
        return

    print("Verarbeite HTML-Struktur...")
    soup = BeautifulSoup(html_inhalte, 'html.parser')

    # Überschriften lokalisieren
    h1_elemente = soup.find_all('h1')

    # 1. DWB1: Alle Tabellenzeilen bis zur zweiten <h1>-Überschrift einsammeln
    eintraege_dwb1 = []
    if len(h1_elemente) >= 1:
        aktueller_knoten = h1_elemente[0].next_sibling
        dwb2_start = h1_elemente[1] if len(h1_elemente) > 1 else None

        while aktueller_knoten and aktueller_knoten != dwb2_start:
            if hasattr(aktueller_knoten, 'find_all'):
                # Alle Zeilen innerhalb gefundener Tabellen des DWB1-Abschnitts verarbeiten
                if aktueller_knoten.name == 'table':
                    eintraege_dwb1.extend(extrahiere_paare_aus_container(aktueller_knoten))
                else:
                    for tab in aktueller_knoten.find_all('table'):
                        eintraege_dwb1.extend(extrahiere_paare_aus_container(tab))
            aktueller_knoten = aktueller_knoten.next_sibling

    # 2. DWB2: Gezielt die letzte Tabelle im Dokument wählen (die vollständige Liste im column-count div)
    alle_tabellen = soup.find_all('table')
    tabelle_dwb2 = alle_tabellen[-1] if len(alle_tabellen) >= 2 else None
    eintraege_dwb2 = extrahiere_paare_aus_container(tabelle_dwb2)

    print(f"Ergebnis: DWB1 = {len(eintraege_dwb1)} Einträge, DWB2 = {len(eintraege_dwb2)} Einträge")

    if not eintraege_dwb1 and not eintraege_dwb2:
        print("Keine Tabelleneinträge gefunden.")
        return

    # --- Datei 1: MediaWiki-Export ---
    mw_dwb1 = generiere_mediawiki_dl("Abkürzungen (DWB1)", eintraege_dwb1)
    mw_dwb2 = generiere_mediawiki_dl("Abkürzungen (Grimm-Nacharbeitung DWB2)", eintraege_dwb2)
    mediawiki_gesamt = mw_dwb1 + "\n" + mw_dwb2

    with open("dwb_abkuerzungen_mediawiki.txt", "w", encoding="utf-8") as f:
        f.write(mediawiki_gesamt)

    # --- Datei 2: HTML5-Export mit druck- und layout-optimiertem CSS ---
    html_dwb1 = generiere_html_dl_abschnitt("Abkürzungen (DWB1)", eintraege_dwb1)
    html_dwb2 = generiere_html_dl_abschnitt("Abkürzungen (Grimm-Nacharbeitung DWB2)", eintraege_dwb2)

    html_gesamt = (
        "<!DOCTYPE html>\n<html lang=\"de\">\n<head>\n"
        "    <meta charset=\"UTF-8\">\n"
        "    <title>DWB1 & DWB2 Abkürzungen - Definitionslisten</title>\n"
        "    <style>\n"
        "        body { font-family: sans-serif; margin: 24px; line-height: 1.4; }\n"
        "        h2 { border-bottom: 2px solid #ccc; padding-bottom: 6px; margin-top: 32px; }\n"
        "        dl { margin: 0; padding: 0; }\n"
        "        dt { font-weight: bold; margin-top: 6px; color: #222; break-after: avoid; }\n"
        "        dd { margin-left: 12px; margin-bottom: 6px; color: #444; }\n"
        "    </style>\n</head>\n<body>\n"
        f"{html_dwb1}\n{html_dwb2}"
        "</body>\n</html>"
    )

    with open("dwb_abkuerzungen_definitionsliste.html", "w", encoding="utf-8") as f:
        f.write(html_gesamt)

    print("\nErfolgreich abgeschlossen:")
    print("✓ MediaWiki-Definitionsliste: dwb_abkuerzungen_mediawiki.txt")
    print("✓ HTML-Definitionsliste:      dwb_abkuerzungen_definitionsliste.html")


if __name__ == '__main__':
    wandle_dwb_tabellen()