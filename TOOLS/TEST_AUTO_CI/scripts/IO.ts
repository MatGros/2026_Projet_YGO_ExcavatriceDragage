import { walkAST, AnalysisResult, VarDeclaration, VariableExpression, VarBlock } from "strucpp";

function analyzeIO(analysis: AnalysisResult, fileName: string) {
  const varInput: string[] = [];
  const varOutput: string[] = [];
  const varInOut: string[] = [];
  const varLocal: string[] = [];
  const usedVars = new Set<string>();
  const readsFromOutside = new Set<string>();
  const writesToOutside = new Set<string>();

  // Construire la map VarDeclaration → VarBlock
  const varBlockMap = buildVarBlockMap(analysis.ast);

  // Parcourir l'AST
  walkAST(analysis.ast, (node) => {
    // Filtrer au fichier demandé
    if (!node.sourceSpan || node.sourceSpan.file !== fileName) return;

    switch (node.kind) {
      case "VarDeclaration":
        // Extraire les déclarations de variables
        const vd = node as VarDeclaration;
        const parentBlock = varBlockMap.get(vd);
        const blockType = parentBlock?.blockType;

        for (const name of vd.names) {
          if (blockType === "VAR_INPUT") varInput.push(name);
          else if (blockType === "VAR_OUTPUT") varOutput.push(name);
          else if (blockType === "VAR_IN_OUT") varInOut.push(name);
          else varLocal.push(name);
        }
        break;

      case "VariableExpression":
        // Extraire les variables utilisées
        const ve = node as VariableExpression;
        usedVars.add(ve.name);
        break;

      // ... autres cas pour les assignments, etc.
    }
  });

  return { varInput, varOutput, varInOut, varLocal, usedVars, readsFromOutside, writesToOutside };
}

// Helper : construire la map VarDeclaration → VarBlock
function buildVarBlockMap(ast: AnalysisResult["ast"]) {
  const map = new Map<VarDeclaration, VarBlock>();

  function indexBlocks(blocks: VarBlock[]) {
    for (const block of blocks) {
      for (const decl of block.declarations) {
        map.set(decl, block);
      }
    }
  }

  for (const prog of ast.programs) indexBlocks(prog.varBlocks);
  for (const func of ast.functions) indexBlocks(func.varBlocks);
  for (const fb of ast.functionBlocks) {
    indexBlocks(fb.varBlocks);
    for (const method of fb.methods) indexBlocks(method.varBlocks);
  }
  if (ast.globalVarBlocks) indexBlocks(ast.globalVarBlocks);

  return map;
}