(* ═══════════════════════════════════════════════════════════════
   🧊 FB_AntiFlickerText — Lissage anti-clignotement d'un texte IHM
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md §5.3
   🎯 Responsabilité : maintient un texte warning/état un temps minimum
      avant de laisser le contenu changer, et laisse passer en direct
      (sans maintien) les messages critiques (défauts AU/puissance).
   🛡️ Sécurité : l'action de sécurité reste instantanée — ce FB ne
      retarde jamais un texte, il ne fait que stabiliser l'affichage.
      Il n'a aucun effet sur la machine.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_AntiFlickerText
VAR_INPUT
    NewText      : STRING(120);  (* --> [CMD] Texte candidat à afficher *)
    ForceInstant : BOOL;         (* --> [CMD] TRUE = afficher immédiatement (défaut critique), sans maintien *)
    HoldTime     : TIME := T#500ms; (* --> [CFG] Durée de maintien min avant changement (AF-07 §5.3) *)
END_VAR
VAR_OUTPUT
    Text         : STRING(120);  (* <-- [STAT] Texte stabilisé exposé à l'IHM *)
END_VAR
VAR
    TonHold      : TON;   (* . [LOC] Temporisation de maintien *)
END_VAR

{region "§1 Lissage anti-clignotement"}
// Défaut critique : affichage immédiat, le TON est remis à zéro (aucune latence).
IF ForceInstant THEN
    Text := NewText;
    TonHold(IN := FALSE);
ELSE
    // Warning / état : le texte ne change qu'après maintien min (HoldTime).
    // Un signal qui oscille plus vite que HoldTime → texte stable.
    TonHold(IN := (NewText <> Text), PT := HoldTime);
    IF TonHold.Q THEN
        Text := NewText;
    END_IF;
END_IF;
{endregion}
