#!/usr/bin/env tsx
// scripts/lint-one-file.ts
// Version avec rapport I/O réel (mock, basé sur :=)

import * as fs from "fs";
import * as path from "path";

type Args = {
  file: string;
  verbose: boolean;
  stats: boolean;
  vars: boolean;
  ifs: boolean;
  io: boolean;
  json: boolean;
};

function parseArgs(argv: string[]): Args {
  const args = argv.slice(2);
  const file = args.find(a => !a.startsWith("-"));

  if (!file) {
    console.error("Usage: lint-one-file.ts <file.st> [options]");
    console.error("Options: --verbose --stats --vars --ifs --io --json");
    process.exit(1);
  }

  const has = (flag: string) => args.includes(flag);

  return {
    file,
    verbose: has("--verbose") || has("-v"),
    stats: has("--stats"),
    vars: has("--vars"),
    ifs: has("--ifs"),
    io: has("--io"),
    json: has("--json"),
  };
}

function logVerbose(...data: unknown[]) {
  if (args.verbose) console.error("[verbose]", ...data);
}

function logInfo(...data: unknown[]) {
  console.error("[info]", ...data);
}

const KEYWORDS = new Set([
  "IF","THEN","ELSE","ELSIF","END_IF",
  "CASE","OF","END_CASE",
  "FOR","TO","BY","DO","END_FOR",
  "WHILE","END_WHILE",
  "REPEAT","UNTIL","END_REPEAT",
  "EXIT","RETURN",
  "PROGRAM","END_PROGRAM",
  "FUNCTION","END_FUNCTION",
  "FUNCTION_BLOCK","END_FUNCTION_BLOCK",
  "CONFIGURATION","END_CONFIGURATION",
  "RESOURCE","END_RESOURCE",
  "TASK","VAR","END_VAR",
  "VAR_INPUT","VAR_OUTPUT","VAR_IN_OUT",
  "VAR_EXTERNAL","VAR_GLOBAL","VAR_TEMP",
  "VAR_CONSTANT","VAR_RETAIN","VAR_NON_RETAIN",
  "CONSTANT","RETAIN","NON_RETAIN",
  "AT","ARRAY","OF","STRUCT","END_STRUCT",
  "TYPE","END_TYPE",
  "INTERFACE","END_INTERFACE",
  "METHOD","END_METHOD",
  "PROPERTY","END_PROPERTY",
  "GET","END_GET","SET","END_SET",
  "EXTENDS","IMPLEMENTS",
  "ABSTRACT","FINAL","OVERRIDE",
  "BOOL","BYTE","WORD","DWORD","LWORD",
  "SINT","INT","DINT","LINT",
  "USINT","UINT","UDINT","ULINT",
  "REAL","LREAL",
  "STRING","WSTRING",
  "TIME","DATE","DATE_AND_TIME","DT","TOD",
  "LTIME","LDATE","LDT","LTOD",
  "TRUE","FALSE","NULL",
  "NOT","AND","OR","XOR",
  "MOD",
  "END_PROGRAM",
  "Programme","Acquisition","Conditionnement","par","la","t","che",
  "DOC","Produire","les","images","acqu","rir","traiter","mesures",
  "codeurs","joystick","publier","retours","AUCUNE","PILOT","VIA",
  "producteur","Data","Mesures","positions","diag","publi","s",
  "IMAGES","PROCESS","MATERIEL","SIMULATION","Image","brute","reelle",
  "physique","simulee","banc","utilisee","metier","arbitree","SOUS",
  "INSTANCES","instSimBench","Banc","de","simulation","integr",
  "instJoystick","Traitement","filtrage","instDiagCanOpen","Diagnostic",
  "reseau","rang","consomme","instDiagEthercat","EtherCAT","variateur",
  "instEncoderM1","Facade","codeur","complet","Homing","Scale","Safety",
  "instEncoderM2","instPosDecoderM3","Decodage","translation",
  "VARIABLES","LOCALES","TECTEURS","Front","demande","reference",
  "benne","ouverte","fermee","Demande","etalonnage","active","Cible",
  "metrique","Frontiere","hardware","in","out","Source","Winch",
  "Translation","Pupitre","Machine","Memoire","precedent","source",
  "Indicateur","initialisation","montant","activation","descendant",
  "desactivation","CONSTANT","CONSTANTES","CANIQUES","bits","single",
  "tour","multi","tours","max","metres","cable","tambour","region",
  "Session","aiguillage","LECTION","DE","Producteur","domaine","vs",
  "SimBypassActive","NetworkBypassActive","Network","Bypass","Global",
  "DeviceVariateurStateRaw","DeviceVariateurSimBypass",
  "DeviceEncoderM1StateRaw","DeviceEncoderM1SimBypass",
  "DeviceEncoderM2StateRaw","DeviceEncoderM2SimBypass","Simulation",
  "AIGUILLAGE","mod","ne","doit","progresser","QUE","quand","vraie",
  "commande","ellement","sortie","FB_Translation","post","interlock",
  "sur","sinon","il","outrepasse","but","limites","me","principe",
  "que","treuils","aliment","Gate","direction","vitesse","elle","rampe",
  "arr","SEL","LIMIT","GVL_PERSISTENT","uniquement","l","tat","tape",
  "curise","transfert","m","si","inter","ArmPulse","observ","e","avec",
  "un","retard","dans","EmergencyArming_RQ","EmergencyArmingCmd","OR",
  "ArmingSeqStep","BtnEmergencyStop","Modes","Cmd","BtnEmergencyCutOff",
  "RawPosM1","RawPosM2","Exposition","image","produite","G","IN0","IN1",
  "brique","standard","IEC","retourne","composer","existant","impl",
  "mentation","remplace","compact","qui","cassaient","g","n","ST","LD",
  "CODE_QUALITY_STANDARDS","Utilisation","explicite","variables",
  "lection","TRAITEMENT","JOYSTICK","E","vue","importe","o","C","blage",
  "TEMPORAIRE","analyser","plus","tard","hors","scope","LOT_JOYSTICK_ARMINGPERMIT",
  "armement","autoris","attendant","future","cha","permission","syst",
  "BusCanOpenOP","DeviceCanOpenMaster","JoystickOP","DeviceJoystick",
  "RawX","RawY","RawButton","BtnCalibrate","JOY1Joystick","DeadbandRaw",
  "_JoystickDeadbandRaw","NeutralHoldTime","DeadmanArmHoldTime",
  "DeadmanArmGraceTime","RawOutOfRangeMargin","NeutralXMem","_JoystickNeutralX",
  "NeutralYMem","_JoystickNeutralY","Publication","tats","axes",
  "JoystickDeadmanArmed","DeadmanArmed","JoystickYNeutral","DirectionY",
  "JoystickDirectionX","DirectionX","JoystickSpeedPctX","ABS","SpeedXPct",
  "JoystickXNeutral","Codeurs","homing","CODEURS","HOMING","TREUIL",
  "Retenue","complete","Reliability","L","autorisation","calculee","ici",
  "mode","treuil","selectionne","remplie","appel","Hw","passe","entier",
  "RawPosIn","AlarmsIn","WarningsIn","SlaveOperational","DeviceEncoderM1",
  "Operational","HomingPermit","PRG_03_Modes_Cycle","Auth","Mode","E_Mode",
  "MAINT_N1","MAINT_N2","JoystickWinchSelectArbitrated","HomingAtTargetM",
  "M1TreuilRetenue","BtnHome","HomingAtZero","BtnHomingAtZero",
  "ConfirmCoherence","BtnConfirmCoherence","CfgHomingTargetM",
  "_WinchM1CfgPersist","CfgHomingTarget_M","CfgTopSensorPosM",
  "CfgTopSensorPos_M","UseDynamicTarget","DynamicHomingTargetM",
  "TopPositionSensor","PointsPerRev","CableM_PerRev","BypassGlobal",
  "Calib","_CalibM1","CablePosM1","Measurement","CablePosM",
  "M1_EncoderIncoherent","EncoderIncoherent","M1_EncoderFault","EncoderFault",
  "M1_HomedAndReliable","HomedAndReliable","M1_Speed_Mps","Speed_Mps",
  "M1_SignedSpeed_Mps","SignedSpeed_Mps","M1_SpeedValid","SpeedValid",
  "COD1_PresettTrigCmd","COD1_CodeSeqTrigCmd","CodeSeqTriggerCmd",
  "COD1_PresetValue","Benne","Ordre","POO","synchronisation","puis",
  "facade","Synchronisation","f","rencement","ouverture","fermeture",
  "M2TreuilBenne","Bucket","BtnConfirmOpenPos","BtnConfirmClosePos",
  "instWinchM1","Status","Busy","instWinchM2","ELSIF","_BucketCfgPersist",
  "Config","OffsetCloseM","DeviceEncoderM2","_WinchM2CfgPersist","_CalibM2",
  "CablePosM2","M2_EncoderIncoherent","M2_EncoderFault","M2_HomedAndReliable",
  "M2_Speed_Mps","M2_SignedSpeed_Mps","M2_SpeedValid","COD2_PresettTrigCmd",
  "COD2_CodeSeqTrigCmd","COD2_PresetValue","TRANSLATION","SensorTremie",
  "SensorPV","SensorP2","SensorP1","SensorMaintenance","TranslationPosTremie",
  "TranslationPosPV","TranslationPosP2","TranslationPosP1","TranslationPosMaintenance",
  "TranslationAtTremie","TranslationAtPV","TranslationAtP2","TranslationAtP1",
  "TranslationAtMaintenance","M3_LimitSwitchFwd","LimitSwitchFwd",
  "M3_LimitSwitchRev","LimitSwitchRev","M3_SensorWordIncoherent","Incoherent",
  "M3_SensorsWord","jamais","assign","bug","pr","conserv","corriger","lot",
  "di","Retours","conditionn","arbitr","M3_StatusWord_Filtered",
  "WORD_TO_UINT","M3_ActualFrequencyHz_Filtered","END_PROGRAM",
  "et","en","le","la","les","un","une","des","du","de","da","d","t","r","l","n","c","o","i","a","b","m","p","q","s","u","v","z","f","g","h","j","k","w","x","y",
  "est","sont","pour","permettre","fonctionnement","OK","physiques","absentes","simul","es","cartes","globale","machine","module","op","rationnel","Si",
  "clar","pas","encore","consomm","modules","carte","portant","TOR","r","elles","AF06","RUNNING",
  "reseaux","Diagnostics","produits","ICI","car","consommes","PRG_02","avant","consommateur","AF02",
  "FID","LIT","elle","sur","mais","quand","meme","tres","bien","dans","avec","tout","plus","moins","sans","aussi","donc","puis","que","qui","dont","ou","se","ne","on","ce","ci","ca","ceci","cela",
]);

