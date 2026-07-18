# Agent Workflow

Workflow d'orchestration des agents pour les projets d'automatisme CODESYS.

## Responsabilité

- préparer le contexte de tâche ;
- orienter les modèles ;
- lancer les contrôles déterministes ;
- coordonner la synchronisation DOC/CODE ;
- appeler les outils externes, notamment `ST_PLCOPENXML_GENERATOR` et Herdr.

## Hors périmètre

Le générateur ST → PLCopenXML reste un outil autonome :

```text
TOOLS/ST_PLCOPENXML_GENERATOR/
```

Il ne doit pas être copié dans `AGENT_WORKFLOW/scripts/`.
