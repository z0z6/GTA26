# Uciekaj przed windykatorem

Gra w stylu GTA2 na prawdziwym układzie miasta (Maków Mazowiecki, dane z OpenStreetMap).
Uciekasz przed windykatorami, zbierasz monety i omijasz absurdy samorządowe. Silnik: Godot 4.4 (GDScript, renderer Compatibility).

## Stan prac

- [x] Krok 1: świat z siatki kafli, chunki podłoża, gracz z kolizjami, kamera, testy w CI
- [ ] Krok 2: budynki jako bloki z perspektywą (shader)
- [ ] Krok 3: wierzyciele, monety, dług, HUD
- [ ] Krok 4: noc, strefy gagów, joystick dotykowy
- [ ] Krok 5: eksport na Androida (GitHub Actions)

## Uruchomienie

1. Otwórz projekt w Godot 4.4.x (Import → wybierz `project.godot`) i naciśnij F5.
2. Sterowanie: strzałki lub WASD, Shift to sprint, przeciągnięcie myszą/palcem też porusza postacią.

## Testy (bez okna, tak jak w CI)

```
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . -- --autotest
```

## Dane mapy

`data/makow_grid.png` to siatka 1074×1001 kafli (ok. 4 m na kafel). Kanały: R = klasa kafla ×16,
G = liczba kondygnacji budynku ×16, B = indeks koloru dachu ×16 (opis klas w `scripts/world.gd`).
Skrypty w `tools/` pokazują, jak powstała (scalanie zrzutów, klasyfikacja kolorów); zrzutów źródłowych nie ma w repo.

## Licencje i atrybucja

Układ ulic, budynków i terenów: © autorzy OpenStreetMap, licencja ODbL (https://www.openstreetmap.org/copyright).
Atrybucja jest widoczna w grze. Postacie i nazwy w grze są zmyślone.
