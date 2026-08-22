import * as vscode from 'vscode';
import * as path from 'path';
import * as cp from 'child_process';
import * as fs from 'fs';

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
                lintFilePath(doc.fileName);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('linterSt.lintSelection', (uri: vscode.Uri, uris?: vscode.Uri[]) =>
            lintSelectionCommand(uris && uris.length > 0 ? uris : uri ? [uri] : [])
        ),
        vscode.commands.registerCommand('linterSt.lintWorkspace', () => lintWorkspaceCommand())
    );
}

/** Resout lint.py + --code-root pour un workspace donne (memes regles que le mode sauvegarde). */
function resolveLintInvocation(workspaceFolder: vscode.WorkspaceFolder): { pythonPath: string; lintScript: string; codeRoot: string } {
    const config = vscode.workspace.getConfiguration('linterSt');
    const pythonPath = config.get<string>('pythonPath', 'python');
    const codeRootSetting = config.get<string>('codeRoot', 'CODE');
    const lintScriptSetting = config.get<string>('lintScriptPath', 'TOOLS/LINTER_ST/lint.py');

    // lint.py est resolu relativement au WORKSPACE ouvert, pas au dossier d'installation de
    // l'extension (context.extensionPath) : une fois installee via .vsix, l'extension tourne
    // depuis ~/.vscode/extensions/... -- un dossier totalement separe du repo, qui ne contient
    // que le TypeScript compile (le .vsix n'embarque jamais lint.py/resolve_deps.py/strucpp.exe,
    // 58 Mo). Cet outil est fait pour UN repo precis (celui qui porte TOOLS/LINTER_ST/) : on
    // suppose que le workspace ouvert EST ce repo (bug verifie empiriquement, session 2026-08-23).
    const lintScript = path.isAbsolute(lintScriptSetting)
        ? lintScriptSetting
        : path.join(workspaceFolder.uri.fsPath, lintScriptSetting);
    const codeRoot = path.join(workspaceFolder.uri.fsPath, codeRootSetting);

    return { pythonPath, lintScript, codeRoot };
}

/** Lance lint.py sur un fichier, retourne le resultat JSON ou null (erreur usage/sortie non-JSON,
 * deja loguee dans Output). */
function runLint(fsPath: string, workspaceFolder: vscode.WorkspaceFolder): Promise<LintResult | null> {
    const { pythonPath, lintScript, codeRoot } = resolveLintInvocation(workspaceFolder);

    return new Promise((resolve) => {
        cp.execFile(
            pythonPath,
            [lintScript, fsPath, '--code-root', codeRoot],
            { cwd: workspaceFolder.uri.fsPath, maxBuffer: 10 * 1024 * 1024 },
            (_error, stdout, stderr) => {
                // lint.py sort avec un code != 0 pour "errors" (1) et "incomplete" (2) --
                // execFile remonte ca comme _error, mais stdout reste un JSON valide dans ces
                // deux cas (seul le code 3, usage, n'a rien d'exploitable sur stdout).
                try {
                    resolve(JSON.parse(stdout));
                } catch {
                    outputChannel.appendLine(`[ERREUR] Sortie non-JSON pour ${fsPath} :`);
                    outputChannel.appendLine(stdout);
                    if (stderr) {
                        outputChannel.appendLine(stderr);
                    }
                    resolve(null);
                }
            }
        );
    });
}

async function lintFilePath(fsPath: string): Promise<LintResult | null> {
    const config = vscode.workspace.getConfiguration('linterSt');
    if (!config.get<boolean>('enableSyntaxCheck', true)) {
        // Interrupteur general : coupe la couche base (compilation STruCpp) sans desinstaller
        // l'extension. La couche standards projet (enableProjectRules) n'existe pas encore --
        // rien a executer dans ce cas non plus.
        diagnosticCollection.delete(vscode.Uri.file(fsPath));
        return null;
    }

    const uri = vscode.Uri.file(fsPath);
    const workspaceFolder = vscode.workspace.getWorkspaceFolder(uri);
    if (!workspaceFolder) {
        outputChannel.appendLine(`[SKIP] ${fsPath} -- hors workspace, impossible de resoudre --code-root`);
        return null;
    }

    const result = await runLint(fsPath, workspaceFolder);
    if (result) {
        const doc = await vscode.workspace.openTextDocument(uri);
        applyResult(doc, result);
    }
    return result;
}