function isLikelyVariableName(token: string): boolean {
  if (!token) return false;
  if (KEYWORDS.has(token)) return false;
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(token)) return false;
  if (token.length === 1) {
    const allowedOneLetter = new Set(["I","O","M","Q","S","T","H","W","X","Y","Z","A","B","C","D","E","F","G","K","L","N","P","R","U","V"]);
    if (!allowedOneLetter.has(token)) {
      return false;
    }
  }
  return true;
}

type BlockInfo = {
  name: string;
  kind: "PROGRAM" | "FUNCTION_BLOCK" | "FUNCTION";
  ifs: number;
  declaredVars: string[];
  usedVars: string[];
  externalVars: string[];
  undeclaredVars: string[];
};

type IoAnalysis = {
  varInput: string[];
  varOutput: string[];
  varInOut: string[];
  varLocal: string[];
  readsFromOutside: string[];
  writesToOutside: string[];
  localsRead: string[];
  localsWritten: string[];
  implicitInputs: string[];
  implicitOutputs: string[];
};

type AnalysisResult = {
  file: string;
  blocks: BlockInfo[];
  totalIfs: number;
  totalDeclaredVars: number;
  totalUsedVars: number;
  totalExternalVars: number;
  totalUndeclaredVars: number;
  io?: IoAnalysis;
};

