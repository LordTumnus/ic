import { styleTags, tags as t } from '@lezer/highlight';

/**
 * Syntax highlighting tag mapping for MATLAB grammar nodes.
 *
 * Maps Lezer node names to @lezer/highlight tags, which CodeMirror
 * then resolves to CSS classes via a HighlightStyle.
 */
export const matlabHighlighting = styleTags({
  // Keywords — control flow
  'if elseif else end for while switch case otherwise': t.controlKeyword,
  'try catch': t.controlKeyword,
  'break continue return': t.controlKeyword,

  // Keywords — definitions
  'function classdef methods properties events enumeration arguments': t.definitionKeyword,

  // Keywords — modifiers
  'global persistent import': t.modifier,

  // Literals
  Number: t.number,
  String: t.string,
  CharArray: t.string,
  BooleanLiteral: t.bool,

  // Identifiers
  Identifier: t.variableName,
  PropertyName: t.propertyName,
  'FunctionDeclaration/Identifier': t.function(t.definition(t.variableName)),
  'CallExpression/Identifier': t.function(t.variableName),
  'ClassDefinition/Identifier': t.definition(t.className),
  'FunctionHandle/Identifier': t.special(t.variableName),

  // Operators
  ArithOp: t.arithmeticOperator,
  CompareOp: t.compareOperator,
  LogicOp: t.logicOperator,
  Transpose: t.operator,
  '=': t.definitionOperator,

  // Comments
  LineComment: t.lineComment,
  BlockComment: t.blockComment,

  // Punctuation
  '( )': t.paren,
  '[ ]': t.squareBracket,
  '{ }': t.brace,
  '. , ;': t.separator,
  ':': t.punctuation,
  '~': t.special(t.variableName),
  '@': t.meta,
  '?': t.meta,

  // Structural
  EndExpression: t.keyword,
  MetaclassExpression: t.typeName,
});
