# Porównanie sesji — 20261114-200122 → 20261120-235625

| | A: `20261114-200122` (1.3.1) | B: `20261120-235625` (1.3.3) |
|---|---|---|
| Przebiegi | 10 | 10 |
| Persona mówi: cel osiągnięty | 1 | 5 |
| Stan końcowy potwierdza (met) | 2/10 | 1/10 |
| Persona się myli (overclaimed) | 0 | 1 |
| Rezygnacja | 8 | 5 |
| Limit kroków | 1 | 0 |
| Średnio kroków | 17.8 | 16.7 |
| Przebiegi skażone (stanowisko) | 3 | 1 |

## Persony

Każdy przebieg: wynik persony / werdykt ze stanu końcowego (kroki); ⚠ = incydent stanowiska.

| Persona | A | B |
|---|---|---|
| `daniel-sourdough` | give_up/partly (25) ⚠, give_up/partly (25) ⚠ | done/partly (26), done/not_met (22) |
| `halina-zeszyt` | give_up/partly (23), give_up/partly (22) | done/partly (18), give_up/not_met (12) ⚠ |
| `kuba-60-sekund` | limit/met (10), give_up/met (10) | done/met (9), give_up/not_met (7) |
| `marta-lodowka` | done/partly (16), give_up/partly (16) | give_up/partly (16), give_up/partly (16) |
| `sophie-gift-book` | give_up/not_met (11), give_up/partly (20) ⚠ | give_up/partly (20), done/partly (21) |

## Znaleziska

**Były w A, nie ma w B** (10)

- F-010 Nowo zapisany przepis Bez książki jest niewidoczny po zapisie — B: `not_reproduced`
- F-024 Chipy minutnika przy pierwszym renderze: czas znika, kreska przecina inne słowa — B: `not_reproduced`
- F-025 Przełącznik Do wypróbowania schowany na dnie formularza, brak w menu przepisu — B: `not_reproduced`
- F-009 Aplikacja przestaje odpowiadać (ANR) po zapisaniu przepisu — B: `not_reproduced`
- F-021 Pole Qty nie pokazuje fokusu — B: `not_exercised`
- F-014 Ikona aparatu bez podpisu w formularzu nowej książki — B: `not_reproduced`
- F-008 Ostrzeżenie o duplikacie na liście zakupów — B: `not_reproduced`
- F-028 Podgląd przepisu przed zapisem — B: `not_reproduced`
- F-031 Podsumowanie po imporcie — B: `not_reproduced`
- F-033 Łatwiejszy odbiorca / Kopiuj listę — B: `not_reproduced`

**Nowe w B** (16)

- F-036 Stan „do wypróbowania” nieczytelny w formularzu i w widoku przepisu
- F-037 Chipy minutnika rozbijają zdania (osierocona kropka lub nawias)
- F-038 Import otwiera się na „Z linku”, gdy użytkownik ma tekst
- F-005 Dodawanie wielu produktów naraz: Paste a whole list niezauważone
- F-004 W widoku książki nie ma pola wyszukiwania
- F-039 Główny przycisk „+” bez podpisu
- F-040 Formularz przepisu: dużo pól naraz przy słabym wzroku
- F-041 Placeholder pokazuje nagłówek „#”, a użytkownik pisze „##”
- F-042 Sekcja lub plakietka „Do wypróbowania” na ekranie głównym
- F-043 Widoczny znak, że ekran nie gaśnie
- F-044 Przy wklejaniu listy pytanie: dodać do tej listy czy założyć nową
- F-017 Nazwa książki widoczna w widoku przepisu
- F-023 Podgląd PDF książki przed wysłaniem
- F-045 Podpowiedź, że import (tekst, zdjęcie, AI) zastąpi ręczne przepisywanie
- F-046 Przycisk A+ także w formularzu przepisu
- F-047 Usuwanie wiodących myślników przy imporcie

**W obu** (16)

- F-011 Przypisanie do książki: pole w formularzu niezauważone, przeniesienie tylko przez ··· → Edytuj
- F-001 Pole Składniki zasłonięte przy wpisywaniu nowego przepisu (duża czcionka)
- F-013 Klawiatura otwiera się sama w Wszystkie przepisy
- F-020 Droga do zakładki Zakupy z wyszukiwania lub przepisu wymaga kilku cofnięć
- F-019 Autokapitalizacja zmienia pierwsze litery linii w składnikach
- F-026 Przykładowa książka Śniadania zaskakuje na świeżej instalacji
- F-006 Co ugotuję z tego, co mam — ranking według brakujących składników
- F-007 Brakujące składniki na listę zakupów jednym przyciskiem
- F-016 Przycisk Wklej ze schowka w polu URL
- F-022 Skalowanie przepisu z przeliczeniem gramów (poza zakresem, SPEC §7)
- F-027 Dodaj zapisane przepisy z widoku książki
- F-029 Wyjaśnienie lub wyłączenie chipów minutnika
- F-030 Większy maksymalny rozmiar tekstu
- F-032 Wysyłanie listy tylko z nowymi pozycjami
- F-034 PDF łatwy do znalezienia z wnętrza książki
- F-035 Zachować wpisany tekst przy zamknięciu aplikacji

„Nie ma w B” znaczy tylko, że B tego nie zgłosiła. Czy ścieżka w ogóle była sprawdzana, mówi wpis znaleziska w sesji B (`not_reproduced` kontra `not_exercised`) i rejestr.
