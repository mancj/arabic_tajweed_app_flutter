# Варианты иллюстрации махраджа — 27 сентября 2026

Три самостоятельных изображения для выбора визуального стиля. Это дизайн-концепты общей сцены, а не утверждённые учебные схемы конкретной буквы. Положение органов и обозначение махраджа для каждой буквы будут уточняться на следующем этапе.

## Контекст

Перед работой прочитан CLAUDE.md. Светлая тема просмотрена в работающем симуляторе: главная, «Мой путь», «Буквы и их формы», тема «Первые буквы». Палитра сверена с lib/app/resources/ui_colors.dart: фон #ECECEC, карточка #F7F7F7, текст #0C233E, акцент #EE7740. Пользовательский референс использован как ориентир сюжета: рот в боковом разрезе и выделение места артикуляции. Исходная картинка не перекрашивалась.

## Финальные варианты

1. [Контурная схема](01-contour.png) — сине-серые линии, мягкие заливки, хорошо различимые границы.
2. [Мягкая цветная иллюстрация](02-soft-color.png) — крупные пастельные формы, минимум обводок.
3. [Матовый рельеф](03-matte-relief.png) — гладкие объёмные формы и мягкие тени, без фактуры живых тканей.

Для продолжения рекомендуется первый вариант: он ближе к графике приложения и сохраняет ясность на небольшом экране. Третий подходит, если хочется заметнее подчеркнуть объём.

Изображения созданы встроенным image_gen. Варианты 1 и 2 — новые генерации. Финальный вариант 3 — переработка варианта 1 с сохранением композиции. Первый слишком реалистичный черновик варианта 3 исключён. Код приложения и учебные материалы не изменялись.

## Точные промпты

### Вариант 1

```text
Use case: scientific-educational.
Asset type: original illustration style exploration for a light-themed Arabic pronunciation learning app, NOT a finished letter-specific teaching diagram.
Primary request: create ONE beautifully art-directed square 1024x1024 illustration of a simplified sagittal cross-section of the human mouth, facing LEFT. Frame from the lower half of the nose to the chin and upper throat, not the entire head. Show clearly separated upper hard palate and rear soft palate, small natural ivory upper and lower incisors in side view, a broad softly curved tongue rooted at the lower right and tapering to a raised tip at the upper left. Tongue tip approaches the ridge immediately behind the upper incisors. Leave a clear white oral air space between tongue and palate. Show a small warm-orange highlight exactly at that local point of near contact, with one restrained thin circular ring. Keep enough lower mouth and right-side throat visible to understand the geometry. The external nose/lips/chin profile should be one clean understandable silhouette. Teeth are small and rounded, never sharp fangs. Anatomy is simplified but coherent; no arbitrary floating tissue, no extra tongue, no rows of front-view teeth.
Visual context observed in the real app: pale grey page #ECECEC, almost-white rounded cards #F7F7F7, dark ink-navy typography #0C233E, warm orange accent #EE7740, very restrained shadows and spacious calm layout. Match this quiet modern visual character; don't mechanically color every organ in brand colors. Choose gentle warm neutral, peach, muted rose, and desaturated blue-grey supporting tones. The orange active contact spot must be the strongest color.
Composition: same eye-level orthographic side-view diagram, centered, fills about 78% of square, generous clear margins, uniform near-white #F7F7F7 background, no surrounding card frame, no device mockup, no UI. No letter, no caption, no numbering, no labels, no text, no leader lines, no arrows, no decorative ornaments. Designed to read crisply at 300 pixels wide. Avoid medical gore, vessels, muscle hatching, harsh black thick outlines, saturated yellow, bright red, photorealism. This is a new original drawing, not a recolored textbook image.
Style/medium: DIRECTION 1 — precise minimal contour illustration. Flat vector-like rendering with exceptionally clean, smooth, medium-fine dark desaturated navy outlines (about 3 px at 1024), rounded stroke joins. Mostly white and very pale blue-grey anatomy with a faint dusty-peach tongue fill. No shadows, no gradients, no texture, no volume. Clear large negative spaces and deliberate line hierarchy. Main silhouette in muted navy; secondary anatomical boundaries slightly lighter. Elegant editorial educational line art that feels native beside the app's crisp typography. Contact marker is small and warm orange, not glowing.
```

