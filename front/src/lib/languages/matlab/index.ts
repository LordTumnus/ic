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
export const matlabLanguage = LRLanguage.define({
  name: 'matlab',
  parser: parser.configure({
    props: [
      indentNodeProp.add({
        FunctionDeclaration: (cx) => cx.baseIndent + cx.unit,
        IfStatement: (cx) => cx.baseIndent + cx.unit,
        ElseifClause: (cx) => cx.baseIndent + cx.unit,
        ElseClause: (cx) => cx.baseIndent + cx.unit,
        ForStatement: (cx) => cx.baseIndent + cx.unit,
        WhileStatement: (cx) => cx.baseIndent + cx.unit,
        SwitchStatement: (cx) => cx.baseIndent + cx.unit,
        CaseClause: (cx) => cx.baseIndent + cx.unit,
        OtherwiseClause: (cx) => cx.baseIndent + cx.unit,
        TryCatchStatement: (cx) => cx.baseIndent + cx.unit,
        CatchClause: (cx) => cx.baseIndent + cx.unit,
        ClassDefinition: (cx) => cx.baseIndent + cx.unit,
        PropertiesBlock: (cx) => cx.baseIndent + cx.unit,
        MethodsBlock: (cx) => cx.baseIndent + cx.unit,
        EventsBlock: (cx) => cx.baseIndent + cx.unit,
        EnumerationBlock: (cx) => cx.baseIndent + cx.unit,
        ArgumentsBlock: (cx) => cx.baseIndent + cx.unit,
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
