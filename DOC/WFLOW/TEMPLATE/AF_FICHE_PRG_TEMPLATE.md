# Fiche PRG — `PRG_XX` (vX.Y)

> 🎯 Complément d'AF‑02 : détail codable d'un seul POU. AF‑02 reste propriétaire de la `MainTask`,
> de l'ordre inter‑PRG et des diagrammes globaux.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| [producteurs et GVL] | [bus publics / sorties] | [hors responsabilité] |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | 🎯 But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. [phase] | [objectif] | 🟢 courant / 🟡 N‑1 justifié | [GVL, bus, image E/S] | [résultat] |

## 🛡️ Invariants

- [Règle de sécurité ou d'intégration non négociable.]

## 🧪 Table des points de validation

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 28px;">
    <col style="width: 50px;">
    <col style="width: calc(100% - 165px);">
    <col style="width: 45px;">
    <col style="width: 26px;">
    <col style="width: 36px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Intention</small></th>
      <th style="padding: 4px 8px;">Séquence & Déroulé des étapes (Comportement attendu)</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-…</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>[intention]</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">[comportement attendu, lossless]</td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§N</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

## 📚 Documents liés

- AF‑02 : architecture et ordonnancement global.
- AF‑03 : contrats FB/DUT.
- [AF métier propriétaire].