function extractVariableFromAssignment(line: string, side: "left" | "right"): string[] {
  // Extrait les variables d'une affectation X := Y
  // side = "left" → X, side = "right" → Y
  const match = line.match(/:=/);
  if (!match) return [];

  const parts = line.split(":=");
  if (side === "left" && parts.length >= 2) {
    const left = parts[0];
    // On prend le dernier identifiant avant := (ex: HwReal.Winch.M1_ContactorsReleased_DI)
    const tokens = left.match(/\b([A-Za-z_][A-Za-z0-9_.]*)\b/g);
    if (!tokens) return [];
    const lastToken = tokens[tokens.length - 1];
    const baseVar = lastToken.split(".")[0];
    if (isLikelyVariableName(baseVar)) {
      return [lastToken];
    }
  } else if (side === "right" && parts.length >= 2) {
    const right = parts[1];
    const tokens = right.match(/\b([A-Za-z_][A-Za-z0-9_.]*)\b/g);
    if (!tokens) return [];
    const result: string[] = [];
    for (const t of tokens) {
      const baseVar = t.split(".")[0];
      if (isLikelyVariableName(baseVar)) {
        result.push(t);
      }
    }
    return result;
  }
  return [];
}

function analyzeFileMock(filePath: string, withIo: boolean): AnalysisResult {
  const content = fs.readFileSync(filePath, "utf-8");
  const fileName = path.basename(filePath);

  logVerbose("Reading file:", filePath);
  logVerbose("Content length:", content.length, "chars");

  const lines = content.split(/\r?\n/);

  let ifCount = 0;
  const declaredVars = new Set<string>();
  const usedVars = new Set<string>();

  const varInput = new Set<string>();
  const varOutput = new Set<string>();
  const varInOut = new Set<string>();
  const varLocal = new Set<string>();

  const readsFromOutside = new Set<string>();
  const writesToOutside = new Set<string>();
  const localsRead = new Set<string>();
  const localsWritten = new Set<string>();

  let currentVarSection: "INPUT" | "OUTPUT" | "IN_OUT" | "LOCAL" | null = null;

  for (const rawLine of lines) {
    const line = rawLine.trim();

    // Détection des sections VAR_*
    if (/^VAR_INPUT\b/.test(line)) {
      currentVarSection = "INPUT";
      continue;
    } else if (/^VAR_OUTPUT\b/.test(line)) {
      currentVarSection = "OUTPUT";
      continue;
    } else if (/^VAR_IN_OUT\b/.test(line)) {
      currentVarSection = "IN_OUT";
      continue;
    } else if (/^VAR\b/.test(line) && !/^VAR_(INPUT|OUTPUT|IN_OUT|EXTERNAL|GLOBAL|CONSTANT|RETAIN|NON_RETAIN|TEMP)\b/.test(line)) {
      currentVarSection = "LOCAL";
      continue;
    } else if (/^END_VAR\b/.test(line)) {
      currentVarSection = null;
      continue;
    }

    // Détection des déclarations de variables
    if (currentVarSection && /\b[A-Za-z_][A-Za-z0-9_]*\s*:/.test(line)) {
      const match = line.match(/\b([A-Za-z_][A-Za-z0-9_]*)\s*:/);
      if (match && isLikelyVariableName(match[1])) {
        const varName = match[1];
        declaredVars.add(varName);
        usedVars.add(varName);
        if (currentVarSection === "INPUT") {
          varInput.add(varName);
        } else if (currentVarSection === "OUTPUT") {
          varOutput.add(varName);
        } else if (currentVarSection === "IN_OUT") {
          varInOut.add(varName);
        } else {
          varLocal.add(varName);
        }
      }
    }

    // Compter les IF
    if (/\bIF\b/.test(line)) {
      ifCount++;
    }

    // Extraction de tous les identifiants
    const idMatches = line.match(/\b([A-Za-z_][A-Za-z0-9_]*)\b/g);
    if (idMatches) {
      for (const id of idMatches) {
        if (isLikelyVariableName(id)) {
          usedVars.add(id);
        }
      }
    }

    // Analyse I/O basée sur :=
    if (withIo && line.includes(":=")) {
      const leftVars = extractVariableFromAssignment(line, "left");
      const rightVars = extractVariableFromAssignment(line, "right");

      for (const v of leftVars) {
        const baseVar = v.split(".")[0];
        if (varLocal.has(baseVar)) {
          localsWritten.add(baseVar);
        } else {
          writesToOutside.add(v);
        }
      }

      for (const v of rightVars) {
        const baseVar = v.split(".")[0];
        if (varLocal.has(baseVar)) {
          localsRead.add(baseVar);
        } else {
          readsFromOutside.add(v);
        }
      }
    }
  }

  // Calcul des entrées/sorties implicites
  const implicitInputs = Array.from(readsFromOutside).filter(v => {
    const baseVar = v.split(".")[0];
    return !varInput.has(baseVar) && !varLocal.has(baseVar);
  });

  const implicitOutputs = Array.from(writesToOutside).filter(v => {
    const baseVar = v.split(".")[0];
    return !varOutput.has(baseVar) && !varInOut.has(baseVar) && !varLocal.has(baseVar);
  });

  const result: AnalysisResult = {
    file: fileName,
    blocks: [
      {
        name: "MOCK_BLOCK",
        kind: "PROGRAM",
        ifs: ifCount,
        declaredVars: Array.from(declaredVars),
        usedVars: Array.from(usedVars),
        externalVars: [],
        undeclaredVars: [],
      },
    ],
    totalIfs: ifCount,
    totalDeclaredVars: declaredVars.length,
    totalUsedVars: usedVars.length,
    totalExternalVars: 0,
    totalUndeclaredVars: 0,
  };

  if (withIo) {
    result.io = {
      varInput: Array.from(varInput),
      varOutput: Array.from(varOutput),
      varInOut: Array.from(varInOut),
      varLocal: Array.from(varLocal),
      readsFromOutside: Array.from(readsFromOutside),
      writesToOutside: Array.from(writesToOutside),
      localsRead: Array.from(localsRead),
      localsWritten: Array.from(localsWritten),
      implicitInputs,
      implicitOutputs,
    };
  }

  return result;
}

