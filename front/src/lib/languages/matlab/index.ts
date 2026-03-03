import {
  LRLanguage,
  LanguageSupport,
  indentNodeProp,
  foldNodeProp,
  foldInside,
} from '@codemirror/language';
import { parser } from './matlab.grammar';

/**
 * MATLAB LR language definition for CodeMirror 6.
 *
 * Configures the Lezer parser with:
 * - Indentation rules for block structures (function, if, for, while, etc.)
 * - Code folding for functions, classes, control flow blocks
 * - Language metadata (comment tokens, bracket closing, indent triggers)
 *
 * The highlighting is loaded via @external propSource in the grammar file,
 * so it doesn't need to be configured here.
 */
// Indent helpers: dedent when the line being indented starts with a
// closing keyword (end, else, elseif, case, otherwise, catch).
const endRe = /^\s*end\b/;
const endElseRe = /^\s*(end|else|elseif)\b/;
const endCaseRe = /^\s*(end|case|otherwise)\b/;
const endCatchRe = /^\s*(end|catch)\b/;

type IndentCx = { baseIndent: number; unit: number; textAfter: string };
const block = (re: RegExp = endRe) => (cx: IndentCx) =>
  cx.baseIndent + (re.test(cx.textAfter) ? 0 : cx.unit);

export const matlabLanguage = LRLanguage.define({
  name: 'matlab',
  parser: parser.configure({
    props: [
      indentNodeProp.add({
        FunctionDeclaration: block(),
        IfStatement: block(endElseRe),
        ElseifClause: block(endElseRe),
        ElseClause: block(),
        ForStatement: block(),
        WhileStatement: block(),
        SwitchStatement: block(endCaseRe),
        CaseClause: block(endCaseRe),
        OtherwiseClause: block(),
        TryCatchStatement: block(endCatchRe),
        CatchClause: block(),
        ClassDefinition: block(),
        PropertiesBlock: block(),
        MethodsBlock: block(),
        EventsBlock: block(),
        EnumerationBlock: block(),
        ArgumentsBlock: block(),
        SpmdStatement: block(),
        ParforStatement: block(),
      }),
      foldNodeProp.add({
        FunctionDeclaration: foldInside,
        IfStatement: foldInside,
        ForStatement: foldInside,
        WhileStatement: foldInside,
        SwitchStatement: foldInside,
        TryCatchStatement: foldInside,
        ClassDefinition: foldInside,
        PropertiesBlock: foldInside,
        MethodsBlock: foldInside,
        EventsBlock: foldInside,
        EnumerationBlock: foldInside,
        ArgumentsBlock: foldInside,
        BlockComment(node) { return { from: node.from + 2, to: node.to - 2 }; },
      }),
    ],
  }),
  languageData: {
    commentTokens: { line: '%', block: { open: '%{', close: '%}' } },
    closeBrackets: { brackets: ['(', '[', '{', '"', "'"] },
    indentOnInput: /^\s*(end|else|elseif|case|otherwise|catch)\b/,
  },
});

/** Complete MATLAB language support for CodeMirror 6. */
export function matlab(): LanguageSupport {
  return new LanguageSupport(matlabLanguage);
}