/** Trouve recursivement tous les .st sous un dossier (ou le fichier lui-meme s'il en est un). */
async function collectStFiles(fsPath: string): Promise<string[]> {
    const stat = await fs.promises.stat(fsPath);
    if (stat.isFile()) {
        return fsPath.toLowerCase().endsWith('.st') ? [fsPath] : [];
    }

    const out: string[] = [];
    const entries = await fs.promises.readdir(fsPath, { withFileTypes: true });
    for (const entry of entries) {
        const full = path.join(fsPath, entry.name);
        if (entry.isDirectory()) {
            out.push(...(await collectStFiles(full)));
        } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.st')) {
            out.push(full);
        }
    }
    return out;
}

async function lintBatch(files: string[], label: string): Promise<void> {
    if (files.length === 0) {
        vscode.window.showInformationMessage(`Linter ST : aucun fichier .st trouve dans ${label}.`);
        return;
    }

    let errorFiles = 0;
    let incompleteFiles = 0;

    await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Notification, title: `Linter ST : analyse de ${label}`, cancellable: false },
        async (progress) => {
            for (let i = 0; i < files.length; i++) {
                const file = files[i];
                progress.report({ message: `${i + 1}/${files.length} -- ${path.basename(file)}`, increment: 100 / files.length });
                const result = await lintFilePath(file);
                if (result?.status === 'errors') {
                    errorFiles++;
                } else if (result?.status === 'incomplete') {
                    incompleteFiles++;
                }
            }
        }
    );

    const parts = [`${files.length} fichier(s) analyse(s)`];
    if (errorFiles > 0) {
        parts.push(`${errorFiles} avec erreur(s)`);
    }
    if (incompleteFiles > 0) {
        parts.push(`${incompleteFiles} incomplet(s) (voir Output "Linter ST")`);
    }
    const message = `Linter ST -- ${parts.join(', ')}.`;
    if (errorFiles > 0) {
        vscode.window.showWarningMessage(message);
    } else {
        vscode.window.showInformationMessage(message);
    }
}

async function lintSelectionCommand(uris: vscode.Uri[]): Promise<void> {
    if (uris.length === 0) {
        vscode.window.showWarningMessage('Linter ST : aucune selection (clic droit sur un dossier ou fichier .st dans l\'Explorateur).');
        return;
    }
    const files: string[] = [];
    for (const uri of uris) {
        files.push(...(await collectStFiles(uri.fsPath)));
    }
    await lintBatch(files, uris.length === 1 ? path.basename(uris[0].fsPath) : `${uris.length} elements selectionnes`);
}

async function lintWorkspaceCommand(): Promise<void> {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showWarningMessage('Linter ST : aucun workspace ouvert.');
        return;
    }
    const codeRootSetting = vscode.workspace.getConfiguration('linterSt').get<string>('codeRoot', 'CODE');
    const codeRoot = path.join(workspaceFolder.uri.fsPath, codeRootSetting);
    const files = await collectStFiles(codeRoot);
    await lintBatch(files, codeRootSetting);
}

function applyResult(doc: vscode.TextDocument, result: LintResult) {
    if (result.status === 'incomplete') {
        // Priorite "zero faux positif" MAINTENUE : ceci n'est jamais une erreur (pas de
        // vscode.DiagnosticSeverity.Error), juste un avertissement informatif -- le linter
        // n'affirme rien sur un bug potentiel, il signale seulement qu'il n'a pas pu conclure
        // (type externe hors CODE/, ex: DEVICE_STATE natif CODESYS/CANopen). Avant : silence
        // total sauf Output, facile a manquer (demande utilisateur, session 2026-08-23).
        const range = new vscode.Range(new vscode.Position(0, 0), new vscode.Position(0, 1));
        const message = `Analyse incomplete -- type(s) hors CODE/ non resolu(s), verification partielle seulement : ${result.unresolved_types.join(', ')}`;
        const diag = new vscode.Diagnostic(range, message, vscode.DiagnosticSeverity.Warning);
        diag.source = 'linter-st';
        diagnosticCollection.set(doc.uri, [diag]);
        outputChannel.appendLine(`[INCOMPLET] ${doc.fileName} -- ${message}`);
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