const args = parseArgs(process.argv);

logInfo("Analyzing file (mock mode):", args.file);
const result = analyzeFileMock(args.file, args.io);

if (args.json) {
  console.log(JSON.stringify(result, null, 2));
} else {
  console.log(`File: ${result.file}`);
  console.log(`Blocks: ${result.blocks.length}`);

  if (args.stats || args.ifs || args.vars) {
    console.log("\n--- Global stats ---");
    if (args.stats || args.ifs) {
      console.log(`Total IF statements (approx): ${result.totalIfs}`);
    }
    if (args.stats || args.vars) {
      console.log(`Total declared variables (approx): ${result.totalDeclaredVars}`);
      console.log(`Total used variables (approx): ${result.totalUsedVars}`);
      console.log(`Total external variables: ${result.totalExternalVars}`);
      console.log(`Total undeclared variables: ${result.totalUndeclaredVars}`);
    }
  }

  if (args.vars) {
    console.log("\n--- Per-block variables (mock) ---");
    for (const b of result.blocks) {
      console.log(`\n${b.kind} ${b.name}:`);
      console.log("  declared:", b.declaredVars.join(", ") || "(none)");
      console.log("  used:", b.usedVars.join(", ") || "(none)");
      console.log("  external:", b.externalVars.join(", ") || "(none)");
      console.log("  undeclared:", b.undeclaredVars.join(", ") || "(none)");
    }
  }

  if (args.ifs) {
    console.log("\n--- IF statements per block (mock) ---");
    for (const b of result.blocks) {
      console.log(`${b.kind} ${b.name}: ${b.ifs} IF (approx)`);
    }
  }

  if (args.io && result.io) {
    const io = result.io;
    console.log("\n--- Rapport I/O réel (mock, basé sur :=) ---");
    console.log("\nInterface formelle :");
    console.log("  VAR_INPUT   :", io.varInput.join(", ") || "(vide)");
    console.log("  VAR_OUTPUT  :", io.varOutput.join(", ") || "(vide)");
    console.log("  VAR_IN_OUT  :", io.varInOut.join(", ") || "(vide)");
    console.log("  VAR_LOCAL   :", io.varLocal.length, "variables");

    console.log("\nFlux réel — Entrées (lectures depuis l'extérieur) :");
    console.log("  Reads from outside:", io.readsFromOutside.length, "variables");
    if (args.verbose) {
      for (const v of io.readsFromOutside.slice(0, 50)) {
        console.log("    -", v);
      }
      if (io.readsFromOutside.length > 50) {
        console.log("    ... et", io.readsFromOutside.length - 50, "autres");
      }
    }

    console.log("\nFlux réel — Sorties (écritures vers l'extérieur) :");
    console.log("  Writes to outside:", io.writesToOutside.length, "variables");
    if (args.verbose) {
      for (const v of io.writesToOutside.slice(0, 50)) {
        console.log("    -", v);
      }
      if (io.writesToOutside.length > 50) {
        console.log("    ... et", io.writesToOutside.length - 50, "autres");
      }
    }

    console.log("\nEntrées implicites (lues mais pas dans VAR_INPUT/VAR_LOCAL) :");
    console.log("  Implicit inputs:", io.implicitInputs.length, "variables");
    if (args.verbose) {
      for (const v of io.implicitInputs.slice(0, 50)) {
        console.log("    -", v);
      }
      if (io.implicitInputs.length > 50) {
        console.log("    ... et", io.implicitInputs.length - 50, "autres");
      }
    }

    console.log("\nSorties implicites (écrites mais pas dans VAR_OUTPUT/VAR_IN_OUT/VAR_LOCAL) :");
    console.log("  Implicit outputs:", io.implicitOutputs.length, "variables");
    if (args.verbose) {
      for (const v of io.implicitOutputs.slice(0, 50)) {
        console.log("    -", v);
      }
      if (io.implicitOutputs.length > 50) {
        console.log("    ... et", io.implicitOutputs.length - 50, "autres");
      }
    }
  }
}