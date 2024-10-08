#  https://www.typografie.info/3/faq.htm/wie-setzt-man-das-lange-s-im-klassischen-fraktursatz-r12/
#     1. Das runde s steht am Ende unverbunden gesprochener, sinntragender Einheiten (Wörter, Teilwörter, Vorsilben, vor Nachsilben). In allen anderen Fällen steht das lange s.
# 
#     Beispiele:
# 
#     Langes s am Anfang sinntragender Einheiten:
#       ſein, ſtark, ſpielen, ſchlau, ſkurril, ſlawiſch, ſzeniſch, Bauſchutt, Anſicht, Trübſal, Mannſchaft;
#     und innerhalb sinntragender Einheiten:
#       brauſen, kreiſt, Knoſpe, Raſter, fiſchen, Blaſe.
#     Rundes s am Ende von Wörtern:
#       Glas, es, bis, Saus und Braus
#     Rundes s am Ende von Teilwörtern u. Ä. (inkl. Fugen‑s):
#       Haustür, Glasſammlung, Hilfsbereitſchaft, Rechtsweg, deshalb, Dienstag, Phosphor (von altgr. φωσ-φόϱος)
#     Rundes s am Ende von Vorsilben:
#       Ausdauer, Disput, Transport
#     Rundes s vor Nachsilben:
#       häuslich, Mäuschen, Bistum, Weisheit, boshaft
#     Langes s am Ende verbunden gesprochener Vorsilben:
#       aſſimilieren, Diſſertation, Tranſit (von lateinisch: trans + ire);
#     und vor verbunden gesprochenen Nachsilben:
#       glaſig, Raſerei, Weiſung
#     Anmerkung: Beugungsendungen werden nicht als Nachsilben aufgefasst bzw. durch verbundene Sprechung abgedeckt:
#       kreiſt, graſte, verglaſten
# 
#     Ausnahmen
# 
#     Auch innerhalb sinntragender Einheiten kann unter gewissen Bedingungen das runde s stehen:
# 
#     2. Das runde s steht an Stelle des langen s, wenn Folgendes zutrifft:
# 
#     Es steht im Silbenauslaut.
#     Der folgende Buchstabe ist nicht p, t oder z.
#     Es ist nicht Teil eines Digraphen, Trigraphen, usw., wie ſſ, ſch oder ſh (aus dem Englischen).
#     Es ist nicht erst durch Auslassung eines tonlosen e an den Silbenauslaut gelangt.
#     Beispiele:
# 
#     Rundes s im Silbenauslaut:
#     Maske, brüsk, Feudalismus, Dresden, Osnabrück, lesbiſch, Gleisner, Kosmos, Oslo, Ischias, Esquire, Esra
#     Langes s im Silbenauslaut vor p, t oder z:
#     kreiſt, Knoſpe, Raſter, Diſziplin
#     Langes s im Silbenauslaut als Teil eines Di- oder Trigraphen:
#     Buſch, Waſſer, aſſimilieren, Diſſertation, Squaſh
#     Langes s im Silbenauslaut durch Auslassung:
#     unſre (von unſere), Drechſler (von Drechſeler), Pilſner (von Pilſener)
#     Dabei wird in Namen polnischer Herkunft wie Jablonski das s als zur letzten Silbe gehörig angesehen und daher Jablonſki geschrieben.
# 
#     Weitere Ausnahmen
# 
#     Die Schreibung einer sehr kleinen Anzahl von Wörtern stand im Widerspruch zu den obigen Regeln:
# 
#     Iſrael, Iſlam, Moſlem, Aſbeſt (von altgr. ἄ-σβεστος)
# 
#     In den meisten Fällen sind die Empfehlungen der Wörterbücher bezüglich dieser Wörter uneinheitlich, sogar innerhalb eines Buches. So empfiehlt Koenigs Großes Wörterbuch der Deutschen Sprache von 1922 Moslem, aber moſleminiſch.
# 

s@(\w)ss(\w)@\1ſſ\2@g;
s@\bs(\w)@ſ\1@g;
s@(\w)s(\w)@\1ſ\2@g;