### Вариант 2

```text
Use case: scientific-educational.
Asset type: original illustration style exploration for a light-themed Arabic pronunciation learning app, NOT a finished letter-specific teaching diagram.
Primary request: create ONE beautifully art-directed square 1024x1024 illustration of a simplified sagittal cross-section of the human mouth, facing LEFT. Frame from the lower half of the nose to the chin and upper throat, not the entire head. Show clearly separated upper hard palate and rear soft palate, small natural ivory upper and lower incisors in side view, a broad softly curved tongue rooted at the lower right and tapering to a raised tip at the upper left. Tongue tip approaches the ridge immediately behind the upper incisors. Leave a clear white oral air space between tongue and palate. Show a small warm-orange highlight exactly at that local point of near contact, with one restrained thin circular ring. Keep enough lower mouth and right-side throat visible to understand the geometry. The external nose/lips/chin profile should be one clean understandable silhouette. Teeth are small and rounded, never sharp fangs. Anatomy is simplified but coherent; no arbitrary floating tissue, no extra tongue, no rows of front-view teeth.
Visual context observed in the real app: pale grey page #ECECEC, almost-white rounded cards #F7F7F7, dark ink-navy typography #0C233E, warm orange accent #EE7740, very restrained shadows and spacious calm layout. Match this quiet modern visual character; don't mechanically color every organ in brand colors. Choose gentle warm neutral, peach, muted rose, and desaturated blue-grey supporting tones. The orange active contact spot must be the strongest color.
Composition: same eye-level orthographic side-view diagram, centered, fills about 78% of square, generous clear margins, uniform near-white #F7F7F7 background, no surrounding card frame, no device mockup, no UI. No letter, no caption, no numbering, no labels, no text, no leader lines, no arrows, no decorative ornaments. Designed to read crisply at 300 pixels wide. Avoid medical gore, vessels, muscle hatching, harsh black thick outlines, saturated yellow, bright red, photorealism. This is a new original drawing, not a recolored textbook image.
Style/medium: DIRECTION 2 — soft flat editorial illustration. Broad organic interlocking matte color shapes, almost no outlines, only short refined muted blue-grey lines wherever needed to clarify teeth and the mouth cavity. Exterior profile and gums in very pale warm greige, upper palate in muted dusty sand, tongue in gentle muted rose-peach, oral and throat cavities near white. Smooth vector-like surfaces and clear silhouettes. No texture, no gradients, no 3D, no shadows. The palette is harmonious and quiet, with tonal separation between adjoining forms. Friendly but adult and refined, neither cartoon nor clinical textbook. Small warm orange contact patch and a delicate circle at the tongue tip.
```

### Вариант 3 — финальная переработка варианта 1

Референс: 01-contour.png.

```text
Use case: style-transfer. Edit target: the supplied contour mouth diagram. Make the THIRD art-direction variant for a modern light-theme mobile learning app.
Keep the existing left-facing mouth geometry, tongue pose, location of upper and lower incisors, point of articulation immediately behind upper incisors, and framing. Remove ALL dark contour lines and convert the flat diagram into a beautifully crafted shallow layered bas-relief made entirely from SMOOTH SOLID MATTE COLORED RESIN, like premium tactile educational design objects.
Crucial material constraints: completely smooth untextured homogeneous surfaces. This is a MANUFACTURED stylized teaching model, NOT biological tissue. Zero pores, zero tongue grain, zero bone cross-section honeycomb, zero muscle striations, zero veins, zero photographic skin. No anatomical atlas realism. Solid warm ivory external profile, pale blue-grey upper palate/soft palate, muted peach tongue, small warm white teeth. Soft bevels only 3–5mm deep, very gentle contact shadows between layers and wide soft studio lighting. Clean continuous rounded silhouette boundaries. No black outlines. No gloss, no metal, no translucent flesh.
The hollow mouth air space stays near white. One small orange #EE7740 contact dot with a thin orange ring stays at the tongue tip. No glowing effects. Background uniform near-white #F7F7F7. Elegant, quiet, minimal, sophisticated mobile-app illustration readable at 300px; ample negative space. Entire image is one diagram, no text, no labels, no numbers, no UI, no border. Aim for a dimensional vector illustration, absolutely not a detailed medical render.
```

