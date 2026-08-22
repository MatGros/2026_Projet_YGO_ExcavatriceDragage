import * as vscode from 'vscode';
import * as path from 'path';
import * as cp from 'child_process';

// Extension minimale (pas de LSP) : diagnostics pousses a la sauvegarde d'un .st, via le
// linter Python autonome TOOLS/LINTER_ST/lint.py (encapsule, aucune dependance externe a ce
// dossier). Voir TOOLS/LINTER_ST/README.md pour le comportement du linter lui-meme.

interface LintDiagnostic {
    file: string;
    line: number;
    col: number;
    severity: 'error' | 'warning';
    message: string;
}

interface LintResult {
    status: 'clean' | 'errors' | 'incomplete';
    target: string;
    diagnostics: LintDiagnostic[];
    unresolved_types: string[];
}

let diagnosticCollection: vscode.DiagnosticCollection;
let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
    diagnosticCollection = vscode.languages.createDiagnosticCollection('linter-st');
    outputChannel = vscode.window.createOutputChannel('Linter ST');
    context.subscriptions.push(diagnosticCollection, outputChannel);

    context.subscriptions.push(
        vscode.workspace.onDidSaveTextDocument((doc) => {
            if (doc.fileName.toLowerCase().endsWith('.st')) {
                lintDocument(doc, context);
            }
        })
    );
}

function lintDocument(doc: vscode.TextDocument, context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('linterSt');
    const pythonPath = config.get<string>('pythonPath', 'python');
    const codeRootSetting = config.get<string>('codeRoot', 'CODE');
    const lintScriptSetting = config.get<string>('lintScriptPath', 'TOOLS/LINTER_ST/lint.py');

    const workspaceFolder = vscode.workspace.getWorkspaceFolder(doc.uri);
    if (!workspaceFolder) {
        outputChannel.appendLine(`[SKIP] ${doc.fileName} -- hors workspace, impossible de resoudre --code-root`);
        return;
    }

    // lint.py est resolu relativement au WORKSPACE ouvert, pas au dossier d'installation de
    // l'extension (context.extensionPath) : une fois installee via .vsix, l'extension tourne
    // depuis ~/.vscode/extensions/... -- un dossier totalement separe du repo, qui ne contient
    // que le TypeScript compile (le .vsix n'embarque jamais lint.py/resolve_deps.py/strucpp.exe,
    // 58 Mo). Cet outil est fait pour UN repo precis (celui qui porte TOOLS/LINTER_ST/) : on
    // suppose que le workspace ouvert EST ce repo, comme convert_codesys_to_iec et strucpp.exe
    // deja verses dans TOOLS/LINTER_ST/ (bug verifie empiriquement, session 2026-08-23 : "python:
    // can't open file '~/.vscode/extensions/lint.py'" apres install .vsix reelle).
    const lintScript = path.isAbsolute(lintScriptSetting)
        ? lintScriptSetting
        : path.join(workspaceFolder.uri.fsPath, lintScriptSetting);
    const codeRoot = path.join(workspaceFolder.uri.fsPath, codeRootSetting);

    cp.execFile(
        pythonPath,
        [lintScript, doc.fileName, '--code-root', codeRoot],
        { cwd: workspaceFolder.uri.fsPath, maxBuffer: 10 * 1024 * 1024 },
        (_error, stdout, stderr) => {
            // lint.py sort avec un code != 0 pour "errors" (1) et "incomplete" (2) --
            // execFile remonte ca comme _error, mais stdout reste un JSON valide dans ces deux
            // cas (seul le code 3, usage, n'a rien d'exploitable sur stdout).
            let result: LintResult;
            try {
                result = JSON.parse(stdout);
            } catch {
                outputChannel.appendLine(`[ERREUR] Sortie non-JSON pour ${doc.fileName} :`);
                outputChannel.appendLine(stdout);
                if (stderr) {
                    outputChannel.appendLine(stderr);
                }
                return;
            }

            applyResult(doc, result);
        }
    );
}

function applyResult(doc: vscode.TextDocument, result: LintResult) {
    if (result.status === 'incomplete') {
        // Priorite "zero faux positif" : aucune alerte visuelle si une dependance de type
        // n'a pas pu etre resolue -- seulement une trace dans Output pour comprendre pourquoi
        // rien n'est remonte.
        diagnosticCollection.delete(doc.uri);
        outputChannel.appendLine(
            `[INCOMPLET] ${doc.fileName} -- type(s) non resolu(s), aucune alerte emise : ${result.unresolved_types.join(', ')}`
        );
        return;
    }

    if (result.status === 'clean') {
        diagnosticCollection.delete(doc.uri);
        return;
    }

    const diagnostics: vscode.Diagnostic[] = result.diagnostics.map((d) => {
        // lint.py fournit ligne/colonne 1-based (STruCpp) ; VSCode attend du 0-based.
        // Une erreur de tokenisation brute (ex: caractere accentue invalide) peut remonter
        // line=0 -- fallback sur le debut du document dans ce cas.
        const line = Math.max(0, d.line - 1);
        const col = Math.max(0, d.col - 1);
        const lineLength = line < doc.lineCount ? doc.lineAt(line).text.length : col + 1;
        const range = new vscode.Range(
            new vscode.Position(line, col),
            new vscode.Position(line, Math.max(col + 1, lineLength))
        );
        const severity =
            d.severity === 'warning' ? vscode.DiagnosticSeverity.Warning : vscode.DiagnosticSeverity.Error;
        const diag = new vscode.Diagnostic(range, d.message, severity);
        diag.source = 'linter-st';
        return diag;
    });

    diagnosticCollection.set(doc.uri, diagnostics);
}

export function deactivate() {
    diagnosticCollection?.dispose();
    outputChannel?.dispose();
}
